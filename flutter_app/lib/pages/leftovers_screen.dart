import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';

class LeftoversScreen extends StatefulWidget {
  const LeftoversScreen({super.key});

  @override
  State<LeftoversScreen> createState() => _LeftoversScreenState();
}

class _LeftoversScreenState extends State<LeftoversScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<dynamic> _leftovers = [];
  List<dynamic> _categories = [];
  List<dynamic> _units = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getAllLeftovers(),
        _apiService.getAllLeftoverCategories(),
        _apiService.getAllUnits(),
      ]);
      setState(() {
        _leftovers = results[0];
        _categories = results[1];
        _units = results[2];
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

  List<dynamic> get _allLeftovers => _leftovers;

  List<dynamic> get _expiringSoon {
    final now = DateTime.now();
    return _leftovers.where((lo) {
      final exp = lo['expiry_date'];
      if (exp == null) return false;
      try {
        final d = DateTime.parse(exp);
        final diff = d.difference(now).inDays;
        return diff >= 0 && diff <= 3;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<dynamic> get _expired {
    final now = DateTime.now();
    return _leftovers.where((lo) {
      final exp = lo['expiry_date'];
      if (exp == null) return false;
      try {
        final d = DateTime.parse(exp);
        return d.isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  int _daysUntil(String? dateStr) {
    if (dateStr == null) return 999;
    try {
      return DateTime.parse(dateStr).difference(DateTime.now()).inDays;
    } catch (_) {
      return 999;
    }
  }

  Color _expiryColor(int days) {
    if (days < 0) return Colors.red;
    if (days == 0) return Colors.deepOrange;
    if (days <= 2) return Colors.orange;
    if (days <= 5) return Colors.amber[700]!;
    return const Color(0xFF388E3C);
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
                              child: Text('Leftover Tracker',
                                  style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2E3E33))),
                            ),
                            _buildSummaryBadge(),
                          ],
                        ),
                      ),

                      // Tabs
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          indicator: BoxDecoration(
                            color: const Color(0xFF388E3C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: [
                            Tab(text: 'All (${_allLeftovers.length})'),
                            Tab(text: 'Expiring (${_expiringSoon.length})'),
                            Tab(text: 'Expired (${_expired.length})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Add button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: Text('Add Leftover',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
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

                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildLeftoverList(_allLeftovers),
                            _buildLeftoverList(_expiringSoon),
                            _buildLeftoverList(_expired),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge() {
    final expCount = _expiringSoon.length + _expired.length;
    if (expCount == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 16, color: Colors.red[400]),
          const SizedBox(width: 4),
          Text('$expCount need attention',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.red[600], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLeftoverList(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.takeout_dining_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No leftovers here',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _buildLeftoverCard(items[i]),
      ),
    );
  }

  Widget _buildLeftoverCard(dynamic lo) {
    final name = lo['name'] ?? 'Unknown';
    final qty = lo['quantity'] ?? 0;
    final unitData = lo['unit_id'];
    final unitName = unitData is Map ? (unitData['unit_name'] ?? '') : '';
    final expiry = lo['expiry_date'];
    final days = _daysUntil(expiry);
    final color = _expiryColor(days);
    final catData = lo['leftover_category_id'];
    final catName = catData is Map ? (catData['name'] ?? '') : '';
    final id = lo['_id'] ?? '';
    final storedAt = lo['stored_at'] ?? '';
    final notes = lo['notes'] ?? '';

    String expiryText;
    if (days < 0) {
      expiryText = 'Expired ${-days} day${-days == 1 ? '' : 's'} ago';
    } else if (days == 0) {
      expiryText = 'Expires today!';
    } else {
      expiryText = 'Expires in $days day${days == 1 ? '' : 's'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    days < 0 ? Icons.warning : Icons.takeout_dining,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF2E3E33))),
                      const SizedBox(height: 2),
                      Text('$qty $unitName',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF388E3C))),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showAddEditDialog(leftover: lo);
                    if (val == 'delete') _deleteLeftover(id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: color),
                const SizedBox(width: 4),
                Text(expiryText,
                    style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                if (catName.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(catName,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.purple[700], fontWeight: FontWeight.w500)),
                  ),
                ],
                if (storedAt.toString().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.kitchen, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text(storedAt, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                ],
              ],
            ),
            if (notes.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(notes,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (expiry != null) ...[
              const SizedBox(height: 8),
              // Expiry progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _expiryProgress(lo),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _expiryProgress(dynamic lo) {
    final created = lo['createdAt'] ?? lo['created_at'];
    final expiry = lo['expiry_date'];
    if (created == null || expiry == null) return 1.0;
    try {
      final start = DateTime.parse(created);
      final end = DateTime.parse(expiry);
      final now = DateTime.now();
      final total = end.difference(start).inHours;
      if (total <= 0) return 1.0;
      final elapsed = now.difference(start).inHours;
      return (elapsed / total).clamp(0.0, 1.0);
    } catch (_) {
      return 1.0;
    }
  }

  void _showAddEditDialog({dynamic leftover}) {
    final isEdit = leftover != null;
    final nameCtrl = TextEditingController(text: isEdit ? (leftover['name'] ?? '') : '');
    final qtyCtrl = TextEditingController(text: isEdit ? '${leftover['quantity'] ?? ''}' : '');
    final notesCtrl = TextEditingController(text: isEdit ? (leftover['notes'] ?? '') : '');
    final storedCtrl = TextEditingController(text: isEdit ? (leftover['stored_at'] ?? '') : '');

    String? selectedUnitId = isEdit
        ? (leftover['unit_id'] is Map ? leftover['unit_id']['_id'] : leftover['unit_id'])
        : null;
    String? selectedCatId = isEdit
        ? (leftover['leftover_category_id'] is Map
            ? leftover['leftover_category_id']['_id']
            : leftover['leftover_category_id'])
        : null;
    DateTime? expiryDate;
    if (isEdit && leftover['expiry_date'] != null) {
      try {
        expiryDate = DateTime.parse(leftover['expiry_date']);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Leftover' : 'Add Leftover',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField('Name', nameCtrl, 'Leftover name'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _dialogField('Quantity', qtyCtrl, '0', isNumber: true)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unit',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButton<String>(
                                    value: selectedUnitId,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    hint: Text('Unit', style: GoogleFonts.poppins(fontSize: 13)),
                                    items: _units.map((u) {
                                      return DropdownMenuItem<String>(
                                        value: u['_id'],
                                        child: Text(u['unit_name'] ?? '',
                                            style: GoogleFonts.poppins(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setDialogState(() => selectedUnitId = val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Category',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButton<String>(
                          value: selectedCatId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: Text('Select category', style: GoogleFonts.poppins(fontSize: 13)),
                          items: _categories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['_id'],
                              child: Text(c['name'] ?? '', style: GoogleFonts.poppins(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedCatId = val),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Expiry Date',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 3)),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => expiryDate = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                expiryDate != null
                                    ? DateFormat('MMM d, yyyy').format(expiryDate!)
                                    : 'Select date',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: expiryDate != null ? Colors.black87 : Colors.grey[400],
                                ),
                              ),
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dialogField('Stored At', storedCtrl, 'e.g. Fridge, Freezer'),
                      const SizedBox(height: 12),
                      _dialogField('Notes', notesCtrl, 'Optional notes', maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final body = <String, dynamic>{
                      'name': nameCtrl.text.trim(),
                      'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                      'unit_id': selectedUnitId,
                      'leftover_category_id': selectedCatId,
                      'stored_at': storedCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                    };
                    if (expiryDate != null) {
                      body['expiry_date'] = expiryDate!.toIso8601String();
                    }
                    try {
                      if (isEdit) {
                        await _apiService.updateLeftover(leftover['_id'], body);
                      } else {
                        await _apiService.addLeftover(body);
                      }
                      Navigator.pop(ctx);
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                  child: Text(isEdit ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLeftover(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Leftover', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _apiService.deleteLeftover(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
