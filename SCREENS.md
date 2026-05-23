# Family Hub — Flutter Screens Reference

> Complete description of every screen in the Flutter app, including detailed backend flows, API payloads, and popup data requirements.
> Stack: Flutter · Dart · Google Fonts (Poppins) · Teal Aqua theme (`AppColors`)
> Backend: Node/Express on `http://localhost:8000/api`
> Auth: JWT stored in `SharedPreferences` · Bilingual: English / Arabic (`AppI18n`)
> JWT payload: `{ id: family_id, member_id }` — sent as `Authorization: Bearer <token>` on every protected call.

---

## Table of Contents

1. [Authentication & Onboarding](#1-authentication--onboarding)
2. [Home & Dashboard](#2-home--dashboard)
3. [Settings](#3-settings)
4. [Tasks & Rewards](#4-tasks--rewards)
5. [Food Hub](#5-food-hub)
6. [Budget & Finance](#6-budget--finance)
7. [Wallet & Analytics](#7-wallet--analytics)
8. [Location & Map](#8-location--map)
9. [Planning AI](#9-planning-ai)
10. [Appendix](#appendix)

---

## 1. Authentication & Onboarding

### 1.1 Splash Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/splash_screen.dart` |
| **Route** | `/splash` |
| **Access** | All (unauthenticated) |

**Purpose:** First screen shown on app launch. Checks for a stored JWT token and routes the user automatically.

**UI Sections:**
- Animated family logo (scale + fade-in, `elasticOut` curve)
- "Family Hub" branding text and tagline
- Three bouncing dots loading indicator

**Backend Flow:**

1. **On Load — no API call.** Reads `token` key from `SharedPreferences` only.
   - Token found → `Navigator.pushReplacementNamed('/home')`
   - No token → `Navigator.pushReplacementNamed('/onboarding')`
2. No network requests are made on this screen.

**Key State:** `_logoController`, `_dotsController`, `_logoScale`, `_logoOpacity`, `_dotAnimations`

---

### 1.2 Onboarding Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/onboarding_screen.dart` |
| **Route** | `/onboarding` |
| **Access** | New users |

**Purpose:** Four-page carousel introducing the app's features to first-time users.

**UI Sections:**
- `PageView` carousel with 4 feature slides (icon + title + description)
- Animated dot indicators (active dot expands)
- "Next" / "Get Started" button; "Skip" top-right

**Backend Flow:**

1. **No API calls on this screen.**
2. Both "Skip" and "Get Started" push `/login`.

**Key State:** `_controller` (PageController), `_currentIndex`

---

### 1.3 Login / Sign-up Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/signup_login.dart` |
| **Routes** | `/login` → `LoginPage` · `SignUpPage` embedded |
| **Access** | Public |

**Purpose:** Three-step auth flow: email entry → family selection → password login. Plus parent registration.

**UI Sections — LoginPage:**
- Email text field → "Continue" button
- Saved profile chips (from `SharedPreferences`)
- Family selector (dropdown) + password field (step 2)
- "Forgot password?" link
- "Create new account" link

**UI Sections — SignUpPage:**
- Email, username, family name, birth date fields
- Password + confirm password
- "Create Account" button

**Backend Flow — Login:**

| Step | Trigger | Endpoint | Payload | Response |
|---|---|---|---|---|
| 1 | Tap "Continue" on email | `GET /api/auth/families?mail={email}` | — | `{ families: [{ _id, Title, mail }] }` |
| 2 | Select family + enter password, tap "Login" | `POST /api/auth/login` | `{ mail, password, family_id }` | `{ token, member: { _id, username, member_type_id, isFirstLogin } }` |
| 3 | First login (child added by parent) | `POST /api/auth/setPassword` | `{ mail, family_id, new_password }` | `{ message: "Password set" }` |

After step 2:
- Token saved to `SharedPreferences['token']`
- `memberType` saved to `SharedPreferences['memberType']`
- Profile saved to `SharedPreferences['savedProfiles']`
- Navigate to `/home`

**Backend Flow — Sign-up:**

| Trigger | Endpoint | Payload | Response |
|---|---|---|---|
| Tap "Create Account" | `POST /api/auth/signup` | `{ mail, password, username, family_title, birth_date }` | `{ token, member: {...} }` |

After sign-up: token saved, navigate to `/login`.

**Forgot Password popup:**
- Input: member email
- `POST /api/auth/forgotPassword` → `{ mail }` → sends reset email
- Reset link calls `PATCH /api/auth/resetPassword/:token` → `{ new_password }`

**Key State:** `_emailController`, `_passwordController`, `_isLoading`, `_savedProfiles`, `_selectedFamilyId`, `_families`, `_obscurePassword`, `_isFirstLogin`

---

### 1.4 Manage Accounts Page

| Property | Detail |
|---|---|
| **File** | `lib/pages/manage_accounts_page.dart` |
| **Access** | All authenticated users |

**Purpose:** Reorderable list of locally saved profiles — switch, reorder, or remove accounts.

**UI Sections:**
- `ReorderableListView` with profile cards (avatar, family name, username, email)
- Switch account / remove buttons per card
- Drag handle for reordering

**Backend Flow:**

| Action | API / Local | Detail |
|---|---|---|
| Screen load | `SharedPreferences` | Reads `savedProfiles` JSON array and `activeProfileKey` |
| Switch account | `POST /api/auth/login` (re-auth via saved token) | `ApiService.switchProfile(profileKey)` — re-sends stored token, refreshes `req.familyAccount` |
| Remove account | `SharedPreferences` only | Removes profile entry from `savedProfiles` |
| Reorder | `SharedPreferences` only | Re-saves array in new order |

Returns `true` to caller if any changes were made (triggers home refresh).

**Key State:** `_profiles`, `_activeProfileKey`, `_loading`, `_changed`

---

## 2. Home & Dashboard

### 2.1 Home Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/home.dart` |
| **Route** | `/home` |
| **Access** | All authenticated members |

**Purpose:** Main app hub showing family overview — members, balances, tasks, events, and points leaderboard.

**UI Sections:**

| Section | Description |
|---|---|
| Header | Teal gradient circle (taps → account switcher) · family title · logout button |
| Family Members | Avatar wrap — tap → options dialog (view / remove). "Add Member" button below |
| Stat Cards | Money Balance (EGP) · Points Balance (pts) |
| Today's Tasks | Up to 3 recent assigned tasks with status dots |
| AI Card | Teal gradient banner → `/planning-chat` |
| Upcoming Events | Up to 3 future events with savings progress bars |
| Points Leaderboard | Top 3 with medal emojis; "Full ranking" → `/family-points` |
| Bottom Nav | Home · Dashboard · AI Chat · Location · Settings |

**Backend Flow — On Load (parallel calls):**

| Call | Endpoint | Response fields used |
|---|---|---|
| `getAllMembers()` | `GET /api/members` | `[{ _id, username, mail, member_type_id, birth_date }]` |
| `getCombinedBalance()` | `GET /api/budget/member/:memberId/combined-balance` | `{ money_balance, points_balance, points_to_money_rate }` |
| `getAllAssignedTasks()` | `GET /api/tasks/all-assigned` | `[{ _id, task_id.title, status, deadline, assigned_points }]` — first 3 shown |
| `getFutureEvents()` | `GET /api/budgets/future-events/all` | `[{ _id, title, event_date, estimated_cost, total_contributed_money }]` — first 3 shown |
| `getPointsRanking()` | `GET /api/point-wallet/ranking` | `[{ member_mail, username, total_points }]` — top 3 shown |

**Popups / Bottom Sheets:**

**Add Member dialog:**
- On open: `GET /api/memberTypes` → `[{ _id, type }]` for dropdown
- On submit: `POST /api/members` → `{ username, mail, birth_date, member_type_id }`
- Response: new member object → appended to `_familyMembers`

**Member options dialog (tap avatar):**
- "View profile" → shows member data already in state
- "Remove member" → confirmation dialog → `DELETE /api/members/:memberId`

**Logout dialog:**
- "This account" → `ApiService.logout()` → clears token from `SharedPreferences` → `/login`
- "All accounts" → `ApiService.logoutAllProfiles()` → clears all saved profiles → `/login`

**Account switcher (tap family circle):**
- Opens `ManageAccountsPage` — see §1.4

**Key State:** `_familyMembers`, `_walletSummary`, `_recentTasks`, `_futureEvents`, `_pointsRanking`, `_loading` flags (separate per section), `_userName`, `_familyTitle`

---

### 2.2 Dashboard Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/dashboard_screen.dart` |
| **Route** | `/dashboard` |
| **Access** | All authenticated members |

**Purpose:** Module hub — grid of shortcuts to all app modules, plus local announcements and events.

**UI Sections:**

| Section | Description |
|---|---|
| Header | Teal gradient circle · "Family Dashboard" title · notification bell |
| Modules grid | 2-column, 16 cards: Tasks, Budget, Events, Wallet, Rewards, Redeem, Status, Points, Food Hub, Inventory, Recipes, Meals, Leftovers, Receipts, Groceries, Categories |
| Edit Mode toggle | Drag-to-reorder mode for module cards |
| Announcements | Local list — "+" adds via dialog |
| Family Events | Local horizontal scroll — "+" adds via dialog |
| Bottom Nav | Home · Dashboard · AI Chat · Location · Settings |

**Backend Flow:**

No backend calls on this screen itself. All data (announcements, local events list) is in-memory `List` state.

Navigation taps dispatch to the relevant module routes:

| Card | Route |
|---|---|
| Tasks | `/tasks` |
| Budget | `/budget` |
| Events | `/future-events` |
| Wallet | `/combined-wallet` |
| Rewards | `/rewards` |
| Redeem | `/redeem` |
| Status | `/status` |
| Family Points | `/family-points` |
| Food Hub | `/food-hub` |
| Inventory | `/inventory` |
| Recipes | `/recipes` |
| Meals | `/meals` |
| Leftovers | `/leftovers` |
| Receipts | `/receipts` |
| Groceries | `/groceries` |
| Categories | `/inventory-categories` |

**Add Announcement dialog:** title + content text fields — stored in local `_announcements` list only.
**Add Event dialog:** title + date + image — stored in local `_events` list only.

**Key State:** `_editMode`, `_announcements` (local), `_events` (local)

---

## 3. Settings

### 3.1 Settings Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/setting.dart` |
| **Route** | `/settings` |
| **Access** | All authenticated members |

**Purpose:** Account, preferences, and family management settings.

**UI Sections:**

| Section | Rows |
|---|---|
| Profile header | Family title, "Edit Profile" link |
| My Account | Personal info · Family Members · Change Password · Switch Profile · Deactivate Account |
| Preferences | Notifications toggle · Language (EN/AR) · Dark Mode · Location Sharing · Theme picker · Conversion Rates (parent only) |
| Support | Help center · Contact us · About |
| Logout | Current / all accounts dialog |

**Backend Flow — On Load:**

| Call | Endpoint | Purpose |
|---|---|---|
| Read `SharedPreferences` | local | Loads `familyTitle`, `memberType`, `languageCode`, `isDark` |
| `GET /api/location/me` | called on load | Reads `is_sharing` flag for location toggle initial state |

**Action → API mapping:**

| Action | Endpoint | Payload |
|---|---|---|
| Edit Profile (save) | Saved to `SharedPreferences` only (username display name) | — |
| Family Members (open sheet) | `GET /api/members` | — |
| Add member in sheet | `POST /api/members` | `{ username, mail, birth_date, member_type_id }` |
| Remove member in sheet | `DELETE /api/members/:memberId` | — |
| Change Password | `POST /api/auth/setPassword` | `{ mail, family_id, new_password }` |
| Switch Profile | Opens `ManageAccountsPage` — see §1.4 | — |
| Location Sharing toggle | `PATCH /api/location/toggle` | — → `{ is_sharing: bool }` |
| Dark Mode toggle | `ThemeProvider.toggleTheme()` → `SharedPreferences['themeMode']` | — |
| Language selector | `LocaleService.setLocale(code)` → `SharedPreferences['locale']` | — |
| Conversion Rates (parent) | `POST /api/budget/conversion-rate` | `{ money_to_points_rate, points_to_money_rate }` |
| Deactivate Account | `POST /api/familyAccounts/deactivate` → confirmation dialog first | — |
| Logout (this account) | Clears token from `SharedPreferences` | — |
| Logout (all accounts) | Clears all saved profiles from `SharedPreferences` | — |

**Family Members bottom sheet data:**
- Opens with member list already loaded from `GET /api/members`
- Shows: username, email, member type, avatar initial
- Parent sees "Remove" button per member
- "Add Member" button at bottom → requires `GET /api/memberTypes` for type dropdown

**Change Password bottom sheet fields:**
- Current password (optional — only for self)
- New password + confirm
- Submit → `POST /api/auth/setPassword`

**Conversion Rates bottom sheet (parent only):**
- Fields: "10 EGP = X pts" and "1 pt = Y EGP"
- Submit → `POST /api/budget/conversion-rate` → `{ money_to_points_rate: Number, points_to_money_rate: Number }`
- Only one rate active per family at a time (backend deactivates old)

**Key State:** `_darkMode`, `_locationSharing`, `_familyTitle`, `_savedProfiles`, `_activeProfileKey`, `_languageCode`, `_isUpdatingLocationSharing`

---

## 4. Tasks & Rewards

### 4.1 Tasks Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/tasks_screen.dart` |
| **Route** | `/tasks` |
| **Access** | Any member |

**Purpose:** Personal task view — member sees only their own assigned tasks.

**UI Sections:**
- Tab bar: **Mandatory** / **Available** tasks
- Task cards: title, reward emoji + amount, progress bar, completion checkbox
- Delete mode toggle (header icon)
- Empty state illustration

**Backend Flow — On Load:**

```
GET /api/tasks/my-tasks
Headers: Authorization: Bearer <token>
Response: [
  {
    _id, task_id: { title, description, reward_type, money_reward, category_id },
    assigned_points, status, deadline, assigned_by
  }
]
```

Tasks are split into `_mandatoryTasks` (task_id.is_mandatory = true) and `_availableTasks`.

**Actions:**

| Action | Endpoint | Payload | Side Effect |
|---|---|---|---|
| Check task complete | `PATCH /api/tasks/:taskDetailId/complete` | — | Status → `'completed'`, triggers parent approval flow |
| Delete task (delete mode) | `DELETE /api/tasks/assignments/:id` | — | Removed from list |

**No popups on this screen.**

**Key State:** `_tabController`, `_isDeleteMode`, `_isLoading`, `_mandatoryTasks`, `_availableTasks`

---

### 4.2 Task Management Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/task_management_screen.dart` |
| **Route** | `/task-management` |
| **Access** | Parent (full); Members (own tasks only) |

**Purpose:** Full task administration for parents; personal task view for members.

**UI Sections (Parent tabs):**
- My Tasks · Assign Task · Templates · Approvals · History

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Used for |
|---|---|---|
| `GET /api/tasks` | Task templates list (Templates tab) | |
| `GET /api/task-categories` | Category dropdown in forms | |
| `GET /api/members` | Member picker in Assign tab | |
| `GET /api/tasks/all-assigned` | All assigned tasks (History, My Tasks tabs) | |
| `GET /api/tasks/my-tasks` | Logged-in member's own tasks | |
| `GET /api/tasks/pending-assignments` | Assignments awaiting parent approval | |
| `GET /api/tasks/waiting-approval` | Completions awaiting parent approval (Approvals tab) | |

**Action → API mapping:**

| Action | Endpoint | Payload |
|---|---|---|
| Assign task to member | `POST /api/tasks/assign` | `{ task_id, member_mail, assigned_points, deadline, notes }` |
| Mark own task complete | `PATCH /api/tasks/:taskDetailId/complete` | — |
| Approve task assignment | `PATCH /api/tasks/assignments/:id/approve-assignment` | `{ approved: true/false, notes }` |
| Approve task completion | `PATCH /api/tasks/assignments/:id/approve-completion` | `{ approved: true/false, notes }` |
| Apply penalty | `POST /api/tasks/assignments/:id/penalty` | `{ penalty_points, reason }` |
| Delete task template | `DELETE /api/tasks/:taskId` | — |
| Edit task template | `PATCH /api/tasks/:taskId` | `{ title, description, reward_type, money_reward }` |

**Approve/Reject bottom sheet data:**
- Requires: `taskDetailId`, current task info (already in state)
- Optional rejection reason text field
- Submit: `PATCH /api/tasks/assignments/:id/approve-completion` → `{ approved: false, rejection_reason: "..." }`

**Assign Task bottom sheet / form:**
- Requires: members list (already loaded), task templates list
- Fields: member picker, task picker (or template), points amount, money reward, deadline date picker, notes
- Submit: `POST /api/tasks/assign`

**Apply Penalty dialog:**
- Fields: penalty_points (number), reason (text)
- Submit: `POST /api/tasks/assignments/:id/penalty` → `{ penalty_points, reason }`
- Effect: `PointWallet.total_points -= penalty_points`, new `PointHistory` record

**Key State:** `_isParent`, `_tabController`, `_taskTemplates`, `_categories`, `_members`, `_myTasks`, `_pendingAssignments`, `_tasksWaitingApproval`, `_isLoading`

---

### 4.3 Create Task Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/create_task_screen.dart` |
| **Access** | Parent only |

**Purpose:** Form for creating reusable task templates with budget validation.

**UI Sections:**
- Title, description, category dropdown
- Mandatory checkbox
- Reward type: Points / Money / Both
- Points input, Money input (shows EGP + equivalent pts conversion)
- Budget remaining indicator + warning
- "Create Task" button

**Backend Flow — On Load:**

| Call | Endpoint | Purpose |
|---|---|---|
| `GET /api/budget/member/:memberId/combined-balance` | Gets `money_to_points_rate` for conversion display | |
| Internal budget check | `getTaskRewardsBudgetStatus()` (provider) | Shows remaining rewards budget |

**On Submit:**

```
POST /api/tasks
Headers: Authorization: Bearer <token>
Payload: {
  title: String,
  description: String,
  category_id: ObjectId,
  is_mandatory: Boolean,
  reward_type: 'points' | 'money' | 'both',
  money_reward: Number   // only if reward_type includes money
}
Response: { task: { _id, title, ... } }
```

If budget overrun: shows warning → user can pass `force_create: true` to proceed anyway.

Pops with `true` on success (caller refreshes task list).

**Key State:** `_titleController`, `_descriptionController`, `_selectedCategoryId`, `_rewardType`, `_isMandatory`, `_pointsAmount`, `_moneyAmount`, `_moneyToPointsRate`, `_isSubmitting`

---

### 4.4 Status Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/status_screen.dart` |
| **Route** | `/status` |
| **Access** | Parent (all tasks); Members (own) |

**Purpose:** Family task completion overview with activity history.

**Backend Flow — On Load:**

```
GET /api/tasks/all-assigned
Response: [ { _id, task_id.title, member_mail, status, assigned_points, penalty_points, deadline } ]
```

Computed from response:
- `_completedCount` = items where `status === 'approved'`
- `_inProgressCount` = items where `status === 'in_progress' || 'assigned'`
- `_pendingCount` = items where `status === 'completed'` (awaiting approval)

**No actions / popups on this screen.** Pull-to-refresh re-calls the same endpoint.

**Key State:** `_isLoading`, `_taskHistory`, `_completedCount`, `_inProgressCount`, `_pendingCount`

---

### 4.5 Rewards Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/rewards_screen.dart` |
| **Route** | `/rewards` |
| **Access** | All members |

**Purpose:** Personal rewards hub — points balance, wishlist items, leaderboard, history.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Used for |
|---|---|---|
| `GET /api/point-wallet/my-wallet` | `{ total_points }` → balance card | |
| `GET /api/point-history/my-history` | Last 10 `PointHistory` records | |
| `GET /api/point-wallet/ranking` | Leaderboard list | |
| `GET /api/wishlist/my-wishlist` | Wishlist items for redemption preview | |
| `GET /api/budget/member/:id/combined-balance` | `points_to_money_rate` for conversion display | |

**Actions:**

| Action | Route | Detail |
|---|---|---|
| Tap "Redeem" button | → `/redeem` | Passes `prefillItemId` for the selected wishlist item |

**No popups on this screen.**

**Key State:** `_totalPoints`, `_rewardsHistory`, `_wishlistItems`, `_familyRanking`, `_earnedThisWeek`, `_redeemedTotal`, `_pointsToMoneyRate`, `_isLoading`

---

### 4.6 Redeem Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/redeem_screen.dart` |
| **Route** | `/redeem` |
| **Access** | Parent (approval view); Child (redemption view) |

**Purpose:** Children request to redeem wishlist items; parents approve/reject.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | View |
|---|---|---|
| `GET /api/budget/member/:id/combined-balance` | `money_balance`, `points_balance`, `points_to_money_rate` | Both |
| `GET /api/wishlist/my-wishlist` | Wishlist items with `estimated_price`, `is_funded` | Child |
| `GET /api/redeem/pending` | All pending redemption requests | Parent |
| `GET /api/members` | Member details for avatar display | Parent |

**Child — Redeem Item flow:**

1. Tap "Redeem" on wishlist item → opens payment method bottom sheet
2. Bottom sheet fields:
   - Payment method pills: Points / Money / Split
   - Split: slider for points % / money %
   - Calculated preview: `points_used`, `money_used`, `remaining_points`, `remaining_money`
3. Confirm:
   - Points only: `POST /api/redeem/request` → `{ wishlist_item_id, points_used }`
   - Money only: `POST /api/redeem/with-money` → `{ wishlist_item_id, money_used }`
   - Split: both fields sent to one of the above with both amounts

**Payment method bottom sheet required data:**
- `wishlist_item.estimated_price` (from state)
- `points_balance` (from state)
- `money_balance` (from state)
- `points_to_money_rate` (from state)

**Parent — Approve/Reject flow:**

| Action | Endpoint | Payload |
|---|---|---|
| Approve | `PATCH /api/redeem/:redeemId/approve` | `{ approved: true }` |
| Reject | `PATCH /api/redeem/:redeemId/approve` | `{ approved: false, notes: "reason" }` |

Rejection notes dialog: single text field.

After approval: `PointWallet.total_points -= points_used`, `MemberWallet.balance -= money_used`, `WishlistItem.is_funded = true`.

**Key State:** `_isParent`, `_userPoints`, `_moneyBalance`, `_pointsToMoneyRate`, `_wishlistItems`, `_pendingRedemptions`, `_prefillItemId`, `_isLoading`

---

### 4.7 Family Points Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/family_points_screen.dart` |
| **Route** | `/family-points` |
| **Access** | All members |

**Purpose:** Family-wide points leaderboard with medal badges.

**Backend Flow — On Load:**

```
GET /api/point-wallet/ranking
Response: [
  { member_mail, username, member_type, total_points }   // sorted desc by total_points
]
```

Top 3 receive 🥇🥈🥉 badges. Pull-to-refresh re-calls same endpoint.

**This week's earnings section:**

```
GET /api/point-history/all          // parent only
Filter client-side: records where createdAt >= 7 days ago, group by member_mail, sum points_amount
```

**No popups on this screen.**

**Key State:** `_isLoading`, `_familyMembers`, `_weeklyEarnings` (map), `_errorMessage`

---

## 5. Food Hub

### 5.1 Food Hub Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/food_hub_screen.dart` |
| **Route** | `/food-hub` |
| **Access** | All members |

**Purpose:** Kitchen management entry point — stats overview, quick actions, expiring leftovers preview.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Response fields used |
|---|---|---|
| `GET /api/inventory/all-items` | `[{ item_name, quantity, threshold_quantity }]` | `_totalItems`, `_lowStockCount` (qty ≤ threshold) |
| `GET /api/recipes` | `[{ _id }]` | `_totalRecipes` (array length) |
| `GET /api/leftovers` | `[{ _id, expiry_date }]` | `_totalLeftovers` |
| `GET /api/leftovers/expiring` | `[{ item_name, expiry_date }]` | `_expiringLeftovers` preview (up to 4) |
| `GET /api/inventory-alerts/unread-count` | `{ count: N }` | Bell badge number |

**Actions:**

| Button | Route |
|---|---|
| Inventory | `/inventory` |
| Recipes | `/recipes` |
| Leftovers | `/leftovers` |
| Alerts | `/inventory-alerts` |
| AI Meal Suggestions | `/meal-suggestions` |

**No popups on this screen.**

**Key State:** `_loading`, `_totalItems`, `_lowStockCount`, `_totalRecipes`, `_totalLeftovers`, `_expiringLeftovers`, `_unreadAlerts`

---

### 5.2 Inventory Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_screen.dart` |
| **Route** | `/inventory` |
| **Access** | All members |

**Purpose:** Full inventory management — multiple inventories, category filtering, CRUD for items.

**Backend Flow — On Load:**

```
Step 1 (parallel):
  GET /api/inventory          → [ { _id, title, type } ]        // inventory containers
  GET /api/inventory-categories  → [ { _id, title } ]           // for filter chips + add form

Step 2 (after Step 1):
  GET /api/inventory/:inventoryId/items  → [ { _id, item_name, quantity, unit_id, item_category, expiry_date, threshold_quantity } ]
```

Default: first inventory in list is selected.

**Filter logic (client-side):**
- Category filter: `items.where(item => item.item_category._id == selectedCategoryId)`
- Search: `items.where(item => item.item_name.contains(query))`

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add item (FAB → sheet) | `POST /api/inventory/:inventoryId/items` | `{ item_name, quantity, unit_id, item_category, threshold_quantity, expiry_date }` |
| Edit item (sheet) | `PATCH /api/inventory/items/:itemId` | `{ item_name, quantity, unit_id, item_category, threshold_quantity, expiry_date }` |
| Delete item | `DELETE /api/inventory/items/:itemId` | — |
| Switch inventory | Re-calls `GET /api/inventory/:inventoryId/items` | — |

**Add / Edit Item bottom sheet required data:**
- Inventory categories list (already in state)
- Units list: `GET /api/units` (called on sheet open if not cached)
- Fields: item name, quantity (number), unit picker, category picker, threshold quantity, expiry date (date picker)

**Key State:** `_selectedInventoryId`, `_selectedCategory`, `_searchQuery`, `_inventories`, `_items`, `_categories`, `_units`, `_isLoading`

---

### 5.3 Inventory Categories Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_categories_screen.dart` |
| **Route** | `/inventory-categories` |
| **Access** | All members (parent for create/delete) |

**Purpose:** Tree-view management of inventory categories.

**Backend Flow — On Load:**

```
GET /api/inventory-categories
Response: [ { _id, title, parent_id } ]   // flat list, tree built client-side
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add category | `POST /api/inventory-categories` | `{ title, parent_id? }` |
| Edit category | `PATCH /api/inventory-categories/:id` | `{ title }` |
| Delete category | `DELETE /api/inventory-categories/:id` | — |

**Add/Edit dialog fields:**
- Category name text field
- Parent category picker (for creating sub-categories)

**Key State:** `_categories`, `_expandedNodes`, `_searchQuery`, `_isLoading`

---

### 5.4 Inventory Alerts Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/inventory_alerts_screen.dart` |
| **Route** | `/inventory-alerts` |
| **Access** | All members |

**Purpose:** Alert management for low stock, expiring, and expired inventory items.

**Backend Flow — On Load:**

```
GET /api/inventory-alerts
Response: [ {
  _id, alert_type: 'low_stock'|'expiring'|'expired'|'out_of_stock',
  item_name, inventory_title, current_quantity, threshold_quantity,
  expiry_date, is_read, createdAt
} ]
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Mark one read | `PATCH /api/inventory-alerts/:alertId/read` | — |
| Mark all read | `PATCH /api/inventory-alerts/mark-all-read` | — |
| Delete alert | `DELETE /api/inventory-alerts/:alertId` | — |
| Clear read alerts | `DELETE /api/inventory-alerts/clear-read` | — |
| Generate fresh scan (FAB) | `POST /api/inventory-alerts/generate` | — → scans all items, creates new alerts |

**No popups.** Filter chips are client-side (`_selectedAlertType` filters `_alerts` list).

**Key State:** `_selectedAlertType`, `_alerts`, `_isLoading`

---

### 5.5 Meals Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/meals_screen.dart` |
| **Route** | `/meals` |
| **Access** | All members |

**Purpose:** Daily meal planner with date navigation and meal-type grouping.

**Backend Flow — On Load:**

```
GET /api/meals?date=YYYY-MM-DD
Response: [ {
  _id, meal_name, meal_date, meal_type, recipe_id, created_by,
  items: [ { item_name, quantity, unit_id } ]
} ]
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Previous / Next day | Re-calls `GET /api/meals?date=...` | — |
| Add meal (FAB → sheet) | `POST /api/meals` | `{ meal_name, meal_date, meal_type, recipe_id? }` |
| Add item to meal | `POST /api/meals/:mealId/items` | `{ item_name, quantity, unit_id }` |
| Remove item | `DELETE /api/meals/:mealId/items/:itemId` | — |
| Mark prepared (from recipe) | `POST /api/meals/:mealId/prepare` | — → auto-deducts recipe ingredients from inventory |
| Delete meal | `DELETE /api/meals/:mealId` | — |

**Add Meal bottom sheet required data:**
- Date (from current selected date — pre-filled)
- Meal type picker: Breakfast / Lunch / Dinner / Snack
- Optional recipe picker: `GET /api/recipes` (called on sheet open if not cached)
- Fields: meal name, date, meal type, optional recipe linkage

**"Mark Prepared" confirmation dialog:**
- Shows ingredient list that will be deducted from inventory
- Confirm → `POST /api/meals/:mealId/prepare`
- Effect: `InventoryItem.quantity -= ingredient.quantity` for each recipe ingredient

**Key State:** `_selectedDate`, `_meals`, `_mealsByType`, `_recipes`, `_isLoading`

---

### 5.6 Meal Suggestions Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/meal_suggestions_screen.dart` |
| **Route** | `/meal-suggestions` |
| **Access** | All members |

**Purpose:** AI-generated meal suggestions based on current inventory stock.

**Backend Flow — On Load:**

```
GET /api/meal-suggestions
Response: [ {
  _id, meal_type, recipe_id: { recipe_name, serving_size },
  reason, score
} ]
```

If no suggestions exist, prompts user to generate.

**Actions:**

| Action | Endpoint | Detail |
|---|---|---|
| Generate suggestions | `POST /api/meal-suggestions/generate` | Backend cross-references `InventoryItem` stock against `RecipeIngredient` requirements. Returns scored `MealSuggestion` list |
| Clear suggestions | `DELETE /api/meal-suggestions` | — |
| "Plan this meal" | `POST /api/meals` | Pre-fills meal form with selected recipe |

Response from generate:
```json
[{ meal_type, recipe_id: { recipe_name }, reason: "Has 4/5 ingredients", score: 0.8 }]
```

**No popup sheets.** Filter chips (meal type) are client-side.

**Key State:** `_suggestions`, `_selectedMealType`, `_isLoading`

---

### 5.7 Recipes Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/recipes_screen.dart` |
| **Route** | `/recipes` |
| **Access** | All members |

**Purpose:** Family recipe book with search and CRUD.

**Backend Flow — On Load:**

```
GET /api/recipes
Response: [ {
  _id, recipe_name, category, serving_size, prep_time, cook_time,
  description, member_mail, family_id
} ]
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add recipe (FAB → form) | `POST /api/recipes` | `{ recipe_name, category, serving_size, prep_time, cook_time, description }` |
| Delete recipe | `DELETE /api/recipes/:recipeId` | — |
| Tap recipe card | → `RecipeDetailScreen` with `recipeId` argument | — |

**Add Recipe bottom sheet fields:**
- Recipe name, category picker (enum: Breakfast/Lunch/Dinner/etc.), servings, prep time, cook time, description
- Submit → `POST /api/recipes`
- After creation: navigate to `RecipeDetailScreen` to add ingredients and steps

**Key State:** `_recipes`, `_searchQuery`, `_filteredRecipes`, `_isLoading`

---

### 5.8 Recipe Detail Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/recipe_detail_screen.dart` |
| **Access** | All members |

**Purpose:** Full recipe viewer/editor with serving scaler and inventory availability.

**Backend Flow — On Load:**

```
Step 1:
  GET /api/recipes/:recipeId
  Response: { recipe_name, category, serving_size, prep_time, cook_time, description,
    ingredients: [ { _id, ingredient_name, quantity, unit_id: { name } } ],
    steps: [ { _id, step_number, instruction, duration_minutes } ]
  }

Step 2 (scaled view):
  GET /api/recipes/:recipeId/scaled?servings=N
  Response: same structure but quantities proportionally scaled
```

**Inventory availability check (client-side):**
- Compares `ingredient.ingredient_name` against loaded `InventoryItem` list (passed from parent or re-fetched)
- Green dot = in-stock, Yellow = partial, Red = unavailable

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Change servings slider | `GET /api/recipes/:recipeId/scaled?servings=N` | — |
| Add ingredient | `POST /api/recipes/:recipeId/ingredients` | `{ ingredient_name, quantity, unit_id, notes }` |
| Remove ingredient | `DELETE /api/recipes/:recipeId/ingredients/:id` | — |
| Add step | `POST /api/recipes/:recipeId/steps` | `{ step_number, instruction, duration_minutes }` |
| Remove step | `DELETE /api/recipes/:recipeId/steps/:id` | — |
| Save recipe changes | `PATCH /api/recipes/:recipeId` | `{ recipe_name, category, serving_size, prep_time, cook_time, description }` |
| Delete recipe | `DELETE /api/recipes/:recipeId` → confirmation dialog | — |

**Add Ingredient sheet fields:** ingredient name, quantity (number), unit picker (`GET /api/units`), notes.
**Add Step sheet fields:** instruction text, duration (minutes).

**Key State:** `_servings`, `_ingredients`, `_steps`, `_isEditMode`, `_isLoading`

---

### 5.9 Leftovers Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/leftovers_screen.dart` |
| **Route** | `/leftovers` |
| **Access** | All members |

**Purpose:** Leftover food tracker with expiry monitoring.

**Backend Flow — On Load:**

```
GET /api/leftovers           → all active leftovers
GET /api/leftovers/expiring  → leftovers expiring within 2 days (for "Expiring Soon" tab)

Response item: {
  _id, item_name, quantity, unit_id: { name }, expiry_date,
  date_added, category_id: { title }, meal_id
}
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add leftover (FAB → sheet) | `POST /api/leftovers` | `{ item_name, quantity, unit_id, expiry_date, category_id?, meal_id? }` |
| Edit leftover (sheet) | `PATCH /api/leftovers/:leftoverId` | same fields |
| Delete leftover | `DELETE /api/leftovers/:leftoverId` | — |

**Add/Edit Leftover sheet required data:**
- Units list: `GET /api/units` (on sheet open)
- Leftover categories: `GET /api/leftovers/categories` (on sheet open)
- Fields: item name, quantity, unit picker, expiry date (date picker), category picker, linked meal (optional)

**Leftover categories CRUD (parent):**
- `POST /api/leftovers/categories` → `{ title }`
- `DELETE /api/leftovers/categories/:id`

**Key State:** `_leftovers`, `_selectedTab`, `_filteredLeftovers`, `_units`, `_categories`, `_isLoading`

---

### 5.10 Receipts Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/receipts_screen.dart` |
| **Route** | `/receipts` |
| **Access** | All members |

**Purpose:** Digital receipt storage with line-item entry and spending totals.

**Backend Flow — On Load:**

```
GET /api/receipts
Response: [ {
  _id, title, total_amount, receipt_date, store_name, category,
  items: [ { name, price, quantity } ], image_url, member_mail
} ]

GET /api/receipts/summary
Response: { total_by_category: { Groceries: 1200, ... }, grand_total: 3450 }
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add receipt (FAB → form) | `POST /api/receipts` | `{ title, total_amount, receipt_date, store_name, category, items: [...], image_url? }` |
| Edit receipt | `PATCH /api/receipts/:receiptId` | same fields |
| Delete receipt | `DELETE /api/receipts/:receiptId` | — |
| View receipt detail | Tap card → detail view (inline expand or separate screen) | — |

**Add Receipt form fields:**
- Store name, date (date picker), category (text/dropdown), photo upload (image picker → `image_url`)
- Line items table: item name, price, quantity — "Add Row" button
- Total auto-calculated from line items

**Key State:** `_receipts`, `_summary`, `_lineItems`, `_totalAmount`, `_isLoading`

---

### 5.11 Groceries Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/groceries_screen.dart` |
| **Route** | `/groceries` |
| **Access** | All members |

**Purpose:** Multi-list grocery manager showing completion progress per list.

**Backend Flow — On Load:**

```
GET /api/grocery-lists
Response: [ {
  _id, title, created_by, is_completed, createdAt,
  items: [ { _id, is_checked } ]   // abbreviated — detail loaded per-list
} ]
```

Progress `= items.where(is_checked).length / items.length`

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Create list (dialog) | `POST /api/grocery-lists` | `{ title }` |
| Delete list | `DELETE /api/grocery-lists/:id` | — |
| Tap list card | → `/grocery-list-detail` with `{ listId, title }` args | — |

**Create List dialog fields:** list title (single text field).

**Key State:** `_groceryLists`, `_searchQuery`, `_filteredLists`, `_isLoading`

---

### 5.12 Grocery List Detail Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/grocery_list_detail_screen.dart` |
| **Route** | `/grocery-list-detail` |
| **Access** | All members |
| **Args received** | `listId: String`, `title: String` |

**Purpose:** Single grocery list with item checking, inline addition, and section split.

**Backend Flow — On Load:**

```
GET /api/grocery-lists/:id
Response: {
  _id, title, is_completed,
  items: [ { _id, item_name, quantity, unit, is_checked, added_by } ]
}
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add item (quick-add field) | `POST /api/grocery-lists/:id/items` | `{ item_name, quantity: 1, unit: '' }` |
| Check/uncheck item | `PATCH /api/grocery-lists/items/:itemId` | `{ is_checked: bool }` |
| Edit item name/qty | `PATCH /api/grocery-lists/items/:itemId` | `{ item_name, quantity, unit }` |
| Delete item | `DELETE /api/grocery-lists/items/:itemId` | — |
| Rename list (app bar edit) | `PATCH /api/grocery-lists/:id` | `{ title }` |

**No popup sheets — all actions are inline in the list.**

**Key State:** `_listId`, `_listTitle`, `_items`, `_newItemCtrl`, `_isLoading`

---

## 6. Budget & Finance

### 6.1 Budget Dashboard Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/budget_dashboard_screen.dart` |
| **Route** | `/budget` |
| **Access** | Parent |

**Purpose:** Main budget hub — active period budgets, spending breakdown, pending expense requests, and member allowances.

**Backend Flow — On Load (via `FamilyBudgetProvider`):**

| Call | Endpoint | Response fields used |
|---|---|---|
| `loadBudgets()` | `GET /api/budget/periods` | `[{ _id, title, period_type, start_date, end_date, total_amount, spent_amount, emergency_fund_percentage, allocations, allowances }]` |
| `loadFutureEvents()` | `GET /api/budgets/future-events/all` | `[{ _id, title, event_date, estimated_cost, total_contributed_money }]` |
| `getExpenseRequests({status:'pending'})` | `GET /api/budget/expense-requests?status=pending` | Pending child requests (shown with approve/reject) |

**Pending Expense Request card (parent):**
- Approve: `PATCH /api/budget/expense-requests/:id/approve` → increments `PeriodBudget.spent_amount` + `BudgetAllocation.spent_amount`
- Reject: `PATCH /api/budget/expense-requests/:id/reject` → status = `'rejected'`, no money moved

**Create Budget FAB → `CreateBudgetScreen`:**
- Fields: title, period type (weekly/monthly/yearly/custom), start/end date (date pickers), total amount EGP, emergency fund %
- Submit: `POST /api/budget/periods` → `{ title, period_type, start_date, end_date, total_amount, emergency_fund_percentage }`

**Budget card actions:**

| Action | Endpoint | Payload / Detail |
|---|---|---|
| View analytics | → `BudgetAnalyticsScreen` with `budgetId` arg | — |
| Edit budget | `PATCH /api/budget/periods/:id` | `{ title, total_amount, emergency_fund_percentage }` |
| Delete budget | `DELETE /api/budget/periods/:id` → confirmation dialog | Cascades: removes all `BudgetAllocation` and `MemberAllowance` records |
| Set allocations | `PUT /api/budget/periods/:id/allocations` | `{ allocations: [{ inventory_category_id, allocated_amount, threshold_percentage }] }` |
| Set allowances | `PUT /api/budget/periods/:id/allowances` | `{ allowances: [{ member_id, money_amount, period_type }] }` → auto-deposits to `MemberWallet` |

**Member Allowances bottom sheet required data:**
- Members list: `GET /api/members` (if not cached)
- Per member: amount EGP field
- Submit: `PUT /api/budget/periods/:id/allowances`
- Effect: `MemberWallet.balance += money_amount` per member, `MemberAllowance` record created

**Category Allocations bottom sheet required data:**
- Categories: `GET /api/inventory-categories` (if not cached)
- Per category: allocated amount EGP, alert threshold %
- Submit: `PUT /api/budget/periods/:id/allocations`

**Key State (in `FamilyBudgetProvider`):** `budgets`, `futureEvents`, `pendingRequests`, `isLoading`, `isParentUser`

---

### 6.2 Add Expense Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/add_expense_screen.dart` |
| **Access** | All members |

**Purpose:** Form for recording a new expense — shared or personal scope.

**Backend Flow — On Load:**

```
GET /api/inventory-categories   → category dropdown list
GET /api/budget/periods         → active budgets list (for budget_id selector)
```

**On Submit:**

**Shared expense (direct — parent or auto-approved):**
```
POST /api/budget/expenses/new
Payload: {
  title: String,
  amount: Number,
  category: String,
  budget_category_id: ObjectId,  // from category picker
  budget_id: ObjectId,           // selected period budget
  expense_date: ISO date,
  expense_scope: 'shared',
  description?: String,
  is_emergency?: Boolean
}
Response: { expense: { _id, ... } }
Effect: PeriodBudget.spent_amount += amount
        BudgetAllocation.spent_amount += amount  (for matched category)
```

**Personal expense:**
```
POST /api/budget/expenses/new
Payload: {
  amount: Number,
  expense_scope: 'personal',
  budget_id: ObjectId,
  member_mail: String,
  expense_date: ISO date,
  description?: String
}
Effect: MemberWallet.balance -= amount
        MemberAllowance.spent_amount += amount
```

**Child — shared expense request (requires approval):**
```
POST /api/budget/expense-requests
Payload: { title, amount, budget_category_id, budget_id, expense_date, description }
Effect: Expense created with request_status: 'pending'
        Parent notified (no money moved yet)
```

**Key State:** `_amountCtrl`, `_descCtrl`, `_selectedCategoryId`, `_expenseScope`, `_expenseDate`, `_isEmergency`, `_isLoading`, `_categories`, `_budgets`

---

### 6.3 Budget Analytics Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/budget_analytics_screen.dart` |
| **Access** | Parent |
| **Args received** | `budgetId: String` |

**Purpose:** Three-tab analytics for a specific period budget — overview pie, daily trend, transactions.

**Backend Flow — On Load:**

```
GET /api/budget/analytics?period_budget_id={budgetId}
Response: {
  total_spent: Number,
  total_budget: Number,
  total_remaining: Number,
  is_over_budget: Boolean,
  pie_chart_data: [
    { category_name, spent_amount, allocated_amount, percentage, expense_count, is_over_budget }
  ],
  daily_trend_data: [
    { _id: "YYYY-MM-DD", daily_spent: Number }
  ]
}
```

Also uses `provider.expenses` (list from `provider.loadBudgets()`) for the Expenses tab.

**Tab behavior:**

| Tab | Data Source | Logic |
|---|---|---|
| Overview | `analytics.pie_chart_data` | Pie chart (fl_chart), over-budget banners for categories >80%, category breakdown list |
| Trend | `analytics.daily_trend_data` | Line chart (fl_chart), x-axis = date labels every 3 days |
| Expenses | `provider.expenses` | Full transaction list filtered to this `budgetId` |

**Actions:**
- Pie chart sections are touch-sensitive (`_touchedIndex` → section expands)
- Refresh button: re-calls `loadAnalytics(budgetId)`
- No popups on this screen

**Key State:** `_tabCtrl`, `_touchedIndex`, provider's `analyticsData`, `expenses`

---

### 6.4 Future Events Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/future_events_screen.dart` |
| **Route** | `/future-events` |
| **Access** | Parent (create/edit); All (view) |

**Purpose:** Plan and track family savings goals for upcoming events.

**Backend Flow — On Load (direct `ApiService` call):**

```
GET /api/budgets/future-events/all
Response: [
  {
    _id, title, description, event_date, estimated_cost,
    total_contributed_money, total_contributed_points,
    funding_source, required_points, created_by
  }
]
```

Data normalized client-side:
- `name` = `title`
- `expected_date` = `event_date`
- `saved_amount` = `total_contributed_money`

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Add event (FAB → sheet) | `POST /api/budgets/future-events` | `{ title, description, event_date, estimated_cost, funding_source, required_points }` |
| Edit event (sheet) | `PUT /api/budgets/future-events/:eventId` | same fields |
| Delete event | Provider `deleteFutureEvent(id)` → `DELETE` | — |

After each mutation: `_fetchEvents()` re-called to refresh local state.

**Add/Edit Event bottom sheet fields:**
- Event name text field
- Estimated cost EGP (number field)
- Already saved EGP (number field, pre-fills `total_contributed_money`)
- Expected date (date picker — min: today, max: +10 years)
- Reminder slider: 1–12 months before
- Saving frequency pills: Weekly / Monthly

**Delete confirmation dialog:** standard "Are you sure?" AlertDialog.

**Key State (local):** `_localEvents`, `_eventsLoading`; mutations via `FamilyBudgetProvider`

---

### 6.5 Event Funding Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/budget/event_funding_screen.dart` |
| **Access** | All members |

**Purpose:** Detailed funding tracker for a single future event — contributions and points redemption.

**Backend Flow — On Load:**

```
GET /api/budgets/future-events/all   (find the specific event from list)
GET /api/members                     (for contribution member list)
GET /api/point-wallet/my-wallet      (for "Redeem for Event Spot" button)
```

**Actions:**

| Action | Endpoint | Payload |
|---|---|---|
| Contribute money | `PUT /api/budgets/future-events/:eventId` | `{ total_contributed_money: newTotal }` |
| Redeem for event spot | `POST /api/redeem/event-spot` | `{ event_id, points_to_redeem }` |
| Update goal | `PUT /api/budgets/future-events/:eventId` | `{ estimated_cost: newGoal }` |

**Contribute Money sheet fields:**
- Amount EGP (number field)
- Member name (auto-filled from current session)

**Redeem Event Spot sheet fields:**
- Points to redeem (number field, max = `my_wallet.total_points`)
- Shows EGP equivalent preview
- Confirm: `POST /api/redeem/event-spot` → `{ event_id, points_to_redeem }` → `PointWallet.total_points -= points_to_redeem`, `FutureEvent.total_contributed_points += points_to_redeem`

**Key State:** `_tabCtrl`, event data, contributions list, `_isLoading`

---

## 7. Wallet & Analytics

### 7.1 Combined Wallet Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/wallet/combined_wallet_screen.dart` |
| **Route** | `/combined-wallet` |
| **Access** | All members |

**Purpose:** Money Wallet + Points Wallet interface with conversion.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Response fields used |
|---|---|---|
| `getCombinedBalance()` | `GET /api/budget/member/:memberId/combined-balance` | `money_balance`, `points_balance`, `money_to_points_rate`, `points_to_money_rate` |
| `getBalanceWalletDetails()` | `GET /api/budget/wallet-details` | Full audit log for transaction lists |
| `getMyPointHistory()` | `GET /api/point-history/my-history` | Points earning/redemption records |

**Money Wallet card:**
- Shows EGP balance, "Convert to Points" button
- Transaction list: `BalanceWalletDetail` filtered to `wallet_scope = 'money_wallet'`

**Points Wallet card:**
- Shows total_points, EGP equivalent, "Convert to Money" button
- Transaction list: `PointHistory` records
- Exchange rate display: "10 EGP = 100 pts"

**Conversion modal (bottom sheet):**

| Direction | Endpoint | Payload | Effect |
|---|---|---|---|
| Money → Points | `POST /api/budget/wallet/convert-to-points` | `{ amount_egp: Number }` | `MemberWallet.balance -= amount`, `PointWallet.total_points += amount * rate` |
| Points → Money | `POST /api/budget/wallet/convert-from-points` | `{ points: Number }` | `PointWallet.total_points -= points`, `MemberWallet.balance += points * rate` |

Conversion sheet fields:
- Amount field (EGP or pts depending on direction)
- Live preview: shows converted amount using stored `money_to_points_rate` / `points_to_money_rate`
- Confirm button (disabled if insufficient balance)

**Parent view — member selector:**
- Dropdown: `GET /api/members` → picks any member
- On select: re-fetches `GET /api/budget/wallet-details?member_mail=...`

**Key State:** `_moneyBalance`, `_pointsBalance`, `_conversionRate`, `_moneyTransactions`, `_pointsTransactions`, `_selectedMemberId`, `_isConverting`, `_isLoading`

---

### 7.2 Balance Wallet Details Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/wallet/balance_wallet_details_screen.dart` |
| **Route** | `/wallet-details` |
| **Access** | All members |

**Purpose:** Full audit trail of every wallet balance change.

**Backend Flow — On Load:**

```
GET /api/budget/wallet-details
Response: {
  member: { username, mail },
  summary: {
    money_wallet: { total_credits, total_debits },
    personal_budget: { total_credits, total_debits },
    shared_budget: { total_credits, total_debits }
  },
  details: [
    {
      _id, wallet_scope, change_type, source_type, amount,
      previous_balance, new_balance, description, createdAt,
      member_mail
    }
  ]
}
```

**Filter chips (client-side):**
- All / Money / Personal / Shared → filters `details` by `wallet_scope`

**No actions / no popups.** Pull-to-refresh re-calls the same endpoint.

**Key State:** `_isLoading`, `_selectedScope`, `_member`, `_summary`, `_details`, `_filteredDetails`

---

### 7.3 Combined Analytics Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/analytics/combined_analytics_screen.dart` |
| **Route** | `/combined-analytics` |
| **Access** | Parent (full); Members (personal subset) |

**Purpose:** Comprehensive spending and rewards analytics.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Used for |
|---|---|---|
| `GET /api/budget/analytics` | Overall spending breakdown | Pie chart, overview cards |
| `GET /api/tasks/rewards-summary` | Points earned per member | Bar chart (earned vs redeemed) |
| `GET /api/budget/wallet-details` | All wallet transactions | Line chart (spending trend) |

**Period filter tabs (Week / Month / Year):**
- Appends `?period=week|month|year` to analytics call
- Client-side re-filter of `details` for trend chart

**Charts:**
- Pie chart (`fl_chart PieChart`): `analytics.pie_chart_data` by category
- Bar chart (`fl_chart BarChart`): `rewards_summary` earned vs redeemed per member
- Line chart (`fl_chart LineChart`): `wallet_details.details` aggregated by day

**No popups on this screen.** PDF export calls `flutter_pdfview` or `printing` package (client-side rendering only).

**Key State:** `_analyticsData`, `_memberAnalytics`, `_selectedTimeRange`, `_isLoading`, `_isPDFExporting`

---

## 8. Location & Map

### 8.1 Family Map Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/family_map_screen.dart` |
| **Route** | `/family-map` |
| **Access** | All members |

**Purpose:** Real-time family location map with member pins, alerts, and sharing controls.

**Backend Flow — On Load (parallel):**

| Call | Endpoint | Response |
|---|---|---|
| `GET /api/location/me` | My current location + `is_sharing` flag | `{ latitude, longitude, is_sharing }` |
| `GET /api/location/family` | All members with sharing ON | `[{ member_mail, username, latitude, longitude, is_sharing, updated_at }]` |
| `GET /api/location/alerts/unread-count` | Bell badge number | `{ count: N }` |

**Polling:** `getFamilyLocations()` called every 30 seconds via `Timer.periodic` to refresh member pins.

**Actions:**

| Action | Endpoint | Payload / Detail |
|---|---|---|
| "Sync my location" FAB | `POST /api/location/update` | `{ latitude, longitude }` from device GPS |
| Toggle sharing | `PATCH /api/location/toggle` | — → flips `is_sharing` boolean |
| Open alerts sheet | `GET /api/location/alerts` | `[{ _id, alert_type, message, is_read, createdAt }]` |
| Mark alert read | `PATCH /api/location/alerts/:id/read` | — |
| Mark all read | `PATCH /api/location/alerts/read-all` | — |

**Selected member bottom sheet (tap marker):**
- Data already in `_familyLocations` state
- Shows: member name, last seen timestamp, sharing status
- "Get Directions" → opens Google Maps external app with `latitude,longitude`

**Alerts bottom sheet data:**
- Opens with `GET /api/location/alerts` response
- Each alert: type badge, message, timestamp, "Mark read" button

**Location Permission flow (optional — from settings):**
- Request: `POST /api/location/permissions` → `{ target_mail }` — asks another member to share their location
- Incoming requests: `GET /api/location/permissions/incoming`
- Approve/Deny: `PATCH /api/location/permissions/:id` → `{ status: 'approved'|'denied' }`

**Key State:** `_familyLocations`, `_myPosition`, `_isSharingEnabled`, `_selectedMember`, `_unreadLocationAlerts`, `_alerts`, `_isSyncingMyLocation`, `_pollingTimer`

---

## 9. Planning AI

### 9.1 Planning Chat Screen

| Property | Detail |
|---|---|
| **File** | `lib/pages/planning_chat_screen.dart` |
| **Route** | `/planning-chat` |
| **Access** | All members |

**Purpose:** Conversational AI assistant (Gemini) that answers questions about all family data.

**UI Sections:**
- Chat list — user bubbles (teal, right) and AI bubbles (white, left)
- Empty state with 6 suggestion chips
- Typing indicator (3 bouncing dots)
- Text input + send button
- Clear history option (top-right menu)

**Backend Flow — On Load:**

```
GET /api/planning/history
Response: {
  messages: [
    { role: 'user'|'assistant', content: String, timestamp: ISO }
  ]
}
```

Last 10 messages loaded and displayed. Empty → shows suggestion chips.

**Send Message:**

```
POST /api/planning/chat
Payload: { message: String }
Response: { reply: String }
```

Backend flow (server-side):
1. `gatherFamilyContext(familyId)` — parallel DB queries fetching members, expenses, budgets, tasks, points, inventory, recipes, meals, leftovers, events (2 batch rounds)
2. `buildSystemPrompt(ctx, familyTitle)` — injects all family data as labelled text sections
3. Last 10 conversation messages sent as Gemini `history` (role: `'user'|'model'`)
4. Gemini `gemini-2.5-flash-lite` generates response
5. Both user message and AI reply saved to `PlanningConversation` in MongoDB

**Clear History:**

```
DELETE /api/planning/history
Response: { message: "History cleared" }
```

After clear: `_messages = []`, suggestion chips shown again.

**Suggestion chips (client-side labels — sent as message text on tap):**
- "Who earned the most points this week?"
- "What can we cook tonight with what we have?"
- "How are we doing on our May budget?"
- "Which category are we overspending on?"
- "How much have we saved for the summer trip?"
- "Give me a weekly meal plan"

**Key State:** `_messages`, `_loading` (AI thinking), `_historyLoading`, `_inputCtrl`, `_scrollCtrl`, `_dotsController`, `_dotAnimations`

---

## Appendix

### Route Map

| Route | Screen File | Module |
|---|---|---|
| `/splash` | `splash_screen.dart` | Auth |
| `/onboarding` | `onboarding_screen.dart` | Auth |
| `/login` | `signup_login.dart` → LoginPage | Auth |
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
| `/future-events` | `budget/future_events_screen.dart` | Budget |
| `/combined-wallet` | `wallet/combined_wallet_screen.dart` | Wallet |
| `/wallet-details` | `wallet/balance_wallet_details_screen.dart` | Wallet |
| `/combined-analytics` | `analytics/combined_analytics_screen.dart` | Analytics |
| `/family-map` | `family_map_screen.dart` | Location |
| `/planning-chat` | `planning_chat_screen.dart` | AI |

---

### Access Level Summary

| Level | Who | Screens |
|---|---|---|
| **Public** | Unauthenticated | Splash, Onboarding, Login, Signup |
| **Any member** | All logged-in | Home, Dashboard, Rewards, Tasks (own), Food Hub, Recipes, Meals, Leftovers, Inventory, Groceries, Receipts, Wallet, Map, Planning AI |
| **Parent only** | `member_type === 'Parent'` | Task Management (full), Create Task, Budget Dashboard, Add Expense (shared direct), Budget Analytics, Future Events management, Conversion Rates, Family Members management |

---

### Common Payload Patterns

**Auth header** (every protected request):
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Family scoping** (automatic via `protect` middleware):
- Every backend query adds `{ family_id: req.familyAccount._id }` — no need to send `family_id` in request body.

**Error format** (all endpoints):
```json
{ "message": "Human-readable error description" }
```
Flutter catches non-2xx status codes and reads `data['message']` to show in `SnackBar`.

---

### Theme Reference

| Token | Value | Used for |
|---|---|---|
| `AppColors.background` | `#E8F5F5` | Page backgrounds |
| `AppColors.primary` | `#00897B` | Buttons, active icons, key actions |
| `AppColors.primaryLight` | `#00ACC1` | Gradient highlights |
| `AppColors.primarySurface` | `#E0F2F1` | Icon backgrounds, active nav item |
| `AppColors.primaryGradient` | `#00695C → #00ACC1` | AppBars, FABs, hero cards |
| `AppColors.textPrimary` | `#00352E` | Headings and primary text |
| `AppColors.textSecondary` | `#4DB6AC` | Subtitles, labels, section headers |
| `AppColors.border` | `#B2DFDB` | Card borders |
| `AppColors.error` | `#E53935` | Errors, badges, warnings |
| Dark bg | `#0A1628` | Page background in dark mode |
| Dark card | `#122030` | Card background in dark mode |
| Dark border | `#1E3A4A` | Card border in dark mode |
| Dark text | `#E0F2F1` | Primary text in dark mode |
