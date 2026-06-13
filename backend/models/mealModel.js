const mongoose = require('mongoose');

const mealSchema = new mongoose.Schema({
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  },
  meal_name: {
    type: String,
    required: [true, 'Please provide the meal name'],
    trim: true
  },
  meal_date: {
    type: Date,
    required: [true, 'Please provide the meal date']
  },
  meal_type: {
    type: String,
    required: [true, 'Please provide the meal type'],
    enum: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
  },
  recipe_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Recipe',
    default: null
  },
  servings: {
    type: Number,
    default: 1,
    min: [1, 'Servings must be at least 1']
  },
  created_by: {
    type: String,
    required: [true, 'Please provide who created the meal'],
    ref: 'Member'
  }
}, {
  timestamps: true
});

// Indexes
mealSchema.index({ family_id: 1, meal_date: 1 });
mealSchema.index({ meal_date: 1, meal_type: 1 });

const Meal = mongoose.model('Meal', mealSchema);

module.exports = Meal;
