const mongoose = require('mongoose');
const nodemailer = require('nodemailer');
const AppError = require('../utils/appError');
const { catchAsync } = require('../utils/catchAsync');
const ConversionRate = require('../models/conversionRateModel');
const MemberWallet = require('../models/memberWalletModel');
const PointWallet = require('../models/point_walletModel');
const PointHistory = require('../models/point_historyModel');
const Member = require('../models/MemberModel');
const Budget = require('../models/budgetModel');
const Expense = require('../models/ExpenseModel');
const FutureEvent = require('../models/futureEventModel');
const Wishlist = require('../models/wishlistModel');
const WishlistItem = require('../models/wishlist_itemModel');
const WishlistCategory = require('../models/wishlist_categoryModel');
const WalletTransaction = require('../models/walletTransactionModel');
const MemberType = require('../models/MemberTypeModel');
const Redeem = require('../models/redeemModel');
const MemberAllowance = require('../models/memberAllowanceModel');
const PeriodBudget = require('../models/periodBudgetModel');
const BudgetAllocation = require('../models/budgetAllocationModel');
const InventoryCategory = require('../models/inventoryCategoryModel');
const BalanceWalletDetail = require('../models/balanceWalletDetailModel');
const { recordBalanceWalletDetail } = require('../utils/balanceWalletDetailHelper');

const DEFAULT_MONEY_TO_POINTS_RATE = 10;
const DEFAULT_POINTS_TO_MONEY_RATE = 0.05;

const getActiveConversionRate = async (familyId) => {
	const conversionRate = await ConversionRate.findOne({
		family_id: familyId,
		is_active: true,
	}).sort({ updated_at: -1, created_at: -1 });

	if (!conversionRate) {
		return {
			money_to_points_rate: DEFAULT_MONEY_TO_POINTS_RATE,
			points_to_money_rate: DEFAULT_POINTS_TO_MONEY_RATE,
			is_active: true,
			source: 'default',
		};
	}

	return conversionRate;
};

const ensureMoneyWallet = async (memberMail, familyId) => {
	let wallet = await MemberWallet.findOne({ member_mail: memberMail, family_id: familyId });

	if (!wallet) {
		wallet = await MemberWallet.create({
			member_mail: memberMail,
			family_id: familyId,
			balance: 0,
		});
	}

	return wallet;
};

const ensurePointWallet = async (memberMail, familyId) => {
	let wallet = await PointWallet.findOne({ member_mail: memberMail, family_id: familyId });

	if (!wallet) {
		wallet = await PointWallet.create({
			member_mail: memberMail,
			family_id: familyId,
			total_points: 0,
		});
	}

	return wallet;
};

const getFamilyParents = async (familyId) => {
	const members = await Member.find({ family_id: familyId })
		.populate('member_type_id', 'type')
		.select('mail username member_type_id');

	return members.filter((member) => member.member_type_id?.type === 'Parent');
};

const sendParentNotification = async (familyId, subject, text, html) => {
	const parents = await getFamilyParents(familyId);
	const recipientEmails = parents.map((parent) => parent.mail).filter(Boolean);

	if (recipientEmails.length === 0) {
		return { sent: false, recipients: [] };
	}

	const emailUser = process.env.EMAIL_USERNAME || process.env.EMAIL_USER;
	const emailPass = process.env.EMAIL_PASSWORD || process.env.EMAIL_PASS;

	if (!emailUser || !emailPass) {
		return { sent: false, recipients: recipientEmails, reason: 'email credentials are not configured' };
	}

	const transporter = nodemailer.createTransport({
		service: 'gmail',
		auth: {
			user: emailUser,
			pass: emailPass,
		},
	});

	await transporter.sendMail({
		from: emailUser,
		to: recipientEmails,
		subject,
		text,
		html: html || text,
	});

	return { sent: true, recipients: recipientEmails };
};

const getRewardsBudget = async (familyId) => {
	return Budget.findOne({ family_id: familyId, category_name: 'Rewards', is_active: true });
};

const computeUsagePercentage = (spent, total) => {
	if (!Number.isFinite(total) || total <= 0) return 0;
	return Number(Math.min(100, ((spent / total) * 100)).toFixed(2));
};

const computeRemaining = (total, spent) => {
	return Number(Math.max(0, (Number(total || 0) - Number(spent || 0))).toFixed(2));
};

const getActivePersonalAllowance = async (familyId, memberMail, expenseDate = new Date()) => {
	const normalizedDate = new Date(expenseDate);
	const allowanceFilter = {
		family_id: familyId,
		member_mail: memberMail,
	};

	const periodAllowance = await MemberAllowance.findOne({
		...allowanceFilter,
		$or: [
			{ start_date: null, end_date: null },
			{ start_date: { $lte: normalizedDate }, end_date: { $gte: normalizedDate } },
		],
	}).sort({ createdAt: -1 });

	if (periodAllowance) {
		return periodAllowance;
	}

	const latestAllowance = await MemberAllowance.findOne(allowanceFilter).sort({ createdAt: -1 });
	if (latestAllowance) {
		return latestAllowance;
	}

	return MemberAllowance.create({
		family_id: familyId,
		member_mail: memberMail,
		period_type: 'custom',
		start_date: normalizedDate,
		end_date: normalizedDate,
		money_amount: 0,
		spent_amount: 0,
		last_activity_at: normalizedDate,
	});
};

const logBalanceWalletDetail = async (payload) => {
	try {
		return await recordBalanceWalletDetail(payload);
	} catch (_) {
		return null;
	}
};

exports.createExpense = catchAsync(async (req, res, next) => {
	const {
		title,
		amount,
		description,
		notes,
		expense_date,
		category,
		budget_id,
		budget_category_id,
		expense_scope,
		source_module,
	} = req.body;

	if (!title || amount === undefined) {
		return next(new AppError('Please provide title and amount', 400));
	}

	const normalizedAmount = Number(amount);
	if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
		return next(new AppError('amount must be a positive number', 400));
	}

	const normalizedScope = (expense_scope || 'shared').toLowerCase();
	if (!['shared', 'personal'].includes(normalizedScope)) {
		return next(new AppError('expense_scope must be shared or personal', 400));
	}

	const expenseDate = expense_date ? new Date(expense_date) : new Date();
	if (Number.isNaN(expenseDate.getTime())) {
		return next(new AppError('expense_date must be a valid date', 400));
	}

	let linkedBudget = null;
	let linkedAllowance = null;
	let expenseSource = normalizedScope === 'personal' ? 'personal_budget' : 'budget';

	if (normalizedScope === 'shared') {
		if (!budget_id || !mongoose.Types.ObjectId.isValid(budget_id)) {
			return next(new AppError('Please provide a valid budget_id for shared expenses', 400));
		}

		linkedBudget = await PeriodBudget.findOne({ _id: budget_id, family_id: req.familyAccount._id, is_active: true });
		if (!linkedBudget) {
			return next(new AppError('Shared budget not found', 404));
		}

		linkedBudget.spent_amount = Number((Number(linkedBudget.spent_amount || 0) + normalizedAmount).toFixed(2));
		await linkedBudget.save();

		if (budget_category_id && mongoose.Types.ObjectId.isValid(budget_category_id)) {
			await BudgetAllocation.findOneAndUpdate(
				{ period_budget_id: linkedBudget._id, inventory_category_id: budget_category_id, is_active: true },
				{ $inc: { spent_amount: normalizedAmount } }
			);
		}
	} else {
		linkedAllowance = await getActivePersonalAllowance(req.familyAccount._id, req.member.mail, expenseDate);
		linkedAllowance.money_amount = Number(Number(linkedAllowance.money_amount || 0).toFixed(2));
		linkedAllowance.spent_amount = Number((Number(linkedAllowance.spent_amount || 0) + normalizedAmount).toFixed(2));
		linkedAllowance.last_activity_at = new Date();
		await linkedAllowance.save();

		const memberWallet = await ensureMoneyWallet(req.member.mail, req.familyAccount._id);
		const prevWalletBalance = Number(memberWallet.balance || 0);
		memberWallet.balance = Number(Math.max(0, prevWalletBalance - normalizedAmount).toFixed(2));
		memberWallet.last_update = new Date();
		await memberWallet.save();
	}

	const expense = await Expense.create({
		family_id: req.familyAccount._id,
		member_id: req.member._id,
		member_mail: req.member.mail,
		category: category || 'General',
		title,
		amount: normalizedAmount,
		description: description || '',
		notes: notes || source_module || '',
		expense_date: expenseDate,
		expense_source: expenseSource,
		expense_scope: normalizedScope,
		budget_id: linkedBudget?._id || budget_id || null,
		budget_category_id: budget_category_id && mongoose.Types.ObjectId.isValid(budget_category_id)
			? budget_category_id
			: null,
		linked_member_allowance_id: linkedAllowance?._id || null,
		is_finalized: true,
		finalized_at: new Date(),
	});

	await logBalanceWalletDetail({
		family_id: req.familyAccount._id,
		member_id: req.member._id,
		member_mail: req.member.mail,
		wallet_scope: normalizedScope === 'personal' ? 'personal_budget' : 'shared_budget',
		change_type: 'debit',
		source_type: 'expense',
		amount: normalizedAmount,
		previous_balance: normalizedScope === 'personal'
			? Number((Number(linkedAllowance?.money_amount || 0) + Number(normalizedAmount || 0)).toFixed(2))
			: Number((Number(linkedBudget?.total_amount || 0) - Number(linkedBudget?.spent_amount || 0) + Number(normalizedAmount || 0)).toFixed(2)),
		new_balance: normalizedScope === 'personal'
			? Number(Math.max(0, Number(linkedAllowance?.money_amount || 0) - Number(linkedAllowance?.spent_amount || 0)).toFixed(2))
			: Number(Math.max(0, Number(linkedBudget?.total_amount || 0) - Number(linkedBudget?.spent_amount || 0)).toFixed(2)),
		title,
		description: description || '',
		added_by_member_id: req.member._id,
		added_by_mail: req.member.mail,
		linked_expense_id: expense._id,
		budget_id: linkedBudget?._id || budget_id || null,
		budget_category_id: budget_category_id && mongoose.Types.ObjectId.isValid(budget_category_id)
			? budget_category_id
			: null,
		notes: source_module || 'manual expense',
	});

	res.status(201).json({
		status: 'success',
		message: normalizedScope === 'personal'
			? 'Personal expense recorded successfully'
			: 'Shared expense recorded successfully',
		data: {
			expense,
			budget: linkedBudget,
			personal_budget: linkedAllowance,
		},
	});
});

const recalcPeriodSpent = async (periodBudgetId) => {
	const aggregate = await BudgetAllocation.aggregate([
		{ $match: { period_budget_id: periodBudgetId, is_active: true } },
		{ $group: { _id: null, totalSpent: { $sum: '$spent_amount' } } },
	]);

	const totalSpent = Number(aggregate[0]?.totalSpent || 0);
	await PeriodBudget.findByIdAndUpdate(periodBudgetId, { $set: { spent_amount: Number(totalSpent.toFixed(2)) } });
	return totalSpent;
};

exports.createPeriodBudget = catchAsync(async (req, res, next) => {
	const {
		title,
		period_type,
		start_date,
		end_date,
		total_amount,
		currency,
		threshold_percentage,
	} = req.body;

	if (!title || !period_type || !start_date || !end_date || total_amount === undefined) {
		return next(new AppError('Please provide title, period_type, start_date, end_date and total_amount', 400));
	}

	if (!['weekly', 'monthly', 'yearly', 'custom'].includes(period_type)) {
		return next(new AppError('period_type must be weekly, monthly, yearly, or custom', 400));
	}

	const totalAmount = Number(total_amount);
	if (!Number.isFinite(totalAmount) || totalAmount <= 0) {
		return next(new AppError('total_amount must be a positive number', 400));
	}

	const startDate = new Date(start_date);
	const endDate = new Date(end_date);
	if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
		return next(new AppError('start_date and end_date must be valid dates', 400));
	}

	if (endDate < startDate) {
		return next(new AppError('end_date must be greater than or equal to start_date', 400));
	}

	const threshold = threshold_percentage === undefined ? 15 : Number(threshold_percentage);
	if (!Number.isFinite(threshold) || threshold < 0 || threshold > 100) {
		return next(new AppError('threshold_percentage must be between 0 and 100', 400));
	}

	const periodBudget = await PeriodBudget.create({
		family_id: req.familyAccount._id,
		title,
		period_type,
		start_date: startDate,
		end_date: endDate,
		total_amount: totalAmount,
		currency: currency || 'EGP',
		threshold_percentage: threshold,
		created_by: req.member._id,
	});

	res.status(201).json({
		status: 'success',
		message: 'Period budget created successfully',
		data: {
			period_budget: periodBudget,
			remaining_amount: computeRemaining(periodBudget.total_amount, periodBudget.spent_amount),
			usage_percentage: computeUsagePercentage(periodBudget.spent_amount, periodBudget.total_amount),
		},
	});
});

exports.getPeriodBudgets = catchAsync(async (req, res, next) => {
	const { include_inactive, active_on } = req.query;
	const filter = {
		family_id: req.familyAccount._id,
	};

	if (include_inactive !== 'true') {
		filter.is_active = true;
	}

	if (active_on) {
		const activeDate = new Date(active_on);
		if (Number.isNaN(activeDate.getTime())) {
			return next(new AppError('active_on must be a valid date', 400));
		}

		filter.start_date = { $lte: activeDate };
		filter.end_date = { $gte: activeDate };
	}

	const periodBudgets = await PeriodBudget.find(filter).sort({ start_date: -1, createdAt: -1 });
	const periodIds = periodBudgets.map((item) => item._id);

	const allocations = await BudgetAllocation.find({
		family_id: req.familyAccount._id,
		period_budget_id: { $in: periodIds },
		is_active: true,
	}).populate('inventory_category_id', 'title');

	const allocationsByPeriod = new Map();
	for (const allocation of allocations) {
		const key = allocation.period_budget_id.toString();
		if (!allocationsByPeriod.has(key)) allocationsByPeriod.set(key, []);
		allocationsByPeriod.get(key).push(allocation);
	}

	const enriched = periodBudgets.map((budget) => {
		const periodAllocations = allocationsByPeriod.get(budget._id.toString()) || [];
		const totalAllocated = periodAllocations.reduce((sum, item) => sum + Number(item.allocated_amount || 0), 0);

		return {
			...budget.toObject(),
			allocation_count: periodAllocations.length,
			total_allocated: Number(totalAllocated.toFixed(2)),
			remaining_amount: computeRemaining(budget.total_amount, budget.spent_amount),
			usage_percentage: computeUsagePercentage(budget.spent_amount, budget.total_amount),
			allocations: periodAllocations,
		};
	});

	res.status(200).json({
		status: 'success',
		results: enriched.length,
		data: { period_budgets: enriched },
	});
});

exports.getInventoryBudgetSummary = catchAsync(async (req, res, next) => {
	const { active_on, period_budget_id, include_periods } = req.query;
	const activeDate = active_on ? new Date(active_on) : new Date();

	if (Number.isNaN(activeDate.getTime())) {
		return next(new AppError('active_on must be a valid date', 400));
	}

	let periodBudget = null;

	if (period_budget_id) {
		if (!mongoose.Types.ObjectId.isValid(period_budget_id)) {
			return next(new AppError('period_budget_id must be a valid ID', 400));
		}

		periodBudget = await PeriodBudget.findOne({
			_id: period_budget_id,
			family_id: req.familyAccount._id,
		});

		if (!periodBudget) {
			return next(new AppError('Selected period budget not found', 404));
		}
	} else {
		periodBudget = await PeriodBudget.findOne({
			family_id: req.familyAccount._id,
			is_active: true,
			start_date: { $lte: activeDate },
			end_date: { $gte: activeDate },
		}).sort({ start_date: -1, createdAt: -1 });
	}

	let availablePeriodBudgets = [];
	if (include_periods === 'true') {
		availablePeriodBudgets = await PeriodBudget.find({
			family_id: req.familyAccount._id,
			is_active: true,
		})
			.sort({ start_date: -1, createdAt: -1 })
			.limit(12)
			.select('_id title period_type start_date end_date total_amount spent_amount currency');
	}

	if (!periodBudget) {
		return res.status(200).json({
			status: 'success',
			data: {
				selected_period_budget_id: null,
				available_period_budgets: availablePeriodBudgets,
				period_budget: null,
				categories: [],
				totals: { allocated: 0, spent: 0, remaining: 0 },
			},
		});
	}

	const allocations = await BudgetAllocation.find({
		family_id: req.familyAccount._id,
		period_budget_id: periodBudget._id,
		is_active: true,
	}).populate('inventory_category_id', 'title');

	const categories = allocations
		.map((allocation) => {
			const allocatedAmount = Number(allocation.allocated_amount || 0);
			const spentAmount = Number(allocation.spent_amount || 0);
			const remainingAmount = computeRemaining(allocatedAmount, spentAmount);

			return {
				allocation_id: allocation._id,
				inventory_category_id: allocation.inventory_category_id?._id || null,
				inventory_category_title: allocation.inventory_category_id?.title || 'Uncategorized',
				allocated_amount: Number(allocatedAmount.toFixed(2)),
				spent_amount: Number(spentAmount.toFixed(2)),
				remaining_amount: remainingAmount,
				threshold_percentage: Number((allocation.threshold_percentage || periodBudget.threshold_percentage || 0).toFixed(2)),
				usage_percentage: computeUsagePercentage(spentAmount, allocatedAmount),
			};
		})
		.sort((a, b) => a.inventory_category_title.localeCompare(b.inventory_category_title));

	const totals = categories.reduce(
		(acc, item) => {
			acc.allocated += Number(item.allocated_amount || 0);
			acc.spent += Number(item.spent_amount || 0);
			acc.remaining += Number(item.remaining_amount || 0);
			return acc;
		},
		{ allocated: 0, spent: 0, remaining: 0 }
	);

	res.status(200).json({
		status: 'success',
		data: {
			selected_period_budget_id: periodBudget._id,
			available_period_budgets: availablePeriodBudgets,
			period_budget: {
				period_budget_id: periodBudget._id,
				title: periodBudget.title,
				period_type: periodBudget.period_type,
				start_date: periodBudget.start_date,
				end_date: periodBudget.end_date,
				currency: periodBudget.currency,
				total_amount: Number(Number(periodBudget.total_amount || 0).toFixed(2)),
				spent_amount: Number(Number(periodBudget.spent_amount || 0).toFixed(2)),
				remaining_amount: computeRemaining(periodBudget.total_amount, periodBudget.spent_amount),
			},
			categories,
			totals: {
				allocated: Number(totals.allocated.toFixed(2)),
				spent: Number(totals.spent.toFixed(2)),
				remaining: Number(totals.remaining.toFixed(2)),
			},
		},
	});
});

exports.setPeriodBudgetAllocations = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;
	const { allocations } = req.body;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	if (!Array.isArray(allocations) || allocations.length === 0) {
		return next(new AppError('Please provide allocations array', 400));
	}

	const periodBudget = await PeriodBudget.findOne({
		_id: periodBudgetId,
		family_id: req.familyAccount._id,
		is_active: true,
	});

	if (!periodBudget) {
		return next(new AppError('Period budget not found', 404));
	}

	let requestedTotal = 0;
	const categoryIds = [];
	const normalizedAllocations = allocations.map((entry) => {
		const categoryId = entry.inventory_category_id;
		const amount = Number(entry.allocated_amount);
		const threshold = entry.threshold_percentage === undefined ? periodBudget.threshold_percentage : Number(entry.threshold_percentage);

		if (!mongoose.Types.ObjectId.isValid(categoryId)) {
			throw new AppError('Invalid inventory_category_id in allocations', 400);
		}

		if (!Number.isFinite(amount) || amount < 0) {
			throw new AppError('allocated_amount must be a non-negative number', 400);
		}

		if (!Number.isFinite(threshold) || threshold < 0 || threshold > 100) {
			throw new AppError('threshold_percentage must be between 0 and 100', 400);
		}

		requestedTotal += amount;
		categoryIds.push(categoryId);

		return {
			inventory_category_id: categoryId,
			allocated_amount: Number(amount.toFixed(2)),
			threshold_percentage: Number(threshold.toFixed(2)),
		};
	});

	if (requestedTotal > Number(periodBudget.total_amount || 0)) {
		return next(new AppError('Total allocation cannot exceed period total_amount', 400));
	}

	const categories = await InventoryCategory.find({ _id: { $in: categoryIds } }).select('_id');
	if (categories.length !== new Set(categoryIds.map((id) => id.toString())).size) {
		return next(new AppError('One or more inventory categories were not found', 404));
	}

	for (const item of normalizedAllocations) {
		await BudgetAllocation.findOneAndUpdate(
			{
				family_id: req.familyAccount._id,
				period_budget_id: periodBudget._id,
				inventory_category_id: item.inventory_category_id,
			},
			{
				$set: {
					allocated_amount: item.allocated_amount,
					threshold_percentage: item.threshold_percentage,
					is_active: true,
				},
			},
			{ upsert: true, new: true, setDefaultsOnInsert: true }
		);
	}

	await BudgetAllocation.updateMany(
		{
			family_id: req.familyAccount._id,
			period_budget_id: periodBudget._id,
			inventory_category_id: { $nin: categoryIds },
		},
		{ $set: { is_active: false } }
	);

	await recalcPeriodSpent(periodBudget._id);

	const updatedAllocations = await BudgetAllocation.find({
		family_id: req.familyAccount._id,
		period_budget_id: periodBudget._id,
		is_active: true,
	}).populate('inventory_category_id', 'title');

	res.status(200).json({
		status: 'success',
		message: 'Budget allocations updated successfully',
		data: {
			period_budget_id: periodBudget._id,
			allocations: updatedAllocations,
			total_allocated: Number(updatedAllocations.reduce((sum, item) => sum + Number(item.allocated_amount || 0), 0).toFixed(2)),
		},
	});
});

exports.recordAllocationWithdrawal = catchAsync(async (req, res, next) => {
	const { allocationId } = req.params;
	const { amount, description, expense_date, paid_by_member_id, receipt_url } = req.body;

	if (!mongoose.Types.ObjectId.isValid(allocationId)) {
		return next(new AppError('Invalid allocation ID', 400));
	}

	const normalizedAmount = Number(amount);
	if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
		return next(new AppError('amount must be a positive number', 400));
	}

	const allocation = await BudgetAllocation.findOne({
		_id: allocationId,
		family_id: req.familyAccount._id,
		is_active: true,
	}).populate('inventory_category_id', 'title');

	if (!allocation) {
		return next(new AppError('Allocation not found', 404));
	}

	const periodBudget = await PeriodBudget.findOne({
		_id: allocation.period_budget_id,
		family_id: req.familyAccount._id,
		is_active: true,
	});

	if (!periodBudget) {
		return next(new AppError('Linked period budget not found', 404));
	}

	const allocationRemaining = computeRemaining(allocation.allocated_amount, allocation.spent_amount);
	if (allocationRemaining < normalizedAmount) {
		return next(new AppError('Insufficient allocated amount for this category', 400));
	}

	let expenseOwner = req.member;
	if (paid_by_member_id) {
		if (!mongoose.Types.ObjectId.isValid(paid_by_member_id)) {
			return next(new AppError('Invalid paid_by_member_id', 400));
		}

		expenseOwner = await Member.findOne({ _id: paid_by_member_id, family_id: req.familyAccount._id });
		if (!expenseOwner) {
			return next(new AppError('paid_by_member_id not found in this family', 404));
		}
	}

	allocation.spent_amount = Number((Number(allocation.spent_amount || 0) + normalizedAmount).toFixed(2));
	await allocation.save();

	const periodSpent = await recalcPeriodSpent(periodBudget._id);

	const expense = await Expense.create({
		family_id: req.familyAccount._id,
		member_id: expenseOwner._id,
		member_mail: expenseOwner.mail,
		category: allocation.inventory_category_id?.title || 'Inventory Category',
		title: description || 'Inventory category withdrawal',
		description: description || 'Withdrawal from category allocation',
		amount: normalizedAmount,
		expense_date: expense_date ? new Date(expense_date) : new Date(),
		expense_source: 'budget',
		notes: `allocation_id=${allocation._id};period_budget_id=${periodBudget._id};receipt_url=${receipt_url || ''}`,
		is_finalized: true,
		finalized_at: new Date(),
	});

	await logBalanceWalletDetail({
		family_id: req.familyAccount._id,
		member_id: expenseOwner._id,
		member_mail: expenseOwner.mail,
		wallet_scope: 'shared_budget',
		change_type: 'debit',
		source_type: 'budget_withdrawal',
		amount: normalizedAmount,
		previous_balance: Number((Number(periodBudget.total_amount || 0) - Number(periodSpent || 0) + normalizedAmount).toFixed(2)),
		new_balance: Number(Math.max(0, Number(periodBudget.total_amount || 0) - Number(periodSpent || 0)).toFixed(2)),
		title: expense.title,
		description: expense.description,
		added_by_member_id: req.member._id,
		added_by_mail: req.member.mail,
		linked_expense_id: expense._id,
		budget_id: periodBudget._id,
		budget_category_id: allocation.inventory_category_id?._id || allocation.inventory_category_id || null,
		notes: `allocation_id=${allocation._id}`,
	});

	const remainingAfter = computeRemaining(allocation.allocated_amount, allocation.spent_amount);
	const remainingPercentage = allocation.allocated_amount > 0
		? Number(((remainingAfter / allocation.allocated_amount) * 100).toFixed(2))
		: 0;

	const lowThresholdReached = remainingPercentage <= Number(allocation.threshold_percentage || 0);

	const alertText = lowThresholdReached
		? `Warning: ${allocation.inventory_category_id?.title || 'Category'} allocation is low. Remaining ${remainingAfter.toFixed(2)}.`
		: null;

	const withdrawalText = `${expenseOwner.username || expenseOwner.mail} recorded a withdrawal of ${normalizedAmount.toFixed(2)} from ${allocation.inventory_category_id?.title || 'category'}.`;

	const notification = await sendParentNotification(
		req.familyAccount._id,
		lowThresholdReached ? 'Budget withdrawal and low allocation warning' : 'Budget withdrawal recorded',
		lowThresholdReached ? `${withdrawalText} ${alertText}` : withdrawalText
	).catch((error) => ({ sent: false, recipients: [], error: error.message }));

	res.status(201).json({
		status: 'success',
		message: 'Withdrawal recorded successfully',
		data: {
			expense,
			allocation: {
				...allocation.toObject(),
				remaining_amount: remainingAfter,
				remaining_percentage: remainingPercentage,
				low_threshold_reached: lowThresholdReached,
			},
			period_budget: {
				...periodBudget.toObject(),
				spent_amount: Number(periodSpent.toFixed(2)),
				remaining_amount: computeRemaining(periodBudget.total_amount, periodSpent),
				usage_percentage: computeUsagePercentage(periodSpent, periodBudget.total_amount),
			},
			alert: lowThresholdReached ? alertText : null,
			notification,
		},
	});
});

exports.getPeriodBudgetDetails = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	const periodBudget = await PeriodBudget.findOne({
		_id: periodBudgetId,
		family_id: req.familyAccount._id,
	});

	if (!periodBudget) {
		return next(new AppError('Period budget not found', 404));
	}

	const allocations = await BudgetAllocation.find({
		family_id: req.familyAccount._id,
		period_budget_id: periodBudget._id,
		is_active: true,
	}).populate('inventory_category_id', 'title');

	const allocationDetails = allocations.map((allocation) => {
		const remainingAmount = computeRemaining(allocation.allocated_amount, allocation.spent_amount);
		const remainingPercentage = allocation.allocated_amount > 0
			? Number(((remainingAmount / allocation.allocated_amount) * 100).toFixed(2))
			: 0;

		return {
			...allocation.toObject(),
			remaining_amount: remainingAmount,
			remaining_percentage: remainingPercentage,
			low_threshold_reached: remainingPercentage <= Number(allocation.threshold_percentage || 0),
		};
	});

	res.status(200).json({
		status: 'success',
		data: {
			period_budget: {
				...periodBudget.toObject(),
				remaining_amount: computeRemaining(periodBudget.total_amount, periodBudget.spent_amount),
				usage_percentage: computeUsagePercentage(periodBudget.spent_amount, periodBudget.total_amount),
			},
			allocations: allocationDetails,
		},
	});
});

exports.setPeriodMemberAllowances = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;
	const { allowances } = req.body;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	if (!Array.isArray(allowances)) {
		return next(new AppError('Please provide allowances array', 400));
	}

	const periodBudget = await PeriodBudget.findOne({
		_id: periodBudgetId,
		family_id: req.familyAccount._id,
		is_active: true,
	});

	if (!periodBudget) {
		return next(new AppError('Period budget not found', 404));
	}

	const normalizedAllowances = [];
	for (const entry of allowances) {
		const memberId = entry.member_id;
		const memberMail = entry.member_mail;
		const moneyAmount = Number(entry.money_amount || 0);
		const allowanceCurrency = entry.allowance_currency || 'money';
		const periodType = entry.period_type || periodBudget.period_type;

		if (!memberMail || typeof memberMail !== 'string') {
			return next(new AppError('Each allowance must include member_mail', 400));
		}

		if (memberId && !mongoose.Types.ObjectId.isValid(memberId)) {
			return next(new AppError('Invalid member_id in allowances', 400));
		}

		if (allowanceCurrency !== 'money') {
			return next(new AppError('allowance_currency must be money', 400));
		}

		if (!Number.isFinite(moneyAmount) || moneyAmount < 0) {
			return next(new AppError('money_amount must be a non-negative number', 400));
		}

		normalizedAllowances.push({
			member_id: memberId || null,
			member_mail: memberMail,
			previous_money_amount: 0,
			money_amount: moneyAmount,
			allowance_currency: allowanceCurrency,
			period_type: periodType,
			start_date: periodBudget.start_date,
			end_date: periodBudget.end_date,
			period_budget_id: periodBudget._id,
		});
	}

	for (const allowance of normalizedAllowances) {
		const existingAllowance = await MemberAllowance.findOne({
			family_id: req.familyAccount._id,
			period_budget_id: periodBudget._id,
			member_mail: allowance.member_mail,
		});
		const previousAmount = Number(existingAllowance?.money_amount || 0);
		const amountDelta = Number((allowance.money_amount - previousAmount).toFixed(2));
		const memberWallet = await ensureMoneyWallet(allowance.member_mail, req.familyAccount._id);
		const previousWalletBalance = Number(memberWallet.balance || 0);

		await MemberAllowance.findOneAndUpdate(
			{
				family_id: req.familyAccount._id,
				period_budget_id: periodBudget._id,
				member_mail: allowance.member_mail,
			},
			{
				$set: {
					member_id: allowance.member_id,
					money_amount: allowance.money_amount,
					allowance_currency: allowance.allowance_currency,
					period_type: allowance.period_type,
					start_date: allowance.start_date,
					end_date: allowance.end_date,
					period_budget_id: allowance.period_budget_id,
				},
			},
			{ upsert: true, new: true, setDefaultsOnInsert: true }
		);

		if (amountDelta !== 0) {
			memberWallet.balance = Number(Math.max(0, previousWalletBalance + amountDelta).toFixed(2));
			memberWallet.last_update = new Date();
			await memberWallet.save();

			await logBalanceWalletDetail({
				family_id: req.familyAccount._id,
				member_id: allowance.member_id,
				member_mail: allowance.member_mail,
				member_wallet_id: memberWallet._id,
				wallet_scope: 'money_wallet',
				change_type: amountDelta >= 0 ? 'credit' : 'debit',
				source_type: 'allowance',
				amount: Math.abs(amountDelta),
				previous_balance: previousWalletBalance,
				new_balance: memberWallet.balance,
				title: 'Personal allowance updated',
				description: `${allowance.member_mail} allowance changed by ${amountDelta.toFixed(2)}`,
				added_by_member_id: req.member._id,
				added_by_mail: req.member.mail,
				budget_id: periodBudget._id,
				notes: `period_type=${allowance.period_type};previous_allowance=${previousAmount.toFixed(2)}`,
			});
		}
	}

	const savedAllowances = await MemberAllowance.find({
		family_id: req.familyAccount._id,
		period_budget_id: periodBudget._id,
	}).sort({ createdAt: 1 });

	res.status(200).json({
		status: 'success',
		message: 'Member allowances saved successfully',
		data: { allowances: savedAllowances },
	});
});

exports.getPeriodMemberAllowances = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	const allowances = await MemberAllowance.find({
		family_id: req.familyAccount._id,
		period_budget_id: periodBudgetId,
	}).sort({ createdAt: 1 });

	res.status(200).json({
		status: 'success',
		results: allowances.length,
		data: { allowances },
	});
});

exports.setConversionRate = catchAsync(async (req, res, next) => {
	const { money_to_points_rate, points_to_money_rate } = req.body;

	if (money_to_points_rate === undefined || points_to_money_rate === undefined) {
		return next(new AppError('Please provide money_to_points_rate and points_to_money_rate', 400));
	}

	const moneyRate = Number(money_to_points_rate);
	const pointsRate = Number(points_to_money_rate);

	if (!Number.isFinite(moneyRate) || moneyRate <= 0 || !Number.isFinite(pointsRate) || pointsRate <= 0) {
		return next(new AppError('Conversion rates must be positive numbers', 400));
	}

	await ConversionRate.updateMany(
		{ family_id: req.familyAccount._id, is_active: true },
		{ $set: { is_active: false } }
	);

	const conversionRate = await ConversionRate.create({
		family_id: req.familyAccount._id,
		money_to_points_rate: moneyRate,
		points_to_money_rate: pointsRate,
		is_active: true,
		created_by: req.member._id,
	});

	res.status(201).json({
		status: 'success',
		message: 'Conversion rate updated successfully',
		data: { conversionRate },
	});
});

exports.getConversionRate = catchAsync(async (req, res, next) => {
	const conversionRate = await getActiveConversionRate(req.familyAccount._id);

	res.status(200).json({
		status: 'success',
		data: { conversionRate },
	});
});

exports.convertMoneyToPoints = catchAsync(async (req, res, next) => {
	const { amount_money } = req.body;
	const amountMoney = Number(amount_money);

	if (!Number.isFinite(amountMoney) || amountMoney <= 0) {
		return next(new AppError('Please provide a valid amount_money', 400));
	}

	const conversionRate = await getActiveConversionRate(req.familyAccount._id);
	const memberWallet = await ensureMoneyWallet(req.member.mail, req.familyAccount._id);
	const pointWallet = await ensurePointWallet(req.member.mail, req.familyAccount._id);

	if (memberWallet.balance < amountMoney) {
		return next(new AppError('Insufficient money balance for conversion', 400));
	}

	const pointsAmount = Number((amountMoney * conversionRate.money_to_points_rate).toFixed(2));

	const previousMoneyBalance = memberWallet.balance;
	const previousPointsBalance = pointWallet.total_points;

	try {
		memberWallet.balance = Number((memberWallet.balance - amountMoney).toFixed(2));
		memberWallet.last_update = new Date();
		await memberWallet.save();

		pointWallet.total_points = Number((pointWallet.total_points + pointsAmount).toFixed(2));
		pointWallet.last_update = new Date();
		await pointWallet.save();

		const pointHistory = await PointHistory.create({
			wallet_id: pointWallet._id,
			member_mail: req.member.mail,
			family_id: req.familyAccount._id,
			points_amount: pointsAmount,
			reason_type: 'conversion',
			granted_by: req.member.mail,
			description: 'Converted from money',
		});

		const walletTransaction = await mongoose.models.WalletTransaction || require('../models/walletTransactionModel');
		const createdTransaction = await walletTransaction.create({
			family_id: req.familyAccount._id,
			member_mail: req.member.mail,
			member_wallet_id: memberWallet._id,
			amount: amountMoney,
			transaction_type: 'withdrawal',
			description: `Converted ${amountMoney} money to ${pointsAmount} points`,
			conversion_type: 'money_to_points',
			converted_amount: pointsAmount,
			conversion_rate: conversionRate.money_to_points_rate,
			linked_point_transaction_id: pointHistory._id,
		});

		await logBalanceWalletDetail({
			family_id: req.familyAccount._id,
			member_id: req.member._id,
			member_mail: req.member.mail,
			member_wallet_id: memberWallet._id,
			wallet_scope: 'money_wallet',
			change_type: 'debit',
			source_type: 'conversion',
			amount: amountMoney,
			previous_balance: previousMoneyBalance,
			new_balance: memberWallet.balance,
			title: 'Money converted to points',
			description: `Converted ${amountMoney} money to ${pointsAmount} points`,
			added_by_member_id: req.member._id,
			added_by_mail: req.member.mail,
			linked_wallet_transaction_id: createdTransaction._id,
			linked_point_history_id: pointHistory._id,
			notes: 'money_to_points conversion',
		});

		const notification = await sendParentNotification(
			req.familyAccount._id,
			'Money to points conversion completed',
			`${req.member.username || req.member.mail} converted ${amountMoney} money into ${pointsAmount} points.`,
			`<p><strong>${req.member.username || req.member.mail}</strong> converted ${amountMoney} money into ${pointsAmount} points.</p>`
		).catch((error) => ({ sent: false, recipients: [], error: error.message }));

		res.status(200).json({
			status: 'success',
			message: 'Money converted to points successfully',
			data: {
				memberWallet,
				pointWallet,
				walletTransaction: createdTransaction,
				pointHistory,
				conversionRate,
				notification,
			},
		});
	} catch (error) {
		memberWallet.balance = previousMoneyBalance;
		memberWallet.last_update = new Date();
		await memberWallet.save();

		pointWallet.total_points = previousPointsBalance;
		pointWallet.last_update = new Date();
		await pointWallet.save();

		return next(error);
	}
});

exports.convertPointsToMoney = catchAsync(async (req, res, next) => {
	const { amount_points } = req.body;
	const amountPoints = Number(amount_points);

	if (!Number.isFinite(amountPoints) || amountPoints <= 0) {
		return next(new AppError('Please provide a valid amount_points', 400));
	}

	const conversionRate = await getActiveConversionRate(req.familyAccount._id);
	const memberWallet = await ensureMoneyWallet(req.member.mail, req.familyAccount._id);
	const pointWallet = await ensurePointWallet(req.member.mail, req.familyAccount._id);

	if (pointWallet.total_points < amountPoints) {
		return next(new AppError('Insufficient points balance for conversion', 400));
	}

	const moneyAmount = Number((amountPoints * conversionRate.points_to_money_rate).toFixed(2));

	const previousMoneyBalance = memberWallet.balance;
	const previousPointsBalance = pointWallet.total_points;

	try {
		pointWallet.total_points = Number((pointWallet.total_points - amountPoints).toFixed(2));
		pointWallet.last_update = new Date();
		await pointWallet.save();

		memberWallet.balance = Number((memberWallet.balance + moneyAmount).toFixed(2));
		memberWallet.last_update = new Date();
		await memberWallet.save();

		const pointHistory = await PointHistory.create({
			wallet_id: pointWallet._id,
			member_mail: req.member.mail,
			family_id: req.familyAccount._id,
			points_amount: -amountPoints,
			reason_type: 'conversion',
			granted_by: req.member.mail,
			description: 'Converted to money',
		});

		const walletTransaction = await mongoose.models.WalletTransaction || require('../models/walletTransactionModel');
		const createdTransaction = await walletTransaction.create({
			family_id: req.familyAccount._id,
			member_mail: req.member.mail,
			member_wallet_id: memberWallet._id,
			amount: moneyAmount,
			transaction_type: 'deposit',
			description: `Converted ${amountPoints} points to ${moneyAmount} money`,
			conversion_type: 'points_to_money',
			converted_amount: moneyAmount,
			conversion_rate: conversionRate.points_to_money_rate,
			linked_point_transaction_id: pointHistory._id,
		});

		await logBalanceWalletDetail({
			family_id: req.familyAccount._id,
			member_id: req.member._id,
			member_mail: req.member.mail,
			member_wallet_id: memberWallet._id,
			wallet_scope: 'money_wallet',
			change_type: 'credit',
			source_type: 'conversion',
			amount: moneyAmount,
			previous_balance: previousMoneyBalance,
			new_balance: memberWallet.balance,
			title: 'Points converted to money',
			description: `Converted ${amountPoints} points to ${moneyAmount} money`,
			added_by_member_id: req.member._id,
			added_by_mail: req.member.mail,
			linked_wallet_transaction_id: createdTransaction._id,
			linked_point_history_id: pointHistory._id,
			notes: 'points_to_money conversion',
		});

		const notification = await sendParentNotification(
			req.familyAccount._id,
			'Points to money conversion completed',
			`${req.member.username || req.member.mail} converted ${amountPoints} points into ${moneyAmount} money.`,
			`<p><strong>${req.member.username || req.member.mail}</strong> converted ${amountPoints} points into ${moneyAmount} money.</p>`
		).catch((error) => ({ sent: false, recipients: [], error: error.message }));

		res.status(200).json({
			status: 'success',
			message: 'Points converted to money successfully',
			data: {
				memberWallet,
				pointWallet,
				walletTransaction: createdTransaction,
				pointHistory,
				conversionRate,
				notification,
			},
		});
	} catch (error) {
		memberWallet.balance = previousMoneyBalance;
		memberWallet.last_update = new Date();
		await memberWallet.save();

		pointWallet.total_points = previousPointsBalance;
		pointWallet.last_update = new Date();
		await pointWallet.save();

		return next(error);
	}
});

exports.getMemberCombinedBalance = catchAsync(async (req, res, next) => {
	const { memberId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(memberId)) {
		return next(new AppError('Invalid member ID', 400));
	}

	const targetMember = await Member.findOne({
		_id: memberId,
		family_id: req.familyAccount._id,
	}).populate('member_type_id', 'type');

	if (!targetMember) {
		return next(new AppError('Member not found in your family', 404));
	}

	const requesterIsParent = req.member.member_type_id?.type === 'Parent';
	const requesterIsTarget = req.member._id.toString() === targetMember._id.toString();

	if (!requesterIsParent && !requesterIsTarget) {
		return next(new AppError('You do not have permission to view this balance', 403));
	}

	const [moneyWallet, pointWallet, conversionRate] = await Promise.all([
		ensureMoneyWallet(targetMember.mail, req.familyAccount._id),
		ensurePointWallet(targetMember.mail, req.familyAccount._id),
		getActiveConversionRate(req.familyAccount._id),
	]);

	const moneyBalance = Number(moneyWallet.balance || 0);
	const pointsBalance = Number(pointWallet.total_points || 0);

	const totalValueInMoney = Number((moneyBalance + (pointsBalance * conversionRate.points_to_money_rate)).toFixed(2));
	const totalValueInPoints = Number((pointsBalance + (moneyBalance * conversionRate.money_to_points_rate)).toFixed(2));

	res.status(200).json({
		status: 'success',
		data: {
			member: {
				memberId: targetMember._id,
				mail: targetMember.mail,
				username: targetMember.username,
			},
			money_balance: moneyBalance,
			points_balance: pointsBalance,
			total_value_in_money: totalValueInMoney,
			total_value_in_points: totalValueInPoints,
			conversionRate,
		},
	});
});

exports.getMemberBalanceWalletDetails = catchAsync(async (req, res, next) => {
	const { memberId } = req.params;
	const { scope } = req.query;

	if (!mongoose.Types.ObjectId.isValid(memberId)) {
		return next(new AppError('Invalid member ID', 400));
	}

	const targetMember = await Member.findOne({
		_id: memberId,
		family_id: req.familyAccount._id,
	}).populate('member_type_id', 'type');

	if (!targetMember) {
		return next(new AppError('Member not found in this family', 404));
	}

	const requesterIsParent = req.member.member_type_id?.type === 'Parent';
	const requesterIsTarget = req.member._id.toString() === targetMember._id.toString();

	if (!requesterIsParent && !requesterIsTarget) {
		return next(new AppError('You do not have permission to view this balance trail', 403));
	}

	const filter = {
		family_id: req.familyAccount._id,
		member_mail: targetMember.mail,
	};

	if (scope && ['money_wallet', 'points_wallet', 'shared_budget', 'personal_budget'].includes(scope)) {
		filter.wallet_scope = scope;
	}

	const details = await BalanceWalletDetail.find(filter)
		.sort({ createdAt: -1 })
		.limit(100);

	const summary = details.reduce((acc, detail) => {
		const key = detail.wallet_scope || 'money_wallet';
		if (!acc[key]) {
			acc[key] = { credits: 0, debits: 0, net: 0 };
		}
		const amount = Number(detail.amount || 0);
		if (detail.change_type === 'credit') {
			acc[key].credits += amount;
			acc[key].net += amount;
		} else {
			acc[key].debits += amount;
			acc[key].net -= amount;
		}
		return acc;
	}, {});

	res.status(200).json({
		status: 'success',
		data: {
			member: {
				member_id: targetMember._id,
				member_name: targetMember.username,
				member_mail: targetMember.mail,
			},
			details,
			summary,
		},
	});
});

exports.getRedeemExpenses = catchAsync(async (req, res, next) => {
	const { start_date, end_date, member_id } = req.query;
	const filter = {
		family_id: req.familyAccount._id,
		expense_source: 'redeem_reward',
	};

	if (member_id) {
		if (!mongoose.Types.ObjectId.isValid(member_id)) {
			return next(new AppError('Invalid member ID', 400));
		}
		filter.member_id = member_id;
	}

	if (start_date || end_date) {
		filter.expense_date = {};
		if (start_date) {
			filter.expense_date.$gte = new Date(start_date);
		}
		if (end_date) {
			filter.expense_date.$lte = new Date(end_date);
		}
	}

	const expenses = await Expense.find(filter)
		.populate('member_id', 'username mail')
		.populate('linked_redeem_id')
		.sort({ expense_date: -1, createdAt: -1 });

	res.status(200).json({
		status: 'success',
		results: expenses.length,
		data: { expenses },
	});
});

exports.createEventWithRewards = catchAsync(async (req, res, next) => {
	const {
		title,
		description,
		event_date,
		estimated_cost,
		funding_source,
		required_points,
		members_contributing,
	} = req.body;

	console.log('📝 createEventWithRewards called for family:', req.familyAccount._id);
	console.log('   Payload:', { title, event_date, estimated_cost });

	if (!title || !event_date) {
		return next(new AppError('Please provide title and event_date', 400));
	}

	const normalizedFundingSource = funding_source || 'budget';
	const normalizedRequiredPoints = Number(required_points || 0);
	const estimatedCost = Number(estimated_cost || 0);

	if (!Number.isFinite(normalizedRequiredPoints) || normalizedRequiredPoints < 0) {
		return next(new AppError('required_points must be a non-negative number', 400));
	}

	if (!Number.isFinite(estimatedCost) || estimatedCost < 0) {
		return next(new AppError('estimated_cost must be a non-negative number', 400));
	}

	let normalizedContributors = [];
	if (normalizedFundingSource === 'member_contributions') {
		if (!Array.isArray(members_contributing) || members_contributing.length === 0) {
			return next(new AppError('members_contributing is required when funding_source is member_contributions', 400));
		}

		normalizedContributors = members_contributing.map((entry) => ({
			member_id: entry.member_id,
			amount_promised: Number(entry.amount_promised || 0),
			amount_paid: Number(entry.amount_paid || 0),
			points_promised: Number(entry.points_promised || 0),
			points_paid: Number(entry.points_paid || 0),
		}));
	}

	const futureEvent = await FutureEvent.create({
		family_id: req.familyAccount._id,
		title,
		description: description || '',
		event_date,
		estimated_cost: estimatedCost,
		funding_source: normalizedFundingSource,
		required_points: normalizedRequiredPoints,
		members_contributing: normalizedContributors,
		total_contributed_money: normalizedContributors.reduce((sum, c) => sum + Number(c.amount_paid || 0), 0),
		total_contributed_points: normalizedContributors.reduce((sum, c) => sum + Number(c.points_paid || 0), 0),
		created_by: req.member.mail,
	});

	console.log('✓ Future event created with ID:', futureEvent._id, 'for family:', futureEvent.family_id);

	const autoCreatedRewardItems = [];
	if (normalizedRequiredPoints > 0) {
		let eventCategory = await WishlistCategory.findOne({
			title: 'Event Rewards',
			family_id: req.familyAccount._id,
		});

		if (!eventCategory) {
			eventCategory = await WishlistCategory.create({
				title: 'Event Rewards',
				description: 'Auto-generated rewards for family events',
				family_id: req.familyAccount._id,
			});
		}

		const familyMembers = await Member.find({ family_id: req.familyAccount._id }).populate('member_type_id', 'type');
		const children = familyMembers.filter((member) => member.member_type_id?.type !== 'Parent');

		for (const child of children) {
			let wishlist = await Wishlist.findOne({ member_mail: child.mail, family_id: req.familyAccount._id });
			if (!wishlist) {
				wishlist = await Wishlist.create({
					member_mail: child.mail,
					family_id: req.familyAccount._id,
					title: `${child.username}'s Wishlist`,
				});
			}

			const rewardItem = await WishlistItem.create({
				wishlist_id: wishlist._id,
				category_id: eventCategory._id,
				item_name: `Event Spot: ${futureEvent.title}`,
				required_points: normalizedRequiredPoints,
				assigned_by: req.member.mail,
				description: `Auto-generated event reward for ${futureEvent.title}`,
				priority: 1,
			});

			autoCreatedRewardItems.push({
				member_mail: child.mail,
				wishlist_item_id: rewardItem._id,
			});
			futureEvent.auto_created_reward_items.push(rewardItem._id);
		}

		await futureEvent.save();
	}

	res.status(201).json({
		status: 'success',
		message: 'Future event created successfully',
		data: {
			event: futureEvent,
			auto_created_reward_items: autoCreatedRewardItems,
		},
	});
});

exports.contributeToEvent = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;
	const {
		contribution_type,
		amount,
		member_id,
		payment_mode = 'pay_now',
		manual_entry = false,
	} = req.body;
	const normalizedAmount = Number(amount);

	if (!['money', 'points'].includes(contribution_type)) {
		return next(new AppError("contribution_type must be 'money' or 'points'", 400));
	}

	if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
		return next(new AppError('amount must be a positive number', 400));
	}

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	const event = await FutureEvent.findOne({ _id: eventId, family_id: req.familyAccount._id });
	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	const requesterType = await MemberType.findById(req.member.member_type_id).select('type');
	const isRequesterParent = requesterType?.type === 'Parent';

	let targetMember = req.member;
	if (member_id) {
		if (!mongoose.Types.ObjectId.isValid(member_id)) {
			return next(new AppError('Invalid member_id', 400));
		}

		targetMember = await Member.findOne({ _id: member_id, family_id: req.familyAccount._id });
		if (!targetMember) {
			return next(new AppError('Target member not found in this family', 404));
		}

		if (!isRequesterParent && targetMember._id.toString() !== req.member._id.toString()) {
			return next(new AppError('You can only contribute for yourself', 403));
		}
	}

	let contribution = event.members_contributing.find(
		(entry) => entry.member_id.toString() === targetMember._id.toString()
	);

	if (!contribution) {
		contribution = {
			member_id: targetMember._id,
			amount_promised: 0,
			amount_paid: 0,
			points_promised: 0,
			points_paid: 0,
		};
		event.members_contributing.push(contribution);
		contribution = event.members_contributing[event.members_contributing.length - 1];
	}

	let createdWalletTransaction = null;
	let createdPointHistory = null;
	const isPromiseOnly = payment_mode === 'promise';
	const isManualPaidEntry = manual_entry === true;

	if (contribution_type === 'money') {
		if (isPromiseOnly) {
			contribution.amount_promised = Number((Number(contribution.amount_promised || 0) + normalizedAmount).toFixed(2));
		} else {
			if (!isRequesterParent || !isManualPaidEntry || targetMember._id.toString() === req.member._id.toString()) {
				const memberWallet = await ensureMoneyWallet(targetMember.mail, req.familyAccount._id);
				if (memberWallet.balance < normalizedAmount) {
					return next(new AppError('Insufficient money balance', 400));
				}

				memberWallet.balance = Number((memberWallet.balance - normalizedAmount).toFixed(2));
				memberWallet.last_update = new Date();
				await memberWallet.save();

				createdWalletTransaction = await WalletTransaction.create({
					family_id: req.familyAccount._id,
					member_mail: targetMember.mail,
					member_wallet_id: memberWallet._id,
					amount: normalizedAmount,
					transaction_type: 'withdrawal',
					description: `Event contribution: ${event.title}`,
					conversion_type: 'none',
					converted_amount: normalizedAmount,
					conversion_rate: 1,
				});
			}

			contribution.amount_paid = Number((Number(contribution.amount_paid || 0) + normalizedAmount).toFixed(2));
			event.total_contributed_money = Number((Number(event.total_contributed_money || 0) + normalizedAmount).toFixed(2));
		}
	} else {
		if (isPromiseOnly) {
			contribution.points_promised = Number((Number(contribution.points_promised || 0) + normalizedAmount).toFixed(2));
		} else {
			if (!isRequesterParent || !isManualPaidEntry || targetMember._id.toString() === req.member._id.toString()) {
				const pointWallet = await ensurePointWallet(targetMember.mail, req.familyAccount._id);
				if (pointWallet.total_points < normalizedAmount) {
					return next(new AppError('Insufficient points balance', 400));
				}

				pointWallet.total_points = Number((pointWallet.total_points - normalizedAmount).toFixed(2));
				pointWallet.last_update = new Date();
				await pointWallet.save();

				createdPointHistory = await PointHistory.create({
					wallet_id: pointWallet._id,
					member_mail: targetMember.mail,
					family_id: req.familyAccount._id,
					points_amount: -normalizedAmount,
					reason_type: 'adjustment',
					granted_by: req.member.mail,
					description: `Event contribution: ${event.title}`,
				});
			}

			contribution.points_paid = Number((Number(contribution.points_paid || 0) + normalizedAmount).toFixed(2));
			event.total_contributed_points = Number((Number(event.total_contributed_points || 0) + normalizedAmount).toFixed(2));
		}
	}

	await event.save();

	const notification = await sendParentNotification(
		req.familyAccount._id,
		'Event contribution received',
		`${targetMember.username || targetMember.mail} ${isPromiseOnly ? 'promised' : 'contributed'} ${normalizedAmount} ${contribution_type} to ${event.title}.`
	).catch((error) => ({ sent: false, recipients: [], error: error.message }));

	res.status(200).json({
		status: 'success',
		message: 'Contribution recorded successfully',
		data: {
			event,
			contribution,
			target_member: {
				member_id: targetMember._id,
				member_mail: targetMember.mail,
				member_name: targetMember.username,
			},
			wallet_transaction: createdWalletTransaction,
			point_history: createdPointHistory,
			notification,
		},
	});
});

exports.markContributionPaid = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;
	const { member_id, contribution_type, amount } = req.body;
	const normalizedAmount = Number(amount);

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	if (!mongoose.Types.ObjectId.isValid(member_id)) {
		return next(new AppError('Invalid member_id', 400));
	}

	if (!['money', 'points'].includes(contribution_type)) {
		return next(new AppError("contribution_type must be 'money' or 'points'", 400));
	}

	if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
		return next(new AppError('amount must be a positive number', 400));
	}

	const event = await FutureEvent.findOne({ _id: eventId, family_id: req.familyAccount._id });
	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	const memberType = await MemberType.findById(req.member.member_type_id).select('type');
	if (memberType?.type !== 'Parent') {
		return next(new AppError('Only parents can mark contributions as paid', 403));
	}

	let contribution = event.members_contributing.find(
		(entry) => entry.member_id.toString() === member_id.toString()
	);

	if (!contribution) {
		contribution = {
			member_id,
			amount_promised: 0,
			amount_paid: 0,
			points_promised: 0,
			points_paid: 0,
		};
		event.members_contributing.push(contribution);
		contribution = event.members_contributing[event.members_contributing.length - 1];
	}

	if (contribution_type === 'money') {
		const availablePromised = Number(contribution.amount_promised || 0);
		if (availablePromised < normalizedAmount) {
			return next(new AppError('Cannot mark paid more than promised money amount', 400));
		}

		contribution.amount_promised = Number((availablePromised - normalizedAmount).toFixed(2));
		contribution.amount_paid = Number((Number(contribution.amount_paid || 0) + normalizedAmount).toFixed(2));
		event.total_contributed_money = Number((Number(event.total_contributed_money || 0) + normalizedAmount).toFixed(2));
	} else {
		const availablePromised = Number(contribution.points_promised || 0);
		if (availablePromised < normalizedAmount) {
			return next(new AppError('Cannot mark paid more than promised points amount', 400));
		}

		contribution.points_promised = Number((availablePromised - normalizedAmount).toFixed(2));
		contribution.points_paid = Number((Number(contribution.points_paid || 0) + normalizedAmount).toFixed(2));
		event.total_contributed_points = Number((Number(event.total_contributed_points || 0) + normalizedAmount).toFixed(2));
	}

	await event.save();

	res.status(200).json({
		status: 'success',
		message: 'Contribution marked as paid',
		data: { event, contribution },
	});
});

exports.adjustFundingGoal = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;
	const { estimated_cost } = req.body;
	const normalizedCost = Number(estimated_cost);

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	if (!Number.isFinite(normalizedCost) || normalizedCost < 0) {
		return next(new AppError('estimated_cost must be a non-negative number', 400));
	}

	const memberType = await MemberType.findById(req.member.member_type_id).select('type');
	if (memberType?.type !== 'Parent') {
		return next(new AppError('Only parents can adjust funding goal', 403));
	}

	const event = await FutureEvent.findOneAndUpdate(
		{ _id: eventId, family_id: req.familyAccount._id },
		{ $set: { estimated_cost: normalizedCost } },
		{ new: true }
	);

	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	res.status(200).json({
		status: 'success',
		message: 'Funding goal adjusted successfully',
		data: { event },
	});
});

exports.getEventFundingStatus = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	const event = await FutureEvent.findOne({ _id: eventId, family_id: req.familyAccount._id })
		.populate('members_contributing.member_id', 'username mail');

	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	const totalEstimatedCost = Number(event.estimated_cost || 0);
	const totalContributedMoney = Number(event.total_contributed_money || 0);
	const totalContributedPoints = Number(event.total_contributed_points || 0);
	const remainingNeeded = Number(Math.max(0, totalEstimatedCost - totalContributedMoney).toFixed(2));
	const progressPercentage = totalEstimatedCost > 0
		? Number(Math.min(100, (totalContributedMoney / totalEstimatedCost) * 100).toFixed(2))
		: 0;
	const eventDate = new Date(event.event_date);
	const now = new Date();
	const daysRemaining = Number(Math.max(0, Math.ceil((eventDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))));
	const monthsRemaining = Math.max(1, Math.ceil(daysRemaining / 30));
	const monthlySavingsNeeded = Number((remainingNeeded / monthsRemaining).toFixed(2));

	const breakdownByMember = event.members_contributing.map((entry) => ({
		member_id: entry.member_id?._id || entry.member_id,
		member_name: entry.member_id?.username || 'Unknown',
		member_mail: entry.member_id?.mail || null,
		amount_promised: Number(entry.amount_promised || 0),
		amount_paid: Number(entry.amount_paid || 0),
		points_promised: Number(entry.points_promised || 0),
		points_paid: Number(entry.points_paid || 0),
	}));

	const redeemedSpots = await Redeem.find({
		family_id: req.familyAccount._id,
		linked_event_id: event._id,
		status: 'child_accepted',
	}).select('requester points_used createdAt');

	const membersRedeemedSpots = redeemedSpots.map((entry) => ({
		member_mail: entry.requester,
		points_used: Number(entry.points_used || 0),
		redeemed_at: entry.createdAt,
	}));

	const rewardsBudget = await getRewardsBudget(req.familyAccount._id);
	const rewardsBudgetRemaining = rewardsBudget
		? Number((Number(rewardsBudget.budget_amount || 0) - Number(rewardsBudget.spent_amount || 0)).toFixed(2))
		: null;

	res.status(200).json({
		status: 'success',
		data: {
			event_id: event._id,
			event_title: event.title,
			event_date: event.event_date,
			funding_source: event.funding_source,
			required_points: Number(event.required_points || 0),
			total_estimated_cost: totalEstimatedCost,
			total_contributed_money: totalContributedMoney,
			total_contributed_points: totalContributedPoints,
			remaining_needed: remainingNeeded,
			progress_percentage: progressPercentage,
			days_remaining: daysRemaining,
			monthly_savings_needed: monthlySavingsNeeded,
			rewards_budget_remaining: rewardsBudgetRemaining,
			members_redeemed_spots: membersRedeemedSpots,
			breakdown_by_member: breakdownByMember,
		},
	});
});

exports.getCombinedAnalytics = catchAsync(async (req, res, next) => {
	const familyId = req.familyAccount._id;
	const { period_budget_id } = req.query;
	const now = new Date();
	const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

	const expenseFilter = { family_id: familyId };
	let scopedPeriodBudget = null;

	if (period_budget_id) {
		if (!mongoose.Types.ObjectId.isValid(period_budget_id)) {
			return next(new AppError('period_budget_id must be a valid ID', 400));
		}

		scopedPeriodBudget = await PeriodBudget.findOne({
			_id: period_budget_id,
			family_id: familyId,
		});

		if (!scopedPeriodBudget) {
			return next(new AppError('Selected period budget not found', 404));
		}

		expenseFilter.expense_date = {
			$gte: new Date(scopedPeriodBudget.start_date),
			$lte: new Date(scopedPeriodBudget.end_date),
		};

		const scopedAllocations = await BudgetAllocation.find({
			family_id: familyId,
			period_budget_id: scopedPeriodBudget._id,
			is_active: true,
		}).populate('inventory_category_id', 'title');

		const scopedCategoryNames = scopedAllocations
			.map((allocation) => allocation.inventory_category_id?.title)
			.filter(Boolean);

		expenseFilter.$or = [
			{ notes: { $regex: `period_budget_id=${scopedPeriodBudget._id}` } },
			{ category: { $in: scopedCategoryNames } },
		];
	}

	const [
		members,
		expenses,
		pointHistory,
		walletTransactions,
		allowances,
		budgets,
		memberWallets,
	] = await Promise.all([
		Member.find({ family_id: familyId }).populate('member_type_id', 'type').select('_id username mail member_type_id'),
		Expense.find(expenseFilter).select('title description category amount expense_source expense_date createdAt member_mail notes linked_member_allowance_id budget_id budget_category_id'),
		PointHistory.find({ family_id: familyId }).select('member_mail points_amount reason_type createdAt'),
		WalletTransaction.find({ family_id: familyId }).select('member_mail amount transaction_type description transaction_date createdAt'),
		MemberAllowance.find({ family_id: familyId }).select('member_mail allowance_currency money_amount spent_amount start_date end_date createdAt'),
		Budget.find({ family_id: familyId, is_active: true }).select('category_name budget_amount spent_amount'),
		MemberWallet.find({ family_id: familyId }).select('member_mail balance'),
	]);

	const children = members.filter((member) => member.member_type_id?.type !== 'Parent');
	const memberByMail = new Map(members.map((member) => [member.mail, member]));

	const totalFamilySpending = expenses.reduce((sum, item) => sum + Number(item.amount || 0), 0);

	let totalPointsEarned = 0;
	let totalPointsRedeemed = 0;
	for (const item of pointHistory) {
		const value = Number(item.points_amount || 0);
		if (value > 0) totalPointsEarned += value;
		if (value < 0 && item.reason_type === 'redeem') totalPointsRedeemed += Math.abs(value);
	}

	const allowanceMoneyFromModel = allowances.reduce(
		(sum, entry) => sum + Number(entry.money_amount || 0),
		0
	);
	const allowanceSpentFromModel = allowances.reduce(
		(sum, entry) => sum + Number(entry.spent_amount || 0),
		0
	);

	const rewardDeposits = walletTransactions.filter((tx) =>
		tx.transaction_type === 'deposit' && /^Task completed:/i.test(tx.description || '')
	);
	const allowanceDeposits = walletTransactions.filter((tx) =>
		tx.transaction_type === 'deposit' && /allowance/i.test(tx.description || '')
	);

	const moneyGivenTaskRewards = rewardDeposits.reduce((sum, tx) => sum + Number(tx.amount || 0), 0);
	const moneyGivenAllowances = allowanceMoneyFromModel + allowanceDeposits.reduce((sum, tx) => sum + Number(tx.amount || 0), 0);
	const totalMoneyGivenAsAllowanceRewards = Number((moneyGivenTaskRewards + moneyGivenAllowances).toFixed(2));

	const personalExpenses = expenses.filter((expense) => expense.expense_source === 'personal_budget');
	const personalSpendingTotal = personalExpenses.reduce((sum, expense) => sum + Number(expense.amount || 0), 0);

	const spendingByCategoryMap = new Map();
	for (const expense of expenses) {
		const category = (expense.category || 'Uncategorized').trim() || 'Uncategorized';
		spendingByCategoryMap.set(
			category,
			Number((Number(spendingByCategoryMap.get(category) || 0) + Number(expense.amount || 0)).toFixed(2))
		);
	}
	if (moneyGivenAllowances > 0) {
		spendingByCategoryMap.set(
			'Allowances',
			Number((Number(spendingByCategoryMap.get('Allowances') || 0) + moneyGivenAllowances).toFixed(2))
		);
	}
	if (moneyGivenTaskRewards > 0) {
		spendingByCategoryMap.set(
			'Rewards',
			Number((Number(spendingByCategoryMap.get('Rewards') || 0) + moneyGivenTaskRewards).toFixed(2))
		);
	}

	const spendingByCategory = Array.from(spendingByCategoryMap.entries()).map(([category, amount]) => ({
		category,
		amount,
	}));

	const pointsEarnedRedeemedByMember = children.map((child) => {
		const history = pointHistory.filter((entry) => entry.member_mail === child.mail);
		const earned = history
			.filter((entry) => Number(entry.points_amount || 0) > 0)
			.reduce((sum, entry) => sum + Number(entry.points_amount || 0), 0);
		const redeemed = history
			.filter((entry) => Number(entry.points_amount || 0) < 0 && entry.reason_type === 'redeem')
			.reduce((sum, entry) => sum + Math.abs(Number(entry.points_amount || 0)), 0);

		return {
			member_id: child._id,
			member_name: child.username,
			member_mail: child.mail,
			points_earned: Number(earned.toFixed(2)),
			points_redeemed: Number(redeemed.toFixed(2)),
		};
	});

	const rewardsSpendingOverTimeMap = new Map();
	for (const expense of expenses) {
		const isRewardExpense =
			(expense.category || '').toLowerCase() === 'rewards' || expense.expense_source === 'redeem_reward';
		if (!isRewardExpense) continue;

		const date = new Date(expense.expense_date || expense.createdAt || now);
		const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
		rewardsSpendingOverTimeMap.set(
			key,
			Number((Number(rewardsSpendingOverTimeMap.get(key) || 0) + Number(expense.amount || 0)).toFixed(2))
		);
	}
	for (const tx of rewardDeposits) {
		const date = new Date(tx.transaction_date || tx.createdAt || now);
		const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
		rewardsSpendingOverTimeMap.set(
			key,
			Number((Number(rewardsSpendingOverTimeMap.get(key) || 0) + Number(tx.amount || 0)).toFixed(2))
		);
	}

	const rewardsSpendingOverTime = Array.from(rewardsSpendingOverTimeMap.entries())
		.sort((a, b) => a[0].localeCompare(b[0]))
		.map(([date, amount]) => ({ date, amount }));

	const walletMap = new Map(memberWallets.map((wallet) => [wallet.member_mail, wallet]));

	const memberSummaries = children.map((child) => {
		const pointsEntries = pointHistory.filter((entry) => entry.member_mail === child.mail);
		const pointsEarned = pointsEntries
			.filter((entry) => Number(entry.points_amount || 0) > 0)
			.reduce((sum, entry) => sum + Number(entry.points_amount || 0), 0);
		const pointsRedeemed = pointsEntries
			.filter((entry) => Number(entry.points_amount || 0) < 0 && entry.reason_type === 'redeem')
			.reduce((sum, entry) => sum + Math.abs(Number(entry.points_amount || 0)), 0);

		const allowanceMoney = allowances
			.filter((entry) => entry.member_mail === child.mail)
			.reduce((sum, entry) => sum + Number(entry.money_amount || 0), 0);

		const taskRewardMoney = rewardDeposits
			.filter((entry) => entry.member_mail === child.mail)
			.reduce((sum, entry) => sum + Number(entry.amount || 0), 0);

		const wallet = walletMap.get(child.mail);
		const memberAllowances = allowances.filter((entry) => entry.member_mail === child.mail);
		const personalBudgetAmount = memberAllowances.reduce((sum, entry) => sum + Number(entry.money_amount || 0), 0);
		const personalBudgetSpent = memberAllowances.reduce((sum, entry) => sum + Number(entry.spent_amount || 0), 0);
		const personalBudgetRemaining = Number(Math.max(0, personalBudgetAmount - personalBudgetSpent).toFixed(2));

		return {
			member_id: child._id,
			member_name: child.username,
			member_mail: child.mail,
			money_received: Number((allowanceMoney + taskRewardMoney).toFixed(2)),
			allowance_money_received: Number(allowanceMoney.toFixed(2)),
			personal_budget_amount: Number(personalBudgetAmount.toFixed(2)),
			personal_budget_spent: Number(personalBudgetSpent.toFixed(2)),
			personal_budget_remaining: personalBudgetRemaining,
			task_rewards_money_received: Number(taskRewardMoney.toFixed(2)),
			points_earned: Number(pointsEarned.toFixed(2)),
			points_redeemed: Number(pointsRedeemed.toFixed(2)),
			current_money_saved: Number((wallet?.balance || 0).toFixed(2)),
		};
	});

	const rewardsBudget = budgets.find((budget) => (budget.category_name || '').toLowerCase() === 'rewards');
	const allowancesBudget = budgets.find((budget) => (budget.category_name || '').toLowerCase() === 'allowances');

	const budgetHealth = {
		rewards: {
			budget_amount: Number(rewardsBudget?.budget_amount || 0),
			spent_amount: Number(rewardsBudget?.spent_amount || 0),
			over_budget: Number(rewardsBudget?.spent_amount || 0) > Number(rewardsBudget?.budget_amount || 0),
		},
		allowances: {
			budget_amount: Number(allowancesBudget?.budget_amount || allowanceMoneyFromModel),
			spent_amount: Number(allowancesBudget?.spent_amount || allowanceSpentFromModel),
			over_budget: Number(allowancesBudget?.spent_amount || allowanceSpentFromModel) > Number(allowancesBudget?.budget_amount || allowanceMoneyFromModel),
		},
		personal_budget: {
			budget_amount: Number(allowanceMoneyFromModel.toFixed(2)),
			spent_amount: Number(allowanceSpentFromModel.toFixed(2)),
			over_budget: allowanceSpentFromModel > allowanceMoneyFromModel,
		},
	};

	const alerts = [];
	if (budgetHealth.rewards.over_budget) {
		alerts.push('Rewards category is over budget');
	}
	if (budgetHealth.allowances.over_budget) {
		alerts.push('Allowances category is over budget');
	}
	if (budgetHealth.personal_budget.over_budget) {
		alerts.push('Some personal budgets are over budget');
	}

	const monthlySummary = {
		month: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`,
		money_spent_this_month: Number(
			expenses
				.filter((entry) => new Date(entry.expense_date || entry.createdAt || now) >= monthStart)
				.reduce((sum, entry) => sum + Number(entry.amount || 0), 0)
				.toFixed(2)
		),
		personal_money_spent_this_month: Number(
			expenses
				.filter((entry) =>
					entry.expense_source === 'personal_budget' && new Date(entry.expense_date || entry.createdAt || now) >= monthStart
				)
				.reduce((sum, entry) => sum + Number(entry.amount || 0), 0)
				.toFixed(2)
		),
		points_earned_this_month: Number(
			pointHistory
				.filter((entry) => new Date(entry.createdAt || now) >= monthStart && Number(entry.points_amount || 0) > 0)
				.reduce((sum, entry) => sum + Number(entry.points_amount || 0), 0)
				.toFixed(2)
		),
		points_redeemed_this_month: Number(
			pointHistory
				.filter(
					(entry) =>
						new Date(entry.createdAt || now) >= monthStart &&
						Number(entry.points_amount || 0) < 0 &&
						entry.reason_type === 'redeem'
				)
				.reduce((sum, entry) => sum + Math.abs(Number(entry.points_amount || 0)), 0)
				.toFixed(2)
		),
	};

	const expenseDetails = expenses
		.map((expense) => ({
			expense_id: expense._id,
			title: expense.title || expense.category || 'Expense',
			description: expense.description || '',
			category: expense.category || 'Uncategorized',
			amount: Number(Number(expense.amount || 0).toFixed(2)),
			expense_source: expense.expense_source || 'budget',
			member_mail: expense.member_mail || '',
			expense_date: expense.expense_date || expense.createdAt,
			notes: expense.notes || '',
		}))
		.sort((a, b) => new Date(b.expense_date) - new Date(a.expense_date));

	res.status(200).json({
		status: 'success',
		data: {
			scope: scopedPeriodBudget
				? {
					period_budget_id: scopedPeriodBudget._id,
					title: scopedPeriodBudget.title,
					start_date: scopedPeriodBudget.start_date,
					end_date: scopedPeriodBudget.end_date,
				}
				: null,
			overview: {
				total_family_spending: Number(totalFamilySpending.toFixed(2)),
				total_points_earned: Number(totalPointsEarned.toFixed(2)),
				total_points_redeemed: Number(totalPointsRedeemed.toFixed(2)),
				total_money_given_as_allowance_rewards: totalMoneyGivenAsAllowanceRewards,
			},
			charts: {
				spending_by_category: spendingByCategory,
				points_earned_vs_redeemed_by_member: pointsEarnedRedeemedByMember,
				rewards_spending_over_time: rewardsSpendingOverTime,
			},
			member_summaries: memberSummaries,
			budget_health: budgetHealth,
			alerts,
			monthly_summary_for_parents: monthlySummary,
			personal_budget_summary: {
				total_budget_amount: Number(allowanceMoneyFromModel.toFixed(2)),
				total_spent_amount: Number(allowanceSpentFromModel.toFixed(2)),
				total_remaining_amount: Number(Math.max(0, allowanceMoneyFromModel - allowanceSpentFromModel).toFixed(2)),
				personal_spending_this_month: Number(personalSpendingTotal.toFixed(2)),
				tracked_expenses: personalExpenses.length,
			},
			expense_details: expenseDetails,
		},
	});
});

// ── Get all future events for a family ─────────────────────────────────────
exports.getFutureEvents = catchAsync(async (req, res, next) => {
	const familyId = req.familyAccount._id;
	console.log('🔍 getFutureEvents called with familyId:', familyId);

	const events = await FutureEvent.find({ family_id: familyId })
		.populate('members_contributing.member_id', 'username email')
		.sort({ event_date: 1 })
		.lean();

	console.log(`✓ Found ${events.length} future events for family ${familyId}`);

	res.status(200).json({
		status: 'success',
		data: {
			events: events || [],
		},
	});
});

// ── Update a future event ──────────────────────────────────────────────────
exports.updateFutureEvent = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;
	const familyId = req.familyAccount._id;
	const { title, description, event_date, estimated_cost, funding_source, required_points } = req.body;

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	const event = await FutureEvent.findOne({ _id: eventId, family_id: familyId });
	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	// Update allowed fields
	if (title !== undefined) event.title = title.trim();
	if (description !== undefined) event.description = description.trim();
	if (event_date !== undefined) event.event_date = new Date(event_date);
	if (estimated_cost !== undefined) event.estimated_cost = Number(estimated_cost);
	if (funding_source !== undefined) {
		if (!['budget', 'member_contributions', 'points_redeem'].includes(funding_source)) {
			return next(new AppError("funding_source must be 'budget', 'member_contributions', or 'points_redeem'", 400));
		}
		event.funding_source = funding_source;
	}
	if (required_points !== undefined) event.required_points = Number(required_points);

	await event.save();

	res.status(200).json({
		status: 'success',
		message: 'Future event updated successfully',
		data: { event },
	});
});

// ── Delete a future event ──────────────────────────────────────────────────
exports.deleteFutureEvent = catchAsync(async (req, res, next) => {
	const { eventId } = req.params;
	const familyId = req.familyAccount._id;

	if (!mongoose.Types.ObjectId.isValid(eventId)) {
		return next(new AppError('Invalid event ID', 400));
	}

	const event = await FutureEvent.findOne({ _id: eventId, family_id: familyId });
	if (!event) {
		return next(new AppError('Event not found', 404));
	}

	// Delete auto-created reward items
	if (event.auto_created_reward_items && event.auto_created_reward_items.length > 0) {
		await WishlistItem.deleteMany({ _id: { $in: event.auto_created_reward_items } });
	}

	await FutureEvent.deleteOne({ _id: eventId });

	res.status(204).json({
		status: 'success',
		data: null,
	});
});

// ── Update a period budget ─────────────────────────────────────────────────
exports.updatePeriodBudget = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	const allowed = ['title', 'period_type', 'start_date', 'end_date', 'total_amount', 'emergency_fund_percentage', 'threshold_percentage', 'is_active'];
	const updates = {};
	allowed.forEach((k) => { if (req.body[k] !== undefined) updates[k] = req.body[k]; });

	const periodBudget = await PeriodBudget.findOneAndUpdate(
		{ _id: periodBudgetId, family_id: req.familyAccount._id },
		{ $set: updates },
		{ new: true, runValidators: true }
	);

	if (!periodBudget) {
		return next(new AppError('Period budget not found', 404));
	}

	res.status(200).json({
		status: 'success',
		message: 'Period budget updated successfully',
		data: { period_budget: periodBudget },
	});
});

// ── Delete a period budget ─────────────────────────────────────────────────
exports.deletePeriodBudget = catchAsync(async (req, res, next) => {
	const { periodBudgetId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(periodBudgetId)) {
		return next(new AppError('Invalid period budget ID', 400));
	}

	const periodBudget = await PeriodBudget.findOneAndDelete({
		_id: periodBudgetId,
		family_id: req.familyAccount._id,
	});

	if (!periodBudget) {
		return next(new AppError('Period budget not found', 404));
	}

	await BudgetAllocation.deleteMany({ period_budget_id: periodBudgetId });
	await MemberAllowance.deleteMany({ period_budget_id: periodBudgetId });

	res.status(204).json({ status: 'success', data: null });
});

// ── Child: submit expense request ──────────────────────────────────────────
exports.createExpenseRequest = catchAsync(async (req, res, next) => {
	const { title, amount, description, budget_id, budget_category_id } = req.body;

	if (!title || amount === undefined) {
		return next(new AppError('Please provide title and amount', 400));
	}

	const normalizedAmount = Number(amount);
	if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
		return next(new AppError('amount must be a positive number', 400));
	}

	const expense = await Expense.create({
		family_id: req.familyAccount._id,
		member_id: req.member._id,
		member_mail: req.member.mail,
		title,
		amount: normalizedAmount,
		description: description || '',
		expense_source: 'budget',
		expense_scope: 'shared',
		budget_id: budget_id && mongoose.Types.ObjectId.isValid(budget_id) ? budget_id : null,
		budget_category_id: budget_category_id && mongoose.Types.ObjectId.isValid(budget_category_id) ? budget_category_id : null,
		request_status: 'pending',
		is_finalized: false,
	});

	await sendParentNotification(
		req.familyAccount._id,
		'New expense request from family member',
		`${req.member.username || req.member.mail} requested an expense: "${title}" for ${normalizedAmount.toFixed(2)} EGP. Please review in the app.`
	).catch(() => {});

	res.status(201).json({
		status: 'success',
		message: 'Expense request submitted for parent approval',
		data: { expense },
	});
});

// ── Parent: get expense requests ───────────────────────────────────────────
exports.getExpenseRequests = catchAsync(async (req, res, next) => {
	const { status } = req.query;
	const filter = {
		family_id: req.familyAccount._id,
		request_status: { $ne: null },
	};
	if (status && ['pending', 'approved', 'rejected'].includes(status)) {
		filter.request_status = status;
	}

	const requests = await Expense.find(filter)
		.populate('member_id', 'username mail')
		.populate('budget_category_id', 'title')
		.sort({ createdAt: -1 })
		.limit(100);

	res.status(200).json({
		status: 'success',
		results: requests.length,
		data: { requests },
	});
});

// ── Parent: approve expense request ───────────────────────────────────────
exports.approveExpenseRequest = catchAsync(async (req, res, next) => {
	const { expenseId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(expenseId)) {
		return next(new AppError('Invalid expense ID', 400));
	}

	const expense = await Expense.findOne({
		_id: expenseId,
		family_id: req.familyAccount._id,
		request_status: 'pending',
	});

	if (!expense) {
		return next(new AppError('Pending expense request not found', 404));
	}

	if (expense.budget_id) {
		const periodBudget = await PeriodBudget.findOne({ _id: expense.budget_id, family_id: req.familyAccount._id });
		if (periodBudget) {
			periodBudget.spent_amount = Number((Number(periodBudget.spent_amount || 0) + expense.amount).toFixed(2));
			await periodBudget.save();
		}
		if (expense.budget_category_id) {
			await BudgetAllocation.findOneAndUpdate(
				{ period_budget_id: expense.budget_id, inventory_category_id: expense.budget_category_id, is_active: true },
				{ $inc: { spent_amount: expense.amount } }
			);
		}
	}

	expense.request_status = 'approved';
	expense.is_finalized = true;
	expense.finalized_at = new Date();
	await expense.save();

	res.status(200).json({
		status: 'success',
		message: 'Expense request approved',
		data: { expense },
	});
});

// ── Parent: reject expense request ────────────────────────────────────────
exports.rejectExpenseRequest = catchAsync(async (req, res, next) => {
	const { expenseId } = req.params;

	if (!mongoose.Types.ObjectId.isValid(expenseId)) {
		return next(new AppError('Invalid expense ID', 400));
	}

	const expense = await Expense.findOne({
		_id: expenseId,
		family_id: req.familyAccount._id,
		request_status: 'pending',
	});

	if (!expense) {
		return next(new AppError('Pending expense request not found', 404));
	}

	expense.request_status = 'rejected';
	await expense.save();

	res.status(200).json({
		status: 'success',
		message: 'Expense request rejected',
		data: { expense },
	});
});
