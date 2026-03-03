import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';

class FoodHubScreen extends StatefulWidget {
  const FoodHubScreen({super.key});

  @override
  State<FoodHubScreen> createState() => _FoodHubScreenState();
}

class _FoodHubScreenState extends State<FoodHubScreen> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  String _familyTitle = '';

  // Stats
  int _totalItems = 0;
  int _lowStockCount = 0;
  int _totalRecipes = 0;
  int _totalLeftovers = 0;
  int _expiringLeftovers = 0;
  int _unreadAlerts = 0;
  List<dynamic> _recentItems = [];
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
        _apiService.getAllReceipts(),
      ]);

      final items = results[0] as List<dynamic>;
      final recipes = results[1] as List<dynamic>;
      final leftovers = results[2] as List<dynamic>;
      final expiring = results[3] as List<dynamic>;
      final alertCount = results[4] as int;

      int lowStock = 0;
      for (var item in items) {
        final qty = item['quantity'] ?? 0;
        final thresh = item['threshold_quantity'] ?? 1;
        if (qty is num && thresh is num && qty <= thresh) lowStock++;
      }

      setState(() {
        _totalItems = items.length;
        _lowStockCount = lowStock;
        _totalRecipes = recipes.length;
        _totalLeftovers = leftovers.length;
        _expiringLeftovers = expiring.length;
        _unreadAlerts = alertCount;
        _recentItems = items.take(5).toList();
        _expiringList = expiring.take(4).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          if (_expiringList.isNotEmpty) ...[
                            _buildExpiringSection(),
                            const SizedBox(height: 24),
                          ],
                          _buildRecentItems(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_familyTitle Family',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                'Food Hub',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E3E33),
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/inventory-alerts'),
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF388E3C), size: 28),
            ),
            if (_unreadAlerts > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadAlerts > 9 ? '9+' : '$_unreadAlerts',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Inventory',
            '$_totalItems items',
            Icons.inventory_2_outlined,
            const Color(0xFF388E3C),
            subtitle: _lowStockCount > 0 ? '$_lowStockCount low stock' : null,
            subtitleColor: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Recipes',
            '$_totalRecipes total',
            Icons.menu_book_outlined,
            const Color(0xFFFF9800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Leftovers',
            '$_totalLeftovers tracked',
            Icons.takeout_dining_outlined,
            const Color(0xFF2196F3),
            subtitle: _expiringLeftovers > 0 ? '$_expiringLeftovers expiring' : null,
            subtitleColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E3E33),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: subtitleColor ?? Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E3E33),
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
            _buildActionCard(
              'Inventory',
              Icons.inventory_2_outlined,
              const Color(0xFF388E3C),
              () => Navigator.pushNamed(context, '/inventory'),
            ),
            _buildActionCard(
              'Recipes',
              Icons.menu_book_outlined,
              const Color(0xFFFF9800),
              () => Navigator.pushNamed(context, '/recipes'),
            ),
            _buildActionCard(
              'Meal Plan',
              Icons.calendar_today_outlined,
              const Color(0xFF2196F3),
              () => Navigator.pushNamed(context, '/meals'),
            ),
            _buildActionCard(
              'Leftovers',
              Icons.takeout_dining_outlined,
              const Color(0xFF9C27B0),
              () => Navigator.pushNamed(context, '/leftovers'),
            ),
            _buildActionCard(
              'Suggestions',
              Icons.auto_awesome_outlined,
              const Color(0xFFE91E63),
              () => Navigator.pushNamed(context, '/meal-suggestions'),
            ),
            _buildActionCard(
              'Receipts',
              Icons.receipt_long_outlined,
              const Color(0xFF607D8B),
              () => Navigator.pushNamed(context, '/receipts'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                color: color.withOpacity(0.1),
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
                color: const Color(0xFF2E3E33),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSection() {
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
                color: const Color(0xFF2E3E33),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/leftovers'),
              child: Text('View All',
                  style: GoogleFonts.poppins(color: const Color(0xFF388E3C), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._expiringList.map((lo) {
          final name = lo['name'] ?? 'Unknown';
          final expiry = lo['expiry_date'] ?? '';
          final daysLeft = _daysUntil(expiry);
          final isExpired = daysLeft < 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpired ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isExpired ? Icons.warning : Icons.schedule,
                    color: isExpired ? Colors.red : Colors.orange,
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
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        isExpired
                            ? 'Expired ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago'
                            : daysLeft == 0
                                ? 'Expires today!'
                                : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isExpired ? Colors.red : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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

  Widget _buildRecentItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Inventory Items',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E3E33),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/inventory'),
              child: Text('View All',
                  style: GoogleFonts.poppins(color: const Color(0xFF388E3C), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('No items yet', style: GoogleFonts.poppins(color: Colors.grey[500])),
              ],
            ),
          )
        else
          ..._recentItems.map((item) {
            final name = item['item_name'] ?? 'Unnamed';
            final qty = item['quantity'] ?? 0;
            final unit = item['unit_id'];
            final unitName = unit is Map ? (unit['unit_name'] ?? '') : '';
            final thresh = item['threshold_quantity'] ?? 1;
            final lowStock = qty is num && thresh is num && qty <= thresh;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lowStock ? Colors.red[50] : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      color: lowStock ? Colors.red : const Color(0xFF388E3C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$qty $unitName',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: lowStock ? Colors.red : const Color(0xFF388E3C),
                        ),
                      ),
                      if (lowStock)
                        Text('Low stock',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 2,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/dashboard');
            break;
          case 2:
            break; // Already on Food Hub
          case 3:
            Navigator.pushNamed(context, '/rewards');
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/settings');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Food Hub'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }
}
