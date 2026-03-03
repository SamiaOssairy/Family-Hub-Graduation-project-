const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const InventoryCategory = require("../models/inventoryCategoryModel");

//========================================================================================
// Create a new inventory category
exports.createCategory = catchAsync(async (req, res, next) => {
  const { title, parent_category_id, description } = req.body;

  if (!title) {
    return next(new AppError("Please provide the category title", 400));
  }

  // Validate parent exists if provided
  if (parent_category_id) {
    const parent = await InventoryCategory.findById(parent_category_id);
    if (!parent) {
      return next(new AppError("Parent category not found", 404));
    }
  }

  const category = await InventoryCategory.create({
    title,
    parent_category_id: parent_category_id || null,
    description: description || ''
  });

  res.status(201).json({
    status: "success",
    data: { category }
  });
});

//========================================================================================
// Get all inventory categories (with optional tree structure)
exports.getAllCategories = catchAsync(async (req, res, next) => {
  const { tree } = req.query;

  const categories = await InventoryCategory.find()
    .populate('parent_category_id')
    .sort({ title: 1 });

  if (tree === 'true') {
    // Build tree structure
    const categoryMap = {};
    const roots = [];

    categories.forEach(cat => {
      categoryMap[cat._id.toString()] = { ...cat.toObject(), children: [] };
    });

    categories.forEach(cat => {
      const catObj = categoryMap[cat._id.toString()];
      if (cat.parent_category_id) {
        const parentId = cat.parent_category_id._id
          ? cat.parent_category_id._id.toString()
          : cat.parent_category_id.toString();
        if (categoryMap[parentId]) {
          categoryMap[parentId].children.push(catObj);
        } else {
          roots.push(catObj);
        }
      } else {
        roots.push(catObj);
      }
    });

    return res.status(200).json({
      status: "success",
      results: categories.length,
      data: { categories: roots }
    });
  }

  res.status(200).json({
    status: "success",
    results: categories.length,
    data: { categories }
  });
});

//========================================================================================
// Get a single inventory category
exports.getCategory = catchAsync(async (req, res, next) => {
  const { categoryId } = req.params;

  const category = await InventoryCategory.findById(categoryId)
    .populate('parent_category_id');

  if (!category) {
    return next(new AppError("Category not found", 404));
  }

  // Get subcategories
  const subcategories = await InventoryCategory.find({ parent_category_id: categoryId });

  res.status(200).json({
    status: "success",
    data: {
      category,
      subcategories
    }
  });
});

//========================================================================================
// Update an inventory category
exports.updateCategory = catchAsync(async (req, res, next) => {
  const { categoryId } = req.params;
  const { title, parent_category_id, description } = req.body;

  // Prevent self-referencing
  if (parent_category_id && parent_category_id === categoryId) {
    return next(new AppError("A category cannot be its own parent", 400));
  }

  // Validate parent exists if provided
  if (parent_category_id) {
    const parent = await InventoryCategory.findById(parent_category_id);
    if (!parent) {
      return next(new AppError("Parent category not found", 404));
    }
  }

  const category = await InventoryCategory.findByIdAndUpdate(
    categoryId,
    { title, parent_category_id, description },
    { new: true, runValidators: true }
  );

  if (!category) {
    return next(new AppError("Category not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { category }
  });
});

//========================================================================================
// Delete an inventory category (restrict if has children)
exports.deleteCategory = catchAsync(async (req, res, next) => {
  const { categoryId } = req.params;

  const category = await InventoryCategory.findById(categoryId);
  if (!category) {
    return next(new AppError("Category not found", 404));
  }

  // Check for subcategories
  const childCount = await InventoryCategory.countDocuments({ parent_category_id: categoryId });
  if (childCount > 0) {
    return next(new AppError(`Cannot delete category with ${childCount} subcategories. Remove subcategories first.`, 400));
  }

  await InventoryCategory.findByIdAndDelete(categoryId);

  res.status(204).json({ status: "success", data: null });
});
