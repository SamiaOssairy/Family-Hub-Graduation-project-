const express = require('express');
const { protect, restrictTo } = require('../controllers/AuthController');
const {
  createReceipt,
  getAllReceipts,
  getReceipt,
  updateReceipt,
  deleteReceipt,
  getSpendingSummary
} = require('../controllers/ReceiptController');

const receiptRouter = express.Router();

// All routes require authentication
receiptRouter.use(protect);

receiptRouter.get('/', getAllReceipts);
receiptRouter.get('/summary', getSpendingSummary);
receiptRouter.get('/:receiptId', getReceipt);
receiptRouter.post('/', createReceipt);
receiptRouter.patch('/:receiptId', updateReceipt);
receiptRouter.delete('/:receiptId', deleteReceipt);

module.exports = receiptRouter;
