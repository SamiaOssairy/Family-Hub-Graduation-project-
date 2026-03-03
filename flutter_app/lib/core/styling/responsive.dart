import 'package:flutter/material.dart';

/// Professional responsive sizing — inspired by Talabat, Instashop, etc.
/// 
/// Key philosophy: On desktop, fonts/icons stay at MOBILE size.
/// Extra screen space goes to LAYOUT (max-width, more columns, whitespace)
/// — NOT to enlarging elements.
/// 
/// Usage:
/// ```dart
/// import 'responsive.dart';
/// 
/// // Wrap your page content in ContentContainer for max-width centering:
/// ContentContainer(child: YourContent())
/// 
/// // Responsive width (percentage of screen)
/// width: Responsive.width(context, 100),
/// 
/// // Font size — stays constant across all screen sizes
/// fontSize: Responsive.fontSize(context, 18),
/// 
/// // Icon size — stays constant across all screen sizes
/// size: Responsive.iconSize(context, 24),
/// 
/// // Spacing — very slight increase on larger screens for breathing room
/// padding: Responsive.spacing(context, 16),
/// ```

class Responsive {
  // Design reference size (iPhone standard)
  static const double _designWidth = 375;
  static const double _designHeight = 812;
  
  // Max content width for desktop (like Talabat/Instashop login forms)
  static const double maxContentWidth = 480;
  // Max content width for wider layouts (dashboards, grids)
  static const double maxWideContentWidth = 900;
  
  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get responsive width (percentage-based)
  static double width(BuildContext context, double percentage) {
    return screenWidth(context) * (percentage / 100);
  }

  /// Get responsive height (percentage-based)
  static double height(BuildContext context, double percentage) {
    return screenHeight(context) * (percentage / 100);
  }

  /// Font size — NO SCALING. Same size on mobile, tablet, desktop.
  /// Professional apps (Talabat, Instashop) keep text at standard web sizes.
  static double fontSize(BuildContext context, double baseSize) {
    return baseSize;
  }

  /// Icon size — NO SCALING. Icons stay compact and crisp.
  static double iconSize(BuildContext context, double baseSize) {
    return baseSize;
  }

  /// Responsive spacing (margins, padding, gaps)
  /// Very slight increase on tablet/desktop for breathing room only.
  /// On mobile: 1:1, on tablet: 1.05x, on desktop: 1.1x max.
  static double spacing(BuildContext context, double baseSpacing) {
    double sw = MediaQuery.of(context).size.width;
    
    if (sw < 600) {
      return baseSpacing;
    } else if (sw < 1200) {
      // Tablet: barely noticeable scaling
      double scaleFactor = 1 + ((sw - 600) / 600) * 0.05;
      return baseSpacing * scaleFactor;
    } else {
      // Desktop: cap at 1.1x
      return baseSpacing * 1.1;
    }
  }

  /// Check device type
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < 600;
  }

  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= 600 && screenWidth(context) < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= 1200;
  }

  /// Get grid cross-axis count based on screen width
  /// More columns on wider screens (like Talabat product grids)
  static int gridColumns(BuildContext context, {int mobileCols = 2, int tabletCols = 3, int desktopCols = 4}) {
    if (isMobile(context)) return mobileCols;
    if (isTablet(context)) return tabletCols;
    return desktopCols;
  }

  /// Get device orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Device padding (safe area)
  static EdgeInsets devicePadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Device view insets (keyboard, etc)
  static EdgeInsets viewInsets(BuildContext context) {
    return MediaQuery.of(context).viewInsets;
  }
}

/// Content container that centers content with a max-width on desktop.
/// This is the #1 pattern used by Talabat, Instashop, and other professional apps.
/// On mobile: full width. On desktop: centered with max-width, like a card.
class ContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Common responsive values
class AppSize {
  // Spacing
  static double xs(BuildContext context) => Responsive.spacing(context, 4);
  static double sm(BuildContext context) => Responsive.spacing(context, 8);
  static double md(BuildContext context) => Responsive.spacing(context, 16);
  static double lg(BuildContext context) => Responsive.spacing(context, 24);
  static double xl(BuildContext context) => Responsive.spacing(context, 32);
  static double xxl(BuildContext context) => Responsive.spacing(context, 48);

  // Font sizes — no scaling
  static double h1(BuildContext context) => 32;
  static double h2(BuildContext context) => 28;
  static double h3(BuildContext context) => 24;
  static double h4(BuildContext context) => 20;
  static double bodyLarge(BuildContext context) => 16;
  static double bodyMedium(BuildContext context) => 14;
  static double bodySmall(BuildContext context) => 12;
  static double caption(BuildContext context) => 10;

  // Icon sizes — no scaling
  static double iconSm(BuildContext context) => 16;
  static double iconMd(BuildContext context) => 24;
  static double iconLg(BuildContext context) => 32;
  static double iconXl(BuildContext context) => 48;

  // Button heights
  static double buttonSmall(BuildContext context) => 36;
  static double buttonMedium(BuildContext context) => 44;
  static double buttonLarge(BuildContext context) => 52;
}

/// Padding helper
class AppPadding {
  static EdgeInsets all(BuildContext context, double size) {
    return EdgeInsets.all(Responsive.spacing(context, size));
  }

  static EdgeInsets symmetric(BuildContext context, {double horizontal = 16, double vertical = 16}) {
    return EdgeInsets.symmetric(
      horizontal: Responsive.spacing(context, horizontal),
      vertical: Responsive.spacing(context, vertical),
    );
  }

  static EdgeInsets only(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: Responsive.spacing(context, left),
      top: Responsive.spacing(context, top),
      right: Responsive.spacing(context, right),
      bottom: Responsive.spacing(context, bottom),
    );
  }
}

/// Border radius helper
class AppRadius {
  static BorderRadius circular(BuildContext context, double radius) {
    return BorderRadius.circular(radius);
  }

  static BorderRadius xs(BuildContext context) => BorderRadius.circular(4);
  static BorderRadius sm(BuildContext context) => BorderRadius.circular(8);
  static BorderRadius md(BuildContext context) => BorderRadius.circular(12);
  static BorderRadius lg(BuildContext context) => BorderRadius.circular(16);
  static BorderRadius xl(BuildContext context) => BorderRadius.circular(20);
  static BorderRadius full(BuildContext context) => BorderRadius.circular(100);
}
