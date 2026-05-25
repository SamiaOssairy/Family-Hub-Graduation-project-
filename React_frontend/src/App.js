// ═══════════════════════════════════════════════════════════════════════════════
// App.js — Family Hub React Router setup (merged from both team members)
// Auth screens  : SplashScreen, OnboardingScreen, LoginScreen, SignUpScreen
// Main screens  : HomeScreen, DashboardScreen, SettingsScreen (new Flutter parity)
// Nav screens   : PlanningChatScreen, FamilyMapScreen
// Module screens: food + tasks
// ═══════════════════════════════════════════════════════════════════════════════
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';

// CSS
import './styles/variables.css';

// ── Auth / Onboarding screens ─────────────────────────────────────────────────
import SplashScreen     from './pages/SplashScreen';
import OnboardingScreen from './pages/OnboardingScreen';
import LoginScreen      from './pages/LoginScreen';
import SignUpScreen     from './pages/SignUpScreen';

// ── Main navigation screens (Flutter parity) ──────────────────────────────────
import HomeScreen        from './pages/HomeScreen';
import DashboardScreen   from './pages/DashboardScreen';
import SettingsScreen    from './pages/SettingsScreen';
import PlanningChatScreen from './pages/PlanningChatScreen';
import FamilyMapScreen   from './pages/FamilyMapScreen';

// ── Tasks module ──────────────────────────────────────────────────────────────
import TasksScreen          from './pages/tasks/TasksScreen';
import TaskManagementScreen from './pages/tasks/TaskManagementScreen';
import RewardsScreen        from './pages/tasks/RewardsScreen';
import RedeemScreen         from './pages/tasks/RedeemScreen';
import FamilyPointsScreen   from './pages/tasks/FamilyPointsScreen';
import StatusScreen         from './pages/tasks/StatusScreen';

// ── Food Hub module ───────────────────────────────────────────────────────────
import FoodHubScreen             from './pages/food/FoodHubScreen';
import RecipesScreen             from './pages/food/RecipesScreen';
import RecipeDetailScreen        from './pages/food/RecipeDetailScreen';
import MealsScreen               from './pages/food/MealsScreen';
import MealSuggestionsScreen     from './pages/food/MealSuggestionsScreen';
import LeftoversScreen           from './pages/food/LeftoversScreen';
import InventoryScreen           from './pages/food/InventoryScreen';
import InventoryCategoriesScreen from './pages/food/InventoryCategoriesScreen';
import InventoryAlertsScreen     from './pages/food/InventoryAlertsScreen';
import GroceriesScreen           from './pages/food/GroceriesScreen';
import GroceryListDetailScreen   from './pages/food/GroceryListDetailScreen';
import ReceiptsScreen            from './pages/food/ReceiptsScreen';

// ── Protected route — redirect to /login if not logged in ─────────────────────
function ProtectedRoute({ children }) {
  const { isLoggedIn } = useAuth();
  if (!isLoggedIn) return <Navigate to="/login" replace />;
  return children;
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Root redirect */}
        <Route path="/" element={<Navigate to="/splash" replace />} />

        {/* ── Auth / Onboarding ── */}
        <Route path="/splash"      element={<SplashScreen />} />
        <Route path="/onboarding"  element={<OnboardingScreen />} />
        <Route path="/login"       element={<LoginScreen />} />
        <Route path="/signup"      element={<SignUpScreen />} />

        {/* ── Main navigation screens ── */}
        <Route path="/home"          element={<ProtectedRoute><HomeScreen /></ProtectedRoute>} />
        <Route path="/dashboard"     element={<ProtectedRoute><DashboardScreen /></ProtectedRoute>} />
        <Route path="/settings"      element={<ProtectedRoute><SettingsScreen /></ProtectedRoute>} />
        <Route path="/planning-chat" element={<ProtectedRoute><PlanningChatScreen /></ProtectedRoute>} />
        <Route path="/family-map"    element={<ProtectedRoute><FamilyMapScreen /></ProtectedRoute>} />

        {/* ── Tasks module ── */}
        <Route path="/tasks"           element={<ProtectedRoute><TasksScreen /></ProtectedRoute>} />
        <Route path="/task-management" element={<ProtectedRoute><TaskManagementScreen /></ProtectedRoute>} />
        <Route path="/rewards"         element={<ProtectedRoute><RewardsScreen /></ProtectedRoute>} />
        <Route path="/redeem"          element={<ProtectedRoute><RedeemScreen /></ProtectedRoute>} />
        <Route path="/family-points"   element={<ProtectedRoute><FamilyPointsScreen /></ProtectedRoute>} />
        <Route path="/status"          element={<ProtectedRoute><StatusScreen /></ProtectedRoute>} />

        {/* ── Food Hub module ── */}
        <Route path="/food-hub"                element={<ProtectedRoute><FoodHubScreen /></ProtectedRoute>} />
        <Route path="/recipes"                 element={<ProtectedRoute><RecipesScreen /></ProtectedRoute>} />
        <Route path="/recipes/:id"             element={<ProtectedRoute><RecipeDetailScreen /></ProtectedRoute>} />
        <Route path="/meals"                   element={<ProtectedRoute><MealsScreen /></ProtectedRoute>} />
        <Route path="/meal-suggestions"        element={<ProtectedRoute><MealSuggestionsScreen /></ProtectedRoute>} />
        <Route path="/leftovers"               element={<ProtectedRoute><LeftoversScreen /></ProtectedRoute>} />
        <Route path="/inventory"               element={<ProtectedRoute><InventoryScreen /></ProtectedRoute>} />
        <Route path="/inventory-categories"    element={<ProtectedRoute><InventoryCategoriesScreen /></ProtectedRoute>} />
        <Route path="/inventory-alerts"        element={<ProtectedRoute><InventoryAlertsScreen /></ProtectedRoute>} />
        <Route path="/groceries"               element={<ProtectedRoute><GroceriesScreen /></ProtectedRoute>} />
        <Route path="/grocery-list-detail/:id" element={<ProtectedRoute><GroceryListDetailScreen /></ProtectedRoute>} />
        <Route path="/receipts"                element={<ProtectedRoute><ReceiptsScreen /></ProtectedRoute>} />

        {/* Catch-all */}
        <Route path="*" element={<Navigate to="/splash" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
