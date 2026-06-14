const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Redeem = require("../models/redeemModel");
const WishlistItem = require("../models/wishlist_itemModel");
const PointWallet = require("../models/point_walletModel");
const PointDetails = require("../models/point_historyModel");
const MemberWallet = require("../models/memberWalletModel");
const WalletTransaction = require("../models/walletTransactionModel");
const Expense = require("../models/ExpenseModel");
const Budget = require("../models/budgetModel");
const FutureEvent = require("../models/futureEventModel");
const Member = require("../models/MemberModel");
const MemberType = require("../models/MemberTypeModel");
const { recordBalanceWalletDetail } = require('../utils/balanceWalletDetailHelper');
const mongoose = require("mongoose");
const nodemailer = require("nodemailer");

const sendParentNotification = async (familyId, subject, text) => {
  const parents = await Member.find({ family_id: familyId })
    .populate('member_type_id', 'type')
    .select('mail username member_type_id');

  const recipientEmails = parents
    .filter((member) => member.member_type_id?.type === 'Parent')
    .map((member) => member.mail)
    .filter(Boolean);

  if (recipientEmails.length === 0) {
    return { sent: false, recipients: [] };
  }

  const emailUser = process.env.EMAIL_USERNAME || process.env.EMAIL_USER;
  const emailPass = process.env.EMAIL_PASSWORD || process.env.EMAIL_PASS;

  if (!emailUser || !emailPass) {
    return { sent: false, recipients: recipientEmails };
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
    html: text,
  });

  return { sent: true, recipients: recipientEmails };
};

const getRewardsBudget = async (familyId) => {
  return Budget.findOne({ family_id: familyId, category_name: 'Rewards', is_active: true });
};

const finalizeRedeemExpense = async (redeemRequest) => {
  let expense = await Expense.findOne({ linked_redeem_id: redeemRequest._id });

  if (!expense) {
    expense = await Expense.create({
      family_id: redeemRequest.family_id || redeemRequest.familyId || redeemRequest.family_id,
      member_id: redeemRequest.member_id || null,
      member_mail: redeemRequest.requester,
      category: 'Rewards',
      title: redeemRequest.request_details,
      description: `Redeemed: ${redeemRequest.request_details}`,
      amount: redeemRequest.money_used || 0,
      expense_source: 'redeem_reward',
      linked_redeem_id: redeemRequest._id,
      is_finalized: true,
      finalized_at: new Date(),
    });
  } else if (!expense.is_finalized) {
    expense.is_finalized = true;
    expense.finalized_at = new Date();
    await expense.save();
  }

  return expense;
};

//========================================================================================
// Request redemption (any member can request)
// Can be for wishlist item OR custom request (school trip, event, etc.)
exports.requestRedemption = catchAsync(async (req, res, next) => {
  const { wishlist_item_id, point_deduction, payment_method, money_used, points_used } = req.body;
  // request_details is derived from the wishlist item when one is given, so it
  // is only required for custom (non-wishlist) redemption requests.
  let request_details = req.body.request_details;

  if (!wishlist_item_id && !request_details) {
    return next(new AppError("Please provide request details (what you want to redeem)", 400));
  }

  let finalPointDeduction = 0;
  const paymentMethod = payment_method || 'points';
  const requestedMoneyUsed = Number(money_used || 0);
  const requestedPointsUsed = Number(points_used || point_deduction || 0);
  let itemDetails = null;
  
  if (wishlist_item_id) {
    // OPTION 1: Redeeming a specific wishlist item
    const item = await WishlistItem.findById(wishlist_item_id)
      .populate('wishlist_id');
    
    if (!item) {
      return next(new AppError("Wishlist item not found", 404));
    }
    
    // Verify item belongs to requester
    if (item.wishlist_id.member_mail !== req.member.mail) {
      return next(new AppError("You can only redeem your own wishlist items", 403));
    }
    
    if (item.status !== 'active') {
      return next(new AppError("This item is not available for redemption", 400));
    }
    
    finalPointDeduction = item.required_points;
    itemDetails = item;
    // Default the request label to the item name when not supplied.
    if (!request_details) request_details = item.item_name;
  } else {
    // OPTION 2: Custom redemption request (school trip, event tickets, etc.)
    if (!point_deduction || point_deduction <= 0) {
      return next(new AppError("Please provide valid point_deduction amount for custom redemption", 400));
    }
    finalPointDeduction = point_deduction;
  }
  
  if ((paymentMethod === 'money' || paymentMethod === 'mixed') && requestedMoneyUsed <= 0) {
    return next(new AppError('Please provide money_used for money or mixed redemptions', 400));
  }

  if ((paymentMethod === 'points' || paymentMethod === 'mixed') && requestedPointsUsed <= 0) {
    return next(new AppError('Please provide points_used for points or mixed redemptions', 400));
  }

  const redeemRequest = await Redeem.create({
    family_id: req.familyAccount._id,
    member_id: req.member._id,
    requester: req.member.mail,
    status: 'pending',
    request_details,
    point_deduction: finalPointDeduction,
    wishlist_item_id: wishlist_item_id || null,
    payment_method: paymentMethod,
    points_used: requestedPointsUsed,
    money_used: requestedMoneyUsed,
    requested_at: Date.now()
  });

  let moneyWallet = null;
  let pointWallet = null;
  let pointHistory = null;
  let walletTransaction = null;
  let expense = null;

  try {
    if (paymentMethod === 'money' || paymentMethod === 'mixed') {
      moneyWallet = await MemberWallet.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
      if (!moneyWallet || moneyWallet.balance < requestedMoneyUsed) {
        await Redeem.findByIdAndDelete(redeemRequest._id);
        return next(new AppError(`Insufficient money balance. You have ${moneyWallet?.balance || 0} but need ${requestedMoneyUsed}.`, 400));
      }

      moneyWallet.balance = Number((moneyWallet.balance - requestedMoneyUsed).toFixed(2));
      moneyWallet.last_update = new Date();
      await moneyWallet.save();

      walletTransaction = await WalletTransaction.create({
        family_id: req.familyAccount._id,
        member_mail: req.member.mail,
        member_wallet_id: moneyWallet._id,
        amount: requestedMoneyUsed,
        transaction_type: 'withdrawal',
        description: `Redeemed: ${request_details}`,
        conversion_type: 'none',
        converted_amount: requestedMoneyUsed,
        conversion_rate: 1,
      });

      await recordBalanceWalletDetail({
        family_id: req.familyAccount._id,
        member_id: req.member._id,
        member_mail: req.member.mail,
        member_wallet_id: moneyWallet._id,
        wallet_scope: 'money_wallet',
        change_type: 'debit',
        source_type: 'redeem',
        amount: requestedMoneyUsed,
        previous_balance: Number((moneyWallet.balance + requestedMoneyUsed).toFixed(2)),
        new_balance: moneyWallet.balance,
        title: 'Redeem payment deducted',
        description: `Redeemed: ${request_details}`,
        added_by_member_id: req.member._id,
        added_by_mail: req.member.mail,
        linked_wallet_transaction_id: walletTransaction._id,
        linked_redeem_id: redeemRequest._id,
        notes: 'redeem money deduction',
      });

      expense = await Expense.create({
        family_id: req.familyAccount._id,
        member_id: req.member._id,
        member_mail: req.member.mail,
        category: 'Rewards',
        title: request_details,
        description: `Redeemed: ${request_details} by ${req.member.username || req.member.mail}`,
        amount: requestedMoneyUsed,
        expense_source: 'redeem_reward',
        linked_redeem_id: redeemRequest._id,
        linked_member_wallet_id: moneyWallet._id,
        is_finalized: false,
      });

      const rewardsBudget = await getRewardsBudget(req.familyAccount._id);
      if (rewardsBudget) {
        rewardsBudget.spent_amount = Number((rewardsBudget.spent_amount + requestedMoneyUsed).toFixed(2));
        await rewardsBudget.save();
      }
    }

    if (paymentMethod === 'points' || paymentMethod === 'mixed') {
      pointWallet = await PointWallet.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
      if (!pointWallet || pointWallet.total_points < requestedPointsUsed) {
        await Redeem.findByIdAndDelete(redeemRequest._id);
        return next(new AppError(`Insufficient points. You have ${pointWallet?.total_points || 0} but need ${requestedPointsUsed}.`, 400));
      }

      pointWallet.total_points = Number((pointWallet.total_points - requestedPointsUsed).toFixed(2));
      pointWallet.last_update = new Date();
      await pointWallet.save();

      pointHistory = await PointDetails.create({
        wallet_id: pointWallet._id,
        member_mail: req.member.mail,
        family_id: req.familyAccount._id,
        points_amount: -requestedPointsUsed,
        reason_type: 'redeem',
        redeem_id: redeemRequest._id,
        granted_by: req.member.mail,
        description: `Redeemed: ${request_details}`
      });
    }

    await sendParentNotification(
      req.familyAccount._id,
      'Reward redeemed',
      `Child redeemed ${request_details} using ${requestedMoneyUsed ? `${requestedMoneyUsed} money` : ''}${requestedMoneyUsed && requestedPointsUsed ? ' + ' : ''}${requestedPointsUsed ? `${requestedPointsUsed} points` : ''}`
    ).catch(() => null);

    if (expense) {
      redeemRequest.linked_expense_id = expense._id;
    }

    if (walletTransaction) {
      redeemRequest.linked_wallet_transaction_id = walletTransaction._id;
      redeemRequest.money_deducted = true;
    }

    if (pointHistory) {
      redeemRequest.points_deducted = true;
    }

    await redeemRequest.save();
  } catch (error) {
    await Redeem.findByIdAndDelete(redeemRequest._id);
    return next(error);
  }
  
  const message = wishlist_item_id 
    ? `Redemption request for "${itemDetails.item_name}" submitted. Waiting for parent approval.`
    : `Custom redemption request for ${finalPointDeduction} points submitted. Waiting for parent approval.`;
  
  res.status(201).json({
    status: "success",
    message,
    data: { redeemRequest }
  });
});

//========================================================================================
// Money-aware redemption endpoint alias
exports.redeemWithMoney = catchAsync(async (req, res, next) => {
  if (!req.body.payment_method || !['money', 'points', 'mixed'].includes(req.body.payment_method)) {
    req.body.payment_method = 'mixed';
  }

  return exports.requestRedemption(req, res, next);
});

//========================================================================================
// Get my redemption requests
exports.getMyRedemptions = catchAsync(async (req, res, next) => {
  const redemptions = await Redeem.find({ requester: req.member.mail })
    .populate('approver', 'username mail')
    .populate('wishlist_item_id')
    .sort({ requested_at: -1 });
  
  res.status(200).json({
    status: "success",
    results: redemptions.length,
    data: { redemptions }
  });
});

//========================================================================================
// Get all pending redemption requests (Parent only)
exports.getPendingRedemptions = catchAsync(async (req, res, next) => {
  // Get all family members
  const members = await Member.find({ family_id: req.familyAccount._id });
  const memberMails = members.map(m => m.mail);
  
  const redemptions = await Redeem.find({ 
    requester: { $in: memberMails },
    status: 'pending'
  })
    .populate('requester', 'username mail')
    .populate('wishlist_item_id')
    .sort({ requested_at: -1 });
  
  res.status(200).json({
    status: "success",
    results: redemptions.length,
    data: { pendingRedemptions: redemptions }
  });
});

//========================================================================================
// Get all redemption requests for family (Parent only)
exports.getAllRedemptions = catchAsync(async (req, res, next) => {
  const members = await Member.find({ family_id: req.familyAccount._id });
  const memberMails = members.map(m => m.mail);
  
  const redemptions = await Redeem.find({ 
    requester: { $in: memberMails }
  })
    .populate('requester', 'username mail')
    .populate('approver', 'username mail')
    .populate('wishlist_item_id')
    .sort({ requested_at: -1 });
  
  res.status(200).json({
    status: "success",
    results: redemptions.length,
    data: { redemptions }
  });
});

//========================================================================================
// Parent approves redemption request (Step 1: Parent approval)
exports.approveRedeemWithBudgetCheck = catchAsync(async (req, res, next) => {
  const { redeemId } = req.params;
  const { approved = true, force_approve, rejection_reason } = req.body;
  
  const redeemRequest = await Redeem.findById(redeemId)
    .populate('requester', 'username mail')
    .populate('wishlist_item_id');
  
  if (!redeemRequest) {
    return next(new AppError("Redemption request not found", 404));
  }
  
  // Verify requester belongs to family
  const member = await Member.findOne({ 
    mail: redeemRequest.requester.mail, 
    family_id: req.familyAccount._id 
  });
  
  if (!member) {
    return next(new AppError("This request doesn't belong to your family", 403));
  }
  
  if (redeemRequest.status !== 'pending') {
    return next(new AppError(`This request has already been ${redeemRequest.status}`, 400));
  }

  if (!approved) {
    redeemRequest.status = 'rejected';
    redeemRequest.approver = req.member.mail;
    redeemRequest.rejection_reason = rejection_reason || 'Rejected by parent';
    await redeemRequest.save();

    return res.status(200).json({
      status: 'success',
      message: 'Redemption request rejected',
      data: { redeemRequest },
    });
  }

  if ((redeemRequest.payment_method === 'money' || redeemRequest.payment_method === 'mixed') && redeemRequest.money_used > 0) {
    const rewardsBudget = await getRewardsBudget(req.familyAccount._id);
    const remainingBudget = rewardsBudget ? Number((rewardsBudget.budget_amount - rewardsBudget.spent_amount).toFixed(2)) : 0;

    if (remainingBudget < redeemRequest.money_used && !force_approve) {
      return res.status(409).json({
        status: 'warning',
        message: 'Budget for Rewards is low. Approve anyway?',
        data: {
          remaining_budget: remainingBudget,
          required_amount: redeemRequest.money_used,
        }
      });
    }

    if (rewardsBudget) {
      const expense = await Expense.findOne({ linked_redeem_id: redeemRequest._id });
      if (expense && !expense.is_finalized) {
        expense.is_finalized = true;
        expense.finalized_at = new Date();
        await expense.save();
      }
    }
  }

  redeemRequest.status = 'child_accepted';
  redeemRequest.approver = req.member.mail;
  redeemRequest.parent_approved_at = Date.now();
  redeemRequest.child_accepted_at = Date.now();
  await redeemRequest.save();

  res.status(200).json({
    status: "success",
    message: "Redemption approved and finalized",
    data: { redeemRequest }
  });
});

// Backward-compatible alias for existing route usage
exports.parentApproveRedemption = exports.approveRedeemWithBudgetCheck;

//========================================================================================
// Get parent-approved redemptions waiting for child acceptance
exports.getApprovedWaitingAcceptance = catchAsync(async (req, res, next) => {
  const redemptions = await Redeem.find({ 
    requester: req.member.mail,
    status: 'parent_approved'
  })
    .populate('approver', 'username mail')
    .populate('wishlist_item_id')
    .sort({ parent_approved_at: -1 });
  
  res.status(200).json({
    status: "success",
    results: redemptions.length,
    data: { approvedRedemptions: redemptions }
  });
});

//========================================================================================
// Child accepts/rejects parent-approved redemption (Step 2: Child acceptance)
exports.childAcceptRedemption = catchAsync(async (req, res, next) => {
  const { redeemId } = req.params;
  const { accept } = req.body;
  
  if (accept === undefined) {
    return next(new AppError("Please provide acceptance status (accept: true/false)", 400));
  }
  
  const redeemRequest = await Redeem.findById(redeemId)
    .populate('wishlist_item_id');
  
  if (!redeemRequest) {
    return next(new AppError("Redemption request not found", 404));
  }
  
  // Only the requester can accept/reject
  if (redeemRequest.requester !== req.member.mail) {
    return next(new AppError("You can only accept/reject your own redemption requests", 403));
  }
  
  if (redeemRequest.status !== 'parent_approved') {
    return next(new AppError("This request is not in parent_approved status", 400));
  }
  
  if (accept) {
    // Child accepts - deduct points
    const wallet = await PointWallet.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
    
    if (!redeemRequest.points_deducted) {
      if (!wallet || wallet.total_points < redeemRequest.point_deduction) {
        return next(new AppError("Insufficient points for redemption", 400));
      }
      
      wallet.total_points -= redeemRequest.point_deduction;
      await wallet.save();
      
      await PointDetails.create({
        wallet_id: wallet._id,
        member_mail: req.member.mail,
        family_id: req.familyAccount._id,
        points_amount: -redeemRequest.point_deduction,
        reason_type: 'redeem',
        redeem_id: redeemRequest._id,
        granted_by: redeemRequest.approver,
        description: `Redeemed: ${redeemRequest.request_details}`
      });
    }
    
    // Update redemption status
    redeemRequest.status = 'child_accepted';
    redeemRequest.child_accepted_at = Date.now();
    await redeemRequest.save();
    
    // Update wishlist item if applicable
    if (redeemRequest.wishlist_item_id) {
      const item = await WishlistItem.findById(redeemRequest.wishlist_item_id);
      if (item) {
        item.status = 'redeemed';
        await item.save();
      }
    }
    
    res.status(200).json({
      status: "success",
      message: `Redemption completed! ${redeemRequest.point_deduction} points deducted.`,
      data: { 
        redeemRequest,
        wallet 
      }
    });
  } else {
    // Child cancels
    redeemRequest.status = 'cancelled';
    redeemRequest.rejection_reason = 'Cancelled by requester';
    await redeemRequest.save();
    
    res.status(200).json({
      status: "success",
      message: "Redemption cancelled",
      data: { redeemRequest }
    });
  }
});

//========================================================================================
// Cancel my redemption request (before parent approval)
exports.cancelRedemption = catchAsync(async (req, res, next) => {
  const { redeemId } = req.params;
  
  const redeemRequest = await Redeem.findById(redeemId);
  
  if (!redeemRequest) {
    return next(new AppError("Redemption request not found", 404));
  }
  
  if (redeemRequest.requester !== req.member.mail) {
    return next(new AppError("You can only cancel your own redemption requests", 403));
  }
  
  if (redeemRequest.status !== 'pending') {
    return next(new AppError("You can only cancel pending requests", 400));
  }
  
  redeemRequest.status = 'cancelled';
  redeemRequest.rejection_reason = 'Cancelled by requester';
  await redeemRequest.save();
  
  res.status(200).json({
    status: "success",
    message: "Redemption request cancelled"
  });
});

//========================================================================================
// Redeem an event spot using points
exports.redeemEventSpot = catchAsync(async (req, res, next) => {
  const { event_id, points_to_use } = req.body;
  const pointsToUse = Number(points_to_use);

  if (!event_id || !mongoose.Types.ObjectId.isValid(event_id)) {
    return next(new AppError('Please provide a valid event_id', 400));
  }

  if (!Number.isFinite(pointsToUse) || pointsToUse <= 0) {
    return next(new AppError('Please provide a valid points_to_use', 400));
  }

  const event = await FutureEvent.findOne({
    _id: event_id,
    family_id: req.familyAccount._id,
  });

  if (!event) {
    return next(new AppError('Event not found', 404));
  }

  if ((event.required_points || 0) <= 0) {
    return next(new AppError('This event does not support point-based spots', 400));
  }

  if (pointsToUse < event.required_points) {
    return next(new AppError(`Minimum points required for this event is ${event.required_points}`, 400));
  }

  const alreadyRedeemed = await Redeem.findOne({
    linked_event_id: event._id,
    requester: req.member.mail,
    status: 'child_accepted',
  });

  if (alreadyRedeemed) {
    return next(new AppError('You already redeemed a spot for this event', 400));
  }

  const wallet = await PointWallet.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  if (!wallet || wallet.total_points < pointsToUse) {
    return next(new AppError(`Insufficient points. You have ${wallet?.total_points || 0} but need ${pointsToUse}.`, 400));
  }

  wallet.total_points = Number((wallet.total_points - pointsToUse).toFixed(2));
  wallet.last_update = new Date();
  await wallet.save();

  const redeemRecord = await Redeem.create({
    family_id: req.familyAccount._id,
    member_id: req.member._id,
    requester: req.member.mail,
    approver: req.member.mail,
    status: 'child_accepted',
    request_details: `Event spot: ${event.title}`,
    point_deduction: pointsToUse,
    payment_method: 'points',
    points_used: pointsToUse,
    money_used: 0,
    points_deducted: true,
    linked_event_id: event._id,
    requested_at: Date.now(),
    parent_approved_at: Date.now(),
    child_accepted_at: Date.now(),
  });

  await PointDetails.create({
    wallet_id: wallet._id,
    member_mail: req.member.mail,
    family_id: req.familyAccount._id,
    points_amount: -pointsToUse,
    reason_type: 'redeem',
    redeem_id: redeemRecord._id,
    granted_by: req.member.mail,
    description: `Redeemed event spot: ${event.title}`,
  });

  let contribution = event.members_contributing.find(
    (entry) => entry.member_id.toString() === req.member._id.toString()
  );

  if (!contribution) {
    contribution = {
      member_id: req.member._id,
      amount_promised: 0,
      amount_paid: 0,
      points_promised: event.required_points,
      points_paid: 0,
    };
    event.members_contributing.push(contribution);
    contribution = event.members_contributing[event.members_contributing.length - 1];
  }

  contribution.points_promised = Math.max(Number(contribution.points_promised || 0), Number(event.required_points || 0));
  contribution.points_paid = Number((Number(contribution.points_paid || 0) + pointsToUse).toFixed(2));
  event.total_contributed_points = Number((Number(event.total_contributed_points || 0) + pointsToUse).toFixed(2));
  event.linked_rewards.push(redeemRecord._id);
  await event.save();

  const notification = await sendParentNotification(
    req.familyAccount._id,
    'Event spot redeemed',
    `${req.member.username || req.member.mail} redeemed an event spot for ${event.title} using ${pointsToUse} points.`
  ).catch((error) => ({ sent: false, recipients: [], error: error.message }));

  res.status(201).json({
    status: 'success',
    message: 'Event spot redeemed successfully',
    data: {
      redeem: redeemRecord,
      event,
      wallet,
      notification,
    },
  });
});









