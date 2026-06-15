const { GoogleGenerativeAI } = require('@google/generative-ai');
const AppError = require('../utils/appError');
const { catchAsync } = require('../utils/catchAsync');
const PlanningConversation = require('../models/planningConversationModel');
const Member = require('../models/MemberModel');
const Task = require('../models/taskModel');
const TaskDetails = require('../models/task_historyModel');
const PointWallet = require('../models/point_walletModel');
const PointHistory = require('../models/point_historyModel');
const Expense = require('../models/ExpenseModel');
const PeriodBudget = require('../models/periodBudgetModel');
const FutureEvent = require('../models/futureEventModel');
const Inventory = require('../models/inventoryModel');
const InventoryItem = require('../models/inventoryItemModel');
const Recipe = require('../models/recipeModel');
const RecipeIngredient = require('../models/recipeIngredientModel');
const Meal = require('../models/mealModel');
const Leftover = require('../models/leftoverModel');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// ─── helpers ────────────────────────────────────────────────────────────────

const fmt = (date) => new Date(date).toLocaleDateString('en-GB');
const money = (n) => `${(+n || 0).toFixed(2)} EGP`;

const gatherFamilyContext = async (familyId) => {
  const now = new Date();

  const threeMonthsAgo = new Date(now);
  threeMonthsAgo.setMonth(now.getMonth() - 3);

  const twoWeeksAgo = new Date(now);
  twoWeeksAgo.setDate(now.getDate() - 14);

  const oneWeekAgo = new Date(now);
  oneWeekAgo.setDate(now.getDate() - 7);

  const [members, expenses, periodBudgets, pointWallets, pointHistory, tasks, taskDetails, futureEvents, inventories, recipes, recentMeals, leftovers] =
    await Promise.all([
      Member.find({ family_id: familyId })
        .populate('member_type_id', 'type')
        .select('username mail member_type_id birth_date'),

      Expense.find({ family_id: familyId, expense_date: { $gte: threeMonthsAgo } })
        .sort({ expense_date: -1 })
        .limit(100),

      PeriodBudget.find({ family_id: familyId })
        .sort({ createdAt: -1 })
        .limit(6),

      PointWallet.find({ family_id: familyId }),

      PointHistory.find({ family_id: familyId, createdAt: { $gte: twoWeeksAgo } })
        .sort({ createdAt: -1 })
        .limit(60),

      Task.find({ family_id: familyId })
        .populate('category_id', 'name')
        .limit(50),

      TaskDetails.find({ createdAt: { $gte: twoWeeksAgo } })
        .populate('task_id', 'title family_id')
        .sort({ createdAt: -1 })
        .limit(60),

      FutureEvent.find({ family_id: familyId }).sort({ event_date: 1 }),

      Inventory.find({ family_id: familyId }),

      Recipe.find({ family_id: familyId }).limit(30),

      Meal.find({ family_id: familyId, meal_date: { $gte: oneWeekAgo } })
        .populate('recipe_id', 'recipe_name')
        .sort({ meal_date: -1 })
        .limit(21),

      Leftover.find({ family_id: familyId, expiry_date: { $gt: now } })
        .populate('unit_id', 'name')
        .sort({ expiry_date: 1 })
        .limit(30),
    ]);

  // Keep only task details that belong to this family
  const familyIdStr = familyId.toString();
  const relevantTaskDetails = taskDetails.filter(
    (td) => td.task_id?.family_id?.toString() === familyIdStr
  );

  // Second batch: queries that depend on IDs from the first batch
  const inventoryIds = inventories.map((i) => i._id);
  const recipeIds = recipes.map((r) => r._id);

  const [inventoryItems, recipeIngredients] = await Promise.all([
    inventoryIds.length
      ? InventoryItem.find({ inventory_id: { $in: inventoryIds }, quantity: { $gt: 0 } })
          .populate('unit_id', 'name')
          .limit(80)
      : Promise.resolve([]),

    recipeIds.length
      ? RecipeIngredient.find({ recipe_id: { $in: recipeIds } })
          .populate('unit_id', 'name')
      : Promise.resolve([]),
  ]);

  return {
    members, expenses, periodBudgets, pointWallets, pointHistory,
    tasks, taskDetails: relevantTaskDetails, futureEvents,
    inventoryItems, recipes, recipeIngredients, recentMeals, leftovers,
  };
};

const buildSystemPrompt = (ctx, familyTitle) => {
  const { members, expenses, periodBudgets, pointWallets, pointHistory, tasks, taskDetails, futureEvents,
          inventoryItems, recipes, recipeIngredients, recentMeals, leftovers } = ctx;

  // ── members ──────────────────────────────────────────────────────────────
  const memberLines = members.map(
    (m) => `  • ${m.username} (${m.member_type_id?.type || 'Member'}) — ${m.mail}`
  ).join('\n') || '  (none)';

  // ── point wallets ─────────────────────────────────────────────────────────
  const walletLines = pointWallets.map((w) => {
    const name = members.find((m) => m.mail === w.member_mail)?.username || w.member_mail;
    return `  • ${name}: ${w.total_points} pts`;
  }).join('\n') || '  (none)';

  // ── recent point activity (last 2 weeks) ──────────────────────────────────
  const activityLines = pointHistory.map((h) => {
    const sign = h.points_amount > 0 ? '+' : '';
    const name = members.find((m) => m.mail === h.member_mail)?.username || h.member_mail;
    return `  • ${name}: ${sign}${h.points_amount} pts — ${h.reason_type}${h.description ? ' (' + h.description + ')' : ''} [${fmt(h.createdAt)}]`;
  }).join('\n') || '  (none)';

  // ── tasks ─────────────────────────────────────────────────────────────────
  const taskLines = tasks.map(
    (t) => `  • "${t.title}" | reward: ${t.reward_type}${t.money_reward ? ' / ' + money(t.money_reward) : ''} | category: ${t.category_id?.name || 'General'}`
  ).join('\n') || '  (none)';

  // ── task completions (last 2 weeks) ───────────────────────────────────────
  const completionLines = taskDetails
    .filter((td) => td.status === 'approved' || td.status === 'completed')
    .map((td) => {
      const name = members.find((m) => m.mail === td.member_mail)?.username || td.member_mail;
      return `  • ${name} completed "${td.task_id?.title || 'task'}" — ${td.assigned_points} pts awarded [${fmt(td.createdAt)}]`;
    }).join('\n') || '  (none)';

  // ── expenses (last 3 months) ──────────────────────────────────────────────
  const expenseLines = expenses.map(
    (e) => `  • ${money(e.amount)} — ${e.title || e.description || 'no desc'} [${e.category || 'Uncategorized'}] on ${fmt(e.expense_date)} by ${e.member_mail || '?'}`
  ).join('\n') || '  (none)';

  // ── monthly expense totals ────────────────────────────────────────────────
  const monthlyTotals = {};
  expenses.forEach((e) => {
    const key = new Date(e.expense_date).toLocaleString('en-GB', { month: 'long', year: 'numeric' });
    monthlyTotals[key] = (monthlyTotals[key] || 0) + (e.amount || 0);
  });
  const monthlyLines = Object.entries(monthlyTotals)
    .map(([k, v]) => `  • ${k}: ${money(v)}`).join('\n') || '  (none)';

  // ── period budgets ────────────────────────────────────────────────────────
  const budgetLines = periodBudgets.map(
    (b) => `  • "${b.title}" | ${b.period_type} | ${money(b.total_amount)} | ${fmt(b.start_date)} → ${fmt(b.end_date)}`
  ).join('\n') || '  (none)';

  // ── future events ─────────────────────────────────────────────────────────
  const eventLines = futureEvents.map(
    (e) => `  • "${e.title}" | target: ${money(e.estimated_cost)} | contributed: ${money(e.total_contributed_money)} | date: ${fmt(e.event_date)}`
  ).join('\n') || '  (none)';

  // ── inventory items (in stock) ────────────────────────────────────────────
  const inventoryLines = inventoryItems.map(
    (i) => `  • ${i.item_name}: ${i.quantity} ${i.unit_id?.name || 'units'}${i.expiry_date ? ' (expires ' + fmt(i.expiry_date) + ')' : ''}`
  ).join('\n') || '  (empty)';

  // ── family recipes ─────────────────────────────────────────────────────────
  const recipeLines = recipes.map((r) => {
    const ingredients = recipeIngredients
      .filter((ri) => ri.recipe_id?.toString() === r._id.toString())
      .map((ri) => `${ri.ingredient_name} ${ri.quantity} ${ri.unit_id?.name || ''}`)
      .join(', ');
    return `  • "${r.recipe_name}" [${r.category}] — serves ${r.serving_size}, prep ${r.prep_time}min, cook ${r.cook_time}min${ingredients ? ' | ingredients: ' + ingredients : ''}`;
  }).join('\n') || '  (none saved)';

  // ── recent meals (last 7 days) ─────────────────────────────────────────────
  const recentMealLines = recentMeals.map(
    (m) => `  • ${m.meal_type} on ${fmt(m.meal_date)}: ${m.meal_name}${m.recipe_id ? ' (recipe: ' + m.recipe_id.recipe_name + ')' : ''}`
  ).join('\n') || '  (no meals logged this week)';

  // ── available leftovers ───────────────────────────────────────────────────
  const leftoverLines = leftovers.map(
    (l) => `  • ${l.item_name}: ${l.quantity} ${l.unit_id?.name || 'units'} — expires ${fmt(l.expiry_date)}`
  ).join('\n') || '  (none)';

  const now = new Date();
  const todayStr = now.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Africa/Cairo' });

  return `You are a smart, friendly Family Planning AI Assistant for the "${familyTitle}" family.
You have access to real, live data from the family's app. Use it to answer questions accurately.

IMPORTANT — TODAY'S DATE IS: ${todayStr}
Always use this date as "today" when answering. Never guess or use a different date.

═══════════════════════════════════════════════
FAMILY MEMBERS
═══════════════════════════════════════════════
${memberLines}

═══════════════════════════════════════════════
POINT WALLETS (current balance)
═══════════════════════════════════════════════
${walletLines}

═══════════════════════════════════════════════
POINTS ACTIVITY — last 2 weeks
═══════════════════════════════════════════════
${activityLines}

═══════════════════════════════════════════════
TASKS DEFINED IN THE APP
═══════════════════════════════════════════════
${taskLines}

═══════════════════════════════════════════════
TASK COMPLETIONS — last 2 weeks
═══════════════════════════════════════════════
${completionLines}

═══════════════════════════════════════════════
EXPENSES — last 3 months (detail)
═══════════════════════════════════════════════
${expenseLines}

═══════════════════════════════════════════════
MONTHLY EXPENSE TOTALS
═══════════════════════════════════════════════
${monthlyLines}

═══════════════════════════════════════════════
PERIOD BUDGETS
═══════════════════════════════════════════════
${budgetLines}

═══════════════════════════════════════════════
FUTURE EVENTS / SAVINGS GOALS
═══════════════════════════════════════════════
${eventLines}

═══════════════════════════════════════════════
AVAILABLE INVENTORY (items in stock)
═══════════════════════════════════════════════
${inventoryLines}

═══════════════════════════════════════════════
FAMILY RECIPES
═══════════════════════════════════════════════
${recipeLines}

═══════════════════════════════════════════════
MEALS THIS WEEK
═══════════════════════════════════════════════
${recentMealLines}

═══════════════════════════════════════════════
AVAILABLE LEFTOVERS
═══════════════════════════════════════════════
${leftoverLines}

═══════════════════════════════════════════════
INSTRUCTIONS
═══════════════════════════════════════════════
- Answer every question using the real data above.
- Calculate averages, totals, and comparisons when needed (show your math briefly).
- For "best child" questions, rank members by points earned in the relevant period.
- For budget questions, compare actual spending vs. budget amounts.
- For meal suggestions: prioritize using available leftovers first (to reduce waste), then suggest recipes whose ingredients match what is in the inventory. Avoid repeating meals already eaten this week. Suggest breakfast, lunch, and dinner if asked about a full day.
- Suggest practical, actionable advice when asked.
- If the data does not contain enough information to answer, say so honestly.
- Respond in the same language the user writes in (Arabic or English).
- Keep answers concise but include key numbers.`;
};

// ─── controllers ─────────────────────────────────────────────────────────────

exports.sendMessage = catchAsync(async (req, res, next) => {
  const { message } = req.body;

  if (!message || !message.trim()) {
    return next(new AppError('Please provide a message', 400));
  }

  const familyId = req.familyAccount._id;
  const memberId = req.memberId;
  const familyTitle = req.familyAccount.Title;

  // Get or create conversation document for this member
  let conversation = await PlanningConversation.findOne({ family_id: familyId, member_id: memberId });
  if (!conversation) {
    conversation = await PlanningConversation.create({ family_id: familyId, member_id: memberId, messages: [] });
  }

  // Gather live family data and build the system prompt
  const ctx = await gatherFamilyContext(familyId);
  const systemPrompt = buildSystemPrompt(ctx, familyTitle);

  // Convert last 10 stored messages to Gemini history format
  const recentMsgs = conversation.messages.slice(-10);
  const chatHistory = recentMsgs.map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  // Call Gemini
  const geminiModel = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash-lite',
    systemInstruction: systemPrompt,
  });

  const chat = geminiModel.startChat({ history: chatHistory });
  const result = await chat.sendMessage(message.trim());
  const aiResponse = result.response.text();

  // Persist both messages
  conversation.messages.push(
    { role: 'user', content: message.trim(), timestamp: new Date() },
    { role: 'assistant', content: aiResponse, timestamp: new Date() }
  );
  await conversation.save();

  res.status(200).json({
    message: 'success',
    data: { response: aiResponse },
  });
});

exports.getChatHistory = catchAsync(async (req, res, next) => {
  const conversation = await PlanningConversation.findOne({
    family_id: req.familyAccount._id,
    member_id: req.memberId,
  });

  res.status(200).json({
    message: 'success',
    data: { messages: conversation ? conversation.messages : [] },
  });
});

exports.clearHistory = catchAsync(async (req, res, next) => {
  await PlanningConversation.findOneAndUpdate(
    { family_id: req.familyAccount._id, member_id: req.memberId },
    { messages: [] }
  );

  res.status(200).json({
    message: 'success',
    data: { message: 'Chat history cleared' },
  });
});
