const mongoose = require('mongoose');

const inventoryItemSchema = new mongoose.Schema({
  inventory_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Inventory',
    required: [true, 'Please provide the inventory ID']
  },
  item_category: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ItemCategory',
    required: [true, 'Please provide the item category']
  },
  item_name: {
    type: String,
    required: [true, 'Please provide the item name'],
    trim: true
  },
  quantity: {
    type: Number,
    required: [true, 'Please provide the quantity'],
    min: [0, 'Quantity cannot be negative']
  },
  unit_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Unit',
    required: [true, 'Please provide the unit']
  },
  threshold_quantity: {
    type: Number,
    default: 1,
    min: [0, 'Threshold cannot be negative']
  },
  purchase_date: {
    type: Date,
    default: Date.now
  },
  expiry_date: {
    type: Date,
    default: null
  },
  receipt_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Receipt',
    default: null
  },
  last_notified_at: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Indexes
inventoryItemSchema.index({ inventory_id: 1 });
inventoryItemSchema.index({ expiry_date: 1 });
inventoryItemSchema.index({ item_category: 1 });

const InventoryItem = mongoose.model('InventoryItem', inventoryItemSchema);

module.exports = InventoryItem;
