import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';
import '../core/styling/app_color.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/guarded_button.dart';

class RecipeDetailScreen extends StatefulWidget {
  final dynamic recipe;

  const RecipeDetailScreen({super.key, this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ApiService _apiService = ApiService();

  late bool _isNew;
  bool _loading = false;
  bool _editing = false;
  dynamic _recipe;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _prepTimeCtrl = TextEditingController();
  final _cookTimeCtrl = TextEditingController();
  String _selectedCategory = 'Other';

  int _scaledServings = 1;

  List<dynamic> _inventoryItems = [];
  List<dynamic> _units = [];

  @override
  void initState() {
    super.initState();
    _isNew = widget.recipe == null;
    if (!_isNew) {
      _recipe = widget.recipe;
      _populateForm();
      _editing = false;
    } else {
      _editing = true;
    }
    _loadSupportData();
  }

  void _populateForm() {
    _nameCtrl.text = _recipe['recipe_name'] ?? '';
    _descCtrl.text = _recipe['description'] ?? '';
    _servingsCtrl.text = '${_recipe['serving_size'] ?? 1}';
    _prepTimeCtrl.text = '${_recipe['prep_time'] ?? ''}';
    _cookTimeCtrl.text = '${_recipe['cook_time'] ?? ''}';
    _scaledServings = _recipe['serving_size'] ?? 1;
    _selectedCategory = _recipe['category'] ?? 'Other';
  }

  Future<void> _loadSupportData() async {
    try {
      final results = await Future.wait([
        _apiService.getAllFamilyItems(),
        _apiService.getAllUnits(),
      ]);
      setState(() {
        _inventoryItems = results[0];
        _units = results[1];
      });

      // Reload full recipe for fresh data
      if (!_isNew && _recipe['_id'] != null) {
        final fresh = await _apiService.getRecipe(_recipe['_id']);
        setState(() {
          _recipe = fresh['data']?['recipe'] ?? fresh;
          _populateForm();
        });
      }
    } catch (e) {
      // Silently handle - support data is optional
    }
  }

  Future<void> _saveRecipe() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe name is required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final body = {
        'recipe_name': _nameCtrl.text.trim(),
        'category': _selectedCategory,
        'description': _descCtrl.text.trim(),
        'serving_size': int.tryParse(_servingsCtrl.text) ?? 1,
        'prep_time': int.tryParse(_prepTimeCtrl.text) ?? 0,
        'cook_time': int.tryParse(_cookTimeCtrl.text) ?? 0,
      };

      if (_isNew) {
        final created = await _apiService.createRecipe(body);
        setState(() {
          _recipe = created['data']?['recipe'] ?? created;
          _isNew = false;
          _editing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe created! Now add ingredients and steps.')),
          );
        }
      } else {
        final updated = await _apiService.updateRecipe(_recipe['_id'], body);
        setState(() {
          _recipe = updated['data']?['recipe'] ?? updated;
          _editing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe updated')),
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
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _servingsCtrl.dispose();
    _prepTimeCtrl.dispose();
    _cookTimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = (_recipe != null ? _recipe['ingredients'] as List<dynamic>? : null) ?? [];
    final steps = (_recipe != null ? _recipe['steps'] as List<dynamic>? : null) ?? [];

    return Scaffold(
      backgroundColor: Appcolor.foodBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, !_isNew),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_back_ios_new, size: 18, color: Appcolor.foodPrimary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isNew ? 'New Recipe' : (_recipe['recipe_name'] ?? 'Recipe'),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Appcolor.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isNew && !_editing)
                        IconButton(
                          onPressed: () => setState(() => _editing = true),
                          icon: Icon(Icons.edit_outlined, color: Appcolor.foodPrimary),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe info form
                        _buildInfoCard(),
                        const SizedBox(height: 20),

                        // Save button when editing
                        if (_editing)
                          SizedBox(
                            width: double.infinity,
                            child: GuardedElevatedButton(
                              onPressed: _saveRecipe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Appcolor.foodPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_isNew ? 'Create Recipe' : 'Save Changes',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                          ),

                        // Ingredients & Steps only shown after recipe is saved
                        if (!_isNew) ...[
                          const SizedBox(height: 24),
                          // Serving scaler
                          _buildServingScaler(),
                          const SizedBox(height: 20),
                          _buildIngredientsSection(ingredients),
                          const SizedBox(height: 20),
                          _buildStepsSection(steps),
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recipe Details',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Appcolor.textDark)),
          const SizedBox(height: 14),
          _buildField('Recipe Name', _nameCtrl, 'Enter recipe name', enabled: _editing),
          const SizedBox(height: 12),
          // Category dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
              const SizedBox(height: 6),
              _editing
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCategory,
                          items: ['Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Snack', 'Appetizer', 'Main Course', 'Side Dish', 'Beverage', 'Other']
                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.poppins(fontSize: 14))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(_selectedCategory, style: GoogleFonts.poppins(fontSize: 14)),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField('Description', _descCtrl, 'Brief description (optional)',
              enabled: _editing, maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildField('Servings', _servingsCtrl, '1', enabled: _editing, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _buildField('Prep (min)', _prepTimeCtrl, '0', enabled: _editing, isNumber: true)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _buildField('Cook (min)', _cookTimeCtrl, '0', enabled: _editing, isNumber: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint,
      {bool enabled = true, int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            filled: !enabled,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildServingScaler() {
    final baseServings = _recipe['serving_size'] ?? 1;
    final scale = _scaledServings / (baseServings > 0 ? baseServings : 1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Appcolor.foodPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.scale, color: Appcolor.foodPrimary, size: 22),
          const SizedBox(width: 12),
          Text('Scale:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            onPressed: _scaledServings > 1
                ? () => setState(() => _scaledServings--)
                : null,
            icon: Icon(Icons.remove_circle_outline, color: Appcolor.foodPrimary),
          ),
          Text('$_scaledServings servings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(
            onPressed: () => setState(() => _scaledServings++),
            icon: Icon(Icons.add_circle_outline, color: Appcolor.foodPrimary),
          ),
          if (scale != 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${scale.toStringAsFixed(1)}x',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Appcolor.foodPrimary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(List<dynamic> ingredients) {
    final baseServings = _recipe['serving_size'] ?? 1;
    final scale = _scaledServings / (baseServings > 0 ? baseServings : 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingredients (${ingredients.length})',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _showAddIngredientDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Appcolor.foodPrimary),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Appcolor.foodPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('No ingredients added yet',
                    style: GoogleFonts.poppins(color: Colors.grey[400])),
              ),
            )
          else
            ...ingredients.asMap().entries.map((entry) {
              final ing = entry.value;
              final ingredientName = ing['ingredient_name'] ?? 'Unknown';
              final unitData = ing['unit_id'];
              final unitName = unitData is Map ? (unitData['unit_name'] ?? '') : '';
              final qty = (ing['quantity'] ?? 0);
              final scaledQty = qty is num ? (qty * scale) : qty;
              final ingId = ing['_id'] ?? '';
              final inInventory = _isInInventory(ingredientName);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: inInventory ? const Color(0xFFFAFAFA) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: inInventory ? Colors.grey[200]! : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: inInventory ? const Color(0xFFFFF3E0) : Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${entry.key + 1}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFFFF9800))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ingredientName,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                          Row(
                            children: [
                              Icon(
                                inInventory ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 12,
                                color: inInventory ? Appcolor.foodPrimary : Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                inInventory ? 'In stock' : 'Not in inventory',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: inInventory ? Appcolor.foodPrimary : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${scaledQty is num ? scaledQty.toStringAsFixed(scaledQty == scaledQty.roundToDouble() ? 0 : 1) : scaledQty} $unitName',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13, color: Appcolor.foodPrimary),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeIngredient(ingId),
                      child: Icon(Icons.close, size: 18, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStepsSection(List<dynamic> steps) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Steps (${steps.length})',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _showAddStepDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Appcolor.foodBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Appcolor.foodPrimary),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Appcolor.foodPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('No steps added yet',
                    style: GoogleFonts.poppins(color: Colors.grey[400])),
              ),
            )
          else
            ...steps.asMap().entries.map((entry) {
              final step = entry.value;
              final stepNum = step['step_number'] ?? (entry.key + 1);
              final instruction = step['instruction'] ?? '';
              final stepId = step['_id'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$stepNum',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2196F3))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(instruction,
                          style: GoogleFonts.poppins(fontSize: 13, height: 1.4)),
                    ),
                    GestureDetector(
                      onTap: () => _removeStep(stepId),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close, size: 18, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Check if an ingredient name matches any inventory item
  bool _isInInventory(String ingredientName) {
    final lower = ingredientName.toLowerCase().trim();
    return _inventoryItems.any((item) =>
        (item['item_name'] ?? '').toString().toLowerCase().trim() == lower);
  }

  void _showAddIngredientDialog() {
    final nameCtrl = TextEditingController();
    String? selectedUnitId;
    final qtyCtrl = TextEditingController();
    List<String> suggestions = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Build autocomplete suggestions from inventory
            void updateSuggestions(String query) {
              if (query.isEmpty) {
                suggestions = [];
              } else {
                suggestions = _inventoryItems
                    .where((item) => (item['item_name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                    .map<String>((item) => item['item_name'].toString())
                    .take(5)
                    .toList();
              }
              setDialogState(() {});
            }

            final isAvailable = nameCtrl.text.trim().isNotEmpty &&
                _isInInventory(nameCtrl.text.trim());

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Add Ingredient',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ingredient Name',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (val) => updateSuggestions(val),
                      decoration: InputDecoration(
                        hintText: 'e.g., Chicken, Rice, Tomato...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: nameCtrl.text.trim().isNotEmpty
                            ? Icon(
                                isAvailable ? Icons.check_circle : Icons.info_outline,
                                color: isAvailable ? Appcolor.foodPrimary : Colors.orange,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                    // Autocomplete suggestions from inventory
                    if (suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (_, i) => InkWell(
                            onTap: () {
                              nameCtrl.text = suggestions[i];
                              nameCtrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: nameCtrl.text.length));
                              suggestions = [];
                              setDialogState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 16, color: Appcolor.foodPrimary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(suggestions[i],
                                        style: GoogleFonts.poppins(fontSize: 13)),
                                  ),
                                  Text('In stock',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Appcolor.foodPrimary,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Availability indicator
                    if (nameCtrl.text.trim().isNotEmpty && suggestions.isEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFFE0F2F1) : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 14,
                              color: isAvailable ? Appcolor.foodPrimary : Colors.orange[700],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isAvailable
                                    ? 'Available in your inventory'
                                    : 'Not in your inventory — you may need to buy this',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isAvailable ? Appcolor.foodPrimary : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantity',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                GuardedElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter ingredient name and quantity')),
                      );
                      return;
                    }
                    if (selectedUnitId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a unit')),
                      );
                      return;
                    }
                    try {
                      await _apiService.addRecipeIngredient(_recipe['_id'], {
                        'ingredient_name': nameCtrl.text.trim(),
                        'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                        'unit_id': selectedUnitId,
                      });
                      Navigator.pop(ctx);
                      _loadSupportData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Appcolor.foodPrimary),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddStepDialog() {
    final instructionCtrl = TextEditingController();
    final steps = (_recipe['steps'] as List<dynamic>?) ?? [];
    final nextStepNum = steps.length + 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Step #$nextStepNum',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: instructionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe this step...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            GuardedElevatedButton(
              onPressed: () async {
                if (instructionCtrl.text.trim().isEmpty) return;
                try {
                  await _apiService.addRecipeStep(_recipe['_id'], {
                    'step_number': nextStepNum,
                    'instruction': instructionCtrl.text.trim(),
                  });
                  Navigator.pop(ctx);
                  _loadSupportData();
                } catch (e) {
                  if (mounted) showErrorSnack(context, 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Appcolor.foodPrimary),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeIngredient(String ingredientId) async {
    try {
      await _apiService.removeRecipeIngredient(_recipe['_id'], ingredientId);
      _loadSupportData();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  Future<void> _removeStep(String stepId) async {
    try {
      await _apiService.removeRecipeStep(_recipe['_id'], stepId);
      _loadSupportData();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }
}
