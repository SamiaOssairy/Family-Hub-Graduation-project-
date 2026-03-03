const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const InventoryAlert = require("../models/inventoryAlertModel");
const InventoryItem = require("../models/inventoryItemModel");
const Inventory = require("../models/inventoryModel");

//========================================================================================
// Get all alerts for the family (with optional filters)
exports.getAlerts = catchAsync(async (req, res, next) => {
  const { is_read, alert_type } = req.query;

  const filter = { family_id: req.familyAccount._id };
  if (is_read !== undefined) filter.is_read = is_read === 'true';
  if (alert_type) filter.alert_type = alert_type;

  const alerts = await InventoryAlert.find(filter)
    .populate({
      path: 'inventory_item_id',
      populate: [
        { path: 'unit_id' },
        { path: 'item_category' },
        { path: 'inventory_id' }
      ]
    })
    .sort({ createdAt: -1 });

  res.status(200).json({
    status: "success",
    results: alerts.length,
    data: { alerts }
  });
});

//========================================================================================
// Get unread alert count
exports.getUnreadCount = catchAsync(async (req, res, next) => {
  const count = await InventoryAlert.countDocuments({
    family_id: req.familyAccount._id,
    is_read: false
  });

  res.status(200).json({
    status: "success",
    data: { unreadCount: count }
  });
});

//========================================================================================
// Mark alert as read
exports.markAsRead = catchAsync(async (req, res, next) => {
  const { alertId } = req.params;

  const alert = await InventoryAlert.findOneAndUpdate(
    { _id: alertId, family_id: req.familyAccount._id },
    { is_read: true },
    { new: true }
  );

  if (!alert) {
    return next(new AppError("Alert not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { alert }
  });
});

//========================================================================================
// Mark all alerts as read
exports.markAllAsRead = catchAsync(async (req, res, next) => {
  await InventoryAlert.updateMany(
    { family_id: req.familyAccount._id, is_read: false },
    { is_read: true }
  );

  res.status(200).json({
    status: "success",
    message: "All alerts marked as read"
  });
});

//========================================================================================
// Delete a single alert
exports.deleteAlert = catchAsync(async (req, res, next) => {
  const { alertId } = req.params;

  const alert = await InventoryAlert.findOneAndDelete({
    _id: alertId,
    family_id: req.familyAccount._id
  });

  if (!alert) {
    return next(new AppError("Alert not found", 404));
  }

  res.status(204).json({ status: "success", data: null });
});

//========================================================================================
// Delete all read alerts
exports.clearReadAlerts = catchAsync(async (req, res, next) => {
  const result = await InventoryAlert.deleteMany({
    family_id: req.familyAccount._id,
    is_read: true
  });

  res.status(200).json({
    status: "success",
    message: `${result.deletedCount} read alerts cleared`
  });
});

//========================================================================================
// Generate alerts - scans inventory and creates persisted alert records
// Called by daily cron or manually
exports.generateAlerts = catchAsync(async (req, res, next) => {
  const familyId = req.familyAccount._id;
  const inventories = await Inventory.find({ family_id: familyId });
  const inventoryIds = inventories.map(inv => inv._id);

  const now = new Date();
  const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const allItems = await InventoryItem.find({ inventory_id: { $in: inventoryIds } })
    .populate('unit_id')
    .populate('item_category');

  const alertsCreated = [];

  for (const item of allItems) {
    // Low stock alert (24hr cooldown)
    if (item.quantity <= item.threshold_quantity) {
      if (!item.last_notified_at || item.last_notified_at <= twentyFourHoursAgo) {
        const existing = await InventoryAlert.findOne({
          inventory_item_id: item._id,
          alert_type: 'low_stock',
          createdAt: { $gte: twentyFourHoursAgo }
        });

        if (!existing) {
          const alert = await InventoryAlert.create({
            inventory_item_id: item._id,
            family_id: familyId,
            alert_type: 'low_stock',
            alert_message: `${item.item_name} is running low (${item.quantity} ${item.unit_id ? item.unit_id.unit_name : 'units'} remaining, threshold: ${item.threshold_quantity})`
          });
          alertsCreated.push(alert);

          // Update last_notified_at
          item.last_notified_at = now;
          await item.save({ validateBeforeSave: false });
        }
      }
    }

    // Expiring soon alert (within 3 days)
    if (item.expiry_date && item.expiry_date <= threeDaysFromNow && item.expiry_date >= now) {
      const existing = await InventoryAlert.findOne({
        inventory_item_id: item._id,
        alert_type: 'expiring_soon',
        createdAt: { $gte: twentyFourHoursAgo }
      });

      if (!existing) {
        const alert = await InventoryAlert.create({
          inventory_item_id: item._id,
          family_id: familyId,
          alert_type: 'expiring_soon',
          alert_message: `${item.item_name} expires on ${item.expiry_date.toLocaleDateString()}`
        });
        alertsCreated.push(alert);
      }
    }

    // Expired alert
    if (item.expiry_date && item.expiry_date < now) {
      const existing = await InventoryAlert.findOne({
        inventory_item_id: item._id,
        alert_type: 'expired',
        createdAt: { $gte: twentyFourHoursAgo }
      });

      if (!existing) {
        const alert = await InventoryAlert.create({
          inventory_item_id: item._id,
          family_id: familyId,
          alert_type: 'expired',
          alert_message: `${item.item_name} has expired (${item.expiry_date.toLocaleDateString()})`
        });
        alertsCreated.push(alert);
      }
    }
  }

  res.status(200).json({
    status: "success",
    message: `${alertsCreated.length} new alerts generated`,
    data: { alerts: alertsCreated }
  });
});
