const mongoose = require('mongoose');

const mealItemSchema = new mongoose.Schema({
  meal_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Meal',
    required: [true, 'Please provide the meal ID']
  },
  // Optional: set when the item comes from tracked inventory (quantity is deducted).
  inventory_item_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'InventoryItem',
    default: null
  },
  // Optional: free-text name for items that are NOT in inventory.
  custom_name: {
    type: String,
    trim: true,
    default: null
  },
  unit_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Unit',
    default: null
  },
  // Optional: free-text unit for custom items (e.g. "cups", "pieces").
  custom_unit: {
    type: String,
    trim: true,
    default: null
  },
  quantity_used: {
    type: Number,
    required: [true, 'Please provide the quantity used'],
    min: [0, 'Quantity used cannot be negative']
  }
});

// An item must reference either a tracked inventory item or a free-text name.
mealItemSchema.pre('validate', function (next) {
  if (!this.inventory_item_id && !this.custom_name) {
    return next(new Error('A meal item needs either an inventory item or a custom name'));
  }
  next();
});

// Index
mealItemSchema.index({ meal_id: 1 });
mealItemSchema.index({ inventory_item_id: 1 });

const MealItem = mongoose.model('MealItem', mealItemSchema);

module.exports = MealItem;
