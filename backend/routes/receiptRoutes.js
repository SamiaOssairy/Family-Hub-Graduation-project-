const express = require('express');
const multer = require('multer');
const { protect, restrictTo } = require('../controllers/AuthController');
const {
  createReceipt,
  getAllReceipts,
  getReceipt,
  updateReceipt,
  deleteReceipt,
  getSpendingSummary,
  scanReceipt
} = require('../controllers/ReceiptController');

const receiptRouter = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

// All routes require authentication
receiptRouter.use(protect);

receiptRouter.get('/', getAllReceipts);
receiptRouter.get('/summary', getSpendingSummary);

// Scan route MUST be before /:receiptId to avoid "scan" matching as an ID
receiptRouter.post('/scan', upload.single('receipt_image'), scanReceipt);

receiptRouter.get('/:receiptId', getReceipt);
receiptRouter.post('/', createReceipt);
receiptRouter.patch('/:receiptId', updateReceipt);
receiptRouter.delete('/:receiptId', deleteReceipt);

module.exports = receiptRouter;
