const express = require('express');
const { protect, restrictTo } = require('../controllers/AuthController');
const {
  createCategory,
  getAllCategories,
  getCategory,
  updateCategory,
  deleteCategory
} = require('../controllers/InventoryCategoryController');

const inventoryCategoryRouter = express.Router();

// All routes require authentication
inventoryCategoryRouter.use(protect);

inventoryCategoryRouter.get('/', getAllCategories);
inventoryCategoryRouter.get('/:categoryId', getCategory);
inventoryCategoryRouter.post('/', restrictTo('Parent'), createCategory);
inventoryCategoryRouter.patch('/:categoryId', restrictTo('Parent'), updateCategory);
inventoryCategoryRouter.delete('/:categoryId', restrictTo('Parent'), deleteCategory);

module.exports = inventoryCategoryRouter;
