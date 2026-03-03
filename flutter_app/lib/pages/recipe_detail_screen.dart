import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

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
          _recipe = fresh;
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
        const SnackBar(content: Text('Recipe name is required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final body = {
        'recipe_name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'serving_size': int.tryParse(_servingsCtrl.text) ?? 1,
        'prep_time': int.tryParse(_prepTimeCtrl.text) ?? 0,
        'cook_time': int.tryParse(_cookTimeCtrl.text) ?? 0,
      };

      if (_isNew) {
        final created = await _apiService.createRecipe(body);
        setState(() {
          _recipe = created;
          _isNew = false;
          _editing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe created! Now add ingredients and steps.')),
          );
        }
      } else {
        final updated = await _apiService.updateRecipe(_recipe['_id'], body);
        setState(() {
          _recipe = updated;
          _editing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe updated')),
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
      backgroundColor: const Color(0xFFE8F5E9),
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
                          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF388E3C)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isNew ? 'New Recipe' : (_recipe['recipe_name'] ?? 'Recipe'),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3E33),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isNew && !_editing)
                        IconButton(
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF388E3C)),
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
                            child: ElevatedButton(
                              onPressed: _loading ? null : _saveRecipe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF388E3C),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(_isNew ? 'Create Recipe' : 'Save Changes',
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
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3E33))),
          const SizedBox(height: 14),
          _buildField('Recipe Name', _nameCtrl, 'Enter recipe name', enabled: _editing),
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
        border: Border.all(color: const Color(0xFF388E3C).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale, color: Color(0xFF388E3C), size: 22),
          const SizedBox(width: 12),
          Text('Scale:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            onPressed: _scaledServings > 1
                ? () => setState(() => _scaledServings--)
                : null,
            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF388E3C)),
          ),
          Text('$_scaledServings servings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(
            onPressed: () => setState(() => _scaledServings++),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF388E3C)),
          ),
          if (scale != 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${scale.toStringAsFixed(1)}x',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFF388E3C), fontWeight: FontWeight.w600)),
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
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF388E3C)),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFF388E3C), fontWeight: FontWeight.w600)),
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
              final itemData = ing['item_id'];
              final itemName = itemData is Map ? (itemData['item_name'] ?? 'Unknown') : 'Item';
              final unitData = ing['unit_id'];
              final unitName = unitData is Map ? (unitData['unit_name'] ?? '') : '';
              final qty = (ing['quantity'] ?? 0);
              final scaledQty = qty is num ? (qty * scale) : qty;
              final ingId = ing['_id'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
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
                      child: Text(itemName,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                    ),
                    Text(
                      '${scaledQty is num ? scaledQty.toStringAsFixed(scaledQty == scaledQty.roundToDouble() ? 0 : 1) : scaledQty} $unitName',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF388E3C)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeIngredient(ingId),
                      child: const Icon(Icons.close, size: 18, color: Colors.red),
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
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF388E3C)),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFF388E3C), fontWeight: FontWeight.w600)),
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

  void _showAddIngredientDialog() {
    String? selectedItemId;
    String? selectedUnitId;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    Text('Inventory Item',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
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
                        hint: Text('Select item', style: GoogleFonts.poppins(fontSize: 13)),
                        items: _inventoryItems.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['_id'],
                            child: Text(item['item_name'] ?? '', style: GoogleFonts.poppins(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedItemId = val),
                      ),
                    ),
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
                ElevatedButton(
                  onPressed: () async {
                    if (selectedItemId == null || qtyCtrl.text.isEmpty) return;
                    try {
                      await _apiService.addRecipeIngredient(_recipe['_id'], {
                        'item_id': selectedItemId,
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
            ElevatedButton(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeStep(String stepId) async {
    try {
      await _apiService.removeRecipeStep(_recipe['_id'], stepId);
      _loadSupportData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
