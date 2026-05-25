// ═══════════════════════════════════════════════════════════════════════════════
// Family Hub — API Service  (mirrors Flutter's api_service.dart exactly)
// Base URL: http://localhost:8000/api
// ═══════════════════════════════════════════════════════════════════════════════

import axios from 'axios';

const BASE_URL = 'http://localhost:8000/api';

// ── Axios instance ────────────────────────────────────────────────────────────
const api = axios.create({ baseURL: BASE_URL });

// Attach JWT token to every request
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token');
  if (token) config.headers['Authorization'] = `Bearer ${token}`;
  return config;
});

// ── Error helper ──────────────────────────────────────────────────────────────
function extractError(err) {
  return err?.response?.data?.message || err?.message || 'An error occurred';
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════════════════════════════════
export async function signup(data) {
  const res = await api.post('/auth/signup', data);
  if (res.data.token) localStorage.setItem('token', res.data.token);
  return res.data;
}

export async function login(data) {
  const res = await api.post('/auth/login', data);
  if (res.data.token) {
    localStorage.setItem('token', res.data.token);
    const d = res.data.data || {};
    localStorage.setItem('memberType',  d.memberType  || '');
    localStorage.setItem('username',    d.username    || '');
    localStorage.setItem('familyTitle', d.familyTitle || '');
    localStorage.setItem('familyId',    d.familyId    || '');
    localStorage.setItem('memberId',    d.memberId    || '');
    localStorage.setItem('memberMail',  d.mail        || '');
    localStorage.setItem('isFirstLogin', d.isFirstLogin ? 'true' : 'false');
  }
  return res.data;
}

export async function getFamiliesByEmail(mail) {
  const res = await api.get(`/auth/families?mail=${encodeURIComponent(mail)}`);
  return res.data?.data?.families || [];
}

export async function setPassword({ currentPassword, newPassword, confirmPassword }) {
  const body = { newPassword, confirmPassword };
  if (currentPassword) body.currentPassword = currentPassword;
  const res = await api.post('/auth/setPassword', body);
  if (res.status === 200) localStorage.setItem('isFirstLogin', 'false');
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMBERS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllMembers() {
  const res = await api.get('/members');
  return res.data?.data?.members || [];
}

export async function createMember(data) {
  const res = await api.post('/members', data);
  return res.data;
}

export async function deleteMember(memberId) {
  const res = await api.delete(`/members/${memberId}`);
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMBER TYPES
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllMemberTypes() {
  const res = await api.get('/memberTypes');
  return res.data?.data?.memberTypes || [];
}

export async function createMemberType(typeName) {
  const res = await api.post('/memberTypes', { type: typeName });
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TASKS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllTasks() {
  const res = await api.get('/tasks');
  return res.data?.data?.tasks || [];
}

export async function createTask(data) {
  const res = await api.post('/tasks', data);
  return res.data;
}

export async function deleteTask(taskId) {
  await api.delete(`/tasks/${taskId}`);
}

export async function updateTask(taskId, data) {
  const res = await api.patch(`/tasks/${taskId}`, data);
  return res.data;
}

export async function getMyTasks() {
  const res = await api.get('/tasks/my-tasks');
  return res.data?.data?.tasks || [];
}

export async function getAllAssignedTasks() {
  const res = await api.get('/tasks/all-assigned');
  return res.data?.data?.assignedTasks || [];
}

export async function assignTask(data) {
  const res = await api.post('/tasks/assign', data);
  return res.data;
}

export async function completeTask(taskDetailId) {
  const res = await api.patch(`/tasks/${taskDetailId}/complete`);
  return res.data;
}

export async function approveTaskCompletion(taskDetailId, approved, notes) {
  const body = { approved };
  if (notes?.trim()) body.notes = notes.trim();
  const res = await api.patch(`/tasks/assignments/${taskDetailId}/approve-completion`, body);
  return res.data;
}

export async function getTasksWaitingApproval() {
  const res = await api.get('/tasks/waiting-approval');
  return res.data?.data?.tasksWaitingApproval || [];
}

export async function getPendingAssignments() {
  const res = await api.get('/tasks/pending-assignments');
  return res.data?.data?.pendingAssignments || [];
}

export async function approveTaskAssignment(taskDetailId, approved) {
  const res = await api.patch(`/tasks/assignments/${taskDetailId}/approve-assignment`, { approved });
  return res.data;
}

export async function applyPenalty(taskDetailId, penaltyPoints, notes) {
  const body = { penalty_points: penaltyPoints };
  if (notes) body.notes = notes;
  const res = await api.post(`/tasks/assignments/${taskDetailId}/penalty`, body);
  return res.data;
}

export async function getTaskRewardsSummary(period = 'monthly') {
  const res = await api.get(`/tasks/rewards-summary?period=${period}`);
  return res.data?.data || {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TASK CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllTaskCategories() {
  const res = await api.get('/task-categories');
  return res.data?.data?.categories || [];
}

export async function createTaskCategory(data) {
  const res = await api.post('/task-categories', data);
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// POINT WALLET
// ═══════════════════════════════════════════════════════════════════════════════
export async function getMyWallet() {
  const res = await api.get('/point-wallet/my-wallet');
  return res.data?.data?.wallet || {};
}

export async function getPointsRanking() {
  const res = await api.get('/point-wallet/ranking');
  return res.data?.data?.ranking || [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// POINT HISTORY
// ═══════════════════════════════════════════════════════════════════════════════
export async function getMyPointHistory() {
  const res = await api.get('/point-history/my-history');
  return res.data?.data?.history || [];
}

export async function getMemberPointHistory(memberMail) {
  const res = await api.get(`/point-history/${encodeURIComponent(memberMail)}`);
  return res.data?.data?.history || [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WISHLIST
// ═══════════════════════════════════════════════════════════════════════════════
export async function getMyWishlistItems() {
  const res = await api.get('/wishlist/my-wishlist');
  return res.data?.data?.items || [];
}

export async function addWishlistItem(data) {
  const res = await api.post('/wishlist/my-wishlist/items', data);
  return res.data;
}

export async function updateWishlistItem(itemId, data) {
  const res = await api.patch(`/wishlist/items/${itemId}`, data);
  return res.data;
}

export async function deleteWishlistItem(itemId) {
  await api.delete(`/wishlist/items/${itemId}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REDEEM
// ═══════════════════════════════════════════════════════════════════════════════
export async function requestRedemption(data) {
  const res = await api.post('/redeem/request', data);
  return res.data;
}

export async function requestRedemptionWithMoney(data) {
  const res = await api.post('/redeem/with-money', data);
  return res.data;
}

export async function getMyRedemptions() {
  const res = await api.get('/redeem/my-redemptions');
  return res.data?.data?.redemptions || [];
}

export async function getPendingRedemptions() {
  const res = await api.get('/redeem/pending');
  return res.data?.data?.pendingRedemptions || res.data?.data?.redemptions || [];
}

export async function parentApproveRedemption(redeemId, approved, note, forceApprove = false) {
  const body = { approved };
  if (forceApprove) body.force_approve = true;
  if (note) body.rejection_reason = note;
  const res = await api.patch(`/redeem/${redeemId}/approve`, body);
  return res.data;
}

export async function cancelRedemption(redeemId) {
  await api.delete(`/redeem/${redeemId}/cancel`);
}

export async function acceptRedemption(redeemId) {
  const res = await api.patch(`/redeem/${redeemId}/accept`);
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNITS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllUnits() {
  const res = await api.get('/units');
  return res.data?.data?.units || [];
}

export async function seedUnits() {
  const res = await api.post('/units/seed');
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllInventories() {
  const res = await api.get('/inventory');
  return res.data?.data?.inventories || [];
}

export async function createInventory(title, type) {
  const body = { title };
  if (type) body.type = type;
  const res = await api.post('/inventory', body);
  return res.data;
}

export async function updateInventory(inventoryId, data) {
  const res = await api.patch(`/inventory/${inventoryId}`, data);
  return res.data;
}

export async function deleteInventory(inventoryId) {
  await api.delete(`/inventory/${inventoryId}`);
}

export async function getAllFamilyItems() {
  const res = await api.get('/inventory/all-items');
  return res.data?.data?.items || [];
}

export async function getInventoryItems(inventoryId) {
  const res = await api.get(`/inventory/${inventoryId}/items`);
  return res.data?.data || {};
}

export async function addInventoryItem(inventoryId, data) {
  const res = await api.post(`/inventory/${inventoryId}/items`, data);
  return res.data;
}

export async function updateInventoryItem(itemId, data) {
  const res = await api.patch(`/inventory/items/${itemId}`, data);
  return res.data;
}

export async function deleteInventoryItem(itemId) {
  await api.delete(`/inventory/items/${itemId}`);
}

export async function getInventoryAlerts() {
  const res = await api.get('/inventory/alerts');
  return res.data?.data || {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllItemCategories() {
  const res = await api.get('/inventory/categories');
  return res.data?.data?.categories || [];
}

export async function getAllInventoryCategories({ tree = false } = {}) {
  const res = await api.get(`/inventory-categories${tree ? '?tree=true' : ''}`);
  return res.data?.data?.categories || [];
}

export async function createItemCategory(data) {
  const res = await api.post('/inventory/categories', data);
  return res.data;
}

export async function updateItemCategory(categoryId, data) {
  const res = await api.patch(`/inventory/categories/${categoryId}`, data);
  return res.data;
}

export async function deleteItemCategory(categoryId) {
  await api.delete(`/inventory/categories/${categoryId}`);
}

// /inventory-categories CRUD (tree-capable, used by InventoryCategoriesScreen)
export async function createInventoryCategory(data) {
  const res = await api.post('/inventory-categories', data);
  return res.data;
}

export async function updateInventoryCategory(categoryId, data) {
  const res = await api.patch(`/inventory-categories/${categoryId}`, data);
  return res.data;
}

export async function deleteInventoryCategory(categoryId) {
  await api.delete(`/inventory-categories/${categoryId}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY ALERTS (persisted)
// ═══════════════════════════════════════════════════════════════════════════════
export async function getInventoryAlertsPersisted({ isRead, alertType } = {}) {
  let url = '/inventory-alerts';
  const params = [];
  if (isRead != null) params.push(`is_read=${isRead}`);
  if (alertType) params.push(`alert_type=${alertType}`);
  if (params.length) url += '?' + params.join('&');
  const res = await api.get(url);
  return res.data?.data?.alerts || [];
}

export async function getUnreadAlertCount() {
  const res = await api.get('/inventory-alerts/unread-count');
  return res.data?.data?.unreadCount || 0;
}

export async function markAlertAsRead(alertId) {
  await api.patch(`/inventory-alerts/${alertId}/read`);
}

export async function markAllAlertsAsRead() {
  await api.patch('/inventory-alerts/mark-all-read');
}

export async function deleteAlert(alertId) {
  await api.delete(`/inventory-alerts/${alertId}`);
}

export async function generateInventoryAlerts() {
  const res = await api.post('/inventory-alerts/generate');
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECIPES
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllRecipes(category) {
  let url = '/recipes';
  if (category) url += `?category=${category}`;
  const res = await api.get(url);
  return res.data?.data?.recipes || [];
}

export async function getRecipe(recipeId) {
  const res = await api.get(`/recipes/${recipeId}`);
  return res.data;
}

export async function getRecipeScaled(recipeId, servings) {
  const res = await api.get(`/recipes/${recipeId}/scaled?servings=${servings}`);
  return res.data;
}

export async function createRecipe(data) {
  const res = await api.post('/recipes', data);
  return res.data;
}

export async function updateRecipe(recipeId, data) {
  const res = await api.patch(`/recipes/${recipeId}`, data);
  return res.data;
}

export async function deleteRecipe(recipeId) {
  await api.delete(`/recipes/${recipeId}`);
}

export async function addRecipeIngredient(recipeId, data) {
  const res = await api.post(`/recipes/${recipeId}/ingredients`, data);
  return res.data;
}

export async function removeRecipeIngredient(recipeId, ingredientId) {
  await api.delete(`/recipes/${recipeId}/ingredients/${ingredientId}`);
}

export async function addRecipeStep(recipeId, data) {
  const res = await api.post(`/recipes/${recipeId}/steps`, data);
  return res.data;
}

export async function removeRecipeStep(recipeId, stepId) {
  await api.delete(`/recipes/${recipeId}/steps/${stepId}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEALS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getMeals({ date, startDate, endDate } = {}) {
  let url = '/meals';
  const params = [];
  if (date) params.push(`date=${date}`);
  if (startDate) params.push(`start_date=${startDate}`);
  if (endDate) params.push(`end_date=${endDate}`);
  if (params.length) url += '?' + params.join('&');
  const res = await api.get(url);
  return res.data?.data?.meals || [];
}

export async function getMeal(mealId) {
  const res = await api.get(`/meals/${mealId}`);
  return res.data?.data || {};
}

export async function createMeal(data) {
  const res = await api.post('/meals', data);
  return res.data;
}

export async function updateMeal(mealId, data) {
  const res = await api.patch(`/meals/${mealId}`, data);
  return res.data;
}

export async function deleteMeal(mealId) {
  await api.delete(`/meals/${mealId}`);
}

export async function addMealItem(mealId, data) {
  const res = await api.post(`/meals/${mealId}/items`, data);
  return res.data;
}

export async function removeMealItem(mealId, mealItemId) {
  await api.delete(`/meals/${mealId}/items/${mealItemId}`);
}

export async function prepareMealFromRecipe(mealId) {
  const res = await api.post(`/meals/${mealId}/prepare`);
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFTOVERS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllLeftovers(expired) {
  let url = '/leftovers';
  if (expired != null) url += `?expired=${expired}`;
  const res = await api.get(url);
  return res.data?.data?.leftovers || [];
}

export async function addLeftover(data) {
  const res = await api.post('/leftovers', data);
  return res.data;
}

export async function updateLeftover(leftoverId, data) {
  const res = await api.patch(`/leftovers/${leftoverId}`, data);
  return res.data;
}

export async function deleteLeftover(leftoverId) {
  await api.delete(`/leftovers/${leftoverId}`);
}

export async function getExpiringLeftovers() {
  const res = await api.get('/leftovers/expiring');
  return res.data;
}

export async function getAllLeftoverCategories() {
  const res = await api.get('/leftovers/categories');
  return res.data?.data?.categories || [];
}

export async function createLeftoverCategory(data) {
  const res = await api.post('/leftovers/categories', data);
  return res.data;
}

export async function deleteLeftoverCategory(categoryId) {
  await api.delete(`/leftovers/categories/${categoryId}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEAL SUGGESTIONS
// ═══════════════════════════════════════════════════════════════════════════════
export async function generateMealSuggestions(mealType = 'Any') {
  const res = await api.post('/meal-suggestions/generate', { meal_type: mealType });
  return res.data;
}

export async function getMealSuggestions() {
  const res = await api.get('/meal-suggestions');
  return res.data?.data?.suggestions || [];
}

export async function clearMealSuggestions() {
  await api.delete('/meal-suggestions');
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECEIPTS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllReceipts({ startDate, endDate, memberMail } = {}) {
  let url = '/receipts';
  const params = [];
  if (startDate) params.push(`start_date=${startDate}`);
  if (endDate) params.push(`end_date=${endDate}`);
  if (memberMail) params.push(`member_mail=${memberMail}`);
  if (params.length) url += '?' + params.join('&');
  const res = await api.get(url);
  return res.data?.data?.receipts || [];
}

export async function getReceipt(receiptId) {
  const res = await api.get(`/receipts/${receiptId}`);
  return res.data;
}

export async function createReceipt(data) {
  const res = await api.post('/receipts', data);
  return res.data;
}

export async function updateReceipt(receiptId, data) {
  const res = await api.patch(`/receipts/${receiptId}`, data);
  return res.data;
}

export async function deleteReceipt(receiptId) {
  await api.delete(`/receipts/${receiptId}`);
}

export async function getSpendingSummary({ startDate, endDate } = {}) {
  let url = '/receipts/summary';
  const params = [];
  if (startDate) params.push(`start_date=${startDate}`);
  if (endDate) params.push(`end_date=${endDate}`);
  if (params.length) url += '?' + params.join('&');
  const res = await api.get(url);
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROCERY LISTS
// ═══════════════════════════════════════════════════════════════════════════════
export async function getAllGroceryLists() {
  const res = await api.get('/grocery-lists');
  return res.data?.data?.groceryLists || [];
}

export async function createGroceryList(data) {
  const res = await api.post('/grocery-lists', data);
  return res.data;
}

export async function getGroceryList(id) {
  const res = await api.get(`/grocery-lists/${id}`);
  return res.data?.data || {};
}

export async function updateGroceryList(id, data) {
  const res = await api.patch(`/grocery-lists/${id}`, data);
  return res.data;
}

export async function deleteGroceryList(id) {
  await api.delete(`/grocery-lists/${id}`);
}

export async function addGroceryItem(listId, data) {
  const res = await api.post(`/grocery-lists/${listId}/items`, data);
  return res.data;
}

export async function updateGroceryItem(itemId, data) {
  const res = await api.patch(`/grocery-lists/items/${itemId}`, data);
  return res.data;
}

export async function deleteGroceryItem(itemId) {
  await api.delete(`/grocery-lists/items/${itemId}`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUDGET / COMBINED WALLET
// ═══════════════════════════════════════════════════════════════════════════════
export async function getCombinedBalance(memberId) {
  const id = memberId || localStorage.getItem('memberId');
  const res = await api.get(`/budget/member/${id}/combined-balance`);
  return res.data?.data || {};
}

export async function getInventoryBudgetSummary({ activeOn, periodBudgetId, includePeriods } = {}) {
  const params = new URLSearchParams();
  if (activeOn) params.append('active_on', activeOn);
  if (periodBudgetId) params.append('period_budget_id', periodBudgetId);
  if (includePeriods) params.append('include_periods', 'true');
  const res = await api.get(`/budgets/inventory-summary?${params.toString()}`);
  return res.data;
}

export async function getFutureEvents() {
  const res = await api.get('/budgets/future-events/all');
  return res.data?.data?.events || [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECEIPT SCAN (AI)
// ═══════════════════════════════════════════════════════════════════════════════
export async function scanReceipt(imageBytes) {
  // imageBytes can be Uint8Array or base64 data URL string
  let base64Str;
  if (typeof imageBytes === 'string') {
    // already a data URL
    base64Str = imageBytes.includes(',') ? imageBytes.split(',')[1] : imageBytes;
  } else {
    // Uint8Array
    base64Str = btoa(String.fromCharCode(...new Uint8Array(imageBytes)));
  }
  const res = await api.post('/receipts/scan', { image_base64: base64Str });
  return res.data?.data || res.data || {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLANNING AI
// ═══════════════════════════════════════════════════════════════════════════════
export async function sendPlanningMessage(message) {
  const res = await api.post('/planning/chat', { message });
  return res.data;
}

export async function getPlanningHistory() {
  const res = await api.get('/planning/history');
  return res.data;
}

export async function clearPlanningHistory() {
  await api.delete('/planning/history');
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCATION
// ═══════════════════════════════════════════════════════════════════════════════
export async function toggleLocationSharing(enable) {
  const res = await api.patch('/location/toggle', { sharing_enabled: enable });
  return res.data;
}

export async function getMyLocation() {
  const res = await api.get('/location/me');
  return res.data;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSION RATE
// ═══════════════════════════════════════════════════════════════════════════════
export async function setConversionRate({ moneyToPointsRate, pointsToMoneyRate }) {
  const res = await api.post('/budget/conversion-rate', {
    money_to_points_rate: moneyToPointsRate,
    points_to_money_rate: pointsToMoneyRate,
  });
  return res.data;
}

export async function getConversionRate() {
  const res = await api.get('/budget/conversion-rate');
  return res.data?.data || {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAMILY ACCOUNT
// ═══════════════════════════════════════════════════════════════════════════════
export async function deactivateAccount(email, password) {
  const res = await api.post('/familyAccounts/deactivate', { email, password });
  return res.data;
}

export default api;
