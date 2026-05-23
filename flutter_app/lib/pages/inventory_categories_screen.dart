import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/guarded_button.dart';

// ── Teal palette for category nodes ──────────────────────────────────────────
const List<Color> _kCatColors = [
  Color(0xFF00897B), Color(0xFF00ACC1), Color(0xFFFB8C00),
  Color(0xFF4DB6AC), Color(0xFF7B1FA2), Color(0xFFE91E63),
  Color(0xFF1565C0), Color(0xFF6D4C41), Color(0xFF00695C),
];

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY CATEGORIES SCREEN — Hierarchical Tree View
// ═══════════════════════════════════════════════════════════════════════════════

class InventoryCategoriesScreen extends StatefulWidget {
  const InventoryCategoriesScreen({super.key});

  @override
  State<InventoryCategoriesScreen> createState() =>
      _InventoryCategoriesScreenState();
}

class _InventoryCategoriesScreenState extends State<InventoryCategoriesScreen> {
  final ApiService _apiService = ApiService();

  bool _isDark = false;

  // ── Data ──
  List<dynamic> _treeCategories = []; // hierarchical (tree) from API
  List<dynamic> _flatCategories = []; // flat list (for parent dropdowns)
  List<dynamic> _inventories = [];
  List<dynamic> _allItems = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedInventoryId; // null = show all categories

  // ── Expansion state ──
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getAllInventoryCategories(tree: true),
        _apiService.getAllInventoryCategories(tree: false),
        _apiService.getAllInventories(),
        _apiService.getAllFamilyItems(),
      ]);
      setState(() {
        _treeCategories = results[0];
        _flatCategories = results[1];
        _inventories = results[2];
        _allItems = results[3];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error loading categories: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEARCH / FILTER
  // ───────────────────────────────────────────────────────────────────────────

  /// Category IDs that are used by items in the selected inventory.
  Set<String> get _usedCategoryIds {
    final items = _selectedInventoryId == null
        ? _allItems
        : _allItems.where((item) {
            final inv = item['inventory_id'];
            if (inv is Map) return inv['_id'] == _selectedInventoryId;
            return inv == _selectedInventoryId;
          });
    final ids = <String>{};
    for (final item in items) {
      final cat = item['item_category'];
      if (cat is Map && cat['_id'] != null) {
        ids.add(cat['_id']);
      } else if (cat is String) {
        ids.add(cat);
      }
    }
    return ids;
  }

  /// When an inventory is selected, only show nodes whose subtree contains at
  /// least one category that is used by items in that inventory.
  bool _nodeHasUsedCategory(dynamic node, Set<String> usedIds) {
    final id = node['_id']?.toString() ?? '';
    if (usedIds.contains(id)) return true;
    final children = node['children'] as List<dynamic>? ?? [];
    return children.any((c) => _nodeHasUsedCategory(c, usedIds));
  }

  /// Returns `true` when [node] or any descendant matches the query.
  bool _nodeMatchesSearch(dynamic node) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final title = (node['title'] ?? '').toString().toLowerCase();
    if (title.contains(q)) return true;
    final children = node['children'] as List<dynamic>? ?? [];
    return children.any(_nodeMatchesSearch);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ADD / EDIT CATEGORY DIALOG
  // ───────────────────────────────────────────────────────────────────────────

  void _showCategoryDialog({dynamic existingCategory}) {
    final isEdit = existingCategory != null;
    final titleCtrl = TextEditingController(
        text: isEdit ? (existingCategory['title'] ?? '') : '');
    final descCtrl = TextEditingController(
        text: isEdit ? (existingCategory['description'] ?? '') : '');

    // Determine the existing parent id
    String? selectedParentId;
    if (isEdit) {
      final parentRef = existingCategory['parent_category_id'];
      if (parentRef is Map) {
        selectedParentId = parentRef['_id']?.toString();
      } else if (parentRef is String) {
        selectedParentId = parentRef;
      }
    }

    // For the parent dropdown, exclude self and own descendants (to prevent cycles)
    final Set<String> excludeIds = {};
    if (isEdit) {
      _collectDescendantIds(existingCategory, excludeIds);
    }

    final parentOptions = _flatCategories
        .where((c) => !excludeIds.contains(c['_id']?.toString()))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Edit Category' : 'Add Category',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category Name *',
                        hintText: 'e.g., Dairy, Leafy Greens',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Parent category dropdown
                    DropdownButtonFormField<String>(
                      value: selectedParentId,
                      decoration: InputDecoration(
                        labelText: 'Parent Category',
                        hintText: 'None (root level)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None (root level)'),
                        ),
                        ...parentOptions.map((c) {
                          final path =
                              buildCategoryPath(c, _flatCategories);
                          return DropdownMenuItem<String>(
                            value: c['_id']?.toString(),
                            child: Text(path,
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedParentId = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                GuardedElevatedButton(
                  onPressed: () async {
                    final name = titleCtrl.text.trim();
                    if (name.isEmpty) return;
                    try {
                      final body = <String, dynamic>{
                        'title': name,
                        'description': descCtrl.text.trim(),
                        'parent_category_id': selectedParentId,
                      };
                      if (isEdit) {
                        await _apiService.updateInventoryCategory(
                            existingCategory['_id'], body);
                      } else {
                        await _apiService.createInventoryCategory(body);
                      }
                      if (mounted) Navigator.pop(ctx);
                      _loadData();
                      if (mounted) {
                        showSuccessSnack(context,
                            isEdit ? 'Category updated' : 'Category created');
                      }
                    } catch (e) {
                      if (mounted) showErrorSnack(context, '$e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B)),
                  child: Text(isEdit ? 'Save' : 'Add',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Collects the [id] of [node] + all its descendants into [ids].
  void _collectDescendantIds(dynamic node, Set<String> ids) {
    final id = node['_id']?.toString();
    if (id != null) ids.add(id);
    final children = node['children'] as List<dynamic>? ?? [];
    for (final child in children) {
      _collectDescendantIds(child, ids);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DELETE CATEGORY
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _deleteCategory(dynamic category) async {
    final children = category['children'] as List<dynamic>? ?? [];
    final title = category['title'] ?? 'this category';
    final message = children.isNotEmpty
        ? 'Cannot delete "$title" because it has ${children.length} '
            'subcategor${children.length == 1 ? "y" : "ies"}. '
            'Remove them first.'
        : 'Are you sure you want to delete "$title"?';

    if (children.isNotEmpty) {
      // Just inform — the backend will also reject it.
      showErrorSnack(context, message);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Category',
      message: message,
    );
    if (!confirmed) return;

    try {
      await _apiService.deleteInventoryCategory(category['_id']);
      _loadData();
      if (mounted) showSuccessSnack(context, '"$title" deleted');
    } catch (e) {
      if (mounted) showErrorSnack(context, '$e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER — add sub‑category pre‑filling the parent
  // ───────────────────────────────────────────────────────────────────────────

  void _addSubcategory(dynamic parentCategory) {
    final parentId = parentCategory['_id']?.toString();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Subcategory',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show parent path
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      size: 18, color: const Color(0xFF00897B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Under: ${buildCategoryPath(parentCategory, _flatCategories)}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF4DB6AC)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Subcategory Name *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          GuardedElevatedButton(
            onPressed: () async {
              final name = titleCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await _apiService.createInventoryCategory({
                  'title': name,
                  'description': descCtrl.text.trim(),
                  'parent_category_id': parentId,
                });
                if (mounted) Navigator.pop(ctx);
                // Auto‑expand the parent so the new child is visible
                if (parentId != null) _expandedIds.add(parentId);
                _loadData();
                if (mounted) showSuccessSnack(context, 'Subcategory created');
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _isDark = context.watch<ThemeProvider>().isDark;
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _buildHeader(),
                _buildInventorySelector(),
                _buildSearchBar(),
                const SizedBox(height: 8),
                _buildStats(),
                const SizedBox(height: 4),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: const Color(0xFF00897B), // teal primary
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Category',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, color: const Color(0xFF00352E)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categories',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00352E),
                  ),
                ),
                if (_selectedInventoryId != null)
                  Text(
                    _inventories
                            .where(
                                (i) => i['_id'] == _selectedInventoryId)
                            .map((i) => i['title'] ?? '')
                            .firstOrNull ??
                        '',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF80CBC4)),
                  ),
              ],
            ),
          ),
          // Expand / collapse all
          IconButton(
            tooltip: 'Expand all',
            onPressed: () {
              setState(() {
                for (final cat in _flatCategories) {
                  final id = cat['_id']?.toString();
                  if (id != null) _expandedIds.add(id);
                }
              });
            },
            icon: Icon(Icons.unfold_more, color: const Color(0xFF00897B)),
          ),
          IconButton(
            tooltip: 'Collapse all',
            onPressed: () => setState(() => _expandedIds.clear()),
            icon: Icon(Icons.unfold_less, color: const Color(0xFF00897B)),
          ),
        ],
      ),
    );
  }

  // ── Inventory Selector ───────────────────────────────────────────────────

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

  Widget _buildInventorySelector() {
    if (_inventories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _inventories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              final isSel = _selectedInventoryId == null;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedInventoryId = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF00897B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            isSel ? const Color(0xFF00897B) : Colors.grey[300]!),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.all_inbox_outlined,
                        size: 16,
                        color: isSel ? Colors.white : const Color(0xFF4DB6AC)),
                    const SizedBox(width: 6),
                    Text('All Inventories',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isSel ? Colors.white : const Color(0xFF00352E))),
                  ]),
                ),
              );
            }
            final inv = _inventories[index - 1];
            final invId = inv['_id'];
            final isSel = _selectedInventoryId == invId;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedInventoryId = isSel ? null : invId;
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF00897B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          isSel ? const Color(0xFF00897B) : Colors.grey[300]!),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_inventoryIcon(inv['type']),
                      size: 16,
                      color: isSel ? Colors.white : const Color(0xFF4DB6AC)),
                  const SizedBox(width: 6),
                  Text(inv['title'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isSel ? Colors.white : const Color(0xFF00352E))),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (val) => setState(() {
            _searchQuery = val;
            // When searching, auto‑expand everything so matches are visible
            if (val.isNotEmpty) {
              for (final cat in _flatCategories) {
                final id = cat['_id']?.toString();
                if (id != null) _expandedIds.add(id);
              }
            }
          }),
          decoration: InputDecoration(
            hintText: 'Search categories...',
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Stats bar ────────────────────────────────────────────────────────────

  Widget _buildStats() {
    final rootCount = _treeCategories.length;
    final totalCount = _flatCategories.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          _statChip(Icons.folder_outlined, '$rootCount root'),
          const SizedBox(width: 12),
          _statChip(Icons.account_tree_outlined, '$totalCount total'),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00897B)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF4DB6AC))),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF00897B)),
      );
    }

    final visibleRoots = _treeCategories.where((node) {
      if (!_nodeMatchesSearch(node)) return false;
      if (_selectedInventoryId != null) {
        return _nodeHasUsedCategory(node, _usedCategoryIds);
      }
      return true;
    }).toList();

    if (visibleRoots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching categories'
                  : 'No categories yet',
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to create your first category',
                style:
                    GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00897B),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: visibleRoots.length,
        itemBuilder: (_, i) =>
            _buildTreeNode(visibleRoots[i], depth: 0, colorIndex: i),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TREE NODE WIDGET
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTreeNode(dynamic node,
      {required int depth, required int colorIndex}) {
    final id = node['_id']?.toString() ?? '';
    final title = (node['title'] ?? '').toString();
    final desc = (node['description'] ?? '').toString();
    final children = (node['children'] as List<dynamic>?) ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(id);
    final icon = getCategoryIcon(title);
    final color =
        _kCatColors[colorIndex % _kCatColors.length];

    // Determine how many categories exist in this sub‑tree
    final totalDescendants = _countDescendants(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Node tile ──
        GestureDetector(
          onTap: hasChildren
              ? () => setState(() {
                    isExpanded
                        ? _expandedIds.remove(id)
                        : _expandedIds.add(id);
                  })
              : null,
          child: Container(
            margin: EdgeInsets.only(
              left: depth * 20.0,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF122030) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: depth == 0
                  ? Border(left: BorderSide(color: color, width: 4))
                  : null,
              boxShadow: [
                if (depth == 0)
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Expand / leaf icon
                  if (hasChildren)
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.chevron_right,
                          size: 22, color: const Color(0xFF4DB6AC)),
                    )
                  else
                    const SizedBox(width: 22),

                  const SizedBox(width: 6),

                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: depth == 0
                          ? color.withOpacity(0.12)
                          : const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: depth == 0 ? color : const Color(0xFF00897B)),
                  ),

                  const SizedBox(width: 10),

                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: depth == 0 ? 15 : 14,
                            color: const Color(0xFF00352E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (desc.isNotEmpty)
                          Text(
                            desc,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: const Color(0xFF80CBC4)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (hasChildren)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${children.length} subcategor${children.length == 1 ? "y" : "ies"}'
                              '${totalDescendants > children.length ? " ($totalDescendants total)" : ""}',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: const Color(0xFF80CBC4)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Depth badge for nested items
                  if (depth > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'L${depth + 1}',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: const Color(0xFF80CBC4)),
                      ),
                    ),

                  // Action buttons
                  _nodePopupMenu(node),
                ],
              ),
            ),
          ),
        ),

        // ── Children (visible when expanded) ──
        if (isExpanded && hasChildren)
          ...children
              .where(_nodeMatchesSearch)
              .toList()
              .asMap()
              .entries
              .map((e) => _buildTreeNode(
                    e.value,
                    depth: depth + 1,
                    colorIndex: colorIndex,
                  )),
      ],
    );
  }

  /// Count all descendants (not just direct children).
  int _countDescendants(dynamic node) {
    final children = (node['children'] as List<dynamic>?) ?? [];
    int count = children.length;
    for (final child in children) {
      count += _countDescendants(child);
    }
    return count;
  }

  // ── Popup menu for each node ─────────────────────────────────────────────

  Widget _nodePopupMenu(dynamic node) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _showCategoryDialog(existingCategory: node);
            break;
          case 'add_sub':
            _addSubcategory(node);
            break;
          case 'delete':
            _deleteCategory(node);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 18, color: const Color(0xFF00897B)),
              const SizedBox(width: 8),
              Text('Edit', style: GoogleFonts.poppins(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_sub',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18, color: const Color(0xFF00ACC1)),
              const SizedBox(width: 8),
              Text('Add Subcategory',
                  style: GoogleFonts.poppins(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: const Color(0xFFE53935)),
              const SizedBox(width: 8),
              Text('Delete',
                  style:
                      GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFE53935))),
            ],
          ),
        ),
      ],
    );
  }
}
