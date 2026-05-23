import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/app_bottom_nav.dart';

// ── Teal category colour palette ──────────────────────────────────────────────
const List<Color> _kCatColors = [
  Color(0xFF00897B), Color(0xFF00ACC1), Color(0xFFFB8C00),
  Color(0xFF4DB6AC), Color(0xFF7B1FA2), Color(0xFFE91E63),
  Color(0xFF1565C0), Color(0xFF6D4C41), Color(0xFF00695C),
];

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isDark = false;
  List<dynamic> _items = [];
  List<dynamic> _categories = [];
  List<dynamic> _inventories = [];
  List<dynamic> _units = [];
  List<dynamic> _budgetPeriods = [];
  Map<String, dynamic>? _inventoryBudgetSummary;
  String? _selectedBudgetPeriodId;
  String _familyTitle = '';
  bool _loading = true;
  String? _selectedCategoryId;
  String? _selectedInventoryId;
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortBy = 'name';
  int _unreadAlerts = 0;

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
        _apiService.getAllInventoryCategories(tree: false),
        _apiService.getAllInventories(),
        _apiService.getAllUnits(),
        _apiService.getInventoryBudgetSummary(includePeriods: true),
      ]);
      int alertCount = 0;
      try {
        alertCount = await _apiService.getUnreadAlertCount();
      } catch (_) {}
      setState(() {
        _items = List<dynamic>.from(results[0] as List);
        _categories = List<dynamic>.from(results[1] as List);
        _inventories = List<dynamic>.from(results[2] as List);
        _units = List<dynamic>.from(results[3] as List);
        _inventoryBudgetSummary = results[4] as Map<String, dynamic>?;
        _budgetPeriods = List<dynamic>.from(
          (_inventoryBudgetSummary?['data']?['available_period_budgets'] as List?) ?? const [],
        );
        _selectedBudgetPeriodId = (_inventoryBudgetSummary?['data']?['selected_period_budget_id'])?.toString();
        _unreadAlerts = alertCount;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error loading inventory: $e');
    }
  }

  Future<void> _loadInventoryBudgetSummary({String? periodBudgetId}) async {
    try {
      final summary = await _apiService.getInventoryBudgetSummary(
        includePeriods: true,
        periodBudgetId: periodBudgetId,
      );
      if (!mounted) return;
      setState(() {
        _inventoryBudgetSummary = summary;
        _budgetPeriods = List<dynamic>.from(
          (summary['data']?['available_period_budgets'] as List?) ?? const [],
        );
        _selectedBudgetPeriodId = (summary['data']?['selected_period_budget_id'])?.toString();
      });
    } catch (_) {
      // Keep inventory usable even when budget summary fails.
    }
  }

  // ── Filtering & Sorting ──────────────────────────────────────

  List<dynamic> get _activeItems {
    if (_selectedInventoryId == null) return _items;
    return _items.where((item) {
      final inv = item['inventory_id'];
      if (inv is Map) return inv['_id'] == _selectedInventoryId;
      return inv == _selectedInventoryId;
    }).toList();
  }

  List<dynamic> get _filteredItems {
    List<dynamic> result = List.from(_activeItems);
    if (_selectedCategoryId != null) {
      result = result.where((item) {
        final cat = item['item_category'];
        if (cat is Map) return cat['_id'] == _selectedCategoryId;
        return cat == _selectedCategoryId;
      }).toList();
    }
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      result = result.where((item) {
        final name = (item['item_name'] ?? '').toString().toLowerCase();
        final catName = _getCategoryName(item).toLowerCase();
        return name.contains(q) || catName.contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'quantity':
        result.sort((a, b) =>
            ((a['quantity'] ?? 0) as num).compareTo((b['quantity'] ?? 0) as num));
        break;
      case 'low_stock':
        result.sort((a, b) {
          final aL = isLowStock(a) ? 0 : 1;
          return aL.compareTo(isLowStock(b) ? 0 : 1);
        });
        break;
      case 'category':
        result.sort(
            (a, b) => _getCategoryName(a).compareTo(_getCategoryName(b)));
        break;
      default:
        result.sort((a, b) => (a['item_name'] ?? '')
            .toString()
            .compareTo((b['item_name'] ?? '').toString()));
    }
    return result;
  }

  String _getCategoryName(dynamic item) {
    final cat = item['item_category'];
    if (cat is Map) return cat['title'] ?? 'Uncategorized';
    final match = _categories.where((c) => c['_id'] == cat).toList();
    if (match.isNotEmpty) return match.first['title'] ?? 'Uncategorized';
    return 'Uncategorized';
  }

  Map<String, List<dynamic>> get _groupedItems {
    final items = _filteredItems;
    final Map<String, List<dynamic>> groups = {};
    for (final item in items) {
      final catName = _getCategoryName(item);
      groups.putIfAbsent(catName, () => []);
      groups[catName]!.add(item);
    }
    return groups;
  }

  int _getItemCountForCategory(String catId) {
    return _activeItems.where((item) {
      final cat = item['item_category'];

      if (cat is Map) return cat['_id'] == catId;
      return cat == catId;
    }).length;
  }

  Map<String, dynamic>? _getBudgetCategorySummary(String categoryId) {
    final categories = (_inventoryBudgetSummary?['data']?['categories'] as List?) ??
        (_inventoryBudgetSummary?['categories'] as List?) ??
        const [];
    for (final entry in categories) {
      if (entry is! Map) continue;
      final entryId = entry['inventory_category_id']?.toString();
      if (entryId == categoryId) {
        return Map<String, dynamic>.from(entry);
      }
    }
    return null;
  }

  // ── Unit dialogs ─────────────────────────────────────────────

  void _showAddUnitDialog(StateSetter setDialogState) {
    final nameCtrl = TextEditingController();
    String selectedType = 'count';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add New Unit',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Name',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                          hintText: 'e.g., kg, liter, piece',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10))),
                  const SizedBox(height: 14),
                  Text('Unit Type',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                      children: ['weight', 'volume', 'count'].map((type) {
                    final isSel = selectedType == type;
                    return Expanded(
                        child: GestureDetector(
                      onTap: () =>
                          setInnerState(() => selectedType = type),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: type != 'count' ? 8 : 0),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF00897B)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Text(
                                type[0].toUpperCase() +
                                    type.substring(1),
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSel
                                        ? Colors.white
                                        : Colors.black87))),
                      ),
                    ));
                  }).toList()),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    await _apiService.createUnit(
                        nameCtrl.text.trim(), selectedType);
                    final u = await _apiService.getAllUnits();
                    setState(() => _units = u);
                    setDialogState(() {});
                    if (mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (mounted) showErrorSnack(context, '$e');
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B)),
                child:
                    const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditUnitDialog(dynamic unit, StateSetter setDialogState) {
    final nameCtrl = TextEditingController(text: unit['unit_name'] ?? '');
    String selectedType = unit['unit_type'] ?? 'count';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setInnerState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit Unit',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Name',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10))),
                  const SizedBox(height: 14),
                  Text('Unit Type',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                      children: ['weight', 'volume', 'count'].map((type) {
                    final isSel = selectedType == type;
                    return Expanded(
                        child: GestureDetector(
                      onTap: () =>
                          setInnerState(() => selectedType = type),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: type != 'count' ? 8 : 0),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF00897B)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Text(
                                type[0].toUpperCase() +
                                    type.substring(1),
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSel
                                        ? Colors.white
                                        : Colors.black87))),
                      ),
                    ));
                  }).toList()),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    await _apiService.updateUnit(unit['_id'],
                        unitName: nameCtrl.text.trim(),
                        unitType: selectedType);
                    final u = await _apiService.getAllUnits();
                    setState(() => _units = u);
                    setDialogState(() {});
                    if (mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (mounted) showErrorSnack(context, '$e');
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B)),
                child:
                    const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Add / Edit Item Dialog ───────────────────────────────────

  DateTime? _tryParseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  void _showAddEditItemDialog({Map<String, dynamic>? existingItem}) {
    final nameCtrl =
        TextEditingController(text: existingItem?['item_name'] ?? '');
    final qtyCtrl = TextEditingController(text: '');
    final minCtrl = TextEditingController(
        text: existingItem != null
            ? existingItem['threshold_quantity']?.toString() ?? '1'
            : '1');
    final double currentQty = existingItem != null
        ? (existingItem['quantity'] is num
            ? (existingItem['quantity'] as num).toDouble()
            : 0.0)
        : 0.0;
    double adjustedQty = currentQty;
    bool isAdding = true;
    String? selectedUnitId;
    String? selectedCategoryId;
    String? selectedInventoryId;
    DateTime? purchaseDate;
    DateTime? expiryDate;

    if (existingItem != null) {
      final unit = existingItem['unit_id'];
      selectedUnitId = unit is Map ? unit['_id'] : unit?.toString();
      final cat = existingItem['item_category'];
      selectedCategoryId = cat is Map ? cat['_id'] : cat?.toString();
      final inv = existingItem['inventory_id'];
      selectedInventoryId = inv is Map ? inv['_id'] : inv?.toString();
      purchaseDate = _tryParseDate(existingItem['purchase_date']);
      expiryDate = _tryParseDate(existingItem['expiry_date']);
    } else {
      if (_selectedInventoryId != null) {
        selectedInventoryId = _selectedInventoryId;
      } else if (_inventories.isNotEmpty) {
        selectedInventoryId = _inventories.first['_id'];
      }
      selectedCategoryId = _selectedCategoryId;
      purchaseDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 420,
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Header
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                      color: const Color(0xFF00897B),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20))),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(existingItem != null ? 'Edit Item' : 'Add New Item',
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon:
                                const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints()),
                      ]),
                ),

                // ── Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Item Name'),
                          const SizedBox(height: 8),
                          TextField(
                              controller: nameCtrl,
                              decoration: _inputDeco('Enter item name')),
                          const SizedBox(height: 16),

                          // ── Category dropdown (unified)
                          _fieldLabel('Category'),
                          const SizedBox(height: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(10)),
                            child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategoryId,
                              hint: Text('Select category',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey)),
                              items: _categories
                                  .map<DropdownMenuItem<String>>((cat) {
                                final path =
                                    buildCategoryPath(cat, _categories);
                                return DropdownMenuItem<String>(
                                    value: cat['_id'],
                                    child: Text(path,
                                        style:
                                            GoogleFonts.poppins(fontSize: 13),
                                        overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) => setDialogState(
                                  () => selectedCategoryId = val),
                            )),
                          ),
                          if (_categories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: GestureDetector(
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  await Navigator.pushNamed(
                                      context, '/inventory-categories');
                                  _loadData();
                                },
                                child: Text(
                                    'No categories \u2014 tap to create one',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF00897B),
                                        decoration:
                                            TextDecoration.underline)),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // ── Unit selector
                          Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _fieldLabel('Unit'),
                                GestureDetector(
                                  onTap: () =>
                                      _showAddUnitDialog(setDialogState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.green[300]!)),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add,
                                              size: 14,
                                              color: Colors.green[800]),
                                          const SizedBox(width: 2),
                                          Text('Add',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.green[800],
                                                  fontWeight:
                                                      FontWeight.w500)),
                                        ]),
                                  ),
                                ),
                              ]),
                          const SizedBox(height: 8),
                          if (_units.isEmpty)
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[300]!)),
                                child: Text('No units \u2014 tap "Add" above',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[500])))
                          else
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _units.map<Widget>((unit) {
                                  final unitId = unit['_id'];
                                  final isSel = selectedUnitId == unitId;
                                  return GestureDetector(
                                    onTap: () => setDialogState(() =>
                                        selectedUnitId =
                                            isSel ? null : unitId),
                                    onLongPress: () => _showEditUnitDialog(
                                        unit, setDialogState),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                            color: isSel
                                                ? const Color(0xFF00897B)
                                                : Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(unit['unit_name'] ?? '',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isSel
                                                    ? Colors.white
                                                    : Colors.black87))),
                                  );
                                }).toList()),
                          const SizedBox(height: 16),

                          // ── Quantity section (edit vs add)
                          if (existingItem != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: adjustedQty <=
                                          (num.tryParse(minCtrl.text) ?? 1)
                                      ? Colors.red[50]
                                      : Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: adjustedQty <=
                                              (num.tryParse(minCtrl.text) ?? 1)
                                          ? Colors.red[300]!
                                          : Colors.green[300]!)),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Current Stock',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey[600])),
                                          Text(_fmtNum(adjustedQty),
                                              style: GoogleFonts.poppins(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: adjustedQty <=
                                                          (num.tryParse(
                                                                  minCtrl
                                                                      .text) ??
                                                              1)
                                                      ? Colors.red[700]
                                                      : const Color(0xFF00897B))),
                                        ]),
                                    if (adjustedQty <=
                                        (num.tryParse(minCtrl.text) ?? 1))
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: Colors.red[100],
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text('Low Stock',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red[700]))),
                                  ]),
                            ),
                            const SizedBox(height: 14),
                            Row(children: [
                              _toggleBtn(
                                  'Add', Icons.add_circle_outline, isAdding,
                                  () {
                                setDialogState(() => isAdding = true);
                              }, left: true),
                              _toggleBtn('Remove',
                                  Icons.remove_circle_outline, !isAdding, () {
                                setDialogState(() => isAdding = false);
                              }, left: false),
                            ]),
                            const SizedBox(height: 10),
                            _fieldLabel(
                                isAdding ? 'Amount to Add' : 'Amount to Remove'),
                            const SizedBox(height: 8),
                            TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  final amount = double.tryParse(val) ?? 0;
                                  setDialogState(() {
                                    adjustedQty = isAdding
                                        ? currentQty + amount
                                        : (currentQty - amount)
                                            .clamp(0, double.infinity);
                                  });
                                },
                                decoration: _inputDeco('0').copyWith(
                                    prefixIcon: Icon(
                                        isAdding
                                            ? Icons.add
                                            : Icons.remove,
                                        color: isAdding
                                            ? const Color(0xFF00897B)
                                            : Colors.red))),
                            const SizedBox(height: 8),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${_fmtNum(currentQty)} ${isAdding ? "+" : "\u2212"} ${_fmtNum(double.tryParse(qtyCtrl.text) ?? 0)} = ${_fmtNum(adjustedQty)}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700])),
                                ])),
                            const SizedBox(height: 14),
                            _fieldLabel('Minimum Threshold'),
                            const SizedBox(height: 8),
                            TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: _inputDeco('1')),
                          ] else ...[
                            Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    _fieldLabel('Quantity'),
                                    const SizedBox(height: 8),
                                    TextField(
                                        controller: qtyCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDeco('0')),
                                  ])),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    _fieldLabel('Minimum'),
                                    const SizedBox(height: 8),
                                    TextField(
                                        controller: minCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDeco('1')),
                                  ])),
                            ]),
                          ],
                          const SizedBox(height: 16),

                          // ── Date pickers
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  _fieldLabel('Purchase Date'),
                                  const SizedBox(height: 8),
                                  _dateTile(
                                    date: purchaseDate,
                                    hint: 'Select date',
                                    icon: Icons.shopping_cart_outlined,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              purchaseDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030));
                                      if (picked != null) {
                                        setDialogState(
                                            () => purchaseDate = picked);
                                      }
                                    },
                                    onClear: () => setDialogState(
                                        () => purchaseDate = null),
                                  ),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  _fieldLabel('Expiry Date'),
                                  const SizedBox(height: 8),
                                  _dateTile(
                                    date: expiryDate,
                                    hint: 'Optional',
                                    icon: Icons.event_outlined,
                                    iconColor: expiryDate != null &&
                                            expiryDate!.isBefore(DateTime.now())
                                        ? Colors.red
                                        : null,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              expiryDate ?? DateTime.now(),
                                          firstDate: DateTime.now()
                                              .subtract(
                                                  const Duration(days: 30)),
                                          lastDate: DateTime(2030));
                                      if (picked != null) {
                                        setDialogState(
                                            () => expiryDate = picked);
                                      }
                                    },
                                    onClear: () => setDialogState(
                                        () => expiryDate = null),
                                  ),
                                ])),
                          ]),
                          const SizedBox(height: 16),

                          // ── Inventory selector (add only)
                          if (existingItem == null) ...[
                            _fieldLabel('Inventory'),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(10)),
                              child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedInventoryId,
                                hint: Text('Select inventory',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey)),
                                items: _inventories
                                    .map<DropdownMenuItem<String>>((inv) =>
                                        DropdownMenuItem<String>(
                                            value: inv['_id'],
                                            child: Text(inv['title'] ?? '',
                                                style:
                                                    GoogleFonts.poppins())))
                                    .toList(),
                                onChanged: (val) => setDialogState(
                                    () => selectedInventoryId = val),
                              )),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Save button
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  final finalQty = existingItem != null
                                      ? adjustedQty.toString()
                                      : qtyCtrl.text;
                                  _saveItem(dialogContext,
                                      existingItem: existingItem,
                                      name: nameCtrl.text,
                                      quantity: finalQty,
                                      minimum: minCtrl.text,
                                      unitId: selectedUnitId,
                                      categoryId: selectedCategoryId,
                                      inventoryId: selectedInventoryId,
                                      purchaseDate: purchaseDate,
                                      expiryDate: expiryDate);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00897B),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                child: Text(
                                    existingItem != null ? 'Update' : 'Add Item',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                              )),
                        ]),
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Text(text,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14));

  InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

  Widget _dateTile(
      {DateTime? date,
      required String hint,
      required IconData icon,
      Color? iconColor,
      required VoidCallback onTap,
      required VoidCallback onClear}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  date != null ? DateFormat('MMM dd, yyyy').format(date) : hint,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: date != null ? const Color(0xFF00352E) : Colors.grey))),
          if (date != null)
            GestureDetector(
                onTap: onClear,
                child:
                    Icon(Icons.close, size: 16, color: Colors.grey[400])),
        ]),
      ),
    );
  }

  Widget _toggleBtn(
      String label, IconData icon, bool active, VoidCallback onTap,
      {required bool left}) {
    return Expanded(
        child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (left ? const Color(0xFF00897B) : Colors.red)
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: left ? const Radius.circular(10) : Radius.zero,
            bottomLeft: left ? const Radius.circular(10) : Radius.zero,
            topRight: !left ? const Radius.circular(10) : Radius.zero,
            bottomRight: !left ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: active ? Colors.white : Colors.black54),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: active ? Colors.white : Colors.black54)),
        ]),
      ),
    ));
  }

  String _fmtNum(double n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);

  // ── CRUD ─────────────────────────────────────────────────────

  Future<void> _saveItem(BuildContext dialogContext,
      {Map<String, dynamic>? existingItem,
      required String name,
      required String quantity,
      required String minimum,
      String? unitId,
      String? categoryId,
      String? inventoryId,
      DateTime? purchaseDate,
      DateTime? expiryDate}) async {
    if (name.isEmpty) {
      showErrorSnack(context, 'Please enter item name');
      return;
    }
    if (unitId == null) {
      showErrorSnack(context, 'Please select a unit');
      return;
    }
    if (categoryId == null) {
      showErrorSnack(context, 'Please select a category');
      return;
    }
    try {
      final data = {
        'item_name': name,
        'quantity': num.tryParse(quantity) ?? 0,
        'threshold_quantity': num.tryParse(minimum) ?? 1,
        'unit_id': unitId,
        'item_category': categoryId,
        if (purchaseDate != null)
          'purchase_date': purchaseDate.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
      };
      if (existingItem != null) {
        await _apiService.updateInventoryItem(existingItem['_id'], data);
      } else {
        if (inventoryId == null) {
          showErrorSnack(context, 'Please select an inventory');
          return;
        }
        await _apiService.addInventoryItem(inventoryId, data);
      }
      if (mounted) Navigator.pop(dialogContext);
      _loadData();
      if (mounted) {
        showSuccessSnack(
            context, existingItem != null ? 'Item updated' : 'Item added');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '$e');
    }
  }

  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirmed = await showConfirmDialog(context,
        title: 'Delete Item',
        message: 'Are you sure you want to delete "$itemName"?');
    if (!confirmed) return;
    try {
      await _apiService.deleteInventoryItem(itemId);
      _loadData();
      if (mounted) showSuccessSnack(context, '"$itemName" deleted');
    } catch (e) {
      if (mounted) showErrorSnack(context, '$e');
    }
  }

  void _showCreateInventoryDialog() {
    final titleCtrl = TextEditingController();
    String selectedType = 'Food';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDlgState) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('New Inventory',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: 'Inventory Name',
                    hintText: 'e.g., Kitchen Pantry, Fridge',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 14),
            Text('Type',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ['Food', 'Electronics', 'Cleaning', 'Personal Care', 'Other']
                        .map((type) {
              final isSel = selectedType == type;
              return GestureDetector(
                onTap: () => setDlgState(() => selectedType = type),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color:
                            isSel ? const Color(0xFF00897B) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(type,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isSel ? Colors.white : Colors.black87))),
              );
            }).toList()),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isNotEmpty) {
                  try {
                    await _apiService.createInventory(
                        titleCtrl.text.trim(),
                        type: selectedType);
                    if (mounted) Navigator.pop(ctx);
                    _loadData();
                    if (mounted) {
                      showSuccessSnack(context, 'Inventory created');
                    }
                  } catch (e) {
                    if (mounted) showErrorSnack(context, '$e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B)),
              child: const Text('Create',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _isDark = context.watch<ThemeProvider>().isDark;
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: const Color(0xFF00897B)))
                : Column(children: [
                    _buildHeader(),
                    _buildInventorySelector(),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    _buildCategoryFilter(),
                    const SizedBox(height: 4),
                    _buildInventoryBudgetSummary(),
                    const SizedBox(height: 4),
                    _buildSummaryRow(),
                    const SizedBox(height: 4),
                    Expanded(child: _buildItemList()),
                  ]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditItemDialog(),
        backgroundColor: const Color(0xFF00897B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Item',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
    );
  }

  // ── Header ──────────────────────────────────────────────────

  Widget _buildHeader() {
    final selectedInv = _selectedInventoryId != null
        ? _inventories.where((i) => i['_id'] == _selectedInventoryId).toList()
        : [];
    final subtitle = selectedInv.isNotEmpty
        ? (selectedInv.first['title'] ?? 'Inventory')
        : '$_familyTitle Family';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: const Color(0xFF00352E))),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Inventory',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00352E))),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFF80CBC4))),
            ])),
        Stack(children: [
          IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/inventory-alerts'),
              icon: const Icon(Icons.notifications_outlined,
                  color: const Color(0xFF00897B))),
          if (_unreadAlerts > 0)
            Positioned(
                right: 6,
                top: 6,
                child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                        _unreadAlerts > 9 ? '9+' : '$_unreadAlerts',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)))),
        ]),
        IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/inventory-categories');
              _loadData();
            },
            icon: const Icon(Icons.account_tree_outlined,
                color: const Color(0xFF00897B)),
            tooltip: 'Manage Categories'),
      ]),
    );
  }

  // ── Inventory Selector ────────────────────────────────────────

  IconData _inventoryIcon(String? type) {
    switch (type) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Electronics':
        return Icons.devices_outlined;
      case 'Cleaning':
        return Icons.cleaning_services_outlined;
      case 'Personal Care':
        return Icons.face_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  int _getItemCountForInventory(String invId) {
    return _items.where((item) {
      final inv = item['inventory_id'];
      if (inv is Map) return inv['_id'] == invId;
      return inv == invId;
    }).length;
  }

  void _showRenameInventoryDialog(dynamic inventory) {
    final invId = inventory['_id'];
    final ctrl = TextEditingController(text: inventory['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text('Rename Inventory', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
              labelText: 'Inventory Name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              try {
                await _apiService
                    .updateInventory(invId, {'title': newName});
                if (mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) showSuccessSnack(context, 'Inventory renamed');
              } catch (e) {
                if (mounted) showErrorSnack(context, '$e');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B)),
            child:
                const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInventoryOptions(dynamic inventory) {
    final invId = inventory['_id'];
    final invTitle = inventory['title'] ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            Text(invTitle,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
                '${_getItemCountForInventory(invId)} items \u2022 ${inventory['type'] ?? 'Other'}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF80CBC4))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: const Color(0xFF00897B)),
              title: Text('Rename Inventory',
                  style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameInventoryDialog(inventory);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete Inventory',
                  style: GoogleFonts.poppins(color: Colors.red)),
              subtitle: Text(
                  _getItemCountForInventory(invId) > 0
                      ? 'Will delete all items in this inventory'
                      : 'This inventory is empty',
                  style:
                      GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showConfirmDialog(context,
                    title: 'Delete "$invTitle"?',
                    message:
                        'This will permanently delete this inventory and all its items.');
                if (!confirmed) return;
                try {
                  await _apiService.deleteInventory(invId);
                  if (_selectedInventoryId == invId) {
                    _selectedInventoryId = null;
                  }
                  _loadData();
                  if (mounted) {
                    showSuccessSnack(context, '"$invTitle" deleted');
                  }
                } catch (e) {
                  if (mounted) showErrorSnack(context, '$e');
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildInventorySelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _inventories.length + 2, // All + inventories + Add button
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // "All" chip
            if (index == 0) {
              final isSel = _selectedInventoryId == null;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedInventoryId = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF00897B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSel
                              ? const Color(0xFF00897B)
                              : Colors.grey[300]!),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                  color: const Color(0xFF00897B)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]
                          : null),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.all_inbox_outlined,
                        size: 18,
                        color: isSel
                            ? Colors.white
                            : const Color(0xFF4DB6AC)),
                    const SizedBox(width: 8),
                    Text('All',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : const Color(0xFF00352E))),
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white.withOpacity(0.25)
                                : Colors.grey[200],
                            borderRadius:
                                BorderRadius.circular(10)),
                        child: Text('${_items.length}',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFF4DB6AC)))),
                  ]),
                ),
              );
            }

            // Add button
            if (index == _inventories.length + 1) {
              return GestureDetector(
                onTap: _showCreateInventoryDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF00897B),
                          style: BorderStyle.solid)),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    const Icon(Icons.add,
                        size: 18, color: const Color(0xFF00897B)),
                    const SizedBox(width: 4),
                    Text('New',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00897B))),
                  ]),
                ),
              );
            }

            // Inventory chip
            final inv = _inventories[index - 1];
            final invId = inv['_id'];
            final isSel = _selectedInventoryId == invId;
            final icon = _inventoryIcon(inv['type']);
            final count = _getItemCountForInventory(invId);
            return GestureDetector(
              onTap: () => setState(
                  () => _selectedInventoryId = isSel ? null : invId),
              child: Container(
                padding: const EdgeInsets.only(
                    left: 14, top: 6, bottom: 6, right: 4),
                decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF00897B)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSel
                            ? const Color(0xFF00897B)
                            : Colors.grey[300]!),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                                color: const Color(0xFF00897B)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ]
                        : null),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(icon,
                      size: 18,
                      color: isSel
                          ? Colors.white
                          : const Color(0xFF4DB6AC)),
                  const SizedBox(width: 8),
                  Text(inv['title'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSel
                              ? Colors.white
                              : const Color(0xFF00352E))),
                  const SizedBox(width: 6),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.25)
                              : Colors.grey[200],
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: Text('$count',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF4DB6AC)))),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onPressed: () => _showInventoryOptions(inv),
                      icon: Icon(Icons.more_vert,
                          color: isSel
                              ? Colors.white70
                              : Colors.grey[500]),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Search bar ────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon:
                  const Icon(Icons.search, color: const Color(0xFF00897B)),
              suffixIcon: PopupMenuButton<String>(
                icon: Icon(Icons.sort, color: Colors.grey[600]),
                tooltip: 'Sort by',
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (_) => [
                  _sortMenuItem('name', 'Name', Icons.sort_by_alpha),
                  _sortMenuItem('quantity', 'Quantity', Icons.numbers),
                  _sortMenuItem(
                      'low_stock', 'Low Stock First', Icons.warning_amber),
                  _sortMenuItem(
                      'category', 'Category', Icons.category_outlined),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            )),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(
      String value, String label, IconData icon) {
    return PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon,
              size: 18,
              color:
                  _sortBy == value ? const Color(0xFF00897B) : Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight:
                      _sortBy == value ? FontWeight.bold : FontWeight.normal)),
        ]));
  }

  // ── Category filter chips ─────────────────────────────────────

  /// Categories that actually have items in the active inventory view.
  List<dynamic> get _activeCategories {
    final items = _activeItems;
    final usedCatIds = <String>{};
    for (final item in items) {
      final cat = item['item_category'];
      if (cat is Map && cat['_id'] != null) {
        usedCatIds.add(cat['_id']);
      } else if (cat is String) {
        usedCatIds.add(cat);
      }
    }
    return _categories.where((c) => usedCatIds.contains(c['_id'])).toList();
  }

  Widget _buildCategoryFilter() {
    final cats = _activeCategories;
    if (cats.isEmpty && _activeItems.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cats.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSel = _selectedCategoryId == null;
            return _filterChip('All', _activeItems.length, isSel, () {
              setState(() => _selectedCategoryId = null);
            });
          }
          final cat = cats[index - 1];
          final catId = cat['_id'];
          final isSel = _selectedCategoryId == catId;
          return _filterChip(
              cat['title'] ?? '', _getItemCountForCategory(catId), isSel, () {
            setState(() => _selectedCategoryId = isSel ? null : catId);
          });
        },
      ),
    );
  }

  Widget _buildInventoryBudgetSummary() {
    final periodBudget = (_inventoryBudgetSummary?['data']?['period_budget'] as Map?) ??
        (_inventoryBudgetSummary?['period_budget'] as Map?);
    final categories = (_inventoryBudgetSummary?['data']?['categories'] as List?) ??
        (_inventoryBudgetSummary?['categories'] as List?) ??
        const [];
    if (periodBudget == null || categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final title = (periodBudget['title'] ?? 'Active budget').toString();
    final periodSubtitle = '${DateFormat('dd MMM').format(DateTime.tryParse((periodBudget['start_date'] ?? '').toString()) ?? DateTime.now())} - '
      '${DateFormat('dd MMM').format(DateTime.tryParse((periodBudget['end_date'] ?? '').toString()) ?? DateTime.now())}';
    final totalAmount = (periodBudget['total_amount'] ?? 0).toString();
    final remainingAmount = (periodBudget['remaining_amount'] ?? 0).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFF00897B).withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF00897B).withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.savings_outlined, color: const Color(0xFF00897B), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00352E))),
                      Text('Source: $periodSubtitle',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: const Color(0xFF80CBC4))),
                    ],
                  ),
                ),
                Text('$remainingAmount / $totalAmount',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00897B))),
              ],
            ),
            const SizedBox(height: 12),
            if (_budgetPeriods.length > 1) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _budgetPeriods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final period = _budgetPeriods[index] as Map;
                    final periodId = (period['_id'] ?? '').toString();
                    final isSelected = periodId == _selectedBudgetPeriodId;
                    final chipLabel = (period['title'] ?? 'Budget').toString();
                    return ChoiceChip(
                      label: Text(chipLabel, overflow: TextOverflow.ellipsis),
                      selected: isSelected,
                      onSelected: (_) => _loadInventoryBudgetSummary(periodBudgetId: periodId),
                      selectedColor: const Color(0xFF00897B).withOpacity(0.15),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isSelected ? const Color(0xFF00897B) : const Color(0xFF00352E),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = categories[index] as Map;
                  final allocated = (entry['allocated_amount'] ?? 0).toString();
                  final spent = (entry['spent_amount'] ?? 0).toString();
                  final remaining = (entry['remaining_amount'] ?? 0).toString();
                  final categoryTitle = (entry['inventory_category_title'] ?? 'Category').toString();
                  return Container(
                    width: 168,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categoryTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00352E))),
                        const SizedBox(height: 4),
                        _budgetStatLine('Allocated', allocated),
                        _budgetStatLine('Spent', spent),
                        _budgetStatLine('Remaining', remaining),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetStatLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 9, color: const Color(0xFF80CBC4))),
        const SizedBox(width: 6),
        Flexible(
          child: Text(value,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00352E))),
        ),
      ],
    );
  }

  Widget _filterChip(
      String label, int count, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00897B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF00897B)
                    : Colors.grey[300]!)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF00352E))),
          const SizedBox(width: 6),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF4DB6AC)))),
        ]),
      ),
    );
  }

  // ── Summary Row ───────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final active = _activeItems;
    final total = active.length;
    final lowStock = active.where((i) => isLowStock(i)).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(children: [
        _statBadge(Icons.inventory_2_outlined, '$total items'),
        const SizedBox(width: 12),
        if (lowStock > 0)
          _statBadge(Icons.warning_amber_rounded, '$lowStock low stock',
              color: const Color(0xFFFB8C00)),
        const Spacer(),
        Text('${_categories.length} categories',
            style: GoogleFonts.poppins(
                fontSize: 11, color: const Color(0xFF80CBC4))),
      ]),
    );
  }

  Widget _statBadge(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color ?? const Color(0xFF00897B)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: color ?? const Color(0xFF4DB6AC),
                fontWeight:
                    color != null ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }

  // ── Item list (grouped by category) ──────────────────────────

  Widget _buildItemList() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
            _searchCtrl.text.isNotEmpty ? 'No matching items' : 'No items yet',
            style:
                GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16)),
        if (_searchCtrl.text.isEmpty)
          Text('Tap + to add your first item',
              style:
                  GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
      ]));
    }

    // If filtering by specific category or using non-default sort, show flat list
    if (_selectedCategoryId != null || _sortBy != 'name') {
      return RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF00897B),
          child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildItemTile(items[i])));
    }

    // Default: group by category
    final grouped = _groupedItems;
    final categoryNames = grouped.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00897B),
      child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          itemCount: categoryNames.length,
          itemBuilder: (_, i) {
            final catName = categoryNames[i];
            return _buildCategorySection(catName, grouped[catName]!);
          }),
    );
  }

  Widget _buildCategorySection(String categoryName, List<dynamic> items) {
    final icon = getCategoryIcon(categoryName);
    final colorIndex = categoryName.hashCode.abs();
    final color =
        _kCatColors[colorIndex % _kCatColors.length];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 8, top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(categoryName,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00352E)))),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  '${items.length} item${items.length == 1 ? "" : "s"}',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color))),
        ]),
      ),
      ...items.map((item) => _buildItemTile(item)),
      const SizedBox(height: 4),
    ]);
  }

  // ── Individual item tile ──────────────────────────────────────

  String _expiryLabel(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now).inDays;
    if (diff < 0) return 'Expired ${-diff}d ago';
    if (diff == 0) return 'Expires today';
    if (diff <= 3) return 'Expires in ${diff}d';
    if (diff <= 7) return 'Expires in ${diff}d';
    return DateFormat('MMM dd').format(expiry);
  }

  Color _expiryColor(DateTime expiry) {
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff < 0) return Colors.red[700]!;
    if (diff <= 3) return Colors.orange[700]!;
    if (diff <= 7) return Colors.amber[700]!;
    return const Color(0xFF80CBC4);
  }

  Widget _buildItemTile(dynamic item) {
    final lowStk = isLowStock(item);
    final qty = item['quantity'] ?? 0;
    final threshold = item['threshold_quantity'] ?? 1;
    final unitName = getUnitName(item);
    final catName = _getCategoryName(item);
    final itemName = item['item_name'] ?? '';
    String inventoryName = '';
    final inv = item['inventory_id'];
    if (inv is Map) inventoryName = inv['title'] ?? '';
    final expiryDate = _tryParseDate(item['expiry_date']);
    final purchaseDate = _tryParseDate(item['purchase_date']);
    final bool isExpired =
        expiryDate != null && expiryDate.isBefore(DateTime.now());
    final bool expiringSoon = expiryDate != null &&
        !isExpired &&
        expiryDate.difference(DateTime.now()).inDays <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: isExpired
              ? Colors.red[50]
              : expiringSoon
                  ? Colors.orange[50]
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
              left: BorderSide(
                  color: isExpired
                      ? Colors.red
                      : lowStk
                          ? const Color(0xFFFB8C00)
                          : const Color(0xFF00897B),
                  width: 3.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ]),
      child: InkWell(
        onTap: () => _showAddEditItemDialog(
            existingItem: Map<String, dynamic>.from(item)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(itemName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF00352E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (_selectedCategoryId == null)
                      _infoBadge(catName,
                          color: const Color(0xFF00897B),
                          bgColor: const Color(0xFFE0F2F1)),
                    if (inventoryName.isNotEmpty)
                      _infoBadge(inventoryName,
                          color: const Color(0xFF80CBC4),
                          bgColor: Colors.grey[100]!),
                    if (purchaseDate != null)
                      _infoBadge(
                          'Bought ${DateFormat('MMM dd').format(purchaseDate)}',
                          color: Colors.blue[700]!,
                          bgColor: Colors.blue[50]!,
                          icon: Icons.shopping_cart_outlined),
                    if (expiryDate != null)
                      _infoBadge(_expiryLabel(expiryDate),
                          color: _expiryColor(expiryDate),
                          bgColor: isExpired
                              ? Colors.red[100]!
                              : expiringSoon
                                  ? Colors.orange[100]!
                                  : Colors.grey[100]!,
                          icon: isExpired
                              ? Icons.error_outline
                              : Icons.event_outlined),
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$qty',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: lowStk
                            ? const Color(0xFFFB8C00)
                            : const Color(0xFF00352E))),
                if (unitName.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Text(unitName,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF80CBC4)))),
              ]),
              Text('min: $threshold',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: const Color(0xFF80CBC4))),
            ]),
            const SizedBox(width: 4),
            IconButton(
                onPressed: () => _deleteItem(item['_id'], itemName),
                icon: Icon(Icons.delete_outline,
                    size: 20, color: Colors.grey[400]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete'),
          ]),
        ),
      ),
    );
  }

  Widget _infoBadge(String text,
      {required Color color,
      required Color bgColor,
      IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 3)],
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
