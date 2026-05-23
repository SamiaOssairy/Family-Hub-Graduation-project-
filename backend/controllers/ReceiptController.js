const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Receipt = require("../models/receiptModel");
const InventoryItem = require("../models/inventoryItemModel");
const { GoogleGenerativeAI } = require("@google/generative-ai");

//========================================================================================
// Create a receipt
exports.createReceipt = catchAsync(async (req, res, next) => {
  const { total_amount, purchase_date, store_name, receipt_photo_url, notes, items, subtotal, taxes } = req.body;

  if (total_amount === undefined || total_amount === null || !purchase_date) {
    return next(new AppError("Please provide total_amount and purchase_date", 400));
  }

  const receipt = await Receipt.create({
    family_id: req.familyAccount._id,
    member_mail: req.member.mail,
    total_amount,
    purchase_date,
    store_name: store_name || '',
    receipt_photo_url: receipt_photo_url || null,
    notes: notes || '',
    items: items || [],
    subtotal: subtotal || 0,
    taxes: taxes || 0
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
  const { total_amount, purchase_date, store_name, receipt_photo_url, notes, items, subtotal, taxes } = req.body;

  const updateData = { total_amount, purchase_date, store_name, receipt_photo_url, notes };
  if (items !== undefined) updateData.items = items;
  if (subtotal !== undefined) updateData.subtotal = subtotal;
  if (taxes !== undefined) updateData.taxes = taxes;

  const receipt = await Receipt.findOneAndUpdate(
    { _id: receiptId, family_id: req.familyAccount._id },
    updateData,
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
// Scan a receipt image with Gemini Vision and extract items
exports.scanReceipt = catchAsync(async (req, res, next) => {
  if (!req.file) {
    return next(new AppError('Please upload a receipt image', 400));
  }

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' });

  const imageBase64 = req.file.buffer.toString('base64');

  // Detect real MIME type from magic bytes.
  // Windows Flutter sends "application/octet-stream" which Gemini rejects.
  let mimeType = req.file.mimetype || 'image/jpeg';
  if (!mimeType.startsWith('image/')) {
    const buf = req.file.buffer;
    if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) {
      mimeType = 'image/png';
    } else if (buf[0] === 0xFF && buf[1] === 0xD8) {
      mimeType = 'image/jpeg';
    } else if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) {
      mimeType = 'image/gif';
    } else {
      mimeType = 'image/jpeg'; // safe fallback for all other binary data
    }
  }

  const prompt = `You are a receipt scanner AI. Carefully analyze this receipt image and extract all information from it.
Return ONLY a valid JSON object with this exact structure — no markdown, no explanation, nothing else:
{
  "store_name": "store or supermarket name as printed on receipt",
  "purchase_date": "YYYY-MM-DD or null if not visible",
  "subtotal": 0,
  "taxes": 0,
  "total_amount": 0,
  "items": [
    {
      "name": "product name",
      "quantity": "1",
      "unit": "",
      "price": 0
    }
  ]
}
Rules:
- Extract every line item visible on the receipt
- All monetary values must be plain numbers (no currency symbols, no commas)
- quantity must be a string: "1", "2", "500", "0.5"
- unit can be empty string "" or a short unit like "kg", "L", "g", "pcs" if shown on receipt
- If the store name is not visible, use "Unknown Store"
- Return ONLY the JSON object — nothing before or after it`;

  const result = await model.generateContent([
    {
      inlineData: {
        data: imageBase64,
        mimeType
      }
    },
    prompt
  ]);

  const text = result.response.text().trim();

  let scanned;
  try {
    // Strip markdown code fences if Gemini wraps the JSON
    const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    scanned = JSON.parse(cleaned);
  } catch (e) {
    return next(new AppError('Could not read the receipt. Please try with a clearer image.', 422));
  }

  // Normalise fields
  scanned.store_name = scanned.store_name || 'Unknown Store';
  scanned.items = Array.isArray(scanned.items) ? scanned.items : [];
  scanned.total_amount = Number(scanned.total_amount) || 0;
  scanned.subtotal = Number(scanned.subtotal) || 0;
  scanned.taxes = Number(scanned.taxes) || 0;

  res.status(200).json({
    status: 'success',
    data: { scanned }
  });
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
