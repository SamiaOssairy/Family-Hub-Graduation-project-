import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';
import '../core/styling/app_color.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/guarded_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GROCERIES SCREEN — Shopping Lists Hub
// ═══════════════════════════════════════════════════════════════════════════════

class GroceriesScreen extends StatefulWidget {
  const GroceriesScreen({super.key});

  @override
  State<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends State<GroceriesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _groceryLists = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final lists = await _apiService.getAllGroceryLists();
      setState(() {
        _groceryLists = lists;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error loading grocery lists: $e');
    }
  }

  List<dynamic> get _filteredLists {
    if (_searchQuery.isEmpty) return _groceryLists;
    final q = _searchQuery.toLowerCase();
    return _groceryLists.where((list) {
      final title = (list['title'] ?? '').toString().toLowerCase();
      return title.contains(q);
    }).toList();
  }

  // ── Create list dialog ────────────────────────────────────────────────────

  void _showCreateListDialog() {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create New List',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'List Name',
            hintText: 'e.g., Weekly Shopping',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          GuardedElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isNotEmpty) {
                try {
                  await _apiService.createGroceryList({
                    'title': titleCtrl.text.trim(),
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadData();
                  if (mounted) showSuccessSnack(context, 'List created');
                } catch (e) {
                  if (mounted) showErrorSnack(context, '$e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Appcolor.foodPrimary),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Delete list ───────────────────────────────────────────────────────────

  Future<void> _deleteList(String listId, String title) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "$title"?',
      message: 'This will permanently delete this list and all its items.',
    );
    if (!confirmed) return;
    try {
      await _apiService.deleteGroceryList(listId);
      _loadData();
      if (mounted) showSuccessSnack(context, '"$title" deleted');
    } catch (e) {
      if (mounted) showErrorSnack(context, '$e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final lists = _filteredLists;

    return Scaffold(
      backgroundColor: Appcolor.foodBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Appcolor.foodPrimary))
                : Column(
                    children: [
                      _buildTopBar(),
                      _buildSearchBar(),
                      const SizedBox(height: 8),
                      // Summary chip
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            _summaryChip(Icons.list_alt_outlined,
                                '${_groceryLists.length} lists'),
                            const SizedBox(width: 12),
                            _summaryChip(
                              Icons.check_circle_outline,
                              '${_groceryLists.fold<int>(0, (sum, l) => sum + ((l['checked_items'] ?? 0) as int))} done',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          color: Appcolor.foodPrimary,
                          child: lists.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 4, 20, 90),
                                  itemCount: lists.length,
                                  itemBuilder: (_, i) =>
                                      _buildListCard(lists[i]),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateListDialog,
        backgroundColor: Appcolor.foodPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New List',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Appcolor.foodPrimary),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Appcolor.textMedium)),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Appcolor.textDark),
          ),
          Expanded(
            child: Text(
              'Grocery Lists',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Appcolor.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search grocery lists...',
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching lists'
                : 'No grocery lists yet',
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first list',
              style: GoogleFonts.poppins(
                  color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ── List card ────────────────────────────────────────────────────────────

  Widget _buildListCard(dynamic list) {
    final title = list['title'] ?? 'Untitled';
    final totalItems = (list['total_items'] ?? 0) as int;
    final checkedItems = (list['checked_items'] ?? 0) as int;
    final progress = totalItems > 0 ? checkedItems / totalItems : 0.0;
    final listId = list['_id'];
    final isComplete = totalItems > 0 && checkedItems == totalItems;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/grocery-list-detail',
          arguments: {'listId': listId, 'title': title},
        ).then((_) => _loadData());
      },
      onLongPress: () => _deleteList(listId, title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
          border: isComplete
              ? Border.all(color: Appcolor.success.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isComplete
                    ? Appcolor.success.withOpacity(0.1)
                    : Appcolor.foodBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isComplete ? Icons.check_circle : Icons.list_alt,
                color: isComplete ? Appcolor.success : Appcolor.foodPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Appcolor.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalItems == 0
                        ? 'Empty list'
                        : '$totalItems items · $checkedItems done',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Appcolor.textMedium),
                  ),
                  if (totalItems > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? Appcolor.success : Appcolor.foodPrimary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
