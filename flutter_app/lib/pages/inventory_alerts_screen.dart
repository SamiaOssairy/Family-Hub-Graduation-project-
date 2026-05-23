import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/guarded_button.dart';

class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> {
  final ApiService _apiService = ApiService();

  bool _isDark = false;
  List<dynamic> _alerts = [];
  bool _loading = true;
  String _filterType = 'all'; // all, low_stock, out_of_stock, expiring_soon, expired

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final alerts = await _apiService.getInventoryAlertsPersisted();
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _generateAlerts() async {
    try {
      await _apiService.generateInventoryAlerts();
      await _loadAlerts();
      if (mounted) showSuccessSnack(context, 'Alerts refreshed!');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.markAllAlertsAsRead();
      _loadAlerts();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.markAlertAsRead(id);
      _loadAlerts();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  Future<void> _deleteAlert(String id) async {
    try {
      await _apiService.deleteAlert(id);
      _loadAlerts();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  int get _unreadCount => _alerts.where((a) => a['is_read'] != true).length;

  IconData _alertIcon(String? type) {
    switch (type) {
      case 'low_stock':
        return Icons.trending_down;
      case 'out_of_stock':
        return Icons.remove_shopping_cart;
      case 'expiring_soon':
        return Icons.schedule;
      case 'expired':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _alertColor(String? type) {
    switch (type) {
      case 'low_stock':
        return Colors.orange;
      case 'out_of_stock':
        return Colors.red;
      case 'expiring_soon':
        return Colors.amber[700]!;
      case 'expired':
        return Colors.red[800]!;
      default:
        return const Color(0xFF00897B);
    }
  }

  String _alertLabel(String? type) {
    switch (type) {
      case 'low_stock':
        return 'Low Stock';
      case 'out_of_stock':
        return 'Out of Stock';
      case 'expiring_soon':
        return 'Expiring Soon';
      case 'expired':
        return 'Expired';
      default:
        return 'Alert';
    }
  }

  List<dynamic> get _filteredAlerts {
    if (_filterType == 'all') return _alerts;
    return _alerts.where((a) => a['alert_type'] == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = context.watch<ThemeProvider>().isDark;
    final bg = _isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5);
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);
    final filtered = _filteredAlerts;
    final unread = filtered.where((a) => a['is_read'] != true).toList();
    final read = filtered.where((a) => a['is_read'] == true).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isDark ? const Color(0xFF122030) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.arrow_back_ios_new,
                                    size: 18, color: Color(0xFF00897B)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Inventory Alerts',
                                      style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary)),
                                  if (_unreadCount > 0)
                                    Text('$_unreadCount unread',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (_unreadCount > 0)
                              TextButton(
                                onPressed: _markAllRead,
                                child: Text('Read All',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF00897B),
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),

                      // Generate button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: GuardedElevatedButton(
                            onPressed: _generateAlerts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Scan Inventory for Alerts',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('all', 'All', Icons.list, _alerts.length),
                              const SizedBox(width: 8),
                              _filterChip('low_stock', 'Low Stock', Icons.trending_down,
                                  _alerts.where((a) => a['alert_type'] == 'low_stock').length),
                              const SizedBox(width: 8),
                              _filterChip('out_of_stock', 'Out of Stock', Icons.remove_shopping_cart,
                                  _alerts.where((a) => a['alert_type'] == 'out_of_stock').length),
                              const SizedBox(width: 8),
                              _filterChip('expiring_soon', 'Expiring', Icons.schedule,
                                  _alerts.where((a) => a['alert_type'] == 'expiring_soon').length),
                              const SizedBox(width: 8),
                              _filterChip('expired', 'Expired', Icons.warning,
                                  _alerts.where((a) => a['alert_type'] == 'expired').length),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Alert list
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _loadAlerts,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  children: [
                                    if (unread.isNotEmpty) ...[
                                      _sectionHeader('New', unread.length),
                                      ...unread.map((a) => _buildAlertCard(a)),
                                      const SizedBox(height: 16),
                                    ],
                                    if (read.isNotEmpty) ...[
                                      _sectionHeader('Read', read.length),
                                      ...read.map((a) => _buildAlertCard(a)),
                                    ],
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String type, String label, IconData icon, int count) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00897B)
              : (_isDark ? const Color(0xFF122030) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00897B)
                : (_isDark ? const Color(0xFF1E3A4A) : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text('$label ($count)',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);
    final bg = _isDark ? const Color(0xFF0F1F35) : const Color(0xFFE0F2F1);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(Icons.notifications_none,
                size: 48, color: Color(0xFF00897B)),
          ),
          const SizedBox(height: 20),
          Text(
              _filterType != 'all'
                  ? 'No ${_alertLabel(_filterType)} alerts'
                  : 'No Alerts',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary)),
          const SizedBox(height: 8),
          Text(
              _filterType != 'all'
                  ? 'Try a different filter or scan inventory'
                  : 'Tap "Scan Inventory" to check for low stock and expiring items',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$title ($count)',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const Expanded(child: Divider(indent: 10)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(dynamic alert) {
    final type = alert['alert_type'] as String?;
    // ── Fix: field is alert_message not message ──
    final message = (alert['alert_message'] ?? alert['message'] ?? '').toString();
    final isRead = alert['is_read'] == true;
    final id = (alert['_id'] ?? '').toString();
    final color = _alertColor(type);
    final icon = _alertIcon(type);
    final label = _alertLabel(type);
    final createdAt = (alert['createdAt'] ?? '').toString();
    final cardBg = _isDark ? const Color(0xFF122030) : Colors.white;
    final cardBorder = _isDark ? const Color(0xFF1E3A4A) : color.withValues(alpha: 0.3);
    final textPrimary = _isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    // ── Extract populated item details ──
    final item = alert['inventory_item_id'];
    final itemName = item is Map ? (item['item_name'] ?? '').toString() : '';
    final itemQty = item is Map ? item['quantity'] : null;
    final itemThreshold = item is Map ? item['threshold_quantity'] : null;
    final unitName = item is Map && item['unit_id'] is Map
        ? (item['unit_id']['unit_name'] ?? '').toString()
        : '';
    final expiryRaw = item is Map ? (item['expiry_date'] ?? '').toString() : '';
    final categoryName = item is Map && item['item_category'] is Map
        ? (item['item_category']['title'] ?? '').toString()
        : '';

    // Format expiry date
    String expiryDisplay = '';
    int daysUntilExpiry = 9999;
    if (expiryRaw.isNotEmpty) {
      try {
        final expiryDt = DateTime.parse(expiryRaw);
        daysUntilExpiry = expiryDt.difference(DateTime.now()).inDays;
        expiryDisplay = DateFormat('MMM d, yyyy').format(expiryDt);
      } catch (_) {}
    }

    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = DateFormat('MMM d').format(dt);
      }
    } catch (_) {}

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) => _deleteAlert(id),
      child: GestureDetector(
        onTap: isRead ? null : () => _markAsRead(id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: isRead ? null : Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isRead ? 0.02 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          if (timeAgo.isNotEmpty)
                            Text(timeAgo,
                                style: GoogleFonts.poppins(
                                    fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Item name (big, prominent)
                      if (itemName.isNotEmpty)
                        Text(itemName,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary)),

                      // Category
                      if (categoryName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(categoryName,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[500])),
                      ],

                      const SizedBox(height: 8),

                      // Detail rows based on type
                      if (type == 'expired' && expiryDisplay.isNotEmpty)
                        _detailRow(Icons.event_busy, 'Expired on $expiryDisplay',
                            Colors.red[700]!),

                      if (type == 'expiring_soon' && expiryDisplay.isNotEmpty)
                        _detailRow(
                          Icons.schedule,
                          daysUntilExpiry == 0
                              ? 'Expires today!'
                              : daysUntilExpiry == 1
                                  ? 'Expires tomorrow · $expiryDisplay'
                                  : 'Expires in $daysUntilExpiry days · $expiryDisplay',
                          Colors.orange[700]!,
                        ),

                      if ((type == 'low_stock' || type == 'out_of_stock') &&
                          itemQty != null) ...[
                        _detailRow(
                          Icons.inventory_2_outlined,
                          'Current stock: $itemQty${unitName.isNotEmpty ? ' $unitName' : ''}',
                          color,
                        ),
                        if (itemThreshold != null)
                          _detailRow(
                            Icons.flag_outlined,
                            'Minimum threshold: $itemThreshold${unitName.isNotEmpty ? ' $unitName' : ''}',
                            Colors.grey[600]!,
                          ),
                      ],

                      // Fallback: show the raw message if no item details
                      if (itemName.isEmpty && message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(message,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: textPrimary,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w500)),
                      ],

                      // Tap hint for unread
                      if (!isRead) ...[
                        const SizedBox(height: 6),
                        Text('Tap to mark as read',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey[400])),
                      ],
                    ],
                  ),
                ),
                // Unread dot
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
