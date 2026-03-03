const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Receipt = require("../models/receiptModel");
const InventoryItem = require("../models/inventoryItemModel");

//========================================================================================
// Create a receipt
exports.createReceipt = catchAsync(async (req, res, next) => {
  const { total_amount, purchase_date, store_name, receipt_photo_url, notes } = req.body;

  if (!total_amount || !purchase_date) {
    return next(new AppError("Please provide total_amount and purchase_date", 400));
  }

  const receipt = await Receipt.create({
    family_id: req.familyAccount._id,
    member_mail: req.member.mail,
    total_amount,
    purchase_date,
    store_name: store_name || '',
    receipt_photo_url: receipt_photo_url || null,
    notes: notes || ''
  });

  res.status(201).json({
    status: "success",
    data: { receipt }
  });
});

//========================================================================================
// Get all receipts for the family
exports.getAllReceipts = catchAsync(async (req, res, next) => {
  const { start_date, end_date, member_mail } = req.query;

  const filter = { family_id: req.familyAccount._id };

  if (start_date && end_date) {
    filter.purchase_date = {
      $gte: new Date(start_date),
      $lte: new Date(end_date)
    };
  } else if (start_date) {
    filter.purchase_date = { $gte: new Date(start_date) };
  } else if (end_date) {
    filter.purchase_date = { $lte: new Date(end_date) };
  }

  if (member_mail) {
    filter.member_mail = member_mail;
  }

  const receipts = await Receipt.find(filter)
    .sort({ purchase_date: -1 });

  res.status(200).json({
    status: "success",
    results: receipts.length,
    data: { receipts }
  });
});

//========================================================================================
// Get a single receipt with linked inventory items
exports.getReceipt = catchAsync(async (req, res, next) => {
  const { receiptId } = req.params;

  const receipt = await Receipt.findOne({
    _id: receiptId,
    family_id: req.familyAccount._id
  });

  if (!receipt) {
    return next(new AppError("Receipt not found", 404));
  }

  // Get inventory items linked to this receipt
  const linkedItems = await InventoryItem.find({ receipt_id: receiptId })
    .populate('unit_id')
    .populate('item_category')
    .populate('inventory_id');

  res.status(200).json({
    status: "success",
    data: {
      receipt,
      linkedItems
    }
  });
});

//========================================================================================
// Update a receipt
exports.updateReceipt = catchAsync(async (req, res, next) => {
  const { receiptId } = req.params;
  const { total_amount, purchase_date, store_name, receipt_photo_url, notes } = req.body;

  const receipt = await Receipt.findOneAndUpdate(
    { _id: receiptId, family_id: req.familyAccount._id },
    { total_amount, purchase_date, store_name, receipt_photo_url, notes },
    { new: true, runValidators: true }
  );

  if (!receipt) {
    return next(new AppError("Receipt not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { receipt }
  });
});

//========================================================================================
// Delete a receipt (unlinks inventory items)
exports.deleteReceipt = catchAsync(async (req, res, next) => {
  const { receiptId } = req.params;

  const receipt = await Receipt.findOneAndDelete({
    _id: receiptId,
    family_id: req.familyAccount._id
  });

  if (!receipt) {
    return next(new AppError("Receipt not found", 404));
  }

  // Unlink inventory items that reference this receipt
  await InventoryItem.updateMany(
    { receipt_id: receiptId },
    { receipt_id: null }
  );

  res.status(204).json({ status: "success", data: null });
});

//========================================================================================
// Get spending summary
exports.getSpendingSummary = catchAsync(async (req, res, next) => {
  const { start_date, end_date } = req.query;

  const matchStage = { family_id: req.familyAccount._id };
  if (start_date && end_date) {
    matchStage.purchase_date = {
      $gte: new Date(start_date),
      $lte: new Date(end_date)
    };
  }

  const summary = await Receipt.aggregate([
    { $match: matchStage },
    {
      $group: {
        _id: null,
        totalSpent: { $sum: '$total_amount' },
        receiptCount: { $sum: 1 },
        avgPerReceipt: { $avg: '$total_amount' },
        firstPurchase: { $min: '$purchase_date' },
        lastPurchase: { $max: '$purchase_date' }
      }
    }
  ]);

  const byStore = await Receipt.aggregate([
    { $match: matchStage },
    {
      $group: {
        _id: '$store_name',
        totalSpent: { $sum: '$total_amount' },
        visitCount: { $sum: 1 }
      }
    },
    { $sort: { totalSpent: -1 } }
  ]);

  const byMember = await Receipt.aggregate([
    { $match: matchStage },
    {
      $group: {
        _id: '$member_mail',
        totalSpent: { $sum: '$total_amount' },
        receiptCount: { $sum: 1 }
      }
    },
    { $sort: { totalSpent: -1 } }
  ]);

  res.status(200).json({
    status: "success",
    data: {
      overall: summary[0] || { totalSpent: 0, receiptCount: 0, avgPerReceipt: 0 },
      byStore,
      byMember
    }
  });
});
