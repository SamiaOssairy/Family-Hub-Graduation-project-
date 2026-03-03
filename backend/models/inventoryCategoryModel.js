const mongoose = require('mongoose');

const inventoryCategorySchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Please provide the category title'],
    trim: true
  },
  parent_category_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'InventoryCategory',
    default: null
  },
  description: {
    type: String,
    default: ''
  }
});

// Index for parent lookup
inventoryCategorySchema.index({ parent_category_id: 1 });

const InventoryCategory = mongoose.model('InventoryCategory', inventoryCategorySchema);

module.exports = InventoryCategory;
