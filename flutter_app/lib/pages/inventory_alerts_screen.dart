import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';

class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _alerts = [];
  bool _loading = true;
  bool _generating = false;

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
    setState(() => _generating = true);
    try {
      await _apiService.generateInventoryAlerts();
      await _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerts refreshed!'),
            backgroundColor: Color(0xFF388E3C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _generating = false);
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.markAllAlertsAsRead();
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.markAlertAsRead(id);
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAlert(String id) async {
    try {
      await _apiService.deleteAlert(id);
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
        return const Color(0xFF388E3C);
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

  @override
  Widget build(BuildContext context) {
    final unread = _alerts.where((a) => a['is_read'] != true).toList();
    final read = _alerts.where((a) => a['is_read'] == true).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C)))
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    size: 18, color: Color(0xFF388E3C)),
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
                                          color: const Color(0xFF2E3E33))),
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
                                        color: const Color(0xFF388E3C),
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
                          child: ElevatedButton.icon(
                            onPressed: _generating ? null : _generateAlerts,
                            icon: _generating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.refresh, color: Colors.white),
                            label: Text(
                              _generating ? 'Scanning...' : 'Scan Inventory for Alerts',
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Alert list
                      Expanded(
                        child: _alerts.isEmpty
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.notifications_none, size: 48, color: Color(0xFF388E3C)),
          ),
          const SizedBox(height: 20),
          Text('No Alerts',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3E33))),
          const SizedBox(height: 8),
          Text('Tap "Scan Inventory" to check for low stock and expiring items',
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
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const Expanded(child: Divider(indent: 10)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(dynamic alert) {
    final type = alert['alert_type'] as String?;
    final message = alert['message'] ?? '';
    final isRead = alert['is_read'] == true;
    final id = alert['_id'] ?? '';
    final color = _alertColor(type);
    final icon = _alertIcon(type);
    final label = _alertLabel(type);
    final createdAt = alert['createdAt'] ?? '';

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
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteAlert(id),
      child: GestureDetector(
        onTap: isRead ? null : () => _markAsRead(id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isRead
                ? null
                : Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isRead ? 0.02 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
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
                      Text(message,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF2E3E33),
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                          )),
                    ],
                  ),
                ),
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
