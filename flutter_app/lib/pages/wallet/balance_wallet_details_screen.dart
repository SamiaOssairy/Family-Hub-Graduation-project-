import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';

class BalanceWalletDetailsScreen extends StatefulWidget {
  const BalanceWalletDetailsScreen({super.key});

  @override
  State<BalanceWalletDetailsScreen> createState() => _BalanceWalletDetailsScreenState();
}

class _BalanceWalletDetailsScreenState extends State<BalanceWalletDetailsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String _selectedScope = 'all';
  Map<String, dynamic> _member = {};
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _details = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getBalanceWalletDetails();
      if (!mounted) return;
      final rawDetails = (data['details'] ?? []) as List;
      setState(() {
        _member = Map<String, dynamic>.from(data['member'] ?? {});
        _summary = Map<String, dynamic>.from(data['summary'] ?? {});
        _details = rawDetails
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load balance details: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredDetails {
    if (_selectedScope == 'all') return _details;
    return _details.where((detail) => (detail['wallet_scope'] ?? '').toString() == _selectedScope).toList();
  }

  @override
  Widget build(BuildContext context) {
    final memberName = (_member['member_name'] ?? 'Member').toString();
    final memberMail = (_member['member_mail'] ?? '').toString();
    final moneySummary = _summary['money_wallet'] as Map<String, dynamic>? ?? {};
    final personalSummary = _summary['personal_budget'] as Map<String, dynamic>? ?? {};
    final sharedSummary = _summary['shared_budget'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: Text('Balance Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _loadDetails,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(memberName, memberMail),
                  const SizedBox(height: 16),
                  _buildSummaryCards(moneySummary, personalSummary, sharedSummary),
                  const SizedBox(height: 16),
                  _buildScopeChips(),
                  const SizedBox(height: 12),
                  _filteredDetails.isEmpty
                      ? _emptyState()
                      : Column(
                          children: _filteredDetails.map(_buildDetailCard).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String name, String mail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(mail, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    Map<String, dynamic> moneySummary,
    Map<String, dynamic> personalSummary,
    Map<String, dynamic> sharedSummary,
  ) {
    final moneyCredits = (moneySummary['credits'] ?? 0) as num;
    final moneyDebits = (moneySummary['debits'] ?? 0) as num;
    final personalCredits = (personalSummary['credits'] ?? 0) as num;
    final personalDebits = (personalSummary['debits'] ?? 0) as num;
    final sharedCredits = (sharedSummary['credits'] ?? 0) as num;
    final sharedDebits = (sharedSummary['debits'] ?? 0) as num;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryCard('Money Wallet', '${moneyCredits.toDouble().toStringAsFixed(2)} in / ${moneyDebits.toDouble().toStringAsFixed(2)} out', const Color(0xFF1565C0)),
        _summaryCard('Personal Budget', '${personalCredits.toDouble().toStringAsFixed(2)} in / ${personalDebits.toDouble().toStringAsFixed(2)} out', const Color(0xFF00897B)),
        _summaryCard('Shared Budget', '${sharedCredits.toDouble().toStringAsFixed(2)} in / ${sharedDebits.toDouble().toStringAsFixed(2)} out', const Color(0xFFF57C00)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 42) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChips() {
    return Wrap(
      spacing: 8,
      children: [
        _scopeChip('All', 'all'),
        _scopeChip('Money', 'money_wallet'),
        _scopeChip('Personal', 'personal_budget'),
        _scopeChip('Shared', 'shared_budget'),
      ],
    );
  }

  Widget _scopeChip(String label, String value) {
    final selected = _selectedScope == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedScope = value),
      selectedColor: const Color(0xFF1B5E20).withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1B5E20) : Colors.black87,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? const Color(0xFF1B5E20) : Colors.grey.shade300),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildDetailCard(Map<String, dynamic> detail) {
    final isCredit = detail['change_type'] == 'credit';
    final scope = (detail['wallet_scope'] ?? 'money_wallet').toString();
    final amount = ((detail['amount'] ?? 0) as num).toDouble();
    final createdAt = DateTime.tryParse((detail['createdAt'] ?? '').toString());
    final title = (detail['title'] ?? 'Balance change').toString();
    final description = (detail['description'] ?? '').toString();
    final source = (detail['source_type'] ?? 'manual_adjustment').toString();
    final author = (detail['added_by_mail'] ?? detail['member_mail'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCredit ? const Color(0xFF00897B).withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isCredit ? const Color(0xFF00897B) : Colors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${isCredit ? '+' : '-'}${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: isCredit ? const Color(0xFF00897B) : Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Text(_formatDate(createdAt), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Text(scope.replaceAll('_', ' '), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          ],
          const SizedBox(height: 6),
          Text('Source: $source', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('By: $author', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text('No balance details yet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Balance changes will appear here once money is added or deducted.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
