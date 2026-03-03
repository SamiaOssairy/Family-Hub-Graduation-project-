const mongoose = require('mongoose');

const itemCategorySchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Please provide the category title'],
    trim: true
  },
  parent_category_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ItemCategory',
    default: null
  },
  description: {
    type: String,
    default: ''
  },
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  }
});

// Unique category title per family
itemCategorySchema.index({ title: 1, family_id: 1 }, { unique: true });

const ItemCategory = mongoose.model('ItemCategory', itemCategorySchema);

module.exports = ItemCategory;
