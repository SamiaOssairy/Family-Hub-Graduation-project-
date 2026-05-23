import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_frontend/core/theme/app_theme.dart';
import 'package:app_frontend/core/theme/theme_provider.dart';
import 'package:app_frontend/pages/budget/budget_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic> budget;
  const AddExpenseScreen({super.key, required this.budget});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // ── State (ALL UNCHANGED) ─────────────────────────────────────────────────
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  String? _selectedCategoryId;
  String _expenseScope = 'shared';
  DateTime _expenseDate = DateTime.now();
  bool _isEmergency = false;
  bool _isLoading   = false;
  XFile? _receiptImage;

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  // ── Logic (ALL UNCHANGED) ─────────────────────────────────────────────────

  List<Map<String, dynamic>> get _categories {
    final raw = List<Map<String, dynamic>>.from(widget.budget['categories'] ?? []);
    final seen = <String>{};
    final normalized = <Map<String, dynamic>>[];
    for (final category in raw) {
      final categoryId =
          (category['_id'] ?? category['category_id'] ?? '').toString().trim();
      if (categoryId.isEmpty || seen.contains(categoryId)) continue;
      seen.add(categoryId);
      normalized.add({
        ...category,
        '_id': categoryId,
        'category_id': categoryId,
      });
    }
    return normalized;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _receiptImage = img);
  }

  Future<void> _submit() async {
    final categories = _categories;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    if (_expenseScope == 'shared' && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final provider = context.read<FamilyBudgetProvider>();
      final isParent = provider.isParentUser;
      final title = _descCtrl.text.trim().isEmpty
          ? '${_expenseScope == 'personal' ? 'Personal' : 'Shared'} expense'
          : _descCtrl.text.trim();
      final categoryName = _selectedCategoryId == null
          ? 'General'
          : (categories.firstWhere(
                (cat) => cat['_id'] == _selectedCategoryId,
                orElse: () => {})['name'] ??
              'General');

      if (!isParent && _expenseScope == 'shared') {
        await provider.submitExpenseRequest({
          'budget_id': widget.budget['_id'],
          'budget_category_id': _selectedCategoryId,
          'amount': amount,
          'description': _descCtrl.text.trim(),
          'title': title,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Request submitted! Waiting for parent approval.'),
                backgroundColor: Color(0xFF1565C0)));
        }
      } else {
        await provider.createExpense({
          'budget_id': widget.budget['_id'],
          'budget_category_id': _selectedCategoryId,
          'amount': amount,
          'expense_date': _expenseDate.toIso8601String(),
          'description': _descCtrl.text.trim(),
          'source_module': 'manual',
          'expense_scope': _expenseScope,
          'title': title,
          'category': categoryName,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Expense added!'),
                backgroundColor: AppColors.primary));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.primary; }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? const Color(0xFF0A1628) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final border = isDark ? const Color(0xFF1E3A4A) : AppColors.border;

    final categories = _categories;
    final selectedCategoryValue = categories.any((c) => c['_id'] == _selectedCategoryId)
        ? _selectedCategoryId : null;
    final emergencyTotal     = (widget.budget['emergency_fund_amount'] ?? 0).toDouble();
    final emergencySpent     = (widget.budget['emergency_fund_spent']  ?? 0).toDouble();
    final emergencyRemaining = emergencyTotal - emergencySpent;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Add Expense',
            style: GoogleFonts.poppins(
                fontSize: _sp(17), fontWeight: FontWeight.w700)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Amount ──────────────────────────────────────────────────────
            _label('AMOUNT', isDark),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF122030) : AppColors.background,
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('EGP',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(14), fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          fontSize: _sp(20), fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFE0F2F1)
                              : AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint, fontSize: _sp(20)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Expense Type ─────────────────────────────────────────────────
            _label('EXPENSE TYPE', isDark),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border.all(color: border, width: 0.8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: ['shared', 'personal'].map((scope) {
                  final isActive = _expenseScope == scope;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _expenseScope = scope),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          children: [
                            Text(
                              scope == 'shared' ? 'Shared' : 'Personal',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: _sp(12), fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              scope == 'shared'
                                  ? 'Family budget'
                                  : 'Member wallet',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: _sp(9),
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Category ─────────────────────────────────────────────────────
            _label(
                _expenseScope == 'shared'
                    ? 'CATEGORY'
                    : 'CATEGORY (OPTIONAL)',
                isDark),
            _fieldContainer(isDark,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.category_outlined,
                          size: 13, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _expenseScope == 'shared'
                          ? 'Select category'
                          : 'Optional',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(12), color: AppColors.textHint),
                    ),
                  ]),
                  value: selectedCategoryValue,
                  dropdownColor: cardBg,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
                  items: categories.map((cat) {
                    final color = _parseColor(cat['color'] ?? '#00897B');
                    return DropdownMenuItem<String>(
                      value: (cat['_id'] ?? cat['category_id']).toString(),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Center(
                            child: Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(cat['name'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(12),
                                color: isDark
                                    ? const Color(0xFFE0F2F1)
                                    : AppColors.textPrimary)),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Date ─────────────────────────────────────────────────────────
            _label('DATE', isDark),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white),
                    ),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _expenseDate = d);
              },
              child: _fieldContainer(isDark,
                child: Row(children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(_expenseDate),
                    style: GoogleFonts.poppins(
                        fontSize: _sp(13),
                        color: isDark
                            ? const Color(0xFFE0F2F1)
                            : AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.textSecondary),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────────────────
            _label('DESCRIPTION (OPTIONAL)', isDark),
            Container(
              constraints: const BoxConstraints(minHeight: 70),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF122030) : AppColors.background,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: TextField(
                controller: _descCtrl,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.poppins(
                    fontSize: _sp(12),
                    color: isDark
                        ? const Color(0xFFE0F2F1)
                        : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: GoogleFonts.poppins(
                      color: AppColors.textHint, fontSize: _sp(12)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Receipt photo ─────────────────────────────────────────────────
            _label('RECEIPT PHOTO (OPTIONAL)', isDark),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: _receiptImage != null ? 160 : 72,
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(
                      color: _receiptImage != null
                          ? AppColors.primary
                          : border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: _receiptImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(File(_receiptImage!.path),
                            fit: BoxFit.cover, width: double.infinity),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.camera_alt_outlined,
                                size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Text('Tap to add receipt photo',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(12),
                                  color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Emergency fund toggle ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border.all(
                    color: _isEmergency
                        ? AppColors.primary
                        : border),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                      child: Text('⚡', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Fund',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(12), fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFE0F2F1)
                                    : AppColors.textPrimary)),
                        Text(
                          _isEmergency
                              ? 'Remaining: ${emergencyRemaining.toStringAsFixed(2)} EGP'
                              : 'Deduct from category budget',
                          style: GoogleFonts.poppins(
                              fontSize: _sp(10), color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _isEmergency,
                      onChanged: (v) => setState(() => _isEmergency = v),
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primarySurface,
                      inactiveTrackColor: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────────────────
            GestureDetector(
              onTap: _isLoading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? null
                      : LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isLoading ? AppColors.border : null,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _isLoading
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Save Expense',
                          style: GoogleFonts.poppins(
                              fontSize: _sp(14), fontWeight: FontWeight.w700,
                              color: Colors.white)),
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

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _label(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: _sp(9), fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _fieldContainer(bool isDark, {required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF122030) : AppColors.background,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(11),
    ),
    child: child,
  );
}
