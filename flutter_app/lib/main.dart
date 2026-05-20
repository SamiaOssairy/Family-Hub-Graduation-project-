import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/signup_login.dart';
import 'pages/home.dart';
import 'pages/setting.dart';
import 'pages/splash_screen.dart';
import 'pages/onboarding_screen.dart';
import 'pages/dashboard_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'pages/tasks_screen.dart';
import 'pages/status_screen.dart';
import 'pages/rewards_screen.dart';
import 'pages/redeem_screen.dart';
import 'pages/task_management_screen.dart';
import 'pages/family_points_screen.dart';
import 'pages/inventory_screen.dart';
import 'pages/inventory_categories_screen.dart';
import 'pages/meals_screen.dart';
import 'pages/food_hub_screen.dart';
import 'pages/recipes_screen.dart';
import 'pages/leftovers_screen.dart';
import 'pages/meal_suggestions_screen.dart';
import 'pages/receipts_screen.dart';
import 'pages/inventory_alerts_screen.dart';
import 'pages/groceries_screen.dart';
import 'pages/grocery_list_detail_screen.dart';
import 'pages/family_map_screen.dart';
import 'pages/wallet/combined_wallet_screen.dart';
import 'pages/wallet/balance_wallet_details_screen.dart';
import 'pages/analytics/combined_analytics_screen.dart';
import 'core/services/api_service.dart';
import 'core/services/locale_service.dart';
import 'package:provider/provider.dart';
import 'package:app_frontend/pages/budget/budget_provider.dart';
import 'package:app_frontend/pages/budget/budget_dashboard_screen.dart';
import 'package:app_frontend/pages/budget/event_funding_screen.dart';
import 'pages/planning_chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleService.loadSavedLocale();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FamilyBudgetProvider>(create: (_) {
          final provider = FamilyBudgetProvider();
          provider.init();
          return provider;
        }),
        ChangeNotifierProvider<ThemeProvider>(create: (_) {
          final tp = ThemeProvider();
          tp.loadTheme();
          return tp;
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ValueListenableBuilder<Locale?>(
            valueListenable: LocaleService.localeNotifier,
            builder: (context, locale, _) {
              return MaterialApp(
                title: 'Family Hub',
                debugShowCheckedModeBanner: false,
                locale: locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ar'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: appLightTheme,
                darkTheme: appDarkTheme,
                themeMode: themeProvider.themeMode,
                home: const AuthBootstrapScreen(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginPage(),
              '/home': (context) => const HomePage(),
              '/settings': (context) => const SettingPage(),
              '/dashboard': (context) => const DashboardScreen(),
              '/tasks': (context) => const TasksScreen(),
              '/status': (context) => const StatusScreen(),
              '/rewards': (context) => const RewardsScreen(),
              '/redeem': (context) => const RedeemScreen(),
              '/task-management': (context) => const TaskManagementScreen(),
              '/family-points': (context) => const FamilyPointsScreen(),
              '/inventory': (context) => const InventoryScreen(),
              '/inventory-categories': (context) => const InventoryCategoriesScreen(),
              '/meals': (context) => const MealsScreen(),
              '/food-hub': (context) => const FoodHubScreen(),
              '/recipes': (context) => const RecipesScreen(),
              '/leftovers': (context) => const LeftoversScreen(),
              '/meal-suggestions': (context) => const MealSuggestionsScreen(),
              '/receipts': (context) => const ReceiptsScreen(),
              '/inventory-alerts': (context) => const InventoryAlertsScreen(),
              '/groceries': (context) => const GroceriesScreen(),
              '/grocery-list-detail': (context) => const GroceryListDetailScreen(),
              '/budget': (context) => const BudgetDashboardScreen(),
              '/event-funding': (context) => const EventFundingScreen(),
              '/family-map': (context) => const FamilyMapScreen(),
              '/combined-wallet': (context) => const CombinedWalletScreen(),
              '/wallet-details': (context) => const BalanceWalletDetailsScreen(),
              '/combined-analytics': (context) => const CombinedAnalyticsScreen(),
              '/planning-chat': (context) => const PlanningChatScreen(),
            },
          );
        },
      );
    },
  ),
);
  }
}

class AuthBootstrapScreen extends StatefulWidget {
  const AuthBootstrapScreen({super.key});

  @override
  State<AuthBootstrapScreen> createState() => _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends State<AuthBootstrapScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final hasSession = await _apiService.hasActiveSession();

      if (hasSession) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      final activeKey = await _apiService.getActiveProfileKey();
      if (activeKey != null && activeKey.isNotEmpty) {
        try {
          await _apiService.switchProfile(activeKey);
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        } catch (_) {
          // Fall through to login if saved active profile cannot be restored.
        }
      }
    } catch (_) {
      // Fall through to login.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
