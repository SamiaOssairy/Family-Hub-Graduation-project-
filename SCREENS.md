# Family Hub — Flutter Screens Reference

> Complete description of every screen in the Flutter app.  
> Stack: Flutter · Dart · Google Fonts (Poppins) · Teal Aqua theme (`AppColors`)  
> Backend: Node/Express on `http://localhost:8000/api`  
> Auth: JWT stored in `SharedPreferences` · Bilingual: English / Arabic (`AppI18n`)

---

## Table of Contents

1. [Authentication & Onboarding](#1-authentication--onboarding)
   - [Splash Screen](#11-splash-screen)
   - [Onboarding Screen](#12-onboarding-screen)
   - [Login / Sign-up Screen](#13-login--sign-up-screen)
   - [Manage Accounts Page](#14-manage-accounts-page)
2. [Home & Dashboard](#2-home--dashboard)
   - [Home Screen](#21-home-screen)
   - [Dashboard Screen](#22-dashboard-screen)
3. [Settings](#3-settings)
   - [Settings Screen](#31-settings-screen)
4. [Tasks & Rewards](#4-tasks--rewards)
   - [Tasks Screen](#41-tasks-screen)
   - [Task Management Screen](#42-task-management-screen)
   - [Create Task Screen](#43-create-task-screen)
   - [Status Screen](#44-status-screen)
   - [Rewards Screen](#45-rewards-screen)
   - [Redeem Screen](#46-redeem-screen)
   - [Family Points Screen](#47-family-points-screen)
5. [Food Hub](#5-food-hub)
   - [Food Hub Screen](#51-food-hub-screen)
   - [Inventory Screen](#52-inventory-screen)
   - [Inventory Categories Screen](#53-inventory-categories-screen)
   - [Inventory Alerts Screen](#54-inventory-alerts-screen)
   - [Meals Screen](#55-meals-screen)
   - [Meal Suggestions Screen](#56-meal-suggestions-screen)
   - [Recipes Screen](#57-recipes-screen)
   - [Recipe Detail Screen](#58-recipe-detail-screen)
   - [Leftovers Screen](#59-leftovers-screen)
   - [Receipts Screen](#510-receipts-screen)
   - [Groceries Screen](#511-groceries-screen)
   - [Grocery List Detail Screen](#512-grocery-list-detail-screen)
6. [Budget & Finance](#6-budget--finance)
   - [Budget Dashboard Screen](#61-budget-dashboard-screen)
   - [Add Expense Screen](#62-add-expense-screen)
   - [Budget Analytics Screen](#63-budget-analytics-screen)
   - [Future Events Screen](#64-future-events-screen)
   - [Event Funding Screen](#65-event-funding-screen)
7. [Wallet & Analytics](#7-wallet--analytics)
   - [Combined Wallet Screen](#71-combined-wallet-screen)
   - [Balance Wallet Details Screen](#72-balance-wallet-details-screen)
   - [Combined Analytics Screen](#73-combined-analytics-screen)
8. [Location & Map](#8-location--map)
   - [Family Map Screen](#81-family-map-screen)
9. [Planning AI](#9-planning-ai)
   - [Planning Chat Screen](#91-planning-chat-screen)

---

## 1. Authentication & Onboarding

### 1.1 Splash Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/splash_screen.dart` |
| **Route** | `/splash` |
| **Access** | All (unauthenticated) |

**Purpose:** First screen shown on app launch. Checks for a stored JWT token and routes the user to the correct destination automatically.

**UI Sections:**
- Animated family logo (scale + fade-in with `elasticOut` curve)
- "Family Hub" branding text and tagline
- Three bouncing dots loading indicator (animated in sequence)

**Logic:**
- Reads `token` from `SharedPreferences`
- If token found → navigates to `/home`
- If no token → navigates to `/onboarding`
- No API calls; purely local check

**Key State:** `_logoController`, `_dotsController`, `_logoScale`, `_logoOpacity`, `_dotAnimations`

---

### 1.2 Onboarding Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/onboarding_screen.dart` |
| **Route** | `/onboarding` |
| **Access** | New users (before signup) |

**Purpose:** Four-page carousel that introduces the app's key features to first-time users.

**UI Sections:**
- `PageView` carousel with 4 feature pages (icon + title + description per page)
- Animated dot indicators (active dot expands in width)
- "Next" / "Get Started" button (changes label on last page)
- "Skip" text button (top-right corner)

**Logic:**
- No API calls
- "Skip" and "Get Started" both push `/login`

**Key State:** `_controller` (PageController), `_currentIndex`, `_pages` list

---

### 1.3 Login / Sign-up Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/signup_login.dart` |
| **Routes** | `/login` → `LoginPage` · `/signup` → `SignUpPage` |
| **Access** | Public |

**Purpose:** Combined authentication screen with three sub-flows: email entry with saved-profile chips, family password login, and parent registration.

**UI Sections — LoginPage:**
- Email text field (green filled, rounded)
- Saved profile chips (loaded from `SharedPreferences`)
- "Continue" button → loads families for that email
- Family selector dropdown + password field (after email step)
- "Forgot password?" link
- "Create a new account" link → `/signup`
- Account switcher bottom sheet (manage saved profiles)

**UI Sections — SignUpPage:**
- Email, username, family name, birth date fields
- Password + confirm password fields
- "Create Account" button
- Redirects to `/login` after success

**UI Sections — FamilyPasswordLoginPage:**
- Shows family list as dropdown
- Password entry
- Login button

**API Calls:**
| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/auth/login` | Authenticate and receive JWT |
| `POST` | `/auth/signup` | Create new family + parent member |
| `GET` | `/auth/families?mail=...` | Fetch families for an email |
| `POST` | `/auth/setPassword` | Set password on first login |
| Local | `SharedPreferences` | Read/write saved profiles |

**Navigation:** → `/home` (after login) · → `/signup` · ← back

**Key State:** `_emailController`, `_passwordController`, `_isLoading`, `_savedProfiles`, `_selectedFamilyId`, `_obscurePassword`, `_isFirstLogin`

---

### 1.4 Manage Accounts Page

| Property | Detail |
|---|---|
| **File** | `lib/pages/manage_accounts_page.dart` |
| **Access** | All authenticated users |

**Purpose:** Reorderable list of all locally saved profiles, allowing the user to switch accounts, reorder them, or remove them.

**UI Sections:**
- `ReorderableListView` with profile cards
- Each card: avatar initial circle, family name + username, email
- Switch account icon button on each card
- Remove account icon button (with confirmation dialog)
- Drag handle for reordering

**API Calls:** `getSavedProfiles()`, `getActiveProfileKey()`, `switchProfile()`, `removeSavedProfile()`, `reorderSavedProfiles()`

**Navigation:** Pops with `true` if any change was made (caller refreshes data).

**Key State:** `_profiles`, `_activeProfileKey`, `_loading`, `_changed`

---

## 2. Home & Dashboard

### 2.1 Home Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/home.dart` |
| **Route** | `/home` |
| **Access** | All authenticated members |

**Purpose:** Main hub of the app. Shows the family's overview: members, wallet balances, recent tasks, upcoming events, and the points leaderboard — all live from the backend.

**UI Sections:**
| Section | Description |
|---|---|
| **Header** | Teal gradient family circle (taps to open account switcher) · Family title + welcome message · Active profile badge · Logout icon button (opens current/all logout dialog) |
| **Family Members** | Compact avatar wrap — emoji per member, online dot, colour-coded ring. Tap → options dialog (view / remove). "Add Member" text button below |
| **Stat Cards** | 2-column: Money Balance (EGP) · Points Balance (pts) — both from wallet API |
| **Today's Tasks** | Up to 3 most recent assigned tasks with coloured status dots (pending/active/done/late) and status badges. Taps → `/task-management` |
| **AI Card** | Teal-to-cyan gradient banner → `/planning-chat` |
| **Upcoming Events** | Up to 3 future events with progress bars (saved/estimated EGP). Taps → `/event-funding` |
| **Points Leaderboard** | Top 3 family members with medal emojis (🥇🥈🥉) and real point counts. "Full ranking" → `/family-points` |
| **Bottom Nav** | Home · Dashboard · AI Chat · Location · Settings |

**API Calls:**
| Call | Data |
|---|---|
| `getAllMembers()` | Family member list with avatars |
| `getCombinedBalance()` | Money + points balances |
| `getAllAssignedTasks()` | Recent tasks for teaser section |
| `getFutureEvents()` | Upcoming events for progress cards |
| `getPointsRanking()` | Points leaderboard top 3 |
| `createMember()` / `deleteMember()` | Add/remove members via dialogs |
| `getAllMemberTypes()` | Dropdown for add-member dialog |
| `logout()` / `logoutAllProfiles()` | Sign out flows |
| `switchProfile()` | Multi-account switching |

**Navigation:** `/dashboard`, `/planning-chat`, `/family-map`, `/settings`, `/task-management`, `/event-funding`, `/family-points`

**Key State:** `_familyMembers`, `_walletSummary`, `_recentTasks`, `_futureEvents`, `_pointsRanking`, `_activeTab`, `_loading`, `_walletLoading`, `_tasksLoading`, `_eventsLoading`, `_rankingLoading`, `_userName`, `_familyTitle`, `_savedProfiles`, `_hasActiveProfile`

---

### 2.2 Dashboard Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/dashboard_screen.dart` |
| **Route** | `/dashboard` |
| **Access** | All authenticated members |

**Purpose:** Module hub — a grid of shortcuts to all app modules, plus local announcements and family events management.

**UI Sections:**
| Section | Description |
|---|---|
| **Header** | Teal gradient circle · "Family Dashboard" title · Notification bell button |
| **Categories grid** | 2-column grid — 12 module cards (Tasks, Rewards, Status, Points, Food Hub, Inventory, Recipes, Meals, Leftovers, Receipts, Groceries, Categories). Each card: coloured icon background + module name |
| **Edit Mode toggle** | Animated teal toggle (top-right of Categories). When on, shows drag handle on each module card |
| **Red badges** | Optional `badge` param on cards for pending-count indicator |
| **Announcements** | Local list. "+" button opens dialog (title + content). Cards with teal icon. Empty state message |
| **Family Events** | Horizontal scroll of event cards (image overlay with teal-tinted darken). "+" button adds event via dialog |
| **Bottom Nav** | Home · Dashboard · AI Chat · Location · Settings (matches home.dart) |

**API Calls:** None (all data is local `List` state for announcements and events)

**Navigation (modules):** `/tasks`, `/rewards`, `/status`, `/family-points`, `/food-hub`, `/inventory`, `/recipes`, `/meals`, `/leftovers`, `/receipts`, `/groceries`, `/inventory-categories`

**Key State:** `_editMode`, `_activeTab`, `_announcements` (local), `_events` (local), text controllers for dialogs

---

## 3. Settings

### 3.1 Settings Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/setting.dart` |
| **Route** | `/settings` |
| **Access** | All authenticated members |

**Purpose:** Personal account settings, preferences, and family management options.

**UI Sections:**
| Section | Rows |
|---|---|
| **Profile header** | Family title, edit profile link |
| **My Account** | Personal info · Family members · Change password · Switch profile · Privacy & security · Deactivate account |
| **Preferences** | Notifications toggle · Language selector (EN/AR) · Dark mode toggle · Location sharing toggle |
| **Support** | Help center · Contact us · About |
| **Logout** | Button showing current/all logout dialog |

**API Calls:** `getSavedProfiles()`, `switchProfile()`, `removeSavedProfile()`, `toggleLocationSharing()`, `setPassword()`, `deactivateAccount()`, `logout()`, `logoutAllProfiles()`

**Key State:** `_darkMode`, `_locationSharing`, `_familyTitle`, `_savedProfiles`, `_activeProfileKey`, `_languageCode`, `_isUpdatingLocationSharing`

---

## 4. Tasks & Rewards

### 4.1 Tasks Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/tasks_screen.dart` |
| **Route** | `/tasks` |
| **Access** | Any member (views own tasks) |

**Purpose:** Lets a member view and interact with their personally assigned tasks.

**UI Sections:**
- Tab bar: **Mandatory** / **Available** tasks
- Task count badge per tab
- Task cards: title, description, reward emoji + amount, progress bar, completion checkbox
- Delete mode toggle (header icons)
- Empty state illustration

**API Calls:** `getMyTasks()` — fetches member's own task assignments

**Key State:** `_tabController`, `_isDeleteMode`, `_isLoading`, `_mandatoryTasks`, `_availableTasks`

---

### 4.2 Task Management Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/task_management_screen.dart` |
| **Route** | `/task-management` |
| **Access** | Parent (full); Members (limited) |

**Purpose:** Comprehensive task administration. Parents can assign tasks, approve completions, and apply penalties. Members view their own task pipeline.

**UI Sections (Parent):**
- Tabs: My Tasks · Assign Task · Templates · Approvals · History
- **My Tasks** sub-tabs: Pending Approval · Active · Waiting Completion · Completed · Rejected
- Stat summary cards (Pending / Active / Done counts)
- Task detail cards: status badge, deadline, priority, penalty/notes
- Assign tab: member picker, points/money reward, deadline date picker
- Templates tab: reusable task templates list
- Approvals tab: pending completion approvals list
- History tab: all assigned tasks

**UI Sections (Member):**
- Only "My Tasks" tab visible
- Task cards with complete button

**API Calls:** `getAllTasks()`, `getAllTaskCategories()`, `getAllMembers()`, `getAllAssignedTasks()`, `getMyTasks()`, `getPendingAssignments()`, `getTasksWaitingApproval()`, `completeTask()`, `approveTaskCompletion()`, `isParent()`

**Navigation:** → `/create-task` (from assign tab)

**Key State:** `_isParent`, `_tabController`, `_taskTemplates`, `_categories`, `_members`, `_myTasks`, `_pendingAssignments`, `_tasksWaitingApproval`, `_isLoading`

---

### 4.3 Create Task Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/create_task_screen.dart` |
| **Access** | Parent only |

**Purpose:** Form for creating reusable task templates with reward budget validation.

**UI Sections:**
- Title and description text fields
- Category dropdown
- Mandatory task checkbox
- Reward type segmented button: **Points** / **Money** / **Both**
- Points input (star icon, number field)
- Money input (EGP, with conversion display showing equivalent points)
- Budget remaining indicator with warning container
- Total value display (when "Both" selected)
- "Create Task" button with loading state

**API Calls:** `getCombinedBalance()` (for conversion rates), `getTaskRewardsBudgetStatus()` (budget remaining), `createTask()` (with `force_create` flag for budget-overrun warnings)

**Navigation:** Pops with `true` on success

**Key State:** `_titleController`, `_descriptionController`, `_selectedCategoryId`, `_rewardType`, `_isMandatory`, `_pointsAmount`, `_moneyAmount`, `_moneyToPointsRate`, `_rewardsBudgetRemaining`, `_isSubmitting`

---

### 4.4 Status Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/status_screen.dart` |
| **Route** | `/status` |
| **Access** | Parent (all); Members (own tasks) |

**Purpose:** Family-wide task completion status overview with activity history.

**UI Sections:**
- Summary cards: Completed · In Progress · Pending counts
- Activity History list with member name, task title, status badge, points earned, date

**API Calls:** `getAllAssignedTasks()` — used to compute all status counts

**Key State:** `_isLoading`, `_taskHistory`, `_completedCount`, `_inProgressCount`, `_pendingCount`

---

### 4.5 Rewards Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/rewards_screen.dart` |
| **Route** | `/rewards` |
| **Access** | All members |

**Purpose:** Personal rewards hub — points balance, earning history, wishlist items, and family leaderboard.

**UI Sections:**
- Points balance gradient card with "Redeem" button
- Stat chips: Earned this week · Redeemed total
- Wishlist rewards cards (items available to redeem)
- Family leaderboard (medal icons for top 3)
- Points history — last 10 transactions

**API Calls:** `getMyWallet()`, `getMyPointHistory()`, `getPointsRanking()`, `getMyWishlistItems()`, `getCombinedBalance()` (for `points_to_money_rate`)

**Navigation:** → `/redeem`

**Key State:** `_totalPoints`, `_rewardsHistory`, `_wishlistItems`, `_familyRanking`, `_earnedThisWeek`, `_redeemedTotal`, `_pointsToMoneyRate`, `_isLoading`

---

### 4.6 Redeem Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/redeem_screen.dart` |
| **Route** | `/redeem` |
| **Access** | Parent (approval view); Members (redemption view) |

**Purpose:** Two-sided redemption screen — children request to redeem wishlist items, parents approve or reject.

**UI Sections — Child view:**
- Points + money balance card at top
- Wishlist items with "Redeem" buttons
- Payment method modal: **Points only** / **Money only** / **Split**
- Split slider for mixed payments
- Calculation breakdown: points used, money used, remaining balances
- Confirmation button

**UI Sections — Parent view:**
- Pending redemptions list
- Approve / reject buttons per request (with optional rejection reason dialog)
- Budget warning if overspending

**API Calls:** `isParent()`, `getMyWallet()`, `getCombinedBalance()`, `getPendingRedemptions()`, `getMyWishlistItems()`, `requestRedemption()`, `requestRedemptionWithMoney()`, `parentApproveRedemption()`

**Key State:** `_isParent`, `_userPoints`, `_moneyBalance`, `_pointsToMoneyRate`, `_wishlistItems`, `_pendingRedemptions`, `_prefillItemId`, `_isLoading`

---

### 4.7 Family Points Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/family_points_screen.dart` |
| **Route** | `/family-points` |
| **Access** | All members (view-only) |

**Purpose:** Family-wide points leaderboard with medals for top 3 positions.

**UI Sections:**
- Gradient header card ("Family Leaderboard" title + member count)
- Ranked list: medal emoji (🥇🥈🥉 for top 3), avatar, username, member type, email, points (gradient badge)
- Pull-to-refresh

**API Calls:** `getPointsRanking()`

**Key State:** `_isLoading`, `_familyMembers` (ranking list), `_errorMessage`

---

## 5. Food Hub

### 5.1 Food Hub Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/food_hub_screen.dart` |
| **Route** | `/food-hub` |
| **Access** | All members |

**Purpose:** Food management dashboard — an overview/entry point to inventory, recipes, and leftovers sub-modules.

**UI Sections:**
- Header: "Family Kitchen" title, alerts bell with unread badge
- Stat cards row: Inventory (total items + low-stock badge) · Recipes count · Leftovers (total + expiring badge)
- Quick action buttons: View Inventory · Browse Recipes · Track Leftovers · View Alerts
- Expiring leftovers preview list (up to 4 items)

**API Calls:** `getAllFamilyItems()`, `getAllRecipes()`, `getAllLeftovers()`, `getExpiringLeftovers()`, `getUnreadAlertCount()`

**Navigation:** → `/inventory`, `/recipes`, `/leftovers`, `/inventory-alerts`

**Key State:** `_loading`, `_totalItems`, `_lowStockCount`, `_totalRecipes`, `_totalLeftovers`, `_expiringLeftovers`, `_unreadAlerts`

---

### 5.2 Inventory Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_screen.dart` |
| **Route** | `/inventory` |
| **Access** | All members |

**Purpose:** Full inventory management — multiple inventories, category filtering, search, and CRUD for items.

**UI Sections:**
- Inventory selector dropdown (e.g. Fridge, Pantry)
- Category filter chips
- Search bar
- Items grouped by category — each card: name, quantity + unit, category colour tag, expiry date (colour-coded: green/yellow/red)
- Edit and delete buttons per item
- Add Item FAB

**API Calls:** `getAllInventories()`, `getInventoryItems()`, `createInventoryItem()`, `updateInventoryItem()`, `deleteInventoryItem()`, `getInventoryBudgetSummary()`

**Key State:** `_selectedInventoryId`, `_selectedCategory`, `_searchQuery`, `_inventories`, `_items`, `_isLoading`

---

### 5.3 Inventory Categories Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_categories_screen.dart` |
| **Route** | `/inventory-categories` |
| **Access** | All members (parent for create/delete) |

**Purpose:** Hierarchical tree view for managing nested inventory categories.

**UI Sections:**
- Search bar (auto-expands matching nodes)
- Expandable tree view with parent → child hierarchy
- Each node: category name, item count, expand/collapse icon
- Add / edit / delete actions

**API Calls:** `getAllInventoryCategories()`, `createInventoryCategory()`, `updateInventoryCategory()`, `deleteInventoryCategory()`

**Key State:** `_categories`, `_expandedNodes`, `_searchQuery`, `_isLoading`

---

### 5.4 Inventory Alerts Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_alerts_screen.dart` |
| **Route** | `/inventory-alerts` |
| **Access** | All members |

**Purpose:** Alert management for low stock, out of stock, expiring, and expired inventory items.

**UI Sections:**
- Alert-type filter chips: All · Low Stock · Out of Stock · Expiring Soon · Expired
- Alert cards: type badge (colour-coded), item name, inventory name, current qty vs threshold, expiry date, dismiss button, action button ("Restock")
- Empty state
- FAB to trigger a fresh inventory scan

**API Calls:** `getInventoryAlertsPersisted()`, `markAlertAsRead()`, `markAllAlertsAsRead()`, `deleteAlert()`, `generateInventoryAlerts()`

**Key State:** `_selectedAlertType`, `_alerts`, `_isLoading`

---

### 5.5 Meals Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/meals_screen.dart` |
| **Route** | `/meals` |
| **Access** | All members |

**Purpose:** Daily meal planner with date navigation and meal-type grouping.

**UI Sections:**
- Date selector with previous/next day arrows
- Meals grouped by type: Breakfast · Lunch · Dinner · Snack
- Meal cards: name, portion, recipe link, ingredient list with availability, "Mark Prepared" button
- Add Meal FAB
- Empty state for days with no meals

**API Calls:** `getMeals(date)`, `createMeal()`, `updateMeal()`, `deleteMeal()`, `prepareMealFromRecipe()`

**Key State:** `_selectedDate`, `_meals`, `_mealsByType` (grouped map), `_isLoading`

---

### 5.6 Meal Suggestions Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/meal_suggestions_screen.dart` |
| **Route** | `/meal-suggestions` |
| **Access** | All members |

**Purpose:** AI-generated meal suggestions based on the family's current inventory stock.

**UI Sections:**
- Meal-type and cuisine filters
- Suggestion cards: meal name + image, match-% badge, ingredient availability (available / missing), "Plan This Meal" button
- Empty state when no matches

**API Calls:** `getMealSuggestions()`, `generateMealSuggestions()`, `clearMealSuggestions()`

**Key State:** `_suggestions`, `_selectedMealType`, `_isLoading`

---

### 5.7 Recipes Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/recipes_screen.dart` |
| **Route** | `/recipes` |
| **Access** | All members |

**Purpose:** Family recipe book with search, browse, and CRUD.

**UI Sections:**
- Search bar
- Recipe cards: name, image, servings, prep time, cook time, ingredient count, step count
- Edit / delete quick-action buttons
- Add Recipe FAB
- Empty state

**API Calls:** `getAllRecipes()`, `createRecipe()`, `deleteRecipe()`

**Navigation:** → `recipe_detail_screen` (view/edit a recipe)

**Key State:** `_recipes`, `_searchQuery`, `_filteredRecipes`, `_isLoading`

---

### 5.8 Recipe Detail Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/recipe_detail_screen.dart` |
| **Access** | All members (edit: authorized users) |

**Purpose:** Full recipe viewer and editor with dynamic serving scaler and inventory availability checks.

**UI Sections:**
- Recipe header image and title
- Servings selector with +/- buttons (scales all ingredient quantities)
- Ingredients list: name, scaled qty + unit, availability colour dot (in-stock / partial / unavailable)
- Steps list with numbered instructions (add/remove in edit mode)
- Save and Delete buttons (edit mode only)

**API Calls:** `getRecipe()`, `getRecipeScaled()`, `updateRecipe()`, `deleteRecipe()`, `addRecipeIngredient()`, `removeRecipeIngredient()`, `addRecipeStep()`, `removeRecipeStep()`

**Key State:** `_servings`, `_ingredients`, `_steps`, `_isLoading`

---

### 5.9 Leftovers Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/leftovers_screen.dart` |
| **Route** | `/leftovers` |
| **Access** | All members |

**Purpose:** Leftover food tracker with expiry monitoring and tab-based filtering.

**UI Sections:**
- Tabs: All · Expiring Soon · Expired
- Leftover cards: name, portion, expiry date + progress bar (time remaining), category tag, storage location, edit/delete buttons
- Swipe-to-dismiss for quick deletion
- Add Leftover FAB with date picker dialog

**API Calls:** `getAllLeftovers()`, `getExpiringLeftovers()`, `addLeftover()`, `updateLeftover()`, `deleteLeftover()`

**Key State:** `_leftovers`, `_selectedTab`, `_filteredLeftovers`, `_isLoading`

---

### 5.10 Receipts Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/receipts_screen.dart` |
| **Route** | `/receipts` |
| **Access** | All members |

**Purpose:** Digital receipt storage with image upload, line-item entry, and spending totals.

**UI Sections:**
- Receipt list cards: image thumbnail, date, vendor name, total amount, item count
- Receipt detail view: full image, line items (name / qty / unit / price), subtotal + tax + total
- Manual entry dialog: vendor name, line items, tax rate, photo upload
- Full-screen image viewer for receipt photos

**API Calls:** `getAllReceipts()`, `createReceipt()`, `getReceipt()`, `updateReceipt()`, `deleteReceipt()`, `getSpendingSummary()`

**Key State:** `_receipts`, `_selectedReceiptImage`, `_lineItems`, `_totalAmount`, `_isLoading`

---

### 5.11 Groceries Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/groceries_screen.dart` |
| **Route** | `/groceries` |
| **Access** | All members |

**Purpose:** Multi-list grocery manager showing progress across all shopping lists.

**UI Sections:**
- Search bar
- Grocery list cards: name, icon, checked/total progress indicator, percentage complete, view/edit/delete buttons
- Create Grocery List button
- Empty state

**API Calls:** `getAllGroceryLists()`, `createGroceryList()`, `deleteGroceryList()`

**Navigation:** → `/grocery-list-detail` (with `listId` and `title` arguments)

**Key State:** `_groceryLists`, `_searchQuery`, `_filteredLists`, `_isLoading`

---

### 5.12 Grocery List Detail Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/grocery_list_detail_screen.dart` |
| **Route** | `/grocery-list-detail` |
| **Access** | All members |

**Purpose:** Single grocery list with item toggling, inline addition, and section separation between pending and completed items.

**UI Sections:**
- Editable list title in app bar
- Quick-add input field at top
- **"To Buy"** section: items with checkboxes, qty + unit, swipe-to-delete
- **"Done"** section: checked items greyed out, swipe-to-delete
- Empty state when list is empty

**API Calls:** `getGroceryListById()`, `addGroceryItem()`, `updateGroceryItem()` (toggle/edit), `deleteGroceryItem()`, `updateGroceryList()` (rename)

**Arguments received:** `listId`, `title`

**Key State:** `_listId`, `_listTitle`, `_items`, `_newItemCtrl`, `_isLoading`

---

## 6. Budget & Finance

### 6.1 Budget Dashboard Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/budget_dashboard_screen.dart` |
| **Route** | `/budget` |
| **Access** | Parent |

**Purpose:** Main budget management hub — active period budgets, spending progress, emergency fund, future events, and member allowances.

**UI Sections:**
- AppBar with refresh and settings icons
- Budget cards: budget name, period, spent/remaining/total amounts, emergency fund indicator, category breakdown with colour-coded tiles, View / Edit / Delete quick actions
- Future Events section with event cards, target cost, and saved amount
- Create Budget FAB

**API Calls (via `FamilyBudgetProvider`):** `loadBudgets()`, `selectBudget()`, `deleteBudget()`, `loadFutureEvents()`

**Navigation:** → `CreateBudgetScreen` (FAB) · → `BudgetViewScreen` (view) · → `BudgetEditScreen` (edit)

**Key State:** Managed by `FamilyBudgetProvider` — `budgets`, `futureEvents`, `isLoading`

---

### 6.2 Add Expense Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/add_expense_screen.dart` |
| **Access** | All members |

**Purpose:** Form for recording a new expense — shared (family budget) or personal (allowance wallet).

**UI Sections:**
- Amount input with currency icon
- Scope toggle: **Shared** / **Personal** with radio buttons and descriptions
- Category dropdown (colour-coded)
- Date picker
- Description field (optional, 2-line max)
- Receipt photo upload with image preview
- Emergency fund toggle with remaining balance
- Save Expense button

**API Calls (via `FamilyBudgetProvider`):**
- `submitExpenseRequest()` — child submitting shared expense (requires parent approval)
- `createExpense()` — parent direct expense, or personal expense

**Role behaviour:** Children submitting shared expenses enter an approval workflow; parents can record directly.

**Key State:** `_amountCtrl`, `_descCtrl`, `_selectedCategoryId`, `_expenseScope`, `_expenseDate`, `_isEmergency`, `_isLoading`, `_receiptImage`, `_categories`

---

### 6.3 Budget Analytics Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/budget_analytics_screen.dart` |
| **Access** | Parent |

**Purpose:** Three-tab analytics view for a specific period budget — pie chart, daily trend, and transaction list.

**UI Sections:**
- **Pie Chart tab:** Summary cards (Total Spent / Remaining / Budget), over-budget warning banner, interactive pie chart with touch-sensitive sections, category breakdown list with spending percentages
- **Trend tab:** Line chart of daily spending over the budget period
- **Expenses tab:** Full transaction list with title, amount, category, member email, date

**API Calls (via `FamilyBudgetProvider`):** `loadAnalytics(budgetId)`

**Key State:** `_tabCtrl`, `_touchedIndex`, `analyticsData` (map)

---

### 6.4 Future Events Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/future_events_screen.dart` |
| **Route** | `/event-funding` (list) |
| **Access** | Parent (create/edit); All (view) |

**Purpose:** Plan and track family savings goals for future events (trips, shopping, parties).

**UI Sections:**
- Event cards: name, estimated cost, expected date, saved amount, reminder frequency slider (1–12 months), savings frequency selector, progress bar, edit/delete buttons
- Add Event FAB
- Empty state
- Calendar date picker in event dialog

**API Calls (via `FamilyBudgetProvider`):** `loadFutureEvents()`, `createFutureEvent()`, `updateFutureEvent()`, `deleteFutureEvent()`

**Key State:** `_events`, `_editingEventId`, `_eventName`, `_estimatedCost`, `_expectedDate`, `_savedAmount`, `_reminderFrequency`, `_isLoading`

---

### 6.5 Event Funding Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/event_funding_screen.dart` |
| **Access** | All members |

**Purpose:** Detailed funding tracker for a single future event — budget plan, member contributions, and points redemption.

**UI Sections:**
- **Budget tab:** Event name, target amount, saved amount, progress bar, savings plan
- **Contributions tab:** Per-member contribution list (promised / paid / status), Add Contribution button
- **Points tab:** Member points earned/redeemed for the event, "Redeem for Event Spot" button, redemption history

**API Calls:** `getEventFundingStatus()`, `contributeToEvent()`, `markEventContributionPaid()`, `redeemEventSpot()`, `adjustEventFundingGoal()`

**Key State:** `_tabCtrl`, event funding data, contributions list, points history, `_isLoading`

---

## 7. Wallet & Analytics

### 7.1 Combined Wallet Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/wallet/combined_wallet_screen.dart` |
| **Route** | `/combined-wallet` |
| **Access** | All members (parents can view any member) |

**Purpose:** Dual wallet interface — Money Wallet and Points Wallet side by side with conversion between them.

**UI Sections:**
- PageView carousel: **Money Wallet** page ↔ **Points Wallet** page
- **Money Wallet page:** Current EGP balance, "Convert to Points" button, recent transaction list
- **Points Wallet page:** Current points balance, "Convert to Money" button, points earning/redemption history, exchange rate display
- Member selector dropdown (parent only — to view other members)
- Conversion modal: amount to convert, calculated result, confirm button

**API Calls:** `getCombinedBalance()`, `getBalanceWalletDetails()`, `convertMoneyToPoints()`, `convertPointsToMoney()`, `getMyPointHistory()`, `getMemberPointHistory()`

**Key State:** `_pageCtrl`, `_moneyBalance`, `_pointsBalance`, `_conversionRate`, `_moneyTransactions`, `_pointsTransactions`, `_selectedMemberId`, `_isLoading`, `_isConverting`

---

### 7.2 Balance Wallet Details Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/wallet/balance_wallet_details_screen.dart` |
| **Route** | `/wallet-details` |
| **Access** | All members (own wallet) |

**Purpose:** Full audit trail of every wallet balance change — credits, debits, conversions, allowances, and budget withdrawals.

**UI Sections:**
- Member profile header (name, email) with gradient background
- Summary cards: Credits/Debits for **Money Wallet**, **Personal Budget**, **Shared Budget**
- Scope filter chips: All · Money · Personal · Shared
- Transaction cards: amount with +/- badge, title, timestamp, scope, source type (`allowance`/`expense`/`conversion`/etc.), description, author

**API Calls:** `getBalanceWalletDetails()` (with optional `scope` filter)

**Key State:** `_isLoading`, `_selectedScope`, `_member`, `_summary`, `_details`, `_filteredDetails`

---

### 7.3 Combined Analytics Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/analytics/combined_analytics_screen.dart` |
| **Route** | `/combined-analytics` |
| **Access** | Parent (full); Members (personal subset) |

**Purpose:** Comprehensive family spending and rewards analytics with multiple chart types and PDF export.

**UI Sections:**
- Overview cards: Total Budget Spent · Total Points Earned · Total Points Redeemed · Budget Health status
- **Pie chart:** Spending breakdown by category
- **Bar chart:** Points earned vs redeemed per family member
- **Line chart:** Spending trend over time
- Member summary cards: balance, earned/redeemed ratio, budget contribution
- Budget health indicator (colour-coded)
- PDF export button

**API Calls:** `getCombinedAnalytics()`, `getTaskRewardsSummary()`, `getBalanceWalletDetails()`

**Key State:** `_analyticsData`, `_memberAnalytics`, `_selectedTimeRange`, `_isLoading`, `_isPDFExporting`

---

## 8. Location & Map

### 8.1 Family Map Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/family_map_screen.dart` |
| **Route** | `/family-map` |
| **Access** | All members |

**Purpose:** Real-time family location tracking — live member pins on an interactive map with distance indicators, alert management, and location sharing controls.

**UI Sections:**
- **Flutter Map** occupying ~65% of screen with coloured member markers (circle avatar + name label)
- Offline/not-sharing members shown faded (opacity 0.5)
- FAB: "Sync location" button (teal gradient, centers map on current user)
- **Selected member sheet** (slides up on marker tap): location text, online status, last seen, directions button → Google Maps
- **Alerts sheet** (bell icon): unread location alert notifications with read/dismiss actions
- **Member list** at bottom: name, sharing status, location toggle, last-seen time
- Unread alert badge on notification bell
- Location sharing toggle in settings row

**API Calls:** `getMyLocation()` / `toggleLocationSharing()`, `updateMyLocation()` (GPS push), `getFamilyLocations()` (all members), `getUnreadAlertCount()`, `getMyAlerts()`, `markAllAlertsRead()`, `markAlertRead()`

**Navigation:** Opens Google Maps for directions (external); uses AppBottomNav (selectedIndex: 3)

**Key State:** `_familyLocations`, `_myPosition`, `_isSharingEnabled`, `_selectedMember`, `_unreadLocationAlerts`, `_lastLocationSyncAt`, `_isSyncingMyLocation`, `_myUsername`, `_isLoading`

---

## 9. Planning AI

### 9.1 Planning Chat Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/planning_chat_screen.dart` |
| **Route** | `/planning-chat` |
| **Access** | All members |

**Purpose:** Conversational AI assistant powered by Google Gemini. Answers natural-language questions about the family's budget, meals, tasks, points, and events — in English or Arabic.

**UI Sections:**
- **Chat list** with two bubble styles: user messages (teal right-aligned) and AI messages (white left-aligned)
- **Empty state** with 6 tappable suggestion chips (e.g. "Who earned the most points?", "Suggest a meal for tonight")
- **Typing indicator** — three bouncing dots animation while awaiting AI response
- **Input bar** at bottom: text field + send button
- **Clear history** option in action menu (top right)

**API Calls:** `getPlanningHistory()` (on init), `sendPlanningMessage()` (on send), `clearPlanningHistory()` (on clear)

**AI Backend:** Gemini `gemini-2.5-flash-lite` — system prompt injects full family context (members, expenses, tasks, inventory, meals, events, points) so answers are data-aware.

**Bilingual:** Responds in the same language as the user's input (Arabic or English).

**Key State:** `_messages`, `_loading` (waiting for AI), `_historyLoading`, `_inputCtrl`, `_scrollCtrl`, `_dotsController`, `_dotAnimations`

---

## Appendix

### Route Map (all named routes)

| Route | Screen File | Module |
|---|---|---|
| `/splash` | `splash_screen.dart` | Auth |
| `/onboarding` | `onboarding_screen.dart` | Auth |
| `/login` | `signup_login.dart` → LoginPage | Auth |
| `/signup` | `signup_login.dart` → SignUpPage | Auth |
| `/home` | `home.dart` | Home |
| `/dashboard` | `dashboard_screen.dart` | Home |
| `/settings` | `setting.dart` | Settings |
| `/tasks` | `tasks_screen.dart` | Tasks |
| `/task-management` | `task_management_screen.dart` | Tasks |
| `/status` | `status_screen.dart` | Tasks |
| `/rewards` | `rewards_screen.dart` | Rewards |
| `/redeem` | `redeem_screen.dart` | Rewards |
| `/family-points` | `family_points_screen.dart` | Rewards |
| `/food-hub` | `food_hub_screen.dart` | Food |
| `/inventory` | `inventory_screen.dart` | Food |
| `/inventory-categories` | `inventory_categories_screen.dart` | Food |
| `/inventory-alerts` | `inventory_alerts_screen.dart` | Food |
| `/meals` | `meals_screen.dart` | Food |
| `/meal-suggestions` | `meal_suggestions_screen.dart` | Food |
| `/recipes` | `recipes_screen.dart` | Food |
| `/leftovers` | `leftovers_screen.dart` | Food |
| `/receipts` | `receipts_screen.dart` | Food |
| `/groceries` | `groceries_screen.dart` | Food |
| `/grocery-list-detail` | `grocery_list_detail_screen.dart` | Food |
| `/budget` | `budget/budget_dashboard_screen.dart` | Budget |
| `/event-funding` | `budget/future_events_screen.dart` | Budget |
| `/combined-wallet` | `wallet/combined_wallet_screen.dart` | Wallet |
| `/wallet-details` | `wallet/balance_wallet_details_screen.dart` | Wallet |
| `/combined-analytics` | `analytics/combined_analytics_screen.dart` | Analytics |
| `/family-map` | `family_map_screen.dart` | Location |
| `/planning-chat` | `planning_chat_screen.dart` | AI |

### Access Level Summary

| Level | Who | Screens |
|---|---|---|
| **Public** | Unauthenticated | Splash, Onboarding, Login, Signup |
| **Any member** | All logged-in users | Home, Dashboard, Rewards, Tasks (own), Food Hub, Recipes, Meals, Leftovers, Inventory, Groceries, Receipts, Wallet, Map, Planning AI |
| **Parent only** | Member whose type = `Parent` | Task Management (full), Create Task, Budget Dashboard, Add Expense (shared), Budget Analytics, Future Events management |

### Theme Reference

| Token | Value | Used for |
|---|---|---|
| `AppColors.background` | `#E8F5F5` | Page backgrounds |
| `AppColors.primary` | `#00897B` | Buttons, active icons, key actions |
| `AppColors.primaryLight` | `#00ACC1` | Gradient highlights |
| `AppColors.primarySurface` | `#E0F2F1` | Icon backgrounds, active nav item |
| `AppColors.textPrimary` | `#00352E` | Headings and primary text |
| `AppColors.textSecondary` | `#4DB6AC` | Subtitles, labels, section headers |
| `AppColors.border` | `#B2DFDB` | Card borders |
| `AppColors.error` | `#E53935` | Notification badges, warnings |
