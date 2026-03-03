import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

class InventoryCategoriesScreen extends StatefulWidget {
  const InventoryCategoriesScreen({super.key});

  @override
  State<InventoryCategoriesScreen> createState() =>
      _InventoryCategoriesScreenState();
}

class _InventoryCategoriesScreenState extends State<InventoryCategoriesScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getAllItemCategories(),
        _apiService.getAllFamilyItems(),
      ]);

      setState(() {
        _categories = results[0];
        _allItems = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  int _getItemCount(String categoryId) {
    return _allItems.where((item) {
      final cat = item['item_category'];
      if (cat is Map) return cat['_id'] == categoryId;
      return cat == categoryId;
    }).length;
  }

  List<dynamic> _getCategoryItems(String categoryId) {
    return _allItems.where((item) {
      final cat = item['item_category'];
      if (cat is Map) return cat['_id'] == categoryId;
      return cat == categoryId;
    }).toList();
  }

  String _getUnitName(dynamic item) {
    final unit = item['unit_id'];
    if (unit is Map) return unit['unit_name'] ?? '';
    return '';
  }

  bool _isLowStock(dynamic item) {
    final qty = (item['quantity'] ?? 0);
    final threshold = (item['threshold_quantity'] ?? 1);
    return qty is num && threshold is num && qty <= threshold;
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

  void _showAddCategoryDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New Category',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Fridge, Pantry, Supplies',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
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
                  await _apiService.createItemCategory({
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                  });
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C)),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Category',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure? Categories with items cannot be deleted.',
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
        await _apiService.deleteItemCategory(categoryId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF388E3C)))
            : Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Color(0xFF2E3E33)),
                        ),
                        Expanded(
                          child: Text(
                            'Categories',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E3E33),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined,
                              color: Color(0xFF388E3C)),
                        ),
                      ],
                    ),
                  ),

                  // Add New Category button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'Add New Category',
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
                  ),
                  const SizedBox(height: 16),

                  // Categories list
                  Expanded(
                    child: _categories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'No categories yet',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey[500], fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final cat = _categories[index];
                                return _buildCategoryCard(cat);
                              },
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

  Widget _buildCategoryCard(dynamic category) {
    final catId = category['_id'];
    final title = category['title'] ?? '';
    final itemCount = _getItemCount(catId);
    final categoryItems = _getCategoryItems(catId);
    final icon = _getCategoryIcon(title);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.green[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF2E3E33),
                        ),
                      ),
                      Text(
                        '$itemCount items',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteCategory(catId),
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red[300], size: 22),
                ),
              ],
            ),
          ),

          // Items grid within category
          if (categoryItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.0,
                ),
                itemCount: categoryItems.length > 4
                    ? 4
                    : categoryItems.length, // Show max 4
                itemBuilder: (context, index) {
                  final item = categoryItems[index];
                  final lowStock = _isLowStock(item);
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lowStock
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['item_name'] ?? '',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item['quantity'] ?? 0} ${_getUnitName(item)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: lowStock
                                ? Colors.red[700]
                                : const Color(0xFF388E3C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // "View more" if > 4 items
          if (categoryItems.length > 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  '+ ${categoryItems.length - 4} more items',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF388E3C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
