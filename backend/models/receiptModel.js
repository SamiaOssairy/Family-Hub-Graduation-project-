const mongoose = require('mongoose');

const receiptSchema = new mongoose.Schema({
  family_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FamilyAccount',
    required: [true, 'Please provide a family account ID']
  },
  member_mail: {
    type: String,
    required: [true, 'Please provide the member email'],
    ref: 'Member'
  },
  total_amount: {
    type: Number,
    required: [true, 'Please provide the total amount'],
    min: [0, 'Total amount cannot be negative']
  },
  purchase_date: {
    type: Date,
    required: [true, 'Please provide the purchase date']
  },
  store_name: {
    type: String,
    trim: true,
    default: ''
  },
  receipt_photo_url: {
    type: String,
    default: null
  },
  notes: {
    type: String,
    default: ''
  },
  items: [{
    name: { type: String, required: true },
    quantity: { type: String, default: '1' },
    unit: { type: String, default: '' },
    price: { type: Number, required: true, min: 0 }
  }],
  subtotal: {
    type: Number,
    default: 0,
    min: 0
  },
  taxes: {
    type: Number,
    default: 0,
    min: 0
  }
}, {
  timestamps: true
});

// Indexes
receiptSchema.index({ family_id: 1, purchase_date: -1 });
receiptSchema.index({ member_mail: 1 });

const Receipt = mongoose.model('Receipt', receiptSchema);

module.exports = Receipt;
