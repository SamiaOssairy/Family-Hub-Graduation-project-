const express = require('express');
const { protect, restrictTo } = require('../controllers/AuthController');
const {
  getAlerts,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteAlert,
  clearReadAlerts,
  generateAlerts
} = require('../controllers/InventoryAlertController');

const inventoryAlertRouter = express.Router();

// All routes require authentication
inventoryAlertRouter.use(protect);

inventoryAlertRouter.get('/', getAlerts);
inventoryAlertRouter.get('/unread-count', getUnreadCount);
inventoryAlertRouter.post('/generate', generateAlerts);
inventoryAlertRouter.patch('/mark-all-read', markAllAsRead);
inventoryAlertRouter.patch('/:alertId/read', markAsRead);
inventoryAlertRouter.delete('/clear-read', clearReadAlerts);
inventoryAlertRouter.delete('/:alertId', deleteAlert);

module.exports = inventoryAlertRouter;
