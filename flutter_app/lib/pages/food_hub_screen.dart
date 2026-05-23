import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/app_bottom_nav.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FOOD HUB — Clean Navigation Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class FoodHubScreen extends StatefulWidget {
  const FoodHubScreen({super.key});

  @override
  State<FoodHubScreen> createState() => _FoodHubScreenState();
}

class _FoodHubScreenState extends State<FoodHubScreen> {
  final ApiService _apiService = ApiService();

  bool _isDark = false;
  bool _loading = true;
  String _familyTitle = '';

  // Summary stats
  int _totalItems = 0;
  int _lowStockCount = 0;
  int _totalRecipes = 0;
  int _totalLeftovers = 0;
  int _expiringLeftovers = 0;
  int _unreadAlerts = 0;
  List<dynamic> _expiringList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _familyTitle = prefs.getString('familyTitle') ?? 'My Family';

      final results = await Future.wait([
        _apiService.getAllFamilyItems(),
        _apiService.getAllRecipes(),
        _apiService.getAllLeftovers(),
        _safeGetExpiringLeftovers(),
        _safeGetUnreadAlertCount(),
      ]);

      final items = results[0] as List<dynamic>;
      final recipes = results[1] as List<dynamic>;
      final leftovers = results[2] as List<dynamic>;
      final expiring = results[3] as List<dynamic>;
      final alertCount = results[4] as int;

      int lowStock = 0;
      for (var item in items) {
        if (isLowStock(item)) lowStock++;
      }

      setState(() {
        _totalItems = items.length;
        _lowStockCount = lowStock;
        _totalRecipes = recipes.length;
        _totalLeftovers = leftovers.length;
        _expiringLeftovers = expiring.length;
        _unreadAlerts = alertCount;
        _expiringList = expiring.take(4).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error loading data: $e');
    }
  }

  Future<int> _safeGetUnreadAlertCount() async {
    try {
      return await _apiService.getUnreadAlertCount();
    } catch (_) {
      return 0;
    }
  }

  Future<List<dynamic>> _safeGetExpiringLeftovers() async {
    try {
      final data = await _apiService.getExpiringLeftovers();
      return data['data']?['leftovers'] ?? [];
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _isDark = context.watch<ThemeProvider>().isDark;
    final bg = _isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00897B)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF00897B),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          if (_expiringList.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildExpiringSection(),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);
    final textSec = const Color(0xFF4DB6AC);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_familyTitle\'s Kitchen',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: textSec),
              ),
              Text(
                'Food Hub',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Alerts bell
        Stack(
          children: [
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/inventory-alerts'),
              icon: const Icon(Icons.notifications_outlined,
                  color: Color(0xFF00897B), size: 28),
            ),
            if (_unreadAlerts > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadAlerts > 9 ? '9+' : '$_unreadAlerts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Stat cards row ───────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Inventory',
            '$_totalItems',
            Icons.inventory_2_outlined,
            const Color(0xFF00897B),
            badge: _lowStockCount > 0 ? '$_lowStockCount low' : null,
            badgeColor: const Color(0xFFE53935),
            onTap: () => Navigator.pushNamed(context, '/inventory'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Recipes',
            '$_totalRecipes',
            Icons.menu_book_outlined,
            const Color(0xFFFB8C00),
            onTap: () => Navigator.pushNamed(context, '/recipes'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Leftovers',
            '$_totalLeftovers',
            Icons.takeout_dining_outlined,
            const Color(0xFF00ACC1),
            badge: _expiringLeftovers > 0
                ? '$_expiringLeftovers exp.'
                : null,
            badgeColor: const Color(0xFFFB8C00),
            onTap: () => Navigator.pushNamed(context, '/leftovers'),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    final cardBg = _isDark ? const Color(0xFF122030) : Colors.white;
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);
    final textSec = const Color(0xFF4DB6AC);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: textSec)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            if (badge != null) ...[
              const SizedBox(height: 2),
              Text(badge,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: badgeColor ?? textSec,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _actionCard('Inventory', Icons.inventory_2_outlined,
                const Color(0xFF00897B), '/inventory'),
            _actionCard('Categories', Icons.account_tree_outlined,
                const Color(0xFF6D4C41), '/inventory-categories'),
            _actionCard('Recipes', Icons.menu_book_outlined,
                const Color(0xFFFB8C00), '/recipes'),
            _actionCard('Meal Plan', Icons.calendar_today_outlined,
                const Color(0xFF00ACC1), '/meals'),
            _actionCard('Groceries', Icons.local_grocery_store,
                const Color(0xFF00BCD4), '/groceries'),
            _actionCard('Leftovers', Icons.takeout_dining_outlined,
                const Color(0xFF7B1FA2), '/leftovers'),
            _actionCard('Suggestions', Icons.auto_awesome_outlined,
                const Color(0xFFE91E63), '/meal-suggestions'),
            _actionCard('Receipts', Icons.receipt_long_outlined,
                const Color(0xFF607D8B), '/receipts'),
            _actionCard('Alerts', Icons.notifications_active_outlined,
                const Color(0xFFE53935), '/inventory-alerts'),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(
      String title, IconData icon, Color color, String route) {
    final cardBg = _isDark ? const Color(0xFF122030) : Colors.white;
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Expiring soon ────────────────────────────────────────────────────────

  Widget _buildExpiringSection() {
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expiring Soon',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/leftovers'),
              child: Text('View All',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF00897B),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._expiringList.map(_buildExpiringCard),
      ],
    );
  }

  Widget _buildExpiringCard(dynamic leftover) {
    final name = leftover['name'] ?? 'Unknown';
    final expiry = leftover['expiry_date'] ?? '';
    final daysLeft = _daysUntil(expiry);
    final isExpired = daysLeft < 0;
    final cardBg = _isDark ? const Color(0xFF122030) : Colors.white;
    final alertColor = isExpired ? const Color(0xFFE53935) : const Color(0xFFFB8C00);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpired ? Icons.warning : Icons.schedule,
              color: alertColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E))),
                Text(
                  isExpired
                      ? 'Expired ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago'
                      : daysLeft == 0
                          ? 'Expires today!'
                          : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: alertColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _daysUntil(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return date.difference(DateTime.now()).inDays;
    } catch (_) {
      return 999;
    }
  }
}
