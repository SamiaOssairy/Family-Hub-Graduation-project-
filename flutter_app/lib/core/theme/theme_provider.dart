import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

// ── Color palettes ─────────────────────────────────────────────────────────────
enum AppPalette { teal, ocean, purple, coral, forest }

extension AppPaletteExtension on AppPalette {
  Color get seed {
    switch (this) {
      case AppPalette.teal:   return const Color(0xFF00897B);
      case AppPalette.ocean:  return const Color(0xFF1565C0);
      case AppPalette.purple: return const Color(0xFF7B1FA2);
      case AppPalette.coral:  return const Color(0xFFE53935);
      case AppPalette.forest: return const Color(0xFF2E7D32);
    }
  }

  String get displayName {
    switch (this) {
      case AppPalette.teal:   return 'Teal';
      case AppPalette.ocean:  return 'Ocean';
      case AppPalette.purple: return 'Purple';
      case AppPalette.coral:  return 'Coral';
      case AppPalette.forest: return 'Forest';
    }
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppPalette _palette  = AppPalette.teal;

  ThemeMode  get themeMode => _themeMode;
  bool       get isDark    => _themeMode == ThemeMode.dark;
  AppPalette get palette   => _palette;

  /// Dynamic themes based on the selected palette seed color.
  ThemeData get lightTheme => buildLightTheme(_palette.seed);
  ThemeData get darkTheme  => buildDarkTheme(_palette.seed);

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final isDarkPref  = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDarkPref ? ThemeMode.dark : ThemeMode.light;

    final paletteName = prefs.getString('appPalette') ?? 'teal';
    _palette = AppPalette.values.firstWhere(
      (p) => p.name == paletteName,
      orElse: () => AppPalette.teal,
    );

    // Sync global AppColors.primary so every widget using it picks up the saved palette.
    AppColors.primary = _palette.seed;

    notifyListeners();
  }

  // ── Theme mode ───────────────────────────────────────────────────────────────

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    notifyListeners();
  }

  // ── Palette ──────────────────────────────────────────────────────────────────

  Future<void> setPalette(AppPalette palette) async {
    _palette = palette;
    // Update global AppColors.primary immediately so all widgets using
    // AppColors.primary / derived getters (primarySurface, gradients, etc.)
    // pick up the new color on the next rebuild triggered by notifyListeners().
    AppColors.primary = palette.seed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appPalette', palette.name);
    notifyListeners();
  }
}
