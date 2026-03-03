import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime.now();
  List<dynamic> _meals = [];
  List<dynamic> _inventoryItems = [];
  bool _loading = true;

  static const _mealTypeOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  static const _mealTypeIcons = {
    'Breakfast': Icons.free_breakfast,
    'Lunch': Icons.lunch_dining,
    'Dinner': Icons.dinner_dining,
    'Snack': Icons.cookie,
  };
  static const _mealTypeColors = {
    'Breakfast': Color(0xFFFFF3E0),
    'Lunch': Color(0xFFE8F5E9),
    'Dinner': Color(0xFFE3F2FD),
    'Snack': Color(0xFFFCE4EC),
  };
  static const _mealTypeAccent = {
    'Breakfast': Color(0xFFFF9800),
    'Lunch': Color(0xFF4CAF50),
    'Dinner': Color(0xFF2196F3),
    'Snack': Color(0xFFE91E63),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final results = await Future.wait([
        _apiService.getMeals(date: dateStr),
        _apiService.getAllFamilyItems(),
      ]);

      setState(() {
        _meals = results[0];
        _inventoryItems = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meals: $e')),
        );
      }
    }
  }

  Future<void> _loadMeals() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final meals = await _apiService.getMeals(date: dateStr);
      setState(() {
        _meals = meals;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ---------- Date Navigation ----------

  void _goToPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadMeals();
  }

  void _goToNextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadMeals();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF388E3C),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadMeals();
    }
  }

  String _formatDateLabel() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selectedDate == todayDate) return 'Today';
    if (selectedDate == todayDate.subtract(const Duration(days: 1))) return 'Yesterday';
    if (selectedDate == todayDate.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(_selectedDate);
  }

  // ---------- Meal CRUD ----------

  void _showAddMealDialog() {
    final nameCtrl = TextEditingController();
    String selectedType = 'Breakfast';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Meal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Meal Name',
                    hintText: 'e.g. Grilled Chicken Salad',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.restaurant_menu),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Meal Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mealTypeOrder.map((type) {
                    final isSelected = selectedType == type;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _mealTypeIcons[type],
                            size: 16,
                            color: isSelected ? Colors.white : _mealTypeAccent[type],
                          ),
                          const SizedBox(width: 4),
                          Text(type),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: _mealTypeAccent[type],
                      backgroundColor: _mealTypeColors[type],
                      labelStyle: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) => setDialogState(() => selectedType = type),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a meal name')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _apiService.createMeal({
                    'meal_name': nameCtrl.text.trim(),
                    'meal_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                    'meal_type': selectedType,
                  });
                  _loadMeals();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMealDialog(Map<String, dynamic> meal) {
    final nameCtrl = TextEditingController(text: meal['meal_name'] ?? '');
    String selectedType = meal['meal_type'] ?? 'Breakfast';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Meal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Meal Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.restaurant_menu),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Meal Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mealTypeOrder.map((type) {
                    final isSelected = selectedType == type;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _mealTypeIcons[type],
                            size: 16,
                            color: isSelected ? Colors.white : _mealTypeAccent[type],
                          ),
                          const SizedBox(width: 4),
                          Text(type),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: _mealTypeAccent[type],
                      backgroundColor: _mealTypeColors[type],
                      labelStyle: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) => setDialogState(() => selectedType = type),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _apiService.updateMeal(meal['_id'], {
                    'meal_name': nameCtrl.text.trim(),
                    'meal_type': selectedType,
                  });
                  _loadMeals();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMeal(Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Meal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "${meal['meal_name']}"? All ingredients used will be restored to inventory.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteMeal(meal['_id']);
                _loadMeals();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- Meal Detail (Items) ----------

  void _showMealDetail(Map<String, dynamic> meal) async {
    try {
      final detail = await _apiService.getMeal(meal['_id']);
      if (!mounted) return;
      _openMealDetailSheet(detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _openMealDetailSheet(Map<String, dynamic> detail) {
    final mealData = detail['meal'] ?? {};
    final List<dynamic> mealItems = detail['mealItems'] ?? [];
    final mealType = mealData['meal_type'] ?? 'Lunch';
    final accentColor = _mealTypeAccent[mealType] ?? const Color(0xFF388E3C);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> refreshDetail() async {
            try {
              final updated = await _apiService.getMeal(mealData['_id']);
              setSheetState(() {
                detail['meal'] = updated['meal'];
                detail['mealItems'] = updated['mealItems'];
                mealItems.clear();
                mealItems.addAll(updated['mealItems'] ?? []);
              });
            } catch (_) {}
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _mealTypeColors[mealType] ?? Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_mealTypeIcons[mealType] ?? Icons.restaurant,
                              color: accentColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mealData['meal_name'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$mealType  •  ${_formatDateLabel()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  // Items Section
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ingredients Used',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddMealItemDialog(mealData);
                              },
                              icon: Icon(Icons.add, color: accentColor, size: 18),
                              label: Text('Add',
                                  style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (mealItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.kitchen, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text(
                                  'No ingredients added yet',
                                  style: GoogleFonts.poppins(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap "Add" to use items from inventory',
                                  style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          ...mealItems.map((item) {
                            final invItem = item['inventory_item_id'];
                            final unit = item['unit_id'];
                            final itemName = invItem is Map
                                ? (invItem['item_name'] ?? 'Unknown')
                                : 'Unknown';
                            final unitName = unit is Map ? (unit['unit_name'] ?? '') : '';
                            final qty = item['quantity_used'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.inventory_2, color: accentColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(itemName,
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                        Text('$qty $unitName',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () async {
                                      try {
                                        await _apiService.removeMealItem(
                                            mealData['_id'], item['_id']);
                                        await refreshDetail();
                                        _loadMeals();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        // Recipe section
                        if (mealData['recipe_id'] != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.menu_book, color: Colors.orange[700], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Linked Recipe',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(
                                        mealData['recipe_id'] is Map
                                            ? (mealData['recipe_id']['recipe_name'] ?? 'Recipe')
                                            : 'Recipe',
                                        style: GoogleFonts.poppins(
                                            color: Colors.orange[800], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      final result =
                                          await _apiService.prepareMealFromRecipe(mealData['_id']);
                                      if (result['status'] == 'partial') {
                                        final missing = result['data']?['missing'] as List? ?? [];
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Missing: ${missing.map((m) => m['ingredient_name']).join(', ')}')),
                                          );
                                        }
                                      } else {
                                        await refreshDetail();
                                        _loadMeals();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('All ingredients deducted from inventory!')),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[700],
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Text('Prepare',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Add Meal Item ----------

  void _showAddMealItemDialog(Map<String, dynamic> meal) {
    String? selectedItemId;
    String? selectedUnitId;
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Get unit name for selected item
          String selectedItemUnit = '';
          if (selectedItemId != null) {
            final item = _inventoryItems.firstWhere(
              (i) => i['_id'] == selectedItemId,
              orElse: () => null,
            );
            if (item != null) {
              final unit = item['unit_id'];
              if (unit is Map) {
                selectedUnitId = unit['_id'];
                selectedItemUnit = unit['unit_name'] ?? '';
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add Ingredient', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select from Inventory',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: selectedItemId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text('Choose an item', style: GoogleFonts.poppins(fontSize: 14)),
                      items: _inventoryItems.map<DropdownMenuItem<String>>((item) {
                        final unit = item['unit_id'];
                        final unitName = unit is Map ? (unit['unit_name'] ?? '') : '';
                        final qty = item['quantity'] ?? 0;
                        return DropdownMenuItem<String>(
                          value: item['_id'],
                          child: Text(
                            '${item['item_name']} ($qty $unitName)',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedItemId = val),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Quantity to use',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixText: selectedItemUnit,
                      prefixIcon: const Icon(Icons.straighten),
                    ),
                  ),
                  if (selectedItemId != null) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final item = _inventoryItems.firstWhere(
                        (i) => i['_id'] == selectedItemId,
                        orElse: () => null,
                      );
                      if (item == null) return const SizedBox();
                      final available = item['quantity'] ?? 0;
                      final unit = item['unit_id'];
                      final unitName = unit is Map ? (unit['unit_name'] ?? '') : '';
                      return Text(
                        'Available: $available $unitName',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedItemId == null || selectedUnitId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an item')),
                    );
                    return;
                  }
                  final qty = double.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quantity must be greater than 0')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final result = await _apiService.addMealItem(meal['_id'], {
                      'inventory_item_id': selectedItemId,
                      'unit_id': selectedUnitId,
                      'quantity_used': qty,
                    });

                    // Show low stock alerts
                    final alerts = result['alerts'] as List? ?? [];
                    for (final alert in alerts) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(alert['message'] ?? 'Low stock alert'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }

                    // Refresh inventory items and reopen detail
                    final items = await _apiService.getAllFamilyItems();
                    setState(() => _inventoryItems = items);
                    _showMealDetail(meal);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Build UI ----------

  Map<String, List<dynamic>> _groupMealsByType() {
    final grouped = <String, List<dynamic>>{};
    for (final type in _mealTypeOrder) {
      grouped[type] = [];
    }
    for (final meal in _meals) {
      final type = meal['meal_type'] ?? 'Snack';
      if (grouped.containsKey(type)) {
        grouped[type]!.add(meal);
      } else {
        grouped['Snack']!.add(meal);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3E33)),
                  ),
                  Expanded(
                    child: Text(
                      'Meal Planner',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E3E33),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Date Selector
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _goToPreviousDay,
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF388E3C)),
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Color(0xFF388E3C)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateLabel(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E3E33),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _goToNextDay,
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF388E3C)),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C)))
                  : RefreshIndicator(
                      onRefresh: _loadMeals,
                      color: const Color(0xFF388E3C),
                      child: _meals.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.45,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.restaurant_menu,
                                            size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 12),
                                        Text('No meals planned',
                                            style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[500])),
                                        const SizedBox(height: 4),
                                        Text('Tap + to plan your first meal',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13, color: Colors.grey[400])),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildMealList(),
                    ),
            ),
          ],
        ),
      ),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMealDialog,
        backgroundColor: const Color(0xFF388E3C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildMealList() {
    final grouped = _groupMealsByType();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: _mealTypeOrder.where((type) => grouped[type]!.isNotEmpty).map((type) {
        final mealsForType = grouped[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(_mealTypeIcons[type], size: 20, color: _mealTypeAccent[type]),
                  const SizedBox(width: 8),
                  Text(
                    type,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _mealTypeAccent[type],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _mealTypeColors[type],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${mealsForType.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _mealTypeAccent[type],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...mealsForType.map((meal) => _buildMealCard(meal, type)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, String type) {
    final hasRecipe = meal['recipe_id'] != null;
    final recipeName = hasRecipe && meal['recipe_id'] is Map
        ? meal['recipe_id']['recipe_name'] ?? ''
        : '';

    return GestureDetector(
      onTap: () => _showMealDetail(meal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: _mealTypeAccent[type] ?? Colors.green,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _mealTypeColors[type] ?? Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _mealTypeIcons[type] ?? Icons.restaurant,
                color: _mealTypeAccent[type] ?? Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['meal_name'] ?? 'Untitled',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (hasRecipe && recipeName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.menu_book, size: 13, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            recipeName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (meal['created_by'] != null)
                    Text(
                      'by ${meal['created_by']}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditMealDialog(meal);
                if (val == 'delete') _confirmDeleteMeal(meal);
                if (val == 'detail') _showMealDetail(meal);
              },
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'detail',
                  child: Row(
                    children: [
                      const Icon(Icons.visibility, size: 18),
                      const SizedBox(width: 8),
                      Text('View Details', style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
            Navigator.pushReplacementNamed(context, '/food-hub');
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
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Food Hub'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }
}
