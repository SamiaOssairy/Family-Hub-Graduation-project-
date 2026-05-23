import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shared teal bottom nav — 5 tabs matching home.dart style.
/// Indices: 0 Home · 1 Dashboard · 2 AI Chat · 3 Location · 4 Settings
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  const AppBottomNav({super.key, this.selectedIndex = 0});

  double _sp(BuildContext context, double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(context, 0, '🏠', 'Home'),
              _item(context, 1, '⊞', 'Dashboard'),
              _item(context, 2, '🤖', 'AI Chat'),
              _item(context, 3, '📍', 'Location'),
              _item(context, 4, '⚙️', 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, String emoji, String label) {
    final isActive = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (isActive) return;
        switch (index) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(context, '/dashboard'); break;
          case 2: Navigator.pushNamed(context, '/planning-chat'); break;
          case 3: Navigator.pushReplacementNamed(context, '/family-map'); break;
          case 4: Navigator.pushReplacementNamed(context, '/settings'); break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primarySurface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: _sp(context, 10),
              color: isActive ? AppColors.primary : const Color(0xFF9E9E9E),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
