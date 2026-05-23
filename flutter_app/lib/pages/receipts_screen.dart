import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';
import '../core/styling/app_color.dart';
import '../core/utils/food_utils.dart';
import '../core/widgets/guarded_button.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _receipts = [];
  List<dynamic> _inventories = [];
  bool _loading = true;
  bool _isScanning = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _apiService.getAllReceipts(),
        _apiService.getAllInventories(),
      ]);
      setState(() {
        _receipts = results[0];
        _inventories = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnack(context, 'Error: $e');
    }
  }

  List<dynamic> get _filteredReceipts {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _receipts;
    return _receipts.where((r) {
      final store = (r['store_name'] ?? '').toString().toLowerCase();
      final notes = (r['notes'] ?? '').toString().toLowerCase();
      return store.contains(q) || notes.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolor.foodBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // Green header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 24),
                  decoration: const BoxDecoration(
                    color: Appcolor.foodPrimary,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Receipts',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Appcolor.foodPrimary))
                      : _receipts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text('No receipts yet',
                                      style: GoogleFonts.poppins(
                                          fontSize: 16, color: Colors.grey[500])),
                                  const SizedBox(height: 4),
                                  Text('Tap + to add your first receipt',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: Column(
                                children: [
                                  // Search bar
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText: 'Search by store name...',
                                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                          prefixIcon: const Icon(Icons.search, color: Appcolor.foodPrimary),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Receipt count
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${_filteredReceipts.length} receipt${_filteredReceipts.length == 1 ? '' : 's'}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        const Spacer(),
                                        if (_receipts.isNotEmpty)
                                          Text(
                                            'Total: EGP ${_receipts.fold<double>(0, (sum, r) => sum + ((r['total_amount'] ?? 0) is num ? (r['total_amount'] as num).toDouble() : 0)).toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Appcolor.foodPrimary),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // List
                                  Expanded(
                                    child: _filteredReceipts.isEmpty
                                        ? Center(
                                            child: Text(
                                              _searchCtrl.text.isNotEmpty
                                                  ? 'No receipts match your search'
                                                  : 'No receipts yet',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 14, color: Colors.grey[500]),
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                                            itemCount: _filteredReceipts.length,
                                            itemBuilder: (ctx, i) =>
                                                _buildReceiptCard(_filteredReceipts[i]),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isScanning)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00695C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('Scanning receipt…',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          FloatingActionButton(
            heroTag: 'scan_fab',
            onPressed: _isScanning ? null : _scanReceipt,
            backgroundColor: const Color(0xFF00695C),
            mini: true,
            tooltip: 'Scan receipt with AI',
            child: const Icon(Icons.document_scanner,
                color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: () => _showAddEditDialog(),
            backgroundColor: Appcolor.foodPrimary,
            tooltip: 'Add receipt manually',
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(dynamic receipt) {
    final store = receipt['store_name'] ?? 'Unknown Store';
    final amount = receipt['total_amount'] ?? 0;
    final date = receipt['purchase_date'] ?? receipt['createdAt'] ?? '';
    final id = receipt['_id'] ?? '';
    final items = receipt['items'] as List<dynamic>? ?? [];
    final photoUrl = receipt['receipt_photo_url'];
    final subtotal = receipt['subtotal'] ?? 0;
    final taxes = receipt['taxes'] ?? 0;

    String formattedDate = '';
    try {
      formattedDate = DateFormat('MMM d, yyyy').format(DateTime.parse(date));
    } catch (_) {
      formattedDate = date.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB2DFDB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green header section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: Appcolor.foodCardBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store: $store',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Appcolor.foodPrimary,
                        ),
                      ),
                      Text(
                        'Date: $formattedDate',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAddEditDialog(receipt: receipt),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.settings_outlined,
                        color: Colors.grey[700], size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _deleteReceipt(id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.grey[700], size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Receipt photo
          if (photoUrl != null && photoUrl.toString().isNotEmpty)
            GestureDetector(
              onTap: () => _showPhotoFullScreen(photoUrl),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: photoUrl.toString().startsWith('data:')
                        ? MemoryImage(base64Decode(photoUrl.toString().split(',').last))
                        : NetworkImage(photoUrl.toString()) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Tap to view',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Line items
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: items.map<Widget>((item) {
                  final name = item['name'] ?? '';
                  final qty = item['quantity'] ?? '1';
                  final unit = item['unit'] ?? '';
                  final price = item['price'] ?? 0;
                  final unitStr = unit.toString().isNotEmpty ? '$unit ' : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$qty $unitStr$name',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: const Color(0xFF00352E)),
                          ),
                        ),
                        Text(
                          'EGP ${(price is num ? price : 0).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Appcolor.textDark),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Payment Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text('Payment Summary',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Appcolor.textDark)),
                  const SizedBox(height: 6),
                  _summaryRow('Subtotal',
                      'EGP ${(subtotal is num ? subtotal : 0).toStringAsFixed(2)}', false),
                  _summaryRow('Taxes',
                      'EGP ${(taxes is num ? taxes : 0).toStringAsFixed(2)}', false),
                  const SizedBox(height: 4),
                ],
                _summaryRow('Total amount',
                    'EGP ${(amount is num ? amount : 0).toStringAsFixed(2)}', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isBold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
                  color: isBold ? Appcolor.textDark : Colors.grey[600])),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: isBold ? Appcolor.textDark : Colors.grey[700])),
        ],
      ),
    );
  }

  void _showPhotoFullScreen(String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: photoUrl.startsWith('data:')
                    ? Image.memory(
                        base64Decode(photoUrl.split(',').last),
                        fit: BoxFit.contain,
                      )
                    : Image.network(photoUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Add/Edit Receipt Dialog ====================

  void _showAddEditDialog({dynamic receipt}) {
    final isEdit = receipt != null;
    final storeCtrl = TextEditingController(
        text: isEdit ? (receipt['store_name'] ?? '') : '');
    final subtotalCtrl = TextEditingController(
        text: isEdit ? '${receipt['subtotal'] ?? 0}' : '');
    final taxesCtrl = TextEditingController(
        text: isEdit ? '${receipt['taxes'] ?? 0}' : '');
    final notesCtrl = TextEditingController(
        text: isEdit ? (receipt['notes'] ?? '') : '');
    DateTime? purchaseDate;
    if (isEdit && receipt['purchase_date'] != null) {
      try {
        purchaseDate = DateTime.parse(receipt['purchase_date']);
      } catch (_) {}
    }

    // Photo
    String? photoBase64 = isEdit ? receipt['receipt_photo_url'] : null;

    // Line items
    List<Map<String, dynamic>> lineItems = [];
    if (isEdit && receipt['items'] != null) {
      for (var item in (receipt['items'] as List<dynamic>)) {
        lineItems.add(Map<String, dynamic>.from(item));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double sub = double.tryParse(subtotalCtrl.text) ?? 0;
            double tax = double.tryParse(taxesCtrl.text) ?? 0;
            double total = sub + tax;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 450,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Appcolor.foodPrimary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isEdit ? 'Edit Receipt' : 'Add Receipt',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
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
                            _formLabel('Store Name'),
                            _formField(storeCtrl, 'e.g. Oscar, Carrefour'),
                            const SizedBox(height: 14),

                            // Receipt Photo
                            _formLabel('Receipt Photo (optional)'),
                            const SizedBox(height: 6),
                            if (photoBase64 != null && photoBase64!.isNotEmpty)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: photoBase64!.startsWith('data:')
                                        ? Image.memory(
                                            base64Decode(photoBase64!.split(',').last),
                                            width: double.infinity,
                                            height: 150,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            photoBase64!,
                                            width: double.infinity,
                                            height: 150,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => setDialogState(() => photoBase64 = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 1200,
                                      maxHeight: 1200,
                                      imageQuality: 70,
                                    );
                                    if (pickedFile != null) {
                                      final bytes = await pickedFile.readAsBytes();
                                      final base64Str = base64Encode(bytes);
                                      final mimeType = pickedFile.mimeType ?? 'image/jpeg';
                                      setDialogState(() {
                                        photoBase64 = 'data:$mimeType;base64,$base64Str';
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error picking image: $e')),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 32, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to add receipt photo',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, color: Colors.grey[500]),
                                      ),
                                      Text(
                                        'Take a photo or choose from gallery',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),

                            _formLabel('Purchase Date'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: purchaseDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (picked != null) {
                                  setDialogState(() => purchaseDate = picked);
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
                                      purchaseDate != null
                                          ? DateFormat('MMM d, yyyy').format(purchaseDate!)
                                          : 'Select date',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: purchaseDate != null
                                              ? Colors.black87
                                              : Colors.grey[400]),
                                    ),
                                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[500]),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Line Items section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Items',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: const Color(0xFF00352E))),
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      lineItems.add({
                                        'name': '',
                                        'quantity': '1',
                                        'unit': '',
                                        'price': 0,
                                      });
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2F1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFB2DFDB)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add, size: 14, color: Color(0xFF00897B)),
                                        const SizedBox(width: 4),
                                        Text('Add Item',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFF00897B),
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (lineItems.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'No items added yet. Tap "Add Item" above.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                                ),
                              )
                            else
                              ...lineItems.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return _buildLineItemRow(item, idx, setDialogState, lineItems);
                              }),

                            const SizedBox(height: 16),

                            // Payment summary
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _formLabel('Subtotal (EGP)'),
                                      _formField(subtotalCtrl, '0.00',
                                          isNumber: true,
                                          onChanged: (_) => setDialogState(() {})),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _formLabel('Taxes (EGP)'),
                                      _formField(taxesCtrl, '0.00',
                                          isNumber: true,
                                          onChanged: (_) => setDialogState(() {})),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Total display
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Appcolor.foodCardBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total amount',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('EGP ${total.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Appcolor.foodPrimary)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            _formLabel('Notes (optional)'),
                            _formField(notesCtrl, 'Optional notes', maxLines: 2),
                            const SizedBox(height: 18),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: GuardedElevatedButton(
                                onPressed: () async {
                                  if (storeCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter store name')),
                                    );
                                    return;
                                  }
                                  final s = double.tryParse(subtotalCtrl.text) ?? 0;
                                  final t = double.tryParse(taxesCtrl.text) ?? 0;
                                  final body = <String, dynamic>{
                                    'store_name': storeCtrl.text.trim(),
                                    'total_amount': s + t,
                                    'subtotal': s,
                                    'taxes': t,
                                    'notes': notesCtrl.text.trim(),
                                    'receipt_photo_url': photoBase64,
                                    'items': lineItems
                                        .where((i) =>
                                            (i['name'] ?? '').toString().isNotEmpty)
                                        .toList(),
                                  };
                                  if (purchaseDate != null) {
                                    body['purchase_date'] = purchaseDate!.toIso8601String();
                                  } else {
                                    body['purchase_date'] = DateTime.now().toIso8601String();
                                  }
                                  try {
                                    if (isEdit) {
                                      await _apiService.updateReceipt(receipt['_id'], body);
                                    } else {
                                      await _apiService.createReceipt(body);
                                    }
                                    Navigator.pop(ctx);
                                    _loadData();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Appcolor.foodPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  isEdit ? 'Save Changes' : 'Add Receipt',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
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

  Widget _buildLineItemRow(Map<String, dynamic> item, int idx,
      StateSetter setDialogState, List<Map<String, dynamic>> lineItems) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: item['name'] ?? ''),
              onChanged: (v) => item['name'] = v,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Item name',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 1,
            child: TextField(
              controller: TextEditingController(text: item['quantity'] ?? '1'),
              onChanged: (v) => item['quantity'] = v,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Qty',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: '${item['price'] ?? ''}'),
              onChanged: (v) => item['price'] = double.tryParse(v) ?? 0,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'EGP',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setDialogState(() => lineItems.removeAt(idx)),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 18, color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint,
      {bool isNumber = false, int maxLines = 1, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  // ==================== Scan Receipt ====================

  Future<void> _scanReceipt() async {
    // Let user choose camera or gallery
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan Receipt',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('AI will read the items automatically',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt,
                    color: Appcolor.foodPrimary),
              ),
              title: Text('Take a Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Use the camera',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library,
                    color: Appcolor.foodPrimary),
              ),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('Pick an existing photo',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isScanning = true);

      final imageBytes = await pickedFile.readAsBytes();
      final scanned = await _apiService.scanReceipt(imageBytes);

      if (!mounted) return;
      setState(() => _isScanning = false);

      _showScanPreviewDialog(scanned, imageBytes);
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        showErrorSnack(context, 'Scan failed: $e');
      }
    }
  }

  // ==================== Scan Preview Dialog ====================

  void _showScanPreviewDialog(
      Map<String, dynamic> scanned, Uint8List imageBytes) {
    final storeCtrl =
        TextEditingController(text: scanned['store_name'] ?? '');
    final subtotalCtrl = TextEditingController(
        text: '${scanned['subtotal'] ?? 0}');
    final taxesCtrl =
        TextEditingController(text: '${scanned['taxes'] ?? 0}');

    DateTime purchaseDate = DateTime.now();
    if (scanned['purchase_date'] != null) {
      try {
        purchaseDate = DateTime.parse(scanned['purchase_date'].toString());
      } catch (_) {}
    }

    // Build items list with an addToInventory toggle
    final List<Map<String, dynamic>> items = [];
    for (final raw in (scanned['items'] as List<dynamic>? ?? [])) {
      final item = raw as Map<String, dynamic>;
      items.add({
        'name': item['name'] ?? '',
        'quantity': item['quantity']?.toString() ?? '1',
        'unit': item['unit'] ?? '',
        'price': (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : 0.0,
        'addToInventory': true,
      });
    }

    String? selectedInventoryId = _inventories.isNotEmpty
        ? _inventories.first['_id']?.toString()
        : null;
    bool addToInventory = _inventories.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sub = double.tryParse(subtotalCtrl.text) ?? 0;
          final tax = double.tryParse(taxesCtrl.text) ?? 0;
          double total = sub + tax;
          if (total == 0) {
            total = (scanned['total_amount'] is num)
                ? (scanned['total_amount'] as num).toDouble()
                : 0;
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 480,
              constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Gradient header ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF00ACC1)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.document_scanner,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Scanned Receipt',
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              Text('Review & confirm before saving',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white70)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close,
                              color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // ── Body ────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Scanned image thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              imageBytes,
                              width: double.infinity,
                              height: 130,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // AI info badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 16,
                                    color: Appcolor.foodPrimary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI detected ${items.length} item${items.length != 1 ? 's' : ''}. Edit or remove before saving.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Appcolor.foodPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Store name
                          _formLabel('Store Name'),
                          _formField(storeCtrl, 'Store name'),
                          const SizedBox(height: 14),

                          // Date picker
                          _formLabel('Purchase Date'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setDialogState(
                                    () => purchaseDate = picked);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM d, yyyy')
                                        .format(purchaseDate),
                                    style: GoogleFonts.poppins(
                                        fontSize: 13),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 18,
                                      color: Colors.grey[500]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Items header
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Items (${items.length})',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: const Color(0xFF00352E)),
                              ),
                              if (items.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    final allOn = items.every(
                                        (i) =>
                                            i['addToInventory'] ==
                                            true);
                                    setDialogState(() {
                                      for (final i in items) {
                                        i['addToInventory'] = !allOn;
                                      }
                                    });
                                  },
                                  child: Text(
                                    items.every((i) =>
                                            i['addToInventory'] == true)
                                        ? 'Deselect all'
                                        : 'Select all',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Appcolor.foodPrimary),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Items list
                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              child: Text('No items detected',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[500])),
                            )
                          else
                            ...items.asMap().entries.map((e) =>
                                _buildScanItemRow(e.value, e.key,
                                    setDialogState, items)),

                          const SizedBox(height: 14),

                          // Subtotal / Taxes
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _formLabel('Subtotal (EGP)'),
                                      _formField(subtotalCtrl, '0.00',
                                          isNumber: true,
                                          onChanged: (_) =>
                                              setDialogState(() {})),
                                    ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _formLabel('Taxes (EGP)'),
                                      _formField(taxesCtrl, '0.00',
                                          isNumber: true,
                                          onChanged: (_) =>
                                              setDialogState(() {})),
                                    ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Appcolor.foodCardBg,
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                  'EGP ${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Appcolor.foodPrimary),
                                ),
                              ],
                            ),
                          ),

                          // ── Add to Inventory section ─────────
                          if (_inventories.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Add to Inventory',
                                          style: GoogleFonts.poppins(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 14,
                                              color: const Color(
                                                  0xFF00352E))),
                                      Text(
                                        'Checked items will be added to your selected inventory',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: addToInventory,
                                  activeThumbColor: Appcolor.foodPrimary,
                                  activeTrackColor: const Color(0xFF80CBC4),
                                  onChanged: (v) => setDialogState(
                                      () => addToInventory = v),
                                ),
                              ],
                            ),
                            if (addToInventory) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey[300]!),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedInventoryId,
                                    hint: Text('Select inventory',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13)),
                                    isExpanded: true,
                                    items: _inventories.map((inv) {
                                      return DropdownMenuItem<String>(
                                        value:
                                            inv['_id']?.toString(),
                                        child: Text(
                                          inv['title']?.toString() ??
                                              inv['name']?.toString() ??
                                              'Inventory',
                                          style: GoogleFonts.poppins(
                                              fontSize: 13),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setDialogState(
                                        () => selectedInventoryId = v),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '✓ Check the items above you want to add',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ],

                          const SizedBox(height: 20),

                          // ── Confirm button ───────────────────
                          SizedBox(
                            width: double.infinity,
                            child: GuardedElevatedButton(
                              onPressed: () async {
                                final s = double.tryParse(
                                        subtotalCtrl.text) ??
                                    0;
                                final t =
                                    double.tryParse(taxesCtrl.text) ??
                                        0;
                                final tot = (s + t) > 0
                                    ? s + t
                                    : (scanned['total_amount'] is num
                                        ? (scanned['total_amount']
                                                as num)
                                            .toDouble()
                                        : 0.0);

                                final photoBase64 =
                                    'data:image/jpeg;base64,${base64Encode(imageBytes)}';

                                final body = <String, dynamic>{
                                  'store_name': storeCtrl.text
                                          .trim()
                                          .isNotEmpty
                                      ? storeCtrl.text.trim()
                                      : 'Unknown Store',
                                  'total_amount': tot,
                                  'subtotal': s,
                                  'taxes': t,
                                  'purchase_date':
                                      purchaseDate.toIso8601String(),
                                  'receipt_photo_url': photoBase64,
                                  'items': items
                                      .where((i) =>
                                          (i['name'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                      .map((i) => {
                                            'name': i['name'],
                                            'quantity': i['quantity'],
                                            'unit': i['unit'],
                                            'price': i['price'],
                                          })
                                      .toList(),
                                };

                                try {
                                  await _apiService.createReceipt(body);

                                  // Add checked items to inventory
                                  if (addToInventory &&
                                      selectedInventoryId != null) {
                                    final checked = items
                                        .where((i) =>
                                            i['addToInventory'] ==
                                                true &&
                                            (i['name'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                        .toList();
                                    for (final item in checked) {
                                      try {
                                        await _apiService
                                            .addInventoryItem(
                                          selectedInventoryId!,
                                          {
                                            'item_name': item['name'],
                                            'quantity':
                                                double.tryParse(
                                                        item['quantity']
                                                            ?.toString() ??
                                                            '1') ??
                                                    1,
                                          },
                                        );
                                      } catch (_) {
                                        // skip individual item failures
                                      }
                                    }
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  _loadData();
                                  final checkedCount = items
                                      .where((i) =>
                                          i['addToInventory'] == true)
                                      .length;
                                  final msg = (addToInventory &&
                                          selectedInventoryId != null)
                                      ? 'Receipt saved & $checkedCount item${checkedCount != 1 ? 's' : ''} added to inventory!'
                                      : 'Receipt saved successfully!';
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(msg,
                                        style: GoogleFonts.poppins()),
                                    backgroundColor:
                                        Appcolor.foodPrimary,
                                  ));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text('Error: $e')));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Appcolor.foodPrimary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'Confirm & Save',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16),
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
      ),
    );
  }

  /// Row used inside the scan preview dialog — shows checkbox + editable fields.
  Widget _buildScanItemRow(
    Map<String, dynamic> item,
    int idx,
    StateSetter setDialogState,
    List<Map<String, dynamic>> items,
  ) {
    final isChecked = item['addToInventory'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isChecked
            ? const Color(0xFFE0F2F1)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isChecked
              ? const Color(0xFFB2DFDB)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Inventory checkbox
          GestureDetector(
            onTap: () => setDialogState(
                () => item['addToInventory'] = !isChecked),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked
                    ? Appcolor.foodPrimary
                    : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isChecked
                      ? Appcolor.foodPrimary
                      : Colors.grey[400]!,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            flex: 3,
            child: TextField(
              controller:
                  TextEditingController(text: item['name'] ?? ''),
              onChanged: (v) => item['name'] = v,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Item name',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Quantity
          Expanded(
            flex: 1,
            child: TextField(
              controller: TextEditingController(
                  text: item['quantity']?.toString() ?? '1'),
              onChanged: (v) => item['quantity'] = v,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Qty',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Price
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(
                  text: '${item['price'] ?? ''}'),
              onChanged: (v) =>
                  item['price'] = double.tryParse(v) ?? 0,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'EGP',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
              ),
            ),
          ),
          // Delete
          GestureDetector(
            onTap: () =>
                setDialogState(() => items.removeAt(idx)),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close,
                  size: 18, color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReceipt(String id) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete Receipt',
      message: 'Are you sure you want to delete this receipt?',
    );
    if (confirm) {
      try {
        await _apiService.deleteReceipt(id);
        _loadData();
      } catch (e) {
        if (mounted) showErrorSnack(context, 'Error: $e');
      }
    }
  }
}
