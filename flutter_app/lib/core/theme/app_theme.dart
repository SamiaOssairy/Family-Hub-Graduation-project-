import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Mutable seed — updated by ThemeProvider.setPalette() ──────────────────
  // All derived getters below automatically use the new value on every rebuild.
  static Color primary = const Color(0xFF00897B);

  // ── Derived accent colours ────────────────────────────────────────────────
  static Color get primaryLight   => Color.lerp(primary, Colors.white, 0.32)!;
  static Color get primarySurface => Color.lerp(primary, Colors.white, 0.88)!;

  // ── Background ────────────────────────────────────────────────────────────
  static Color get background     => Color.lerp(primary, Colors.white, 0.93)!;
  static const Color navBg        = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────────────
  // textPrimary stays const (near-black) so it works in const contexts.
  static const Color textPrimary  = Color(0xFF00352E);
  static const Color textSecondary = Color(0xFF4DB6AC);
  static const Color textHint     = Color(0xFF80CBC4);

  // ── Borders ──────────────────────────────────────────────────────────────
  static Color get border         => Color.lerp(primary, Colors.white, 0.65)!;
  static Color get borderLight    => Color.lerp(primary, Colors.white, 0.85)!;

  // ── Status / Badge ────────────────────────────────────────────────────────
  static const Color success        = Color(0xFF43A047);
  static const Color successSurface = Color(0xFFE8F5F5);
  static const Color warning        = Color(0xFFFB8C00);
  static const Color warningSurface = Color(0xFFFFF3E0);
  static const Color error          = Color(0xFFE53935);
  static const Color errorSurface   = Color(0xFFFFEBEE);
  static Color get onlineDot        => primary;

  // ── Food module accent (kept separate so food screens stay on-brand) ──────
  static const Color foodPrimary   = Color(0xFF43A047);

  // ── Member Ring Colors ────────────────────────────────────────────────────
  static const Color ring1 = Color(0xFFCE93D8);
  static const Color ring2 = Color(0xFF80DEEA);
  static const Color ring3 = Color(0xFFFFCC80);
  static const Color ring4 = Color(0xFFF48FB1);
  static const Color ring5 = Color(0xFFA5D6A7);
  static const Color ring6 = Color(0xFF90CAF9);

  // ── Gradients ────────────────────────────────────────────────────────────
  // Non-const getters so they automatically reflect the current primary.
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [
      Color.lerp(primary, Colors.black, 0.22)!,
      Color.lerp(primary, Colors.white, 0.22)!,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get heroGradient => LinearGradient(
    colors: [
      primary,
      Color.lerp(primary, Colors.white, 0.28)!,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  static const Color darkBg     = Color(0xFF0A1628);
  static const Color darkCard   = Color(0xFF122030);
  static const Color darkBorder = Color(0xFF1E3A4A);
  static const Color darkText   = Color(0xFFE0F2F1);

  // ── Backwards-compat aliases ──────────────────────────────────────────────
  static Color get secondary => Color.lerp(primary, Colors.white, 0.35)!;
  static const Color textDark = textPrimary;
  static Color get light      => primaryLight;
  static Color get dark       => Color.lerp(primary, Colors.black, 0.25)!;
  static const Color white    = Color(0xFFFFFFFF);
  static Color get cardBg     => primarySurface;
}

class AppRadius {
  AppRadius._();
  static const double card    = 16.0;
  static const double button  = 14.0;
  static const double chip    = 20.0;
  static const double icon    = 11.0;
  static const double navItem = 12.0;
  static const double input   = 12.0;
}

class AppText {
  AppText._();

  // Getters (not fields) so they always use the current AppColors.primary value.
  static TextStyle get pageTitle => GoogleFonts.poppins(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static TextStyle get sectionLabel => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8,
  );
  static TextStyle get cardTitle => GoogleFonts.poppins(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static TextStyle get cardSubtitle => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static TextStyle get statValue => GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle get badge => GoogleFonts.poppins(
    fontSize: 9, fontWeight: FontWeight.w600,
  );
  static TextStyle get navLabel => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey,
  );
  static TextStyle get navLabelActive => GoogleFonts.poppins(
    fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary,
  );
  static TextStyle get memberName => GoogleFonts.poppins(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static TextStyle get memberRole => GoogleFonts.poppins(
    fontSize: 9, fontWeight: FontWeight.w400,
  );
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration get card => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.border, width: 0.8),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  static BoxDecoration get cardWithShadow => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.border, width: 0.8),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 5)),
    ],
  );

  static BoxDecoration get primaryGradientCard => BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(AppRadius.card),
    boxShadow: [
      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );

  // No longer const — primaryGradient is now a getter.
  static BoxDecoration get aiGradient => BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
  );

  static BoxDecoration iconWrap(Color bg) => BoxDecoration(
    color: bg, borderRadius: BorderRadius.circular(AppRadius.icon),
  );

  static BoxDecoration get navItem => BoxDecoration(
    color: AppColors.primarySurface, borderRadius: BorderRadius.circular(AppRadius.navItem),
  );
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class AppSectionLabel extends StatelessWidget {
  final String label;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? trailing;
  const AppSectionLabel({super.key, required this.label, this.actionText, this.onAction, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppText.sectionLabel),
        const Spacer(),
        if (trailing != null) trailing!,
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionText!,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }
}

// ── Static theme objects (kept for backward-compat; main.dart uses dynamic builders) ──

ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primaryLight,
    surface: AppColors.white,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(),
  cardTheme: CardThemeData(
    color: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: AppColors.border, width: 0.8),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.white,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: Colors.grey,
    elevation: 0,
  ),
  dividerColor: AppColors.borderLight,
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey),
    trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.primarySurface : Colors.grey.shade200),
  ),
);

ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBg,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.primaryLight,
    surface: AppColors.darkCard,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  cardTheme: CardThemeData(
    color: AppColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.darkBorder, width: 0.8),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBg,
    elevation: 0,
    iconTheme: const IconThemeData(color: AppColors.darkText),
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkCard,
    selectedItemColor: AppColors.primaryLight,
    unselectedItemColor: Colors.grey,
  ),
  dividerColor: AppColors.darkBorder,
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey),
    trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.primarySurface : Colors.grey.shade800),
  ),
);

// ── Dynamic theme builders (used by ThemeProvider for palette support) ────────

ThemeData buildLightTheme(Color seed) {
  final cs  = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  final bg  = Color.lerp(seed, Colors.white, 0.93)!;
  final srf = Color.lerp(seed, Colors.white, 0.88)!;
  final bdr = Color.lerp(seed, Colors.white, 0.65)!;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,
    textTheme: GoogleFonts.poppinsTextTheme(),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: bdr, width: 0.8),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: cs.primary,
      unselectedItemColor: Colors.grey,
      elevation: 0,
    ),
    dividerColor: Color.lerp(seed, Colors.white, 0.80)!,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? cs.primary : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? srf : Colors.grey.shade200),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? cs.primary : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: cs.primary,
    ),
  );
}

ThemeData buildDarkTheme(Color seed) {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: cs,
    scaffoldBackgroundColor: AppColors.darkBg,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.8),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.darkText),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkCard,
      selectedItemColor: cs.primary,
      unselectedItemColor: Colors.grey,
    ),
    dividerColor: AppColors.darkBorder,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? cs.primary : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? cs.primaryContainer : Colors.grey.shade800),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? cs.primary : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: cs.primary,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const AppProgressBar({super.key, required this.value, this.color, this.height = 3});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: AppColors.borderLight,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.primary),
        minHeight: height,
      ),
    );
  }
}
