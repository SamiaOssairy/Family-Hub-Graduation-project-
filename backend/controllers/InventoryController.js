const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Inventory = require("../models/inventoryModel");
const InventoryItem = require("../models/inventoryItemModel");
const ItemCategory = require("../models/itemCategoryModel");

//========================================================================================
// INVENTORY MANAGEMENT
//========================================================================================

// Create a new inventory (e.g., "Kitchen Pantry", "Fridge")
exports.createInventory = catchAsync(async (req, res, next) => {
  const { title, type } = req.body;

  if (!title) {
    return next(new AppError("Please provide the inventory title", 400));
  }

  const inventory = await Inventory.create({
    family_id: req.familyAccount._id,
    title,
    type: type || 'Food'
  });

  res.status(201).json({
    status: "success",
    data: { inventory }
  });
});

//========================================================================================
// Get all inventories for the family
exports.getAllInventories = catchAsync(async (req, res, next) => {
  const inventories = await Inventory.find({ family_id: req.familyAccount._id });

  res.status(200).json({
    status: "success",
    results: inventories.length,
    data: { inventories }
  });
});

//========================================================================================
// Delete an inventory (RESTRICT if items exist)
exports.deleteInventory = catchAsync(async (req, res, next) => {
  const { inventoryId } = req.params;

  const inventory = await Inventory.findOne({
    _id: inventoryId,
    family_id: req.familyAccount._id
  });

  if (!inventory) {
    return next(new AppError("Inventory not found", 404));
  }

  // Check if items exist
  const itemCount = await InventoryItem.countDocuments({ inventory_id: inventoryId });
  if (itemCount > 0) {
    return next(new AppError(`Cannot delete inventory with ${itemCount} items. Remove all items first.`, 400));
  }

  await Inventory.findByIdAndDelete(inventoryId);

  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// ITEM CATEGORY MANAGEMENT
//========================================================================================

// Create item category
exports.createItemCategory = catchAsync(async (req, res, next) => {
  const { title, description, parent_category_id } = req.body;

  if (!title) {
    return next(new AppError("Please provide the category title", 400));
  }

  // Validate parent category exists if provided
  if (parent_category_id) {
    const parent = await ItemCategory.findOne({
      _id: parent_category_id,
      family_id: req.familyAccount._id
    });
    if (!parent) {
      return next(new AppError("Parent category not found", 404));
    }
  }

  const category = await ItemCategory.create({
    title,
    description: description || '',
    parent_category_id: parent_category_id || null,
    family_id: req.familyAccount._id
  });

  res.status(201).json({
    status: "success",
    data: { category }
  });
});

//========================================================================================
// Get all item categories for the family
exports.getAllItemCategories = catchAsync(async (req, res, next) => {
  const categories = await ItemCategory.find({ family_id: req.familyAccount._id })
    .populate('parent_category_id')
    .sort({ title: 1 });

  res.status(200).json({
    status: "success",
    results: categories.length,
    data: { categories }
  });
});

//========================================================================================
// Delete item category
exports.deleteItemCategory = catchAsync(async (req, res, next) => {
  const { categoryId } = req.params;

  const category = await ItemCategory.findOne({
    _id: categoryId,
    family_id: req.familyAccount._id
  });

  if (!category) {
    return next(new AppError("Category not found", 404));
  }

  // Check if items use this category
  const itemCount = await InventoryItem.countDocuments({ item_category: categoryId });
  if (itemCount > 0) {
    return next(new AppError(`Cannot delete category with ${itemCount} items using it`, 400));
  }

  await ItemCategory.findByIdAndDelete(categoryId);

  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// INVENTORY ITEM MANAGEMENT
//========================================================================================

// Add item to inventory
exports.addItem = catchAsync(async (req, res, next) => {
  const { inventoryId } = req.params;
  const { item_name, item_category, quantity, unit_id, threshold_quantity, purchase_date, expiry_date, receipt_id } = req.body;

  if (!item_name || !item_category || !quantity || !unit_id) {
    return next(new AppError("Please provide item_name, item_category, quantity, and unit_id", 400));
  }

  // Verify inventory belongs to family
  const inventory = await Inventory.findOne({
    _id: inventoryId,
    family_id: req.familyAccount._id
  });

  if (!inventory) {
    return next(new AppError("Inventory not found", 404));
  }

  // Verify category belongs to family
  const category = await ItemCategory.findOne({
    _id: item_category,
    family_id: req.familyAccount._id
  });

  if (!category) {
    return next(new AppError("Item category not found or doesn't belong to your family", 404));
  }

  // Validate expiry_date >= purchase_date
  if (expiry_date && purchase_date && new Date(expiry_date) < new Date(purchase_date)) {
    return next(new AppError("Expiry date must be after purchase date", 400));
  }

  const item = await InventoryItem.create({
    inventory_id: inventoryId,
    item_category,
    item_name,
    quantity,
    unit_id,
    threshold_quantity: threshold_quantity || 1,
    purchase_date: purchase_date || Date.now(),
    expiry_date: expiry_date || null,
    receipt_id: receipt_id || null
  });

  await item.populate(['unit_id', 'item_category']);

  res.status(201).json({
    status: "success",
    data: { item }
  });
});

//========================================================================================
// Get all items in an inventory
exports.getInventoryItems = catchAsync(async (req, res, next) => {
  const { inventoryId } = req.params;

  // Verify inventory belongs to family
  const inventory = await Inventory.findOne({
    _id: inventoryId,
    family_id: req.familyAccount._id
  });

  if (!inventory) {
    return next(new AppError("Inventory not found", 404));
  }

  const items = await InventoryItem.find({ inventory_id: inventoryId })
    .populate('unit_id')
    .populate('item_category')
    .sort({ item_name: 1 });

  res.status(200).json({
    status: "success",
    results: items.length,
    data: { inventory, items }
  });
});

//========================================================================================
// Get ALL items across all family inventories
exports.getAllFamilyItems = catchAsync(async (req, res, next) => {
  const inventories = await Inventory.find({ family_id: req.familyAccount._id });
  const inventoryIds = inventories.map(inv => inv._id);

  const items = await InventoryItem.find({ inventory_id: { $in: inventoryIds } })
    .populate('unit_id')
    .populate('item_category')
    .populate('inventory_id')
    .sort({ item_name: 1 });

  res.status(200).json({
    status: "success",
    results: items.length,
    data: { items }
  });
});

//========================================================================================
// Update inventory item (quantity, expiry, etc.)
exports.updateItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;
  const { item_name, quantity, unit_id, threshold_quantity, expiry_date, item_category } = req.body;

  // Find item and verify it belongs to family
  const item = await InventoryItem.findById(itemId)
    .populate('inventory_id');

  if (!item) {
    return next(new AppError("Item not found", 404));
  }

  const inventory = await Inventory.findOne({
    _id: item.inventory_id._id,
    family_id: req.familyAccount._id
  });

  if (!inventory) {
    return next(new AppError("Item not found in your family's inventory", 404));
  }

  if (item_name) item.item_name = item_name;
  if (quantity !== undefined) item.quantity = quantity;
  if (unit_id) item.unit_id = unit_id;
  if (threshold_quantity !== undefined) item.threshold_quantity = threshold_quantity;
  if (expiry_date !== undefined) item.expiry_date = expiry_date;
  if (item_category) item.item_category = item_category;

  await item.save();
  await item.populate(['unit_id', 'item_category']);

  // Check for low stock alert
  const alerts = [];
  if (item.quantity <= item.threshold_quantity) {
    alerts.push({
      type: 'low_stock',
      message: `Low stock: ${item.item_name} (${item.quantity} remaining)`
    });
  }

  res.status(200).json({
    status: "success",
    data: { item },
    alerts
  });
});

//========================================================================================
// Delete inventory item
exports.deleteItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;

  const item = await InventoryItem.findById(itemId)
    .populate('inventory_id');

  if (!item) {
    return next(new AppError("Item not found", 404));
  }

  const inventory = await Inventory.findOne({
    _id: item.inventory_id._id,
    family_id: req.familyAccount._id
  });

  if (!inventory) {
    return next(new AppError("Item not found in your family's inventory", 404));
  }

  await InventoryItem.findByIdAndDelete(itemId);

  res.status(204).json({
    status: "success",
    data: null
  });
});

//========================================================================================
// Get alerts (low stock + expiring soon)
exports.getAlerts = catchAsync(async (req, res, next) => {
  const inventories = await Inventory.find({ family_id: req.familyAccount._id });
  const inventoryIds = inventories.map(inv => inv._id);

  const now = new Date();
  const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

  // Get all items in family inventories
  const allItems = await InventoryItem.find({ inventory_id: { $in: inventoryIds } })
    .populate('unit_id')
    .populate('item_category')
    .populate('inventory_id');

  // Low stock items
  const lowStock = allItems.filter(item => item.quantity <= item.threshold_quantity);

  // Expiring soon items (within 3 days)
  const expiringSoon = allItems.filter(item =>
    item.expiry_date && item.expiry_date <= threeDaysFromNow && item.expiry_date >= now
  );

  // Already expired
  const expired = allItems.filter(item =>
    item.expiry_date && item.expiry_date < now
  );

  res.status(200).json({
    status: "success",
    data: {
      lowStock: {
        count: lowStock.length,
        items: lowStock
      },
      expiringSoon: {
        count: expiringSoon.length,
        items: expiringSoon
      },
      expired: {
        count: expired.length,
        items: expired
      }
    }
  });
});
