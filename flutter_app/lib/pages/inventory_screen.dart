import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import 'inventory_categories_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _items = [];
  List<dynamic> _categories = [];
  List<dynamic> _inventories = [];
  List<dynamic> _units = [];
  String _familyTitle = '';
  bool _loading = true;
  String? _selectedCategoryId;

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
        _apiService.getAllItemCategories(),
        _apiService.getAllInventories(),
        _apiService.getAllUnits(),
      ]);

      setState(() {
        _items = results[0];
        _categories = results[1];
        _inventories = results[2];
        _units = results[3];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  List<dynamic> get _filteredItems {
    if (_selectedCategoryId == null) return _items;
    return _items.where((item) {
      final cat = item['item_category'];
      if (cat is Map) return cat['_id'] == _selectedCategoryId;
      return cat == _selectedCategoryId;
    }).toList();
  }

  String _getUnitName(dynamic item) {
    final unit = item['unit_id'];
    if (unit is Map) return unit['unit_name'] ?? '';
    return '';
  }

  String _getCategoryName(dynamic item) {
    final cat = item['item_category'];
    if (cat is Map) return cat['title'] ?? '';
    return '';
  }

  bool _isLowStock(dynamic item) {
    final qty = (item['quantity'] ?? 0);
    final threshold = (item['threshold_quantity'] ?? 1);
    return qty is num && threshold is num && qty <= threshold;
  }

  // ==================== UNIT MANAGEMENT DIALOGS ====================

  void _showAddUnitDialog(StateSetter setDialogState) {
    final nameCtrl = TextEditingController();
    String selectedType = 'count';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Add New Unit',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., kg, liter, piece',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Unit Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['weight', 'volume', 'count'].map((type) {
                      final isSelected = selectedType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setInnerState(() => selectedType = type),
                          child: Container(
                            margin: EdgeInsets.only(right: type != 'count' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF388E3C) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                type[0].toUpperCase() + type.substring(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await _apiService.createUnit(nameCtrl.text.trim(), selectedType);
                      final updatedUnits = await _apiService.getAllUnits();
                      setState(() => _units = updatedUnits);
                      setDialogState(() {});
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditUnitDialog(dynamic unit, StateSetter setDialogState) {
    final nameCtrl = TextEditingController(text: unit['unit_name'] ?? '');
    String selectedType = unit['unit_type'] ?? 'count';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Edit Unit',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Unit Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['weight', 'volume', 'count'].map((type) {
                      final isSelected = selectedType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setInnerState(() => selectedType = type),
                          child: Container(
                            margin: EdgeInsets.only(right: type != 'count' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF388E3C) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                type[0].toUpperCase() + type.substring(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await _apiService.updateUnit(
                        unit['_id'],
                        unitName: nameCtrl.text.trim(),
                        unitType: selectedType,
                      );
                      final updatedUnits = await _apiService.getAllUnits();
                      setState(() => _units = updatedUnits);
                      setDialogState(() {});
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteUnitConfirm(dynamic unit, StateSetter setDialogState, VoidCallback onDeleted) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Unit', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${unit['unit_name']}"?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.deleteUnit(unit['_id']);
                final updatedUnits = await _apiService.getAllUnits();
                setState(() => _units = updatedUnits);
                onDeleted();
                setDialogState(() {});
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================================================================

  void _showAddEditItemDialog({Map<String, dynamic>? existingItem}) {
    final nameCtrl = TextEditingController(text: existingItem?['item_name'] ?? '');
    final qtyCtrl = TextEditingController(
        text: existingItem != null ? '' : ''); // For new items: total qty; for edit: adjustment amount
    final minCtrl = TextEditingController(
        text: existingItem != null ? existingItem['threshold_quantity']?.toString() ?? '1' : '1');

    // For editing: track the current quantity and adjustment
    final double currentQty = existingItem != null
        ? (existingItem['quantity'] is num ? (existingItem['quantity'] as num).toDouble() : 0.0)
        : 0.0;
    double adjustedQty = currentQty; // the live result shown to user
    bool isAdding = true; // true = add, false = remove

    String? selectedUnitId;
    String? selectedCategoryId;
    String? selectedInventoryId;

    // Parse existing item data
    if (existingItem != null) {
      final unit = existingItem['unit_id'];
      selectedUnitId = unit is Map ? unit['_id'] : unit?.toString();

      final cat = existingItem['item_category'];
      selectedCategoryId = cat is Map ? cat['_id'] : cat?.toString();

      final inv = existingItem['inventory_id'];
      selectedInventoryId = inv is Map ? inv['_id'] : inv?.toString();
    } else {
      if (_inventories.isNotEmpty) {
        selectedInventoryId = _inventories.first['_id'];
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 420,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF388E3C),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existingItem != null ? 'Edit Item' : 'Add New Item',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Name
                            Text('Item Name',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                hintText: 'Enter item name',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Unit selector with management
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Unit',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600, fontSize: 14)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        try {
                                          await _apiService.seedUnits();
                                          final updatedUnits = await _apiService.getAllUnits();
                                          setState(() => _units = updatedUnits);
                                          setDialogState(() {});
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Default units loaded!')),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.orange[300]!),
                                        ),
                                        child: Text('Seed Defaults',
                                            style: GoogleFonts.poppins(
                                                fontSize: 11, color: Colors.orange[800],
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showAddUnitDialog(setDialogState),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green[300]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 14, color: Colors.green[800]),
                                            const SizedBox(width: 2),
                                            Text('Add',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 11, color: Colors.green[800],
                                                    fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _units.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.grey[400], size: 28),
                                        const SizedBox(height: 6),
                                        Text('No units available',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13, color: Colors.grey[500])),
                                        const SizedBox(height: 4),
                                        Text('Tap "Seed Defaults" for common units or "Add" to create custom ones',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                                fontSize: 11, color: Colors.grey[400])),
                                      ],
                                    ),
                                  )
                                : Container(
                                    constraints: const BoxConstraints(maxHeight: 180),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: _units.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                                      itemBuilder: (context, index) {
                                        final unit = _units[index];
                                        final unitId = unit['_id'];
                                        final isSelected = selectedUnitId == unitId;
                                        return ListTile(
                                          dense: true,
                                          visualDensity: const VisualDensity(vertical: -2),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                          leading: Radio<String>(
                                            value: unitId,
                                            groupValue: selectedUnitId,
                                            activeColor: const Color(0xFF388E3C),
                                            onChanged: (val) {
                                              setDialogState(() => selectedUnitId = val);
                                            },
                                          ),
                                          title: Text(
                                            unit['unit_name'] ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              color: isSelected ? const Color(0xFF388E3C) : Colors.black87,
                                            ),
                                          ),
                                          subtitle: Text(
                                            unit['unit_type'] ?? '',
                                            style: GoogleFonts.poppins(
                                                fontSize: 10, color: Colors.grey[500]),
                                          ),
                                          selected: isSelected,
                                          selectedTileColor: Colors.green[50],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _showEditUnitDialog(
                                                    unit, setDialogState),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(6),
                                                  child: Icon(Icons.edit_outlined,
                                                      size: 18, color: Colors.blue[400]),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _showDeleteUnitConfirm(
                                                    unit, setDialogState, () {
                                                  if (selectedUnitId == unitId) {
                                                    selectedUnitId = null;
                                                  }
                                                }),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(6),
                                                  child: Icon(Icons.delete_outline,
                                                      size: 18, color: Colors.red[400]),
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              selectedUnitId = isSelected ? null : unitId;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                            const SizedBox(height: 16),

                            // Quantity section
                            if (existingItem != null) ...[
                              // ---- EDIT MODE: Current stock + adjustment ----
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: adjustedQty <= (num.tryParse(minCtrl.text) ?? 1)
                                      ? Colors.red[50]
                                      : Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: adjustedQty <= (num.tryParse(minCtrl.text) ?? 1)
                                        ? Colors.red[300]!
                                        : Colors.green[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Current Stock',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12, color: Colors.grey[600])),
                                        Text(
                                          '${adjustedQty % 1 == 0 ? adjustedQty.toInt() : adjustedQty.toStringAsFixed(1)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: adjustedQty <= (num.tryParse(minCtrl.text) ?? 1)
                                                ? Colors.red[700]
                                                : const Color(0xFF388E3C),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (adjustedQty <= (num.tryParse(minCtrl.text) ?? 1))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('Low Stock',
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red[700])),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Add / Remove toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setDialogState(() => isAdding = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isAdding ? const Color(0xFF388E3C) : Colors.grey[200],
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_circle_outline,
                                                size: 18,
                                                color: isAdding ? Colors.white : Colors.black54),
                                            const SizedBox(width: 6),
                                            Text('Add',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isAdding ? Colors.white : Colors.black54,
                                                )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setDialogState(() => isAdding = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: !isAdding ? Colors.red : Colors.grey[200],
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.remove_circle_outline,
                                                size: 18,
                                                color: !isAdding ? Colors.white : Colors.black54),
                                            const SizedBox(width: 6),
                                            Text('Remove',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: !isAdding ? Colors.white : Colors.black54,
                                                )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Adjustment amount input
                              Text(
                                isAdding ? 'Amount to Add' : 'Amount to Remove',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  final amount = double.tryParse(val) ?? 0;
                                  setDialogState(() {
                                    if (isAdding) {
                                      adjustedQty = currentQty + amount;
                                    } else {
                                      adjustedQty = currentQty - amount;
                                      if (adjustedQty < 0) adjustedQty = 0;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: '0',
                                  prefixIcon: Icon(
                                    isAdding ? Icons.add : Icons.remove,
                                    color: isAdding ? const Color(0xFF388E3C) : Colors.red,
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Result preview
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 16, color: Colors.grey[500]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${currentQty % 1 == 0 ? currentQty.toInt() : currentQty.toStringAsFixed(1)}'
                                      ' ${isAdding ? "+" : "−"} '
                                      '${(double.tryParse(qtyCtrl.text) ?? 0) % 1 == 0 ? (double.tryParse(qtyCtrl.text) ?? 0).toInt() : (double.tryParse(qtyCtrl.text) ?? 0).toStringAsFixed(1)}'
                                      ' = ${adjustedQty % 1 == 0 ? adjustedQty.toInt() : adjustedQty.toStringAsFixed(1)}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Minimum row
                              Text('Minimum',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  hintText: '1',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                            ] else ...[
                              // ---- NEW ITEM MODE: Simple quantity + minimum ----
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Quantity',
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: qtyCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: '0',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Minimum',
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: minCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: '1',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Category dropdown
                            Text('Category',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedCategoryId,
                                  hint: Text('Select category',
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey)),
                                  items: _categories.map<DropdownMenuItem<String>>((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat['_id'],
                                      child: Text(cat['title'] ?? '',
                                          style: GoogleFonts.poppins()),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setDialogState(() => selectedCategoryId = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Inventory dropdown (only for new items)
                            if (existingItem == null) ...[
                              Text('Inventory',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedInventoryId,
                                    hint: Text('Select inventory',
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey)),
                                    items:
                                        _inventories.map<DropdownMenuItem<String>>((inv) {
                                      return DropdownMenuItem<String>(
                                        value: inv['_id'],
                                        child: Text(inv['title'] ?? '',
                                            style: GoogleFonts.poppins()),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setDialogState(
                                          () => selectedInventoryId = val);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                    final finalQty = existingItem != null
                                        ? adjustedQty.toString()
                                        : qtyCtrl.text;
                                    _saveItem(
                                      dialogContext,
                                      existingItem: existingItem,
                                      name: nameCtrl.text,
                                      quantity: finalQty,
                                      minimum: minCtrl.text,
                                      unitId: selectedUnitId,
                                      categoryId: selectedCategoryId,
                                      inventoryId: selectedInventoryId,
                                    );
                                  },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF388E3C),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  existingItem != null ? 'Update' : 'Add Item',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveItem(
    BuildContext dialogContext, {
    Map<String, dynamic>? existingItem,
    required String name,
    required String quantity,
    required String minimum,
    String? unitId,
    String? categoryId,
    String? inventoryId,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name')),
      );
      return;
    }

    if (unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit')),
      );
      return;
    }

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    try {
      final data = {
        'item_name': name,
        'quantity': num.tryParse(quantity) ?? 0,
        'threshold_quantity': num.tryParse(minimum) ?? 1,
        'unit_id': unitId,
        'item_category': categoryId,
      };

      if (existingItem != null) {
        // Update
        await _apiService.updateInventoryItem(existingItem['_id'], data);
      } else {
        // Create
        if (inventoryId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an inventory')),
          );
          return;
        }
        await _apiService.addInventoryItem(inventoryId, data);
      }

      if (mounted) Navigator.pop(dialogContext);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Item', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this item?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteInventoryItem(itemId);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showCreateInventoryDialog() {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Inventory',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Inventory Name',
                hintText: 'e.g., Kitchen Pantry, Fridge',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                try {
                  await _apiService.createInventory(titleCtrl.text);
                  if (mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

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
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_familyTitle Family',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Inventory Management',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E3E33),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _showCreateInventoryDialog,
                                icon: const Icon(Icons.add_box_outlined,
                                    color: Color(0xFF388E3C)),
                                tooltip: 'New Inventory',
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.notifications_outlined,
                                    color: Color(0xFF388E3C)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Add New Item button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddEditItemDialog(),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            'Add New Item',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Items grid
                      if (items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No items yet',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Tap "Add New Item" to get started',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive: more columns on wider screens
                            final width = constraints.maxWidth;
                            final crossAxisCount = width > 900
                                ? 4
                                : width > 600
                                    ? 3
                                    : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.4,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _buildItemCard(item);
                              },
                            );
                          },
                        ),

                      const SizedBox(height: 28),

                      // Categories Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Categories',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E3E33),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const InventoryCategoriesScreen(),
                                ),
                              );
                              _loadData();
                            },
                            child: Text(
                              'View All',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF388E3C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category chips
                      SizedBox(
                        height: 90,
                        child: _categories.isEmpty
                            ? Center(
                                child: Text(
                                  'No categories yet',
                                  style: GoogleFonts.poppins(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final cat = _categories[index];
                                  final catId = cat['_id'];
                                  final isSelected =
                                      _selectedCategoryId == catId;
                                  // Count items in this category
                                  final count = _items.where((item) {
                                    final c = item['item_category'];
                                    if (c is Map) return c['_id'] == catId;
                                    return c == catId;
                                  }).length;

                                  return _buildCategoryChip(
                                    cat['title'] ?? '',
                                    count,
                                    _getCategoryIcon(cat['title'] ?? ''),
                                    isSelected,
                                    () {
                                      setState(() {
                                        _selectedCategoryId =
                                            isSelected ? null : catId;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 100), // Space for bottom nav
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

  Widget _buildItemCard(dynamic item) {
    final lowStock = _isLowStock(item);

    return GestureDetector(
      onTap: () => _showAddEditItemDialog(existingItem: Map<String, dynamic>.from(item)),
      onLongPress: () => _deleteItem(item['_id']),
      child: Container(
        decoration: BoxDecoration(
          color: lowStock ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: lowStock
              ? Border.all(color: Colors.red[300]!, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item icon and menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lowStock ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: lowStock ? Colors.red[700] : Colors.green[700],
                    size: 20,
                  ),
                ),
                if (lowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Low',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Item name
            Text(
              item['item_name'] ?? '',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF2E3E33),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Quantity
            Text(
              '${item['quantity'] ?? 0} ${_getUnitName(item)}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: lowStock ? Colors.red[700] : const Color(0xFF388E3C),
              ),
            ),
            // Minimum label
            Text(
              'minimum  ${item['threshold_quantity'] ?? 1}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String title,
    int count,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF388E3C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : const Color(0xFF388E3C),
                size: 28),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2E3E33),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$count items',
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: isSelected ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('fridge')) return Icons.kitchen;
    if (lower.contains('freezer')) return Icons.ac_unit;
    if (lower.contains('pantry')) return Icons.shelves;
    if (lower.contains('suppli')) return Icons.shopping_bag;
    if (lower.contains('device')) return Icons.devices;
    if (lower.contains('clean')) return Icons.cleaning_services;
    if (lower.contains('bathroom')) return Icons.bathroom;
    return Icons.category;
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 2, // Inventory is at index 2
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
            // Already on inventory
            break;
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
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
        BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }
}
