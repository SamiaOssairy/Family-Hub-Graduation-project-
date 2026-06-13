const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Meal = require("../models/mealModel");
const MealItem = require("../models/mealItemModel");
const InventoryItem = require("../models/inventoryItemModel");
const Inventory = require("../models/inventoryModel");
const Recipe = require("../models/recipeModel");
const RecipeIngredient = require("../models/recipeIngredientModel");

//========================================================================================
// Create a meal plan
exports.createMeal = catchAsync(async (req, res, next) => {
  const { meal_name, meal_date, meal_type, recipe_id, servings } = req.body;

  if (!meal_name || !meal_date || !meal_type) {
    return next(new AppError("Please provide meal_name, meal_date, and meal_type", 400));
  }

  // Validate meal_date not more than 6 months in the past
  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
  if (new Date(meal_date) < sixMonthsAgo) {
    return next(new AppError("Meal date cannot be more than 6 months in the past", 400));
  }

  // If recipe_id provided, verify it belongs to the family
  if (recipe_id) {
    const recipe = await Recipe.findOne({
      _id: recipe_id,
      family_id: req.familyAccount._id
    });
    if (!recipe) {
      return next(new AppError("Recipe not found in your family", 404));
    }
  }

  const meal = await Meal.create({
    family_id: req.familyAccount._id,
    meal_name,
    meal_date,
    meal_type,
    recipe_id: recipe_id || null,
    servings: servings && servings > 0 ? servings : 1,
    created_by: req.member.mail
  });

  await meal.populate('recipe_id');

  res.status(201).json({
    status: "success",
    data: { meal }
  });
});

//========================================================================================
// Get meals for a specific date (or date range)
exports.getMeals = catchAsync(async (req, res, next) => {
  const { date, start_date, end_date } = req.query;

  const filter = { family_id: req.familyAccount._id };

  if (date) {
    // Single date - get all meals for that day
    const dayStart = new Date(date);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(date);
    dayEnd.setHours(23, 59, 59, 999);
    filter.meal_date = { $gte: dayStart, $lte: dayEnd };
  } else if (start_date && end_date) {
    // Date range
    filter.meal_date = { $gte: new Date(start_date), $lte: new Date(end_date) };
  }

  const meals = await Meal.find(filter)
    .populate('recipe_id')
    .sort({ meal_date: 1, meal_type: 1 });

  res.status(200).json({
    status: "success",
    results: meals.length,
    data: { meals }
  });
});

//========================================================================================
// Get a single meal with its items
exports.getMeal = catchAsync(async (req, res, next) => {
  const { mealId } = req.params;

  const meal = await Meal.findOne({
    _id: mealId,
    family_id: req.familyAccount._id
  }).populate('recipe_id');

  if (!meal) {
    return next(new AppError("Meal not found", 404));
  }

  const mealItems = await MealItem.find({ meal_id: mealId })
    .populate('inventory_item_id')
    .populate('unit_id');

  res.status(200).json({
    status: "success",
    data: { meal, mealItems }
  });
});

//========================================================================================
// Update a meal
exports.updateMeal = catchAsync(async (req, res, next) => {
  const { mealId } = req.params;
  const { meal_name, meal_date, meal_type, recipe_id, servings } = req.body;

  const meal = await Meal.findOne({
    _id: mealId,
    family_id: req.familyAccount._id
  });

  if (!meal) {
    return next(new AppError("Meal not found", 404));
  }

  if (meal_name) meal.meal_name = meal_name;
  if (meal_date) meal.meal_date = meal_date;
  if (meal_type) meal.meal_type = meal_type;
  if (recipe_id !== undefined) meal.recipe_id = recipe_id;
  if (servings !== undefined && servings > 0) meal.servings = servings;

  await meal.save();
  await meal.populate('recipe_id');

  res.status(200).json({
    status: "success",
    data: { meal }
  });
});

//========================================================================================
// Delete a meal (cascade to meal items)
exports.deleteMeal = catchAsync(async (req, res, next) => {
  const { mealId } = req.params;

  const meal = await Meal.findOne({
    _id: mealId,
    family_id: req.familyAccount._id
  });

  if (!meal) {
    return next(new AppError("Meal not found", 404));
  }

  await MealItem.deleteMany({ meal_id: mealId });
  await Meal.findByIdAndDelete(mealId);

  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// Add items to a meal (deducts from inventory)
exports.addMealItem = catchAsync(async (req, res, next) => {
  const { mealId } = req.params;
  const { inventory_item_id, unit_id, quantity_used, custom_name, custom_unit } = req.body;

  if (!quantity_used) {
    return next(new AppError("Please provide quantity_used", 400));
  }
  if (!inventory_item_id && !(custom_name && custom_name.trim())) {
    return next(new AppError("Please provide either an inventory item or a custom item name", 400));
  }

  // Verify meal belongs to family
  const meal = await Meal.findOne({
    _id: mealId,
    family_id: req.familyAccount._id
  });

  if (!meal) {
    return next(new AppError("Meal not found", 404));
  }

  const alerts = [];
  let mealItem;

  if (inventory_item_id) {
    // ── Tracked inventory item: verify ownership and deduct quantity ──
    if (!unit_id) {
      return next(new AppError("Please provide the unit for an inventory item", 400));
    }

    const inventoryItem = await InventoryItem.findById(inventory_item_id)
      .populate('inventory_id');

    if (!inventoryItem) {
      return next(new AppError("Inventory item not found", 404));
    }

    const inventory = await Inventory.findOne({
      _id: inventoryItem.inventory_id._id,
      family_id: req.familyAccount._id
    });

    if (!inventory) {
      return next(new AppError("Inventory item doesn't belong to your family", 404));
    }

    // Check if enough quantity available
    if (inventoryItem.quantity < quantity_used) {
      return next(new AppError(
        `Not enough ${inventoryItem.item_name}. Available: ${inventoryItem.quantity}, Needed: ${quantity_used}`,
        400
      ));
    }

    mealItem = await MealItem.create({
      meal_id: mealId,
      inventory_item_id,
      unit_id,
      quantity_used
    });

    // Deduct from inventory
    inventoryItem.quantity -= quantity_used;
    await inventoryItem.save();

    await mealItem.populate(['inventory_item_id', 'unit_id']);

    if (inventoryItem.quantity <= inventoryItem.threshold_quantity) {
      alerts.push({
        type: 'low_stock',
        message: `Low stock: ${inventoryItem.item_name} (${inventoryItem.quantity} remaining)`
      });
    }
  } else {
    // ── Custom free-text item: not in inventory, nothing to deduct ──
    mealItem = await MealItem.create({
      meal_id: mealId,
      custom_name: custom_name.trim(),
      custom_unit: custom_unit && custom_unit.trim() ? custom_unit.trim() : null,
      unit_id: unit_id || null,
      quantity_used
    });

    if (unit_id) await mealItem.populate('unit_id');
  }

  res.status(201).json({
    status: "success",
    data: { mealItem },
    alerts
  });
});

//========================================================================================
// Remove meal item (restores inventory quantity)
exports.removeMealItem = catchAsync(async (req, res, next) => {
  const { mealId, mealItemId } = req.params;

  const mealItem = await MealItem.findOne({
    _id: mealItemId,
    meal_id: mealId
  });

  if (!mealItem) {
    return next(new AppError("Meal item not found", 404));
  }

  // Restore quantity to inventory
  const inventoryItem = await InventoryItem.findById(mealItem.inventory_item_id);
  if (inventoryItem) {
    inventoryItem.quantity += mealItem.quantity_used;
    await inventoryItem.save();
  }

  await MealItem.findByIdAndDelete(mealItemId);

  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// Prepare meal from recipe (auto-deduct ingredients from inventory)
exports.prepareMealFromRecipe = catchAsync(async (req, res, next) => {
  const { mealId } = req.params;

  const meal = await Meal.findOne({
    _id: mealId,
    family_id: req.familyAccount._id
  }).populate('recipe_id');

  if (!meal) {
    return next(new AppError("Meal not found", 404));
  }

  if (!meal.recipe_id) {
    return next(new AppError("This meal has no recipe linked", 400));
  }

  // Get recipe ingredients
  const ingredients = await RecipeIngredient.find({ recipe_id: meal.recipe_id._id })
    .populate('unit_id');

  // Get all family inventory items
  const inventories = await Inventory.find({ family_id: req.familyAccount._id });
  const inventoryIds = inventories.map(inv => inv._id);
  const inventoryItems = await InventoryItem.find({ inventory_id: { $in: inventoryIds } });

  const used = [];
  const missing = [];
  const alerts = [];

  for (const ingredient of ingredients) {
    // Try to find matching inventory item by name (case-insensitive)
    const match = inventoryItems.find(item =>
      item.item_name.toLowerCase() === ingredient.ingredient_name.toLowerCase() &&
      item.unit_id.toString() === ingredient.unit_id._id.toString()
    );

    if (!match || match.quantity < ingredient.quantity) {
      missing.push({
        ingredient_name: ingredient.ingredient_name,
        needed: ingredient.quantity,
        available: match ? match.quantity : 0,
        unit: ingredient.unit_id.unit_name
      });
    } else {
      used.push({
        inventory_item_id: match._id,
        unit_id: ingredient.unit_id._id,
        quantity_used: ingredient.quantity,
        item_name: match.item_name
      });
    }
  }

  if (missing.length > 0) {
    return res.status(200).json({
      status: "partial",
      message: "Some ingredients are missing from inventory",
      data: {
        missing,
        available: used
      }
    });
  }

  // Deduct all ingredients from inventory and create meal items
  for (const item of used) {
    await MealItem.create({
      meal_id: mealId,
      inventory_item_id: item.inventory_item_id,
      unit_id: item.unit_id,
      quantity_used: item.quantity_used
    });

    const invItem = await InventoryItem.findById(item.inventory_item_id);
    invItem.quantity -= item.quantity_used;
    await invItem.save();

    if (invItem.quantity <= invItem.threshold_quantity) {
      alerts.push({
        type: 'low_stock',
        message: `Low stock: ${invItem.item_name} (${invItem.quantity} remaining)`
      });
    }
  }

  res.status(200).json({
    status: "success",
    message: "All ingredients deducted from inventory",
    data: { used },
    alerts
  });
});
