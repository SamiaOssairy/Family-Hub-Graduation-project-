import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

class GroceryListDetailScreen extends StatefulWidget {
  const GroceryListDetailScreen({super.key});

  @override
  State<GroceryListDetailScreen> createState() =>
      _GroceryListDetailScreenState();
}

class _GroceryListDetailScreenState extends State<GroceryListDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _addItemCtrl = TextEditingController();
  final FocusNode _addItemFocus = FocusNode();

  String _listId = '';
  String _listTitle = '';
  List<dynamic> _items = [];
  bool _loading = true;
  bool _isEditing = false;
  final TextEditingController _titleCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _listId.isEmpty) {
      _listId = args['listId'] ?? '';
      _listTitle = args['title'] ?? 'Grocery List';
      _titleCtrl.text = _listTitle;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_listId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await _apiService.getGroceryListById(_listId);
      setState(() {
        _listTitle = data['list']?['title'] ?? _listTitle;
        _titleCtrl.text = _listTitle;
        _items = data['items'] ?? [];
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

  Future<void> _addItem() async {
    final name = _addItemCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      await _apiService.addGroceryItem(_listId, {'item_name': name});
      _addItemCtrl.clear();
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleItem(String itemId, bool isChecked) async {
    try {
      await _apiService.updateGroceryItem(itemId, {'is_checked': !isChecked});
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
    try {
      await _apiService.deleteGroceryItem(itemId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateTitle() async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty || newTitle == _listTitle) {
      setState(() => _isEditing = false);
      return;
    }
    try {
      await _apiService.updateGroceryList(_listId, {'title': newTitle});
      setState(() {
        _listTitle = newTitle;
        _isEditing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "$_listTitle"?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete this list and all items.',
          style: GoogleFonts.poppins(),
        ),
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
        await _apiService.deleteGroceryList(_listId);
        if (mounted) Navigator.pop(context);
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
  void dispose() {
    _addItemCtrl.dispose();
    _addItemFocus.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unchecked = _items.where((i) => i['is_checked'] != true).toList();
    final checked = _items.where((i) => i['is_checked'] == true).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _buildTopBar(),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00897B)),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAddItemInput(),
                            const SizedBox(height: 16),
                            if (_items.isEmpty)
                              _buildEmptyState()
                            else ...[
                              if (unchecked.isNotEmpty) ...[
                                Text(
                                  'To Buy (${unchecked.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...unchecked.map((item) =>
                                    _buildItemTile(item, false)),
                              ],
                              if (checked.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Done (${checked.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...checked.map((item) =>
                                    _buildItemTile(item, true)),
                              ],
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, color: Color(0xFF00352E)),
          ),
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00352E),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _updateTitle(),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _listTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00352E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined,
                            size: 18, color: Colors.grey[500]),
                      ],
                    ),
                  ),
          ),
          if (_isEditing)
            IconButton(
              onPressed: _updateTitle,
              icon: Icon(Icons.check, color: Color(0xFF00897B)),
            )
          else
            IconButton(
              onPressed: _deleteList,
              icon: Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildAddItemInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addItemCtrl,
              focusNode: _addItemFocus,
              decoration: InputDecoration(
                hintText: 'Add an item...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _addItem(),
            ),
          ),
          IconButton(
            onPressed: _addItem,
            icon: Icon(Icons.add_circle,
                color: Color(0xFF00897B), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No items in this list',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add items using the input above',
            style: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(dynamic item, bool isChecked) {
    final name = item['item_name'] ?? '';
    final itemId = item['_id'] ?? '';

    return Dismissible(
      key: Key(itemId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(itemId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isChecked
              ? null
              : Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleItem(itemId, isChecked),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? const Color(0xFF00897B) : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? const Color(0xFF00897B)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isChecked ? Colors.grey[400] : const Color(0xFF00352E),
                  decoration:
                      isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _deleteItem(itemId),
              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
