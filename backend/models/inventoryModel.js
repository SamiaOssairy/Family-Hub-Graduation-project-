const mongoose = require('mongoose');

const inventorySchema = new mongoose.Schema({
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  },
  title: {
    type: String,
    required: [true, 'Please provide the inventory title'],
    trim: true
  },
  type: {
    type: String,
    default: 'Food',
    enum: ['Food', 'Electronics', 'Cleaning', 'Personal Care', 'Other']
  }
}, {
  timestamps: true
});

// Index
inventorySchema.index({ family_id: 1 });

const Inventory = mongoose.model('Inventory', inventorySchema);

module.exports = Inventory;
