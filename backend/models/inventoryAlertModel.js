const mongoose = require('mongoose');

const inventoryAlertSchema = new mongoose.Schema({
  inventory_item_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'InventoryItem',
    required: [true, 'Please provide the inventory item ID']
  },
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  },
  alert_type: {
    type: String,
    required: [true, 'Please provide the alert type'],
    enum: ['low_stock', 'expiring_soon', 'expired']
  },
  alert_message: {
    type: String,
    required: [true, 'Please provide the alert message']
  },
  is_read: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

// Indexes
inventoryAlertSchema.index({ family_id: 1, createdAt: -1 });
inventoryAlertSchema.index({ inventory_item_id: 1, alert_type: 1 });
inventoryAlertSchema.index({ is_read: 1 });

const InventoryAlert = mongoose.model('InventoryAlert', inventoryAlertSchema);

module.exports = InventoryAlert;
