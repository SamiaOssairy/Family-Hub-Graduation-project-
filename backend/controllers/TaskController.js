const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Task = require("../models/taskModel");
const TaskDetails = require("../models/task_historyModel");
const TaskCategory = require("../models/task_categoryModel");
const Member = require("../models/MemberModel");
const MemberType = require("../models/MemberTypeModel");
const Budget = require("../models/budgetModel");
const PointWallet = require("../models/point_walletModel");
const PointHistory = require("../models/point_historyModel");
const MemberWallet = require("../models/memberWalletModel");
const WalletTransaction = require("../models/walletTransactionModel");
const { recordBalanceWalletDetail } = require('../Utils/balanceWalletDetailHelper');

const TASKS_REWARDS_CATEGORY = "Tasks/Rewards";

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

const applyTaskRewards = async ({ task, taskDetail, familyId, actorMail }) => {
  const rewardType = task.reward_type || "points";
  const pointReward = rewardType === "points" || rewardType === "both" ? Number(taskDetail.assigned_points || 0) : 0;
  const moneyReward = rewardType === "money" || rewardType === "both" ? Number(task.money_reward || 0) : 0;

  let pointWallet = null;
  let moneyWallet = null;
  let pointHistory = null;
  let walletTransaction = null;
  let budgetAfterUpdate = null;

  if (pointReward > 0) {
    pointWallet = await ensurePointWallet(taskDetail.member_mail, familyId);
    pointWallet.total_points = Number((pointWallet.total_points + pointReward).toFixed(2));
    pointWallet.last_update = new Date();
    await pointWallet.save();

    pointHistory = await PointHistory.create({
      wallet_id: pointWallet._id,
      member_mail: taskDetail.member_mail,
      family_id: familyId,
      points_amount: pointReward,
      reason_type: "task_completion",
      task_id: taskDetail.task_id,
      granted_by: actorMail,
      description: `Task completed: ${task.title}`,
    });
  }

  if (moneyReward > 0) {
    moneyWallet = await ensureMoneyWallet(taskDetail.member_mail, familyId);
    moneyWallet.balance = Number((moneyWallet.balance + moneyReward).toFixed(2));
    moneyWallet.last_update = new Date();
    await moneyWallet.save();

    walletTransaction = await WalletTransaction.create({
      family_id: familyId,
      member_mail: taskDetail.member_mail,
      member_wallet_id: moneyWallet._id,
      amount: moneyReward,
      transaction_type: "deposit",
      description: `Task completed: ${task.title}`,
      conversion_type: "none",
      converted_amount: moneyReward,
      conversion_rate: 1,
      linked_point_transaction_id: pointHistory ? pointHistory._id : null,
    });

    await recordBalanceWalletDetail({
      family_id: familyId,
      member_id: taskDetail.member_id || null,
      member_mail: taskDetail.member_mail,
      member_wallet_id: moneyWallet._id,
      wallet_scope: 'money_wallet',
      change_type: 'credit',
      source_type: 'task_reward',
      amount: moneyReward,
      previous_balance: Number((moneyWallet.balance - moneyReward).toFixed(2)),
      new_balance: moneyWallet.balance,
      title: 'Task reward added',
      description: `Task completed: ${task.title}`,
      added_by_mail: actorMail,
      linked_wallet_transaction_id: walletTransaction._id,
      linked_point_history_id: pointHistory ? pointHistory._id : null,
      linked_task_history_id: taskDetail._id,
      notes: 'task reward money deposit',
    });

    const budget = await Budget.findOne({ family_id: familyId, category_name: TASKS_REWARDS_CATEGORY, is_active: true });
    if (budget) {
      budget.spent_amount = Number((Number(budget.spent_amount || 0) + moneyReward).toFixed(2));
      await budget.save();
      budgetAfterUpdate = budget;
    }

    task.paid_to_wallet = true;
    await task.save();
  }

  return {
    reward_type: rewardType,
    points_awarded: pointReward,
    money_awarded: moneyReward,
    point_wallet: pointWallet,
    money_wallet: moneyWallet,
    point_history: pointHistory,
    wallet_transaction: walletTransaction,
    budget: budgetAfterUpdate,
  };
};
// Anyone can create tasks and assign to anyone
// Non-parent assignments need parent approval
// Child marks complete → Parent approves → Points auto-awarded
// Auto/manual penalty for missed deadlines
// Task priority and mandatory flags
//========================================================================================
// Create a new task template
exports.createTask = catchAsync(async (req, res, next) => {
  const { title, description, is_mandatory, category_id, reward_type, money_reward, force_create } = req.body;
  
  if (!title || !category_id) {
    return next(new AppError("Please provide title and category_id", 400));
  }
  
  // Verify category exists and belongs to this family
  const category = await TaskCategory.findOne({ 
    _id: category_id, 
    family_id: req.familyAccount._id 
  });
  
  if (!category) {
    return next(new AppError("Category not found or doesn't belong to your family", 404));
  }
  
  const normalizedRewardType = reward_type || 'points';
  const normalizedMoneyReward = Number(money_reward || 0);

  if (!['points', 'money', 'both'].includes(normalizedRewardType)) {
    return next(new AppError("reward_type must be one of: points, money, both", 400));
  }

  if (!Number.isFinite(normalizedMoneyReward) || normalizedMoneyReward < 0) {
    return next(new AppError("money_reward must be a non-negative number", 400));
  }

  if ((normalizedRewardType === 'money' || normalizedRewardType === 'both') && normalizedMoneyReward <= 0) {
    return next(new AppError("money_reward must be greater than 0 when reward_type is money or both", 400));
  }

  if (normalizedRewardType === 'money' || normalizedRewardType === 'both') {
    const budget = await Budget.findOne({
      family_id: req.familyAccount._id,
      category_name: TASKS_REWARDS_CATEGORY,
      is_active: true,
    });

    if (budget) {
      const remaining = Number((Number(budget.budget_amount || 0) - Number(budget.spent_amount || 0)).toFixed(2));
      if (remaining < normalizedMoneyReward && !force_create) {
        return res.status(409).json({
          status: 'warning',
          message: 'Budget for Tasks/Rewards is low. Create anyway?',
          data: {
            remaining_budget: remaining,
            required_amount: normalizedMoneyReward,
          },
        });
      }
    }
  }

  const newTask = await Task.create({
    title,
    description: description || '',
    is_mandatory: is_mandatory || false,
    created_by: req.member.mail,
    reward_type: normalizedRewardType,
    money_reward: normalizedMoneyReward,
    category_id,
    family_id: req.familyAccount._id
  });
  
  await newTask.populate('category_id');
  
  res.status(201).json({
    status: "success",
    data: { task: newTask }
  });
});

//========================================================================================
// Get all tasks for the family
exports.getAllTasks = catchAsync(async (req, res, next) => {
  const tasks = await Task.find({ family_id: req.familyAccount._id })
    .populate('category_id');
  
  res.status(200).json({
    status: "success",
    results: tasks.length,
    data: { tasks }
  });
});

//========================================================================================
// Update/Edit a task
exports.updateTask = catchAsync(async (req, res, next) => {
  const { taskId } = req.params;
  const { title, description, is_mandatory, category_id } = req.body;
  
  const task = await Task.findOne({ 
    _id: taskId, 
    family_id: req.familyAccount._id 
  });
  
  if (!task) {
    return next(new AppError("Task not found", 404));
  }
  
  // Only parent or creator can edit
  const memberType = await MemberType.findById(req.member.member_type_id);
  if (memberType.type !== 'Parent' && task.created_by !== req.member.mail) {
    return next(new AppError("You don't have permission to edit this task", 403));
  }
  
  if (title) task.title = title;
  if (description !== undefined) task.description = description;
  if (is_mandatory !== undefined) task.is_mandatory = is_mandatory;
  if (category_id) {
    // Verify new category belongs to family
    const category = await TaskCategory.findOne({ 
      _id: category_id, 
      family_id: req.familyAccount._id 
    });
    if (!category) {
      return next(new AppError("Category not found", 404));
    }
    task.category_id = category_id;
  }
  
  await task.save();
  await task.populate('category_id');
  
  res.status(200).json({
    status: "success",
    data: { task }
  });
});

//========================================================================================
// Delete a task
exports.deleteTask = catchAsync(async (req, res, next) => {
  const { taskId } = req.params;
  
  const task = await Task.findOne({ 
    _id: taskId, 
    family_id: req.familyAccount._id 
  });
  
  if (!task) {
    return next(new AppError("Task not found", 404));
  }
  
  // Only parent or creator can delete
  const memberType = await MemberType.findById(req.member.member_type_id);
  if (memberType.type !== 'Parent' && task.created_by !== req.member.mail) {
    return next(new AppError("You don't have permission to delete this task", 403));
  }
  
  await Task.findByIdAndDelete(taskId);
  
  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// Assign a task to a member
exports.assignTask = catchAsync(async (req, res, next) => {
  const { task_id, member_mail, assigned_points, penalty_points, deadline, priority } = req.body;
  
  if (!task_id || !member_mail || !assigned_points || !deadline) {
    return next(new AppError("Please provide task_id, member_mail, assigned_points, and deadline", 400));
  }
  
  // Verify task exists and belongs to family
  const task = await Task.findOne({ 
    _id: task_id, 
    family_id: req.familyAccount._id 
  });
  
  if (!task) {
    return next(new AppError("Task not found", 404));
  }
  
  // Verify member exists and belongs to family
  const targetMember = await Member.findOne({ 
    mail: member_mail, 
    family_id: req.familyAccount._id 
  });
  
  if (!targetMember) {
    return next(new AppError("Member not found in your family", 404));
  }
  
  // Check if assigner is Parent
  const assignerType = await MemberType.findById(req.member.member_type_id);
  const needsApproval = assignerType.type !== 'Parent';
  
  const taskDetail = await TaskDetails.create({
    task_id,
    member_mail,
    assigned_points,
    penalty_points: penalty_points || 0,
    deadline,
    assigned_by: req.member.mail,
    assignment_approved: !needsApproval,
    assignment_approved_by: needsApproval ? null : req.member.mail,
    priority: priority || 0,
    status: 'assigned'
  });
  
  await taskDetail.populate('task_id');
  
  res.status(201).json({
    status: "success",
    message: needsApproval ? "Task assigned successfully. Waiting for parent approval." : "Task assigned successfully.",
    data: { taskDetail }
  });
});

//========================================================================================
// Approve task assignment (Parent only)
exports.approveTaskAssignment = catchAsync(async (req, res, next) => {
  const { taskDetailId } = req.params;
  const { approved } = req.body; // true or false
  
  if (approved === undefined) {
    return next(new AppError("Please provide approval status (approved: true/false)", 400));
  }
  
  const taskDetail = await TaskDetails.findById(taskDetailId)
    .populate('task_id');
  
  if (!taskDetail) {
    return next(new AppError("Task assignment not found", 404));
  }
  
  // Verify task belongs to family
  const task = await Task.findById(taskDetail.task_id);
  if (task.family_id.toString() !== req.familyAccount._id.toString()) {
    return next(new AppError("This task doesn't belong to your family", 403));
  }
  
  if (taskDetail.assignment_approved) {
    return next(new AppError("This task assignment is already approved", 400));
  }
  
  if (approved) {
    taskDetail.assignment_approved = true;
    taskDetail.assignment_approved_by = req.member.mail;
    await taskDetail.save();
    
    res.status(200).json({
      status: "success",
      message: "Task assignment approved",
      data: { taskDetail }
    });
  } else {
    // Reject - delete the assignment
    await TaskDetails.findByIdAndDelete(taskDetailId);
    
    res.status(200).json({
      status: "success",
      message: "Task assignment rejected and removed"
    });
  }
});

//========================================================================================
// Get pending task assignments (Parent only - for approval)
exports.getPendingAssignments = catchAsync(async (req, res, next) => {
  const taskDetails = await TaskDetails.find({ assignment_approved: false })
    .populate({
      path: 'task_id',
      match: { family_id: req.familyAccount._id },
      populate: { path: 'category_id' }
    });
  
  // Filter out null task_id (tasks from other families)
  const filteredTaskDetails = taskDetails.filter(td => td.task_id !== null);
  
  res.status(200).json({
    status: "success",
    results: filteredTaskDetails.length,
    data: { pendingAssignments: filteredTaskDetails }
  });
});

//========================================================================================
// Get member's assigned tasks
exports.getMyTasks = catchAsync(async (req, res, next) => {
  // Get ALL tasks assigned to this member (regardless of approval status)
  const taskDetails = await TaskDetails.find({ 
    member_mail: req.member.mail
  })
    .populate({
      path: 'task_id',
      populate: { path: 'category_id' }
    })
    .sort({ deadline: 1 });
  
  res.status(200).json({
    status: "success",
    results: taskDetails.length,
    data: { tasks: taskDetails }
  });
});

//========================================================================================
// Get all assigned tasks for family (Parent can see all)
exports.getAllAssignedTasks = catchAsync(async (req, res, next) => {
  const taskDetails = await TaskDetails.find({ assignment_approved: true })
    .populate({
      path: 'task_id',
      match: { family_id: req.familyAccount._id },
      populate: { path: 'category_id' }
    })
    .sort({ createdAt: -1 });
  
  // Filter out null task_id (tasks from other families)
  const filteredTaskDetails = taskDetails.filter(td => td.task_id !== null);
  
  res.status(200).json({
    status: "success",
    results: filteredTaskDetails.length,
    data: { assignedTasks: filteredTaskDetails }
  });
});

//========================================================================================
// Mark task as completed (by assignee)
exports.completeTask = catchAsync(async (req, res, next) => {
  const { taskDetailId } = req.params;
  const notes = req.body?.notes || '';
  
  const taskDetail = await TaskDetails.findById(taskDetailId)
    .populate('task_id');
  
  if (!taskDetail) {
    return next(new AppError("Task assignment not found", 404));
  }
  
  // Only the assigned member can mark it complete
  if (taskDetail.member_mail !== req.member.mail) {
    return next(new AppError("You can only complete tasks assigned to you", 403));
  }
  
  if (!taskDetail.assignment_approved) {
    return next(new AppError("This task assignment is not yet approved", 400));
  }
  
  if (taskDetail.status === 'approved') {
    return next(new AppError("This task is already completed and rewarded", 400));
  }

  // Allow re-submitting a task that was rejected or marked late.
  const completableStatuses = ['assigned', 'in_progress', 'completed', 'rejected', 'late'];
  if (!completableStatuses.includes(taskDetail.status)) {
    return next(new AppError("This task cannot be completed from its current status", 400));
  }

  // A Parent is the approval authority — when a Parent completes their OWN task
  // it is auto-approved and rewarded. Anyone else must wait for a Parent to review.
  const isParentCompleter = req.member.member_type_id?.type === 'Parent';

  if (isParentCompleter) {
    taskDetail.status = 'approved';
    taskDetail.completed_at = Date.now();
    taskDetail.approved_at = Date.now();
    taskDetail.approved_by = req.member.mail;
    if (notes) taskDetail.notes = notes;
    await taskDetail.save();

    const rewardSummary = await applyTaskRewards({
      task: taskDetail.task_id,
      taskDetail,
      familyId: req.familyAccount._id,
      actorMail: req.member.mail,
    });

    return res.status(200).json({
      status: "success",
      message: "Task completed and rewards applied successfully.",
      data: { taskDetail, rewardSummary }
    });
  }

  // Non-parent → submit for parent approval. No reward until a parent approves.
  taskDetail.status = 'completed';
  taskDetail.completed_at = Date.now();
  if (notes) taskDetail.notes = notes;
  await taskDetail.save();

  res.status(200).json({
    status: "success",
    message: "Task submitted! Waiting for a parent to approve and release your reward.",
    data: { taskDetail }
  });
});

//========================================================================================
// Get completed tasks waiting for approval (Parent only)
exports.getTasksWaitingApproval = catchAsync(async (req, res, next) => {
  const taskDetails = await TaskDetails.find({ status: 'completed' })
    .populate({
      path: 'task_id',
      match: { family_id: req.familyAccount._id },
      populate: { path: 'category_id' }
    })
    .sort({ completed_at: -1 });
  
  const filteredTaskDetails = taskDetails.filter(td => td.task_id !== null);
  
  res.status(200).json({
    status: "success",
    results: filteredTaskDetails.length,
    data: { tasksWaitingApproval: filteredTaskDetails }
  });
});

//========================================================================================
// Approve/Reject completed task and award points (Parent only)
exports.approveTaskCompletion = catchAsync(async (req, res, next) => {
  const { taskDetailId } = req.params;
  const { approved, notes } = req.body;
  
  if (approved === undefined) {
    return next(new AppError("Please provide approval status (approved: true/false)", 400));
  }
  
  const taskDetail = await TaskDetails.findById(taskDetailId)
    .populate('task_id');
  
  if (!taskDetail) {
    return next(new AppError("Task assignment not found", 404));
  }
  
  // Verify belongs to family
  const task = await Task.findById(taskDetail.task_id);
  if (task.family_id.toString() !== req.familyAccount._id.toString()) {
    return next(new AppError("This task doesn't belong to your family", 403));
  }
  
  if (taskDetail.status !== 'completed') {
    return next(new AppError("Task is not marked as completed", 400));
  }
  
  if (approved) {
    // Approve and apply rewards (points and/or money)
    taskDetail.status = 'approved';
    taskDetail.approved_by = req.member.mail;
    taskDetail.approved_at = Date.now();
    if (notes) taskDetail.notes += `\nApproval notes: ${notes}`;
    await taskDetail.save();

    const rewardSummary = await applyTaskRewards({
      task,
      taskDetail,
      familyId: req.familyAccount._id,
      actorMail: req.member.mail,
    });
    
    res.status(200).json({
      status: "success",
      message: `Task approved and rewards applied successfully.`,
      data: { taskDetail, rewardSummary }
    });
  } else {
    // Reject
    taskDetail.status = 'rejected';
    taskDetail.approved_by = req.member.mail;
    if (notes) taskDetail.notes += `\nRejection reason: ${notes}`;
    await taskDetail.save();
    
    res.status(200).json({
      status: "success",
      message: "Task completion rejected",
      data: { taskDetail }
    });
  }
});

//========================================================================================
// Rewards summary for tasks
exports.getTaskRewardsSummary = catchAsync(async (req, res, next) => {
  const period = (req.query.period || 'monthly').toLowerCase();
  const now = new Date();
  let periodStart;

  if (period === 'yearly') {
    periodStart = new Date(now.getFullYear(), 0, 1);
  } else {
    periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
  }

  const isParent = req.member.member_type_id?.type === 'Parent';

  if (isParent) {
    const moneyTransactions = await WalletTransaction.find({
      family_id: req.familyAccount._id,
      transaction_type: 'deposit',
      description: { $regex: '^Task completed:' },
      createdAt: { $gte: periodStart },
    });

    const totalMoneyPaid = moneyTransactions.reduce((sum, tx) => sum + Number(tx.amount || 0), 0);

    return res.status(200).json({
      status: 'success',
      data: {
        role: 'Parent',
        period,
        total_money_paid_for_tasks: Number(totalMoneyPaid.toFixed(2)),
        transactions_count: moneyTransactions.length,
      },
    });
  }

  const [moneyTransactions, pointRewards] = await Promise.all([
    WalletTransaction.find({
      family_id: req.familyAccount._id,
      member_mail: req.member.mail,
      transaction_type: 'deposit',
      description: { $regex: '^Task completed:' },
      createdAt: { $gte: periodStart },
    }),
    PointHistory.find({
      family_id: req.familyAccount._id,
      member_mail: req.member.mail,
      reason_type: 'task_completion',
      createdAt: { $gte: periodStart },
    }),
  ]);

  const totalMoneyEarned = moneyTransactions.reduce((sum, tx) => sum + Number(tx.amount || 0), 0);
  const totalPointsEarned = pointRewards.reduce((sum, item) => sum + Number(item.points_amount || 0), 0);

  res.status(200).json({
    status: 'success',
    data: {
      role: 'Child',
      period,
      total_money_earned_from_tasks: Number(totalMoneyEarned.toFixed(2)),
      total_points_earned_from_tasks: Number(totalPointsEarned.toFixed(2)),
      money_transactions_count: moneyTransactions.length,
      point_rewards_count: pointRewards.length,
    },
  });
});

//========================================================================================
// Set point deduction for undone tasks (manual penalty by Parent)
exports.manualPenalty = catchAsync(async (req, res, next) => {
  const { taskDetailId } = req.params;
  const { penalty_points, notes } = req.body;
  
  if (!penalty_points || penalty_points <= 0) {
    return next(new AppError("Please provide valid penalty_points", 400));
  }
  
  const taskDetail = await TaskDetails.findById(taskDetailId)
    .populate('task_id');
  
  if (!taskDetail) {
    return next(new AppError("Task assignment not found", 404));
  }
  
  const task = await Task.findById(taskDetail.task_id);
  if (task.family_id.toString() !== req.familyAccount._id.toString()) {
    return next(new AppError("This task doesn't belong to your family", 403));
  }
  
  // Update wallet
  let wallet = await ensurePointWallet(taskDetail.member_mail, req.familyAccount._id);
  
  wallet.total_points = Math.max(0, wallet.total_points - penalty_points);
  await wallet.save();
  
  // Create penalty history
  await PointHistory.create({
    wallet_id: wallet._id,
    member_mail: taskDetail.member_mail,
    family_id: req.familyAccount._id,
    points_amount: -penalty_points,
    reason_type: 'penalty',
    task_id: taskDetail.task_id,
    granted_by: req.member.mail,
    description: notes || `Penalty for task: ${task.title}`
  });
  
  // Update task status
  if (taskDetail.status === 'assigned') {
    taskDetail.status = 'late';
  }
  taskDetail.notes += `\nPenalty applied: -${penalty_points} points. ${notes || ''}`;
  await taskDetail.save();
  
  res.status(200).json({
    status: "success",
    message: `Penalty applied: -${penalty_points} points`,
    data: { taskDetail, wallet }
  });
});
