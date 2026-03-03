import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/services/api_service.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final receipts = await _apiService.getAllReceipts();
      setState(() {
        _receipts = receipts;
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
                // Green header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF388E3C),
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
                          child: CircularProgressIndicator(color: Color(0xFF388E3C)))
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
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                                itemCount: _receipts.length,
                                itemBuilder: (ctx, i) => _buildReceiptCard(_receipts[i]),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF388E3C),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildReceiptCard(dynamic receipt) {
    final store = receipt['store_name'] ?? 'Unknown Store';
    final amount = receipt['total_amount'] ?? 0;
    final date = receipt['purchase_date'] ?? receipt['createdAt'] ?? '';
    final id = receipt['_id'] ?? '';
    final items = receipt['items'] as List<dynamic>? ?? [];
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
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green header section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFC8E6C9),
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
                          color: const Color(0xFF388E3C),
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
                      color: Colors.white.withOpacity(0.5),
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
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.grey[700], size: 20),
                  ),
                ),
              ],
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
                                fontSize: 13, color: const Color(0xFF2E3E33)),
                          ),
                        ),
                        Text(
                          'EGP ${(price is num ? price : 0).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E3E33)),
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
                          color: const Color(0xFF2E3E33))),
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
                  color: isBold ? const Color(0xFF2E3E33) : Colors.grey[600])),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: isBold ? const Color(0xFF2E3E33) : Colors.grey[700])),
        ],
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
                        color: Color(0xFF388E3C),
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
                                        color: const Color(0xFF2E3E33))),
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
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add, size: 14, color: Colors.green[800]),
                                        const SizedBox(width: 4),
                                        Text('Add Item',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.green[800],
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
                                color: const Color(0xFFC8E6C9),
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
                                          color: const Color(0xFF388E3C))),
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
                              child: ElevatedButton(
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
                                  backgroundColor: const Color(0xFF388E3C),
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

  Future<void> _deleteReceipt(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Receipt',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this receipt?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _apiService.deleteReceipt(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
