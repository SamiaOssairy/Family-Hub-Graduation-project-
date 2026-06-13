# Claude.md — Family Hub Project Context
> Read this file before making ANY modification. It gives full project context so you never need to re-read the entire codebase.

---

## 1. Project Overview

**Name:** Family Hub (graduation project)
**Stack:** Node.js/Express backend · Flutter mobile/desktop app · React web (secondary, less active)
**Database:** MongoDB via Mongoose v9
**Auth:** JWT (family-scoped — one email can belong to multiple families)

---

## 2. Directory Structure

```
auth implementation/
├── backend/                  # Node.js + Express REST API
│   ├── server.js             # Entry point (starts server on PORT=8000)
│   ├── app.js                # Express setup, all routers registered here
│   ├── controllers/          # Request logic
│   ├── routes/               # Route → controller mapping
│   ├── models/               # Mongoose schemas
│   ├── utils/                # catchAsync, AppError, etc.
│   ├── scripts/              # Seed scripts
│   └── .env                  # Secrets (never commit)
├── flutter_app/
│   └── lib/
│       ├── main.dart         # App entry, routes map, MultiProvider
│       ├── pages/            # All screens
│       └── core/
│           ├── services/api_service.dart   # ALL HTTP calls centralized here
│           ├── localization/app_i18n.dart  # AppI18n.t(context, en, ar)
│           └── services/locale_service.dart
└── React_frontend/           # Secondary web client (less active)
```

---

## 3. Run Commands

```bash
# Backend
cd backend && npm run dev        # nodemon (development)
cd backend && npm start          # node server.js (production)

# Flutter
cd flutter_app && flutter run -d windows
cd flutter_app && flutter run -d chrome
cd flutter_app && flutter run              # mobile

# React
cd React_frontend && npm start
```

**Restart backend manually (when nodemon isn't running):**
```powershell
# Find PID on port 8000
netstat -ano | findstr ":8000"
# Kill it
Stop-Process -Id <PID> -Force
# Restart
cd backend; node server.js
```

---

## 4. Auth & JWT Pattern — CRITICAL

JWT payload: `{ id: family_id, member_id }`

The `protect` middleware (in `controllers/AuthController.js`) sets:
- `req.familyAccount` → full FamilyAccount document (has `._id`, `.Title`, `.mail`)
- `req.memberId` → ObjectId of the logged-in member
- `req.member` → full Member document

**Every protected controller uses:**
```javascript
const familyId  = req.familyAccount._id;
const memberId  = req.memberId;
```

All data is **family-scoped**: every query must include `{ family_id: familyId }`.

---

## 5. Backend Architecture

```
Route file  →  protect middleware  →  Controller  →  Model  →  JSON response
```

Error handling: wrap controllers in `catchAsync` from `utils/catchAsync.js`.
Throw errors with `new AppError(message, statusCode)` from `utils/appError.js`.
Global error handler in `app.js` formats all errors as `{ message: "..." }`.

---

## 6. All Registered API Routes (app.js)

> **Budget routes use TWO prefixes** — both `/api/budget` and `/api/budgets` are registered and hit the same router.

| Prefix | Router file |
|--------|-------------|
| `/api/auth` | authRoutes.js |
| `/api/familyAccounts` | familyAccountRoutes.js |
| `/api/members` | memberRoutes.js |
| `/api/memberTypes` | memberTypeRoutes.js |
| `/api/tasks` | taskRoutes.js |
| `/api/task-categories` | taskCategoryRoutes.js |
| `/api/point-wallet` | pointWalletRoutes.js |
| `/api/point-history` | pointHistoryRoutes.js |
| `/api/wishlist` | wishlistRoutes.js |
| `/api/wishlist-categories` | wishlistCategoryRoutes.js |
| `/api/redeem` | redeemRoutes.js |
| `/api/budget` + `/api/budgets` | BudgetRoutes.js |
| `/api/planning` | planningRoutes.js ← **Planning AI** |
| `/api/units` | unitRoutes.js |
| `/api/recipes` | recipeRoutes.js |
| `/api/inventory` | inventoryRoutes.js |
| `/api/inventory-categories` | inventoryCategoryRoutes.js |
| `/api/inventory-alerts` | inventoryAlertRoutes.js |
| `/api/receipts` | receiptRoutes.js |
| `/api/meals` | mealRoutes.js |
| `/api/leftovers` | leftoverRoutes.js |
| `/api/meal-suggestions` | mealSuggestionRoutes.js |
| `/api/location` | locationRoutes.js |
| `/api/grocery-lists` | groceryRoutes.js |

---

## 7. All Module Routes — Quick Reference

### Auth (`/api/auth`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/signup` | Public | Create family + parent member |
| `POST` | `/login` | Public | Login → returns JWT token |
| `GET` | `/families` | Public | Get families by email |
| `POST` | `/setPassword` | Any | Set/change password |
| `POST` | `/forgotPassword` | Parent | Send reset email |
| `PATCH` | `/resetPassword/:token` | Parent | Reset via token |

### Members (`/api/members`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List all family members |
| `POST` | `/` | Parent | Add member to family |
| `DELETE` | `/:memberId` | Parent | Remove member |

### Member Types (`/api/memberTypes`)
CRUD — `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id` — all Parent only except GET.

### Tasks (`/api/tasks`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List task templates |
| `POST` | `/` | Any | Create task template |
| `PATCH` | `/:taskId` | Parent | Update task template |
| `DELETE` | `/:taskId` | Parent | Delete task template |
| `GET` | `/rewards-summary` | Any | Points earned summary |
| `POST` | `/assign` | Any | Assign task to member |
| `GET` | `/pending-assignments` | Parent | Assignments awaiting approval |
| `PATCH` | `/assignments/:id/approve-assignment` | Parent | Approve/reject assignment |
| `GET` | `/my-tasks` | Any | My assigned tasks |
| `GET` | `/all-assigned` | Any | All assigned tasks in family |
| `PATCH` | `/:taskDetailId/complete` | Any | Mark task complete |
| `GET` | `/waiting-approval` | Parent | Completions awaiting approval |
| `PATCH` | `/assignments/:id/approve-completion` | Parent | Approve/reject completion |
| `POST` | `/assignments/:id/penalty` | Parent | Apply manual penalty |

### Task Categories (`/api/task-categories`)
CRUD — `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id` — all Parent only except GET.

### Point Wallets (`/api/point-wallet`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/initialize` | Any | Init wallets for all members |
| `GET` | `/my-wallet` | Any | My own points balance |
| `GET` | `/ranking` | Any | Family leaderboard |
| `GET` | `/:memberMail` | Parent | View any member's wallet |
| `POST` | `/adjust` | Parent | Manual point adjustment |

### Point History (`/api/point-history`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/my-history` | Any | My own point transactions |
| `GET` | `/all` | Parent | All family point history |
| `GET` | `/:memberMail` | Parent | Specific member's history |

### Wishlist (`/api/wishlist`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/my-wishlist` | Any | My wishlist |
| `GET` | `/my-wishlist/progress` | Any | Wishlist funding progress |
| `POST` | `/my-wishlist/items` | Any | Add item to my wishlist |
| `PATCH` | `/my-wishlist/prioritize` | Any | Reorder wishlist items |
| `PATCH` | `/items/:itemId` | Any | Update wishlist item |
| `DELETE` | `/items/:itemId` | Any | Remove wishlist item |
| `GET` | `/:memberMail` | Parent | View any member's wishlist |
| `POST` | `/:memberMail/items` | Parent | Add item to member's wishlist |

### Wishlist Categories (`/api/wishlist-categories`)
CRUD — `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id` — Parent only except GET.

### Redeem (`/api/redeem`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/request` | Any | Request points redemption (uses wishlist item) |
| `POST` | `/with-money` | Any | Redeem using money wallet |
| `POST` | `/event-spot` | Any | Redeem a future event spot |
| `GET` | `/my-redemptions` | Any | My redemption history |
| `GET` | `/approved-waiting` | Any | Approved but not yet accepted |
| `DELETE` | `/:redeemId/cancel` | Any | Cancel pending request |
| `PATCH` | `/:redeemId/accept` | Child | Accept approved redemption |
| `GET` | `/pending` | Parent | All pending requests |
| `GET` | `/all` | Parent | Full redemption history |
| `PATCH` | `/:redeemId/approve` | Parent | Approve/reject redemption |

### Inventory (`/api/inventory`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/alerts` | Any | Threshold/expiry alerts |
| `GET` | `/all-items` | Any | All items across all inventories |
| `GET` | `/categories` | Any | Item categories |
| `POST` | `/categories` | Parent | Create item category |
| `PATCH` | `/categories/:id` | Parent | Update item category |
| `DELETE` | `/categories/:id` | Parent | Delete item category |
| `GET` | `/` | Any | List inventories |
| `POST` | `/` | Parent | Create inventory |
| `PATCH` | `/:inventoryId` | Parent | Update inventory |
| `DELETE` | `/:inventoryId` | Parent | Delete inventory |
| `GET` | `/:inventoryId/items` | Any | Items in an inventory |
| `POST` | `/:inventoryId/items` | Any | Add item to inventory |
| `PATCH` | `/items/:itemId` | Any | Update item |
| `DELETE` | `/items/:itemId` | Any | Delete item |

### Inventory Categories (`/api/inventory-categories`)
CRUD — `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id` — Parent only except GET.

### Inventory Alerts (`/api/inventory-alerts`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | All alerts |
| `GET` | `/unread-count` | Any | Unread alert count |
| `POST` | `/generate` | Any | Trigger alert generation |
| `PATCH` | `/mark-all-read` | Any | Mark all alerts read |
| `PATCH` | `/:alertId/read` | Any | Mark alert read |
| `DELETE` | `/clear-read` | Any | Clear read alerts |
| `DELETE` | `/:alertId` | Any | Delete alert |

### Recipes (`/api/recipes`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List all recipes |
| `POST` | `/` | Any | Create recipe |
| `GET` | `/:recipeId` | Any | Get recipe with ingredients + steps |
| `GET` | `/:recipeId/scaled` | Any | Get recipe scaled to serving size |
| `PATCH` | `/:recipeId` | Any | Update recipe |
| `DELETE` | `/:recipeId` | Any | Delete recipe |
| `POST` | `/:recipeId/ingredients` | Any | Add ingredient |
| `DELETE` | `/:recipeId/ingredients/:id` | Any | Remove ingredient |
| `POST` | `/:recipeId/steps` | Any | Add step |
| `DELETE` | `/:recipeId/steps/:id` | Any | Remove step |

### Meals (`/api/meals`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List meals |
| `POST` | `/` | Any | Create meal log |
| `GET` | `/:mealId` | Any | Get meal detail |
| `PATCH` | `/:mealId` | Any | Update meal |
| `DELETE` | `/:mealId` | Any | Delete meal |
| `POST` | `/:mealId/items` | Any | Add item to meal |
| `DELETE` | `/:mealId/items/:itemId` | Any | Remove item from meal |
| `POST` | `/:mealId/prepare` | Any | Prepare from recipe (auto-deducts inventory) |

### Meal Suggestions (`/api/meal-suggestions`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | Get saved suggestions |
| `POST` | `/generate` | Any | Generate AI-based suggestions from inventory |
| `DELETE` | `/` | Any | Clear suggestions |

### Leftovers (`/api/leftovers`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/expiring` | Any | Expiring soon alert |
| `GET` | `/categories` | Any | Leftover categories |
| `POST` | `/categories` | Parent | Create category |
| `DELETE` | `/categories/:id` | Parent | Delete category |
| `GET` | `/` | Any | List active leftovers |
| `POST` | `/` | Any | Add leftover |
| `PATCH` | `/:leftoverId` | Any | Update leftover |
| `DELETE` | `/:leftoverId` | Any | Delete leftover |

### Receipts (`/api/receipts`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List all receipts |
| `GET` | `/summary` | Any | Spending summary from receipts |
| `GET` | `/:receiptId` | Any | Get receipt detail |
| `POST` | `/` | Any | Create receipt |
| `PATCH` | `/:receiptId` | Any | Update receipt |
| `DELETE` | `/:receiptId` | Any | Delete receipt |

### Grocery Lists (`/api/grocery-lists`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List all grocery lists |
| `POST` | `/` | Any | Create grocery list |
| `GET` | `/:id` | Any | Get list with items |
| `PATCH` | `/:id` | Any | Update list |
| `DELETE` | `/:id` | Any | Delete list |
| `POST` | `/:id/items` | Any | Add item to list |
| `PATCH` | `/items/:itemId` | Any | Update item (name, qty, checked) |
| `DELETE` | `/items/:itemId` | Any | Delete item |

### Location (`/api/location`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/update` | Any | Update my location |
| `PATCH` | `/toggle` | Any | Toggle sharing on/off |
| `GET` | `/me` | Any | My current location |
| `GET` | `/family` | Any | All family members' locations |
| `GET` | `/family-members` | Any | Family member list |
| `POST` | `/permissions` | Any | Request location permission |
| `GET` | `/permissions/incoming` | Any | Incoming permission requests |
| `GET` | `/permissions/outgoing` | Any | My outgoing requests |
| `PATCH` | `/permissions/:id` | Any | Approve/deny permission |
| `DELETE` | `/permissions/:id` | Any | Revoke permission |
| `GET` | `/history` | Any | Location history |
| `DELETE` | `/history` | Any | Clear history |
| `POST` | `/alerts` | Any | Create location alert (geofence) |
| `GET` | `/alerts` | Any | My alerts |
| `GET` | `/alerts/unread-count` | Any | Unread alert count |
| `PATCH` | `/alerts/read-all` | Any | Mark all read |
| `PATCH` | `/alerts/:id/read` | Any | Mark one read |
| `DELETE` | `/alerts/:id` | Any | Delete alert |
| `POST` | `/shared` | Any | Share a location snapshot |
| `GET` | `/shared/received` | Any | Received location shares |
| `GET` | `/shared/sent` | Any | Sent location shares |
| `PATCH` | `/shared/:id/viewed` | Any | Mark share viewed |
| `DELETE` | `/shared/:id` | Any | Delete share |

### Units (`/api/units`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `GET` | `/` | Any | List all units |
| `POST` | `/seed` | Parent | Seed default units |
| `POST` | `/` | Parent | Create unit |
| `PATCH` | `/:unitId` | Parent | Update unit |
| `DELETE` | `/:unitId` | Parent | Delete unit |

### Family Accounts (`/api/familyAccounts`)
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/deactivate` | Parent | Deactivate family account |

---

## 7b. Key Model Schemas (non-obvious fields — read before querying)

> Only covers non-obvious / tricky fields. Standard fields (family_id, _id, createdAt) are omitted.

### Expense (`models/ExpenseModel.js`)
- `title` (String, required)
- `amount` (Number)
- `category` (String — plain string, NOT a ref)
- `expense_date` (Date) ← use this, NOT `date`
- `member_mail` (String) ← who recorded it, NOT `recorded_by`
- `family_id` (ObjectId ref FamilyAccount)
- ⚠️ Does NOT have `category_id` field — use `budget_category_id` if you need a ref to InventoryCategory

### Member (`models/MemberModel.js`)
- `username`, `mail`, `family_id`, `member_type_id` (ref MemberType), `birth_date`

### Task (`models/taskModel.js`)
- `title`, `created_by` (String/mail), `reward_type` ('points'|'money'|'both'), `money_reward`
- `category_id` (ref TaskCategory), `family_id`
- ⚠️ No `reward_points` field — points are in TaskDetails.assigned_points

### TaskDetails / task history (`models/task_historyModel.js`)
- `task_id` (ref Task), `member_mail` (String), `assigned_points`, `penalty_points`
- `status` ('assigned'|'in_progress'|'completed'|'late'|'approved'|'rejected')
- `assigned_by` (String/mail), `deadline` (Date)
- ⚠️ No `family_id` field — filter by joining with Task.family_id

### PointWallet (`models/point_walletModel.js`)
- `member_mail` (String), `family_id`, `total_points`

### PointHistory (`models/point_historyModel.js`)
- `wallet_id` (ref PointWallet), `member_mail`, `family_id`
- `points_amount`, `reason_type` ('task_completion'|'penalty'|'redeem'|'bonus'|'adjustment'|'manual_grant'|'conversion')
- `granted_by` (String/mail), `task_id` (optional ref), `description`

### Inventory (`models/inventoryModel.js`)
- `family_id`, `title`, `type` ('Food'|'Electronics'|'Cleaning'|'Personal Care'|'Other')

### InventoryItem (`models/inventoryItemModel.js`)
- `inventory_id` (ref Inventory — NOT family_id directly)
- `item_name`, `quantity`, `unit_id` (ref Unit), `item_category` (ref InventoryCategory)
- `threshold_quantity`, `expiry_date`
- ⚠️ No direct `family_id` — to query by family: find Inventory._ids first, then query InventoryItem

### InventoryCategory (`models/inventoryCategoryModel.js`)
- `title` (String) ← field is `title` NOT `name`

### Recipe (`models/recipeModel.js`)
- `recipe_name`, `member_mail`, `family_id`
- `category` (enum: 'Breakfast'|'Lunch'|'Dinner'|'Dessert'|'Snack'|'Appetizer'|'Main Course'|'Side Dish'|'Beverage'|'Other')
- `serving_size`, `prep_time`, `cook_time`, `description`

### RecipeIngredient (`models/recipeIngredientModel.js`)
- `recipe_id` (ref Recipe — NOT family_id directly)
- `ingredient_name`, `quantity`, `unit_id` (ref Unit), `notes`

### Meal (`models/mealModel.js`)
- `family_id`, `meal_name`, `meal_date`, `created_by` (String/mail — NOT ObjectId)
- `meal_type` ('Breakfast'|'Lunch'|'Dinner'|'Snack'), `recipe_id` (optional)

### Leftover (`models/leftoverModel.js`)
- `family_id`, `member_mail`, `item_name`, `quantity`, `unit_id`
- `expiry_date` (required), `date_added`, `meal_id` (optional), `category_id` (optional)

### FutureEvent (`models/futureEventModel.js`)
- `family_id`, `title`, `description`, `event_date`, `estimated_cost`
- `total_contributed_money`, `total_contributed_points`
- `funding_source` ('budget'|'member_contributions'|'points_redeem')
- `created_by` (String/mail)

### PeriodBudget (`models/periodBudgetModel.js`)
- `family_id`, `title`, `period_type` ('weekly'|'monthly'|'yearly'|'custom')
- `start_date`, `end_date`, `total_amount`, `spent_amount`
- `emergency_fund_percentage`, `emergency_fund_spent`, `is_active`

### PlanningConversation (`models/planningConversationModel.js`)
- `family_id`, `member_id`
- `messages[]`: `{ role: 'user'|'assistant', content: String, timestamp: Date }`

### Expense (`models/ExpenseModel.js`) — updated fields
- `expense_scope`: `'shared' | 'personal'` ← NEW (added May 2026)
- `request_status`: `'pending' | 'approved' | 'rejected' | null` ← NEW — null = direct expense
- `budget_id` refs **PeriodBudget** (not old Budget model)
- `budget_category_id` refs InventoryCategory

### MemberWallet (`models/memberWalletModel.js`)
- `member_mail`, `family_id`, `balance` (Number), `last_update`
- One per member per family — auto-created by `ensureMoneyWallet()`

### MemberAllowance (`models/memberAllowanceModel.js`)
- `family_id`, `period_budget_id`, `member_id`, `member_mail`
- `money_amount` (allowance given), `spent_amount` (how much used)
- `period_type`, `start_date`, `end_date`
- Virtual: `remaining_amount = money_amount - spent_amount`

### BudgetAllocation (`models/budgetAllocationModel.js`)
- `family_id`, `period_budget_id`, `inventory_category_id`
- `allocated_amount`, `spent_amount`, `threshold_percentage`, `is_active`
- Unique index: `(period_budget_id, inventory_category_id)`

### ConversionRate (`models/conversionRateModel.js`)
- `family_id`, `money_to_points_rate` (default 10), `points_to_money_rate` (default 0.05)
- `is_active` — only one active rate per family at a time

### WalletTransaction (`models/walletTransactionModel.js`)
- `family_id`, `member_mail`, `member_wallet_id`
- `amount`, `transaction_type` (`'deposit'|'withdrawal'`)
- `description`, `conversion_type`, `converted_amount`, `conversion_rate`
- `linked_point_transaction_id`

### BalanceWalletDetail (`models/balanceWalletDetailModel.js`)
- Full audit log for every wallet change
- `wallet_scope`: `'money_wallet'|'personal_budget'|'shared_budget'`
- `change_type`: `'credit'|'debit'`
- `source_type`: `'allowance'|'expense'|'conversion'|'budget_withdrawal'|'manual'`
- `previous_balance`, `new_balance`, `amount`

### GroceryList (`models/groceryListModel.js`)
- `family_id`, `title`, `created_by` (String/mail), `is_completed`

### GroceryItem (`models/groceryItemModel.js`)
- `grocery_list_id` (ref GroceryList), `item_name`, `quantity`, `unit`, `is_checked`, `added_by`
- ⚠️ No direct `family_id` — filter via `grocery_list_id`

### Receipt (`models/receiptModel.js`)
- `family_id`, `member_mail`, `title`, `total_amount`, `receipt_date`
- `store_name`, `category`, `items[]` (array of `{ name, price, quantity }`)
- `image_url` (optional photo)

### TaskDetails / task_history (`models/task_historyModel.js`)
- `task_id`, `member_mail`, `assigned_points`, `penalty_points`
- `status`: `'assigned'|'in_progress'|'completed'|'late'|'approved'|'rejected'`
- `assigned_by` (String/mail), `deadline`
- ⚠️ **No `family_id`** — filter by joining with Task.family_id

### WishlistItem (`models/wishlist_itemModel.js`)
- `wishlist_id` (ref Wishlist), `item_name`, `description`, `estimated_price`
- `priority` (Number), `is_funded`, `funded_amount`, `linked_event_id`

### Redeem (`models/redeemModel.js`)
- `family_id`, `member_mail`, `wishlist_item_id`, `points_used`, `money_used`
- `status`: `'pending'|'approved'|'rejected'|'accepted'|'cancelled'`
- `approved_by` (String/mail), `notes`

### Location models
- `LocationShare` (`models/locationShareModel.js`): `sender_mail`, `receiver_mail`, `latitude`, `longitude`, `family_id`, `is_viewed`
- `LocationPermission` (`models/locationPermissionModel.js`): `requester_mail`, `target_mail`, `family_id`, `status` (`'pending'|'approved'|'denied'`)
- `LocationHistory` (`models/locationHistoryModel.js`): `member_mail`, `family_id`, `latitude`, `longitude`, `timestamp`
- `LocationAlert` (`models/locationAlertModel.js`): `family_id`, `member_mail`, `alert_type`, `message`, `is_read`

### RecipeStep (`models/recipeStepModel.js`)
- `recipe_id`, `step_number`, `instruction`, `duration_minutes`

### MealItem (`models/mealItemModel.js`)
- `meal_id`, `item_name`, `quantity`, `unit_id`

### MealSuggestion (`models/mealSuggestionModel.js`)
- `family_id`, `meal_type` (`'Breakfast'|'Lunch'|'Dinner'|'Snack'`), `recipe_id`, `reason`, `score`

---

## 8. Planning AI Module (built in this project)

**Routes** (`routes/planningRoutes.js`) — all protected:
- `POST /api/planning/chat` → `sendMessage`
- `GET  /api/planning/history` → `getChatHistory`
- `DELETE /api/planning/history` → `clearHistory`

**Controller** (`controllers/PlanningAIController.js`):
- Uses **Google Gemini** (`@google/generative-ai` v0.24.1)
- Model: `gemini-2.5-flash-lite` (free tier, works as of May 2026)
- `gatherFamilyContext(familyId)` — runs 2 batches of parallel DB queries:
  - Batch 1: members, expenses, periodBudgets, pointWallets, pointHistory, tasks, taskDetails, futureEvents, inventories, recipes, recentMeals (last 7 days), leftovers (not expired)
  - Batch 2 (depends on batch 1 IDs): inventoryItems (quantity > 0), recipeIngredients
- `buildSystemPrompt(ctx, familyTitle)` — injects all family data as labelled sections
- Conversation history stored in MongoDB (PlanningConversation), last 10 msgs sent to Gemini as chat history
- Gemini role mapping: stored `'assistant'` → Gemini `'model'`

**Gemini API key** in `backend/.env`:
```
GEMINI_API_KEY=AIzaSyDWafwiWXBcCZux9PeTvuRoRN57JlNRmns
```

**⚠️ Known Gemini issues:**
- `gemini-1.5-flash` → 404 (deprecated in v1beta)
- `gemini-2.0-flash` / `gemini-2.0-flash-lite` → 429 quota exceeded on this key
- `gemini-2.5-flash-lite` → ✅ working

---

## 9. Flutter App

**Base URL:** `http://localhost:8000/api` (in `core/services/api_service.dart` line 6)

**All HTTP calls** go through `ApiService` class in `api_service.dart`. Always add new API methods there.

**Localization:** `AppI18n.t(context, 'English text', 'نص عربي')` — bilingual throughout.

**State management:** Provider (`MultiProvider` in `main.dart`). `FamilyBudgetProvider` is the main one.

**Navigation:** Named routes defined in `main.dart`. Add new screens there.

**All named routes (defined in `main.dart`):**
| Route | File | Notes |
|-------|------|-------|
| `/splash` | pages/splash_screen.dart | App entry point |
| `/onboarding` | pages/onboarding_screen.dart | First-time flow |
| `/login` | pages/signup_login.dart → LoginPage | Email → family → password |
| `/home` | pages/home.dart | Main home screen |
| `/settings` | pages/setting.dart | App settings |
| `/dashboard` | pages/dashboard_screen.dart | Module hub |
| `/tasks` | pages/tasks_screen.dart | Task list |
| `/task-management` | pages/task_management_screen.dart | Parent task management |
| `/status` | pages/status_screen.dart | Family status overview |
| `/rewards` | pages/rewards_screen.dart | Points & rewards |
| `/redeem` | pages/redeem_screen.dart | Redeem points |
| `/family-points` | pages/family_points_screen.dart | Family leaderboard |
| `/inventory` | pages/inventory_screen.dart | Inventory management |
| `/inventory-categories` | pages/inventory_categories_screen.dart | Manage categories |
| `/inventory-alerts` | pages/inventory_alerts_screen.dart | Threshold alerts |
| `/meals` | pages/meals_screen.dart | Meal log |
| `/food-hub` | pages/food_hub_screen.dart | Food Hub entry screen |
| `/recipes` | pages/recipes_screen.dart | Recipe list |
| `/leftovers` | pages/leftovers_screen.dart | Leftover tracker |
| `/meal-suggestions` | pages/meal_suggestions_screen.dart | AI meal suggestions |
| `/receipts` | pages/receipts_screen.dart | Receipt tracking |
| `/groceries` | pages/groceries_screen.dart | Grocery lists |
| `/grocery-list-detail` | pages/grocery_list_detail_screen.dart | Items in a list |
| `/budget` | pages/budget/budget_dashboard_screen.dart | Budget dashboard |
| `/event-funding` | pages/budget/... | Future event funding |
| `/family-map` | pages/family_map_screen.dart | Location tracking map |
| `/combined-wallet` | pages/wallet/combined_wallet_screen.dart | Money + points wallet |
| `/wallet-details` | pages/wallet/... | Balance audit trail |
| `/combined-analytics` | pages/analytics/combined_analytics_screen.dart | Spending analytics |
| `/planning-chat` | pages/planning_chat_screen.dart | AI family assistant |

**Planning AI screen** (`pages/planning_chat_screen.dart`):
- Suggestion chips, message bubbles (user=green right, AI=white left)
- Calls `_api.sendPlanningMessage()`, `getPlanningHistory()`, `clearPlanningHistory()`
- Bilingual, typing indicator, clear history button

---

## 10. Test Data (for habiba1278@gmail.com — "Habibo's fam")

**AI test data** — `backend/scripts/seed-ai-test-data.js` → `node backend/scripts/seed-ai-test-data.js`
**Budget test data** — `backend/scripts/seed-budget-test-data.js` → `node backend/scripts/seed-budget-test-data.js` (see §17 for full details)

**Members seeded:**
- Habiba (Parent, habiba1278@gmail.com)
- Ahmed (Child, ahmed.family@gmail.com) — 310 pts total, 80 pts last 2 weeks
- Ziad (Child, ziad.family@gmail.com) — 220 pts total, 50 pts last 2 weeks
- Noor (Child, noor.family@gmail.com) — 145 pts total, 35 pts last 2 weeks

**Expenses (last 3 months):** Feb ~3500 EGP, Mar ~4600 EGP, Apr ~5300 EGP (overspent vs 5000 budget)

**Period budgets:** Feb/Mar/Apr/May 2026, 5000 EGP each

**Recipes:** Cheese Omelette, Tomato Rice, Pasta with Tomato Sauce, Cheese Sandwich, Green Salad, Pancakes

**Inventory:** Eggs (12), Cheese (400g), Milk (2L), Tomatoes (1kg), Rice (3kg), Pasta (500g), Bread (1), Flour (2kg), Olive Oil (500ml), Onion (5), Cucumber (4), Lettuce (1), Yogurt (3), Salt

**Leftovers:** Leftover Tomato Rice (expires +1 day), Leftover Pasta (expires +2 days)

**Future events:** Summer Family Trip (8000 EGP, 2000 contributed), Eid Shopping (3000, 500 contributed), Ahmed's School Trip (800, fully funded)

---

## 11. Known Gotchas & Fixed Bugs

1. **Expense.populate('category_id')** — field doesn't exist, throws Mongoose `strictPopulate` error. Use `e.category` (plain string field) instead.
2. **Expense date field** is `expense_date` NOT `date`.
3. **Expense recorder** is `member_mail` NOT `recorded_by`.
4. **Meal.created_by** is a String (member email) NOT ObjectId.
5. **TaskDetails has no family_id** — filter with `td.task_id?.family_id?.toString() === familyIdStr`.
6. **InventoryItem has no family_id** — must query via `Inventory._ids` first.
7. **RecipeIngredient has no family_id** — query via `Recipe._ids` first.
8. **InventoryCategory uses `title` not `name`**.
9. **Gemini model names** — only `gemini-2.5-flash-lite` works on this free-tier key (May 2026).
10. **`createExpense` shared scope** — Flutter sends a `PeriodBudget._id` as `budget_id`. The old code queried the wrong `Budget` model → always 404. Fixed: now queries `PeriodBudget` and also increments `BudgetAllocation.spent_amount`.
11. **`createExpense` personal scope** — was updating `MemberAllowance.spent_amount` but never deducting from `MemberWallet.balance`. Fixed.
12. **`selectBudget` response key** — backend returns `data['data']['period_budget']`, NOT `data['data']['budget']`. Fixed in `budget_provider.dart`.
13. **`PeriodBudget` balance fields** — uses `total_amount` NOT `budget_amount` (that was the old `Budget` model field).

---

## 12. .env Variables

```
PORT=8000
DB=mongodb+srv://samia:<db_password>@cluster0.ncj8lb3.mongodb.net/?appName=Cluster0
DB_PASSWORD=samia123
JWT_SECRET=NodeJS_JWT_SECRET_PASSWORD_SECURE
JWT_EXPIRES_IN=90d
GEMINI_API_KEY=AIzaSyDWafwiWXBcCZux9PeTvuRoRN57JlNRmns
```

---

## 13. Adding a New Module — Checklist

1. Create `backend/models/newModel.js` with `family_id` field
2. Create `backend/controllers/newController.js` — wrap all exports in `catchAsync`, use `req.familyAccount._id`
3. Create `backend/routes/newRoutes.js` — apply `protect` middleware
4. Register in `backend/app.js`: `app.use('/api/new-thing', newRouter)`
5. Add API methods to `flutter_app/lib/core/services/api_service.dart`
6. Create screen in `flutter_app/lib/pages/new_screen.dart`
7. Add import + named route in `flutter_app/lib/main.dart`
8. Add navigation button in `flutter_app/lib/pages/home.dart` if needed

---

## 14. Quick Debug: Test Any Endpoint Without the App

```javascript
// backend/scripts/gen-token.js (or run inline)
const jwt = require('jsonwebtoken');
// family_id and member_id from DB
const token = jwt.sign({ id: '<family_id>', member_id: '<member_id>' }, process.env.JWT_SECRET, { expiresIn: '1h' });
```

Then:
```bash
curl -X POST http://localhost:8000/api/planning/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"message":"Your test question"}'
```

---

## 15. Budget Module — Full Architecture

### Period Budget flow (active design — NOT the old `Budget` model)
```
PeriodBudget → BudgetAllocation (per category) → Expense (shared)
            → MemberAllowance (per child)      → MemberWallet (balance)
```

### Key routes (`/api/budget` prefix, all protected):
| Method | Path | Who | Action |
|--------|------|-----|--------|
| `POST` | `/periods` | Parent | Create period budget |
| `GET` | `/periods` | Parent | List all period budgets |
| `GET` | `/periods/:id` | Parent | Budget + allocations detail |
| `PATCH` | `/periods/:id` | Parent | Update budget (title, amounts, dates) |
| `DELETE` | `/periods/:id` | Parent | Delete budget + cascade allocations + allowances |
| `PUT` | `/periods/:id/allocations` | Parent | Set category allocations |
| `PUT` | `/periods/:id/allowances` | Parent | Set member allowances (auto-deposits to MemberWallet) |
| `GET` | `/periods/:id/allowances` | Parent | Get member allowances |
| `POST` | `/expenses/new` | Any | Create shared or personal expense |
| `POST` | `/expense-requests` | Child | Submit expense request (pending parent approval) |
| `GET` | `/expense-requests` | Parent | List requests (`?status=pending\|approved\|rejected`) |
| `PATCH` | `/expense-requests/:id/approve` | Parent | Approve → deducts from budget |
| `PATCH` | `/expense-requests/:id/reject` | Parent | Reject → no money moved |
| `POST` | `/allocations/:id/withdrawals` | Any | Record withdrawal against an allocation |
| `GET` | `/analytics` | Any | Spending analytics (`?period_budget_id=`) |
| `GET` | `/member/:memberId/combined-balance` | Any | Money + points balance |

### Expense model new fields (added):
- `request_status`: `'pending' | 'approved' | 'rejected' | null` — null means direct expense, not a request
- `expense_scope`: `'shared' | 'personal'`

### Child expense request flow:
1. Child calls `POST /budget/expense-requests` → Expense created with `request_status: 'pending'`, parent gets email notification
2. Parent calls `GET /budget/expense-requests?status=pending` to review
3. Parent calls `PATCH /budget/expense-requests/:id/approve` → budget/allocation `spent_amount` incremented
4. Or parent calls `PATCH /budget/expense-requests/:id/reject` → no money moved

### Flutter provider methods (in `budget_provider.dart`):
- `submitExpenseRequest(payload)` — child submits
- `getExpenseRequests({status})` — parent fetches
- `approveExpenseRequest(id)` — parent approves
- `rejectExpenseRequest(id)` — parent rejects
- `selectBudget(id)` — reads `data['data']['period_budget']` (fixed key)

---

## 16. Flutter UI — Current State (May 2026)

### Login / Signup (`pages/signup_login.dart`)
- Shared helpers at top of file: `_fieldDeco(hint, icon, {suffix})` and `_primaryBtn()`
- All inputs: filled light-green tint, green border, green prefix icon, radius 12, green focus border
- All buttons: dark green `0xFF2E7D32`, radius 14, subtle shadow
- Social login buttons (Facebook/Google/Apple) **removed** — were non-functional
- Poppins w700 for all headings
- `_buildTextField` in `SignUpPage` accepts `icon` parameter

### Home page (`pages/home.dart`)
- Header: gradient avatar, Poppins family name, logout icon button
- Family members: color-coded avatars (6-color palette)
- Wallet: bank-card style gradient card (green), total balance large, money+points chips *(reverted — check git)*
- Calendar: interactive full-month grid, real future events from API, dot indicators *(reverted — check git)*
- Safety card: tappable → opens `/family-map`, location toggle *(reverted — check git)*
- Bottom nav: 4 tabs — Home, Dashboard, AI Chat, Settings *(reverted — check git)*

> ⚠️ The home page wallet/calendar/safety/bottom-nav redesign was reverted by the user (`git restore`). The committed state is the version before those changes. The login/signup and splash screen changes ARE committed.

### Planning AI chat (`pages/planning_chat_screen.dart`)
- 3-dot bounce typing indicator animation (SingleTickerProviderStateMixin)
- Suggestion chips on empty state
- Bilingual, clear history button

### Splash screen (`pages/splash_screen.dart`)
- Logo above text (fixed order)
- Scale + fade logo animation (elasticOut)
- 3-dot bounce loading animation

---

## 18. Module Overview — What Each Module Does

---

### Authentication & Family Management

**Purpose:** Multi-family, multi-member JWT authentication. One email can belong to multiple families. Every family has one parent (the creator) and any number of children/members.

**Sign-up flow:**
1. Parent calls `POST /api/auth/signup` → creates `FamilyAccount` + the parent `Member` in one step
2. Returns a JWT token immediately (auto-login)
3. Parent adds children via `POST /api/members` → creates `Member` linked to the same family

**Login flow:**
1. Flutter calls `GET /api/auth/families?mail=...` → returns a list of families this email belongs to
2. User picks a family + types password
3. Flutter calls `POST /api/auth/login` with `{ mail, password, family_id }` → returns JWT
4. JWT payload: `{ id: family_id, member_id }` — every request after this is family-scoped
5. First-time members (added by parent) get `isFirstLogin: true` → forced to set their own password

**JWT / middleware:**
- `protect` middleware reads the token, populates `req.familyAccount`, `req.memberId`, `req.member`
- `restrictTo('Parent')` checks `req.member.member_type_id.type === 'Parent'`
- All data queries include `family_id: req.familyAccount._id` — nothing leaks between families

---

### Tasks & Rewards System

**Purpose:** Gamify family chores — parents create task templates, assign them to children, children complete them, parents approve, points are awarded. Children can spend points via the Redeem module.

**Full flow:**
```
Parent creates Task template → assigns to Member (TaskDetails created, status='assigned')
→ Member completes task (status='completed')
→ Parent approves (status='approved') → PointWallet updated, PointHistory recorded
```

**Task templates** (`Task` model): define title, reward type (`'points'|'money'|'both'`), optional `money_reward`, category
**Task assignments** (`TaskDetails` / task_history model): per-assignment record with `assigned_points`, `deadline`, `status`
**Points flow**: On approval → `PointWallet.total_points += assigned_points` + `PointHistory` record with `reason_type: 'task_completion'`
**Penalties**: Parent can call `POST /tasks/assignments/:id/penalty` → deducts from `PointWallet`, creates negative `PointHistory`

**Key rules:**
- `TaskDetails` has NO `family_id` — to filter by family, join with `Task.family_id`
- Points are in `TaskDetails.assigned_points`, NOT in the `Task` model
- `Task.reward_type` determines what's awarded; `money_reward` is on `Task` but money transfer is separate

---

### Points Wallet & Conversion

**Purpose:** Each member has a `PointWallet` (points) and a `MemberWallet` (money). Points can be earned from tasks and converted to money; money can be converted to points.

**Conversion rates** (`ConversionRate` model): Family sets their own rates. Default: 10 EGP = 100 pts, 1 pt = 0.05 EGP.
Only one active rate per family at a time — new rate deactivates the old one.

**Conversion APIs** (in BudgetRoutes):
- `POST /api/budget/wallet/convert-to-points` — deducts from `MemberWallet.balance`, credits `PointWallet.total_points`
- `POST /api/budget/wallet/convert-from-points` — deducts from `PointWallet`, credits `MemberWallet.balance`

**Leaderboard:** `GET /api/point-wallet/ranking` — ranks all family members by `total_points` descending.

**Audit trail:** Every wallet change writes a `BalanceWalletDetail` record via the `recordBalanceWalletDetail()` helper.

---

### Wishlist & Redeem System

**Purpose:** Children add items to their wishlist (toys, games, clothes, etc.). Points they earn from tasks can be redeemed to fund wishlist items. Parents approve redemptions.

**Full flow:**
```
Child adds WishlistItem to their wishlist
→ Child submits redemption: POST /api/redeem/request (selects wishlist item, uses points)
→ Parent sees pending: GET /api/redeem/pending
→ Parent approves: PATCH /api/redeem/:id/approve → deducts points, marks item as funded
→ Child accepts: PATCH /api/redeem/:id/accept (confirms they received it)
```

**Alternative redemption paths:**
- `POST /api/redeem/with-money` — pay with money wallet instead of points
- `POST /api/redeem/event-spot` — redeem points for a future family event spot

**Redeem status lifecycle:** `pending → approved → accepted` OR `pending → rejected` OR `cancelled`

**WishlistItem** can be linked to a `FutureEvent` via `linked_event_id` — events can auto-create reward items that children work towards.

---

### Budget Module

**Purpose:** Family financial planning. Parent sets a monthly/weekly/yearly budget with category allocations and per-child allowances. All spending is tracked. Children can request shared expenses; parents approve.

**Core data model:**
```
PeriodBudget (e.g. "May 2026 Budget", 5500 EGP)
 ├── BudgetAllocation × N categories (Groceries 2000, Utilities 1000, ...)
 ├── MemberAllowance × N children (Ahmed 300, Ziad 250, ...)
 │    └── Auto-deposits to MemberWallet.balance when set
 └── Expense × M transactions (shared or personal)
```

**Expense types:**
- `expense_scope: 'shared'` — deducted from `PeriodBudget.spent_amount` + `BudgetAllocation.spent_amount`
- `expense_scope: 'personal'` — deducted from `MemberWallet.balance` + tracked in `MemberAllowance.spent_amount`
- `request_status: 'pending'` — child-submitted request, not deducted until parent approves

**Emergency fund:** Each `PeriodBudget` has `emergency_fund_percentage` (default 10%). The emergency fund amount is a virtual computed field: `total_amount × emergency_fund_percentage / 100`. Tracked separately in `emergency_fund_spent`.

**Future Events / Savings Goals** (`FutureEvent` model): Family plans for upcoming big expenses (trips, shopping). Members can contribute money or points. Three funding sources: `'budget'`, `'member_contributions'`, `'points_redeem'`.

**Analytics:** `GET /api/budget/analytics?period_budget_id=...` returns detailed spending breakdown by category, timeline, and member.

**Children see:** Only their own `MemberWallet` balance and personal expenses. Cannot see `PeriodBudget` or family allocations (by design).

**Flutter:** `FamilyBudgetProvider` (`pages/budget/budget_provider.dart`) manages all budget state using `ChangeNotifier`. Budget screens live in `pages/budget/`.

---

### Inventory Module

**Purpose:** Track what the family has at home (food, cleaning supplies, electronics, etc.). Get alerts when items drop below threshold or near expiry.

**Structure:**
```
Inventory (a "container", e.g. "Fridge", "Pantry") — type: Food|Electronics|Cleaning|Personal Care|Other
 └── InventoryItem × N (eggs, milk, rice, ...)
      └── has: quantity, unit_id, item_category, threshold_quantity, expiry_date
```

**Alerts:** Items below `threshold_quantity` OR expiring within 3 days trigger alerts. Call `POST /api/inventory-alerts/generate` to re-scan. Alerts persist until marked read or deleted.

**Key gotchas:**
- `InventoryItem` has NO `family_id` — to query by family, find `Inventory._ids` first, then query items
- `InventoryCategory` field is `title` NOT `name`
- Two category systems: `InventoryCategory` (for items) and the old `ItemCategory` model (deprecated, use InventoryCategory)

---

### Food Hub Module

**Purpose:** Full kitchen management — recipes with ingredients and steps, meal logging, leftover tracking, AI-powered meal suggestions, and grocery list generation.

**Sub-modules:**

**Recipes** (`/api/recipes`):
- Full CRUD with `RecipeIngredient[]` and `RecipeStep[]` sub-documents
- `GET /:recipeId/scaled?servings=N` — scales ingredient quantities proportionally
- Recipe categories: `Breakfast|Lunch|Dinner|Dessert|Snack|Appetizer|Main Course|Side Dish|Beverage|Other`

**Meals** (`/api/meals`):
- Log what the family ate (`meal_date`, `meal_type`, optional `recipe_id`)
- `POST /:mealId/prepare` — "prepare from recipe" automatically deducts ingredients from `InventoryItem`
- `MealItem` sub-documents track individual food items in a meal

**Leftovers** (`/api/leftovers`):
- Track food leftovers with expiry dates
- `GET /expiring` — alerts for leftovers expiring within 2 days
- Has its own `LeftoverCategory` system for organization

**Meal Suggestions** (`/api/meal-suggestions`):
- `POST /generate` — analyzes current `InventoryItem` stock + recent `Meal` history → suggests what to cook
- Avoids recently eaten meals
- Stores suggestions as `MealSuggestion` documents (score + reason)

**Grocery Lists** (`/api/grocery-lists`):
- Shareable grocery lists with checkable items
- Items can be checked off during shopping
- Each list has a title, `is_completed`, and `GroceryItem[]`

---
=
### Location Module

**Purpose:** Real-time family location tracking with privacy controls. Members can share their location with the family, request location permission from specific members, set geofence alerts, and share point-in-time location snapshots.

**Key concepts:**

**Live sharing:**
- `POST /api/location/update` — updates member's current lat/lng in `LocationShare`
- `PATCH /api/location/toggle` — turn sharing on/off
- `GET /api/location/family` — get all family members' current locations (only those with sharing ON)

**Permissions:**
- Member can request another member's location permission
- Target approves/denies via `PATCH /api/location/permissions/:id`
- Revocable at any time

**Location history:** Logged automatically on each update. Viewable and clearable.

**Geofence alerts** (`LocationAlert`): Create alerts for specific areas. When a family member enters/exits the zone, an alert fires.

**Snapshots** (`LocationShare`): Share a one-time location snapshot (like "I'm here right now") — receiver sees it, marks it viewed, then it can be deleted.

**Flutter screen:** `pages/family_map_screen.dart` — interactive map showing all family members' live pins.

---

### Receipts Module

**Purpose:** Digital receipt tracking. Members photograph or manually enter receipts to maintain a spending record separate from the budget system.

**Receipt model:** `title`, `total_amount`, `receipt_date`, `store_name`, `category`, `items[]` (array of `{ name, price, quantity }`), optional `image_url`.
**`GET /api/receipts/summary`** — returns total spending grouped by category and time period.
Receipts are family-scoped and visible to all members.

---

### Planning AI Module

**Purpose:** A Gemini-powered family assistant that answers questions about family data in natural language — budget trends, best-performing child, meal suggestions, event savings progress, etc.

**How it works:**
1. User sends a message via `POST /api/planning/chat`
2. Backend calls `gatherFamilyContext(familyId)` — runs 2 parallel DB query batches pulling ALL family data: members, expenses, budgets, tasks, points, inventory, recipes, meals, leftovers, future events
3. `buildSystemPrompt(ctx, familyTitle)` — injects all that data as labelled text sections into the Gemini system prompt
4. Last 10 conversation messages are sent as Gemini `history` (chat mode, not single-turn)
5. Gemini `gemini-2.5-flash-lite` generates a response using the injected real data
6. Both the user message and AI response are saved to `PlanningConversation` in MongoDB

**What it can answer:**
- "What was our average budget for the last 3 months?"
- "Who was the best child in the past 2 weeks?" (ranks by points earned)
- "Suggest meals for today based on what we have" (uses inventory + leftover data)
- "Which category did we overspend on?" (compares expenses vs allocations)
- "How much have we saved for the summer trip?"

**Bilingual:** Responds in the same language the user writes in (Arabic or English).

**Files:**
- Controller: `backend/controllers/PlanningAIController.js`
- Model: `backend/models/planningConversationModel.js`
- Routes: `backend/routes/planningRoutes.js`
- Flutter screen: `flutter_app/lib/pages/planning_chat_screen.dart`
- Flutter API methods: `sendPlanningMessage()`, `getPlanningHistory()`, `clearPlanningHistory()` in `api_service.dart`

**Gemini model:** `gemini-2.5-flash-lite` — only this works on the free-tier key. See §12 for the API key.

---

## 17. Budget Test Data (habiba1278@gmail.com)

**Full budget seed script:** `backend/scripts/seed-budget-test-data.js`
Run: `node backend/scripts/seed-budget-test-data.js`
⚠️ This script **clears** all existing budget/wallet/expense data for the family before seeding.

**What it seeds:**
- Conversion rate: 10 EGP = 100 pts
- March 2026 budget (4,620/5,000 spent) + 10 expenses
- April 2026 budget (5,380/5,000 OVERSPENT, emergency used) + 10 expenses
- **Active:** May 2026 budget (5,500 EGP, 10% emergency = 550 EGP)
  - 6 allocations: Groceries 2000, Utilities 1000, Education 500, Entertainment 800, Transport 400, Healthcare 250
  - 3 child allowances: Ahmed 300, Ziad 250, Noor 200 (auto-deposited to wallets)
  - 9 shared expenses already recorded (3,190 EGP spent)
  - 6 personal expenses from children
- **Expense requests:** PENDING (Ahmed, textbook 120), APPROVED (Ziad, ticket 85), REJECTED (Noor, sneakers 450)
- **Wallets:** Ahmed 185, Ziad 170, Noor 165, Habiba 1200 EGP
