import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_frontend/core/services/api_service.dart';
import 'package:app_frontend/core/theme/app_theme.dart';
import 'package:app_frontend/core/theme/theme_provider.dart';
import 'package:app_frontend/core/widgets/app_bottom_nav.dart';
import 'package:app_frontend/pages/budget/budget_provider.dart';
import 'package:app_frontend/pages/budget/add_expense_screen.dart';
import 'package:app_frontend/pages/budget/budget_analytics_screen.dart';
import 'package:app_frontend/pages/budget/future_events_screen.dart';
import 'package:app_frontend/pages/budget/widgets/budget_progress_indicator.dart' as bpi;
import 'package:app_frontend/pages/budget/widgets/emergency_fund_card.dart' as efc;
import 'package:app_frontend/pages/budget/widgets/category_spending_tile.dart' as cst;

class BudgetDashboardScreen extends StatefulWidget {
  const BudgetDashboardScreen({super.key});
  @override
  State<BudgetDashboardScreen> createState() => _BudgetDashboardScreenState();
}

class _BudgetDashboardScreenState extends State<BudgetDashboardScreen> {
  // ── New state ──────────────────────────────────────────────────────────────
  final ApiService _apiService = ApiService();
  bool _isParent = false;
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _pendingLoading = false;

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FamilyBudgetProvider>().loadBudgets();
      _checkParentStatus();
      _loadPendingRequests();
    });
  }

  // ── New helper methods ─────────────────────────────────────────────────────

  Future<void> _checkParentStatus() async {
    try {
      final result = await _apiService.isParent();
      if (mounted) setState(() => _isParent = result);
    } catch (_) {}
  }

  Future<void> _loadPendingRequests() async {
    if (mounted) setState(() => _pendingLoading = true);
    try {
      final requests = await context.read<FamilyBudgetProvider>().getExpenseRequests(status: 'pending');
      if (mounted) setState(() => _pendingRequests = requests);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<void> _approveRequest(String id) async {
    try {
      await context.read<FamilyBudgetProvider>().approveExpenseRequest(id);
      _loadPendingRequests();
      context.read<FamilyBudgetProvider>().loadBudgets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request approved', style: GoogleFonts.poppins()),
              backgroundColor: AppColors.primary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectRequest(String id) async {
    try {
      await context.read<FamilyBudgetProvider>().rejectExpenseRequest(id);
      _loadPendingRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request rejected', style: GoogleFonts.poppins())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red));
      }
    }
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color _categoryColor(String name, int index) {
    final n = name.toLowerCase();
    if (n.contains('grocer') || n.contains('food')) return const Color(0xFF00897B);
    if (n.contains('util')) return const Color(0xFF00ACC1);
    if (n.contains('entertain')) return const Color(0xFFFB8C00);
    if (n.contains('educ')) return const Color(0xFF4DB6AC);
    if (n.contains('transport') || n.contains('travel')) return const Color(0xFF7B1FA2);
    if (n.contains('health') || n.contains('medical')) return const Color(0xFFE91E63);
    const fallback = [
      Color(0xFF00897B), Color(0xFF00ACC1), Color(0xFFFB8C00),
      Color(0xFF4DB6AC), Color(0xFF7B1FA2), Color(0xFFE91E63),
    ];
    return fallback[index % fallback.length];
  }

  static const _memberColors = [
    {'bg': Color(0xFFE3F2FD), 'text': Color(0xFF1565C0), 'border': Color(0xFF90CAF9)},
    {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFE65100), 'border': Color(0xFFFFCC80)},
    {'bg': Color(0xFFFCE4EC), 'text': Color(0xFFC2185B), 'border': Color(0xFFF48FB1)},
    {'bg': Color(0xFFE0F2F1), 'text': Color(0xFF00695C), 'border': Color(0xFF80CBC4)},
  ];

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? const Color(0xFF0A1628) : AppColors.background;

    return Consumer<FamilyBudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    _buildHeader(context, provider, isDark),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.primary))
                          : provider.budgets.isEmpty
                              ? _buildEmptyState(context, provider)
                              : _buildContent(context, provider, isDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _buildFAB(context, provider),
          bottomNavigationBar: const AppBottomNav(selectedIndex: 1),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, FamilyBudgetProvider provider, bool isDark) {
    final textColor = isDark ? const Color(0xFFE0F2F1) : AppColors.textPrimary;
    final headerBg = isDark ? const Color(0xFF122030) : AppColors.background;
    final reminders = provider.activeReminders;

    return Container(
      color: headerBg,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.primary),
              ),
              Expanded(
                child: Text('Budget',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(20), fontWeight: FontWeight.w700, color: textColor)),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/combined-analytics'),
                icon: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                tooltip: 'Analytics',
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => FutureEventsScreen())),
                    icon: const Icon(Icons.event_outlined, color: AppColors.primary),
                    tooltip: 'Events',
                  ),
                  if (reminders.isNotEmpty)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 9, height: 9,
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (reminders.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FutureEventsScreen())),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${reminders.length} upcoming event reminder${reminders.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: _sp(11)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 16),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Scrollable content ─────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, FamilyBudgetProvider provider, bool isDark) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        provider.loadBudgets();
        _loadPendingRequests();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        children: [
          ...provider.budgets.map((b) => _buildBudgetBlock(context, provider, b, isDark)),
          if (_isParent && (_pendingLoading || _pendingRequests.isNotEmpty))
            _buildPendingSection(isDark),
        ],
      ),
    );
  }

  // ── Full budget block (hero + categories + allowances + actions) ────────────

  Widget _buildBudgetBlock(BuildContext context, FamilyBudgetProvider provider,
      Map<String, dynamic> budget, bool isDark) {
    final categories = List<Map<String, dynamic>>.from(budget['categories'] ?? []);
    final allowances = List<Map<String, dynamic>>.from(budget['allowances'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(budget),
        const SizedBox(height: 12),
        if (categories.isNotEmpty) ...[
          _buildSectionLabel('CATEGORY ALLOCATIONS', isDark),
          const SizedBox(height: 6),
          _buildCategoryCard(categories, isDark),
          const SizedBox(height: 12),
        ],
        if (allowances.isNotEmpty) ...[
          _buildSectionLabel('MEMBER ALLOWANCES', isDark),
          const SizedBox(height: 6),
          _buildAllowancesCard(allowances, isDark),
          const SizedBox(height: 12),
        ],
        _buildActionRow(context, provider, budget, isDark),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Hero gradient card ─────────────────────────────────────────────────────

  Widget _buildHeroCard(Map<String, dynamic> budget) {
    final total = (budget['total_amount'] ?? 0).toDouble();
    final spent = (budget['total_spent'] ?? budget['spent_amount'] ?? 0).toDouble();
    final remaining = (budget['remaining_amount'] ?? (total - spent)).toDouble();
    final emergencyTotal = (budget['emergency_fund_amount'] ?? 0).toDouble();
    final isOverBudget = budget['is_over_budget'] == true;
    final periodType = (budget['period_type'] ?? 'monthly').toString();
    final title = budget['title']?.toString() ?? 'Budget';
    final progress = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    final periodLabel = switch (periodType) {
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => 'Custom',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$periodLabel Budget',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(10), color: Colors.white.withOpacity(0.7))),
                  const Spacer(),
                  if (isOverBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Over Budget',
                          style: GoogleFonts.poppins(
                              fontSize: _sp(9), color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: _sp(13), color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(symbol: '', decimalDigits: 0).format(total) + ' EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(26), fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Spent: ',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(10), color: Colors.white.withOpacity(0.7))),
                  Text(
                    '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(spent)} EGP',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(10), color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text('Left: ',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(10), color: Colors.white.withOpacity(0.7))),
                  Text(
                    '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(remaining)} EGP',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(10), color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isOverBudget ? Colors.redAccent : Colors.white),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used'
                '${emergencyTotal > 0 ? ' · Emergency: ${NumberFormat.currency(symbol: '', decimalDigits: 0).format(emergencyTotal)} EGP' : ''}',
                style: GoogleFonts.poppins(
                    fontSize: _sp(9), color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Category allocations ───────────────────────────────────────────────────

  Widget _buildCategoryCard(List<Map<String, dynamic>> categories, bool isDark) {
    final cardColor = isDark ? const Color(0xFF122030) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E3A4A) : AppColors.border;
    final dividerColor = isDark ? const Color(0xFF1E3A4A) : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: categories.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final isLast = i == categories.length - 1;
          final name = (cat['name'] ?? cat['title'] ?? 'Category').toString();
          final allocated = (cat['allocated_amount'] ?? 0).toDouble();
          final spent = (cat['spent_amount'] ?? 0).toDouble();
          final progress = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
          final isWarn = progress >= 0.8;
          final color = _categoryColor(name, i);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(
                  bottom: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: _sp(11), fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE0F2F1) : AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark
                              ? const Color(0xFF1E3A4A)
                              : AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isWarn ? const Color(0xFFFB8C00) : color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(spent)}/${NumberFormat.currency(symbol: '', decimalDigits: 0).format(allocated)}',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(9), fontWeight: FontWeight.w600,
                      color: isWarn ? const Color(0xFFE65100) : AppColors.textSecondary),
                ),
                if (isWarn) ...[
                  const SizedBox(width: 4),
                  const Text('⚠️', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Member allowances ──────────────────────────────────────────────────────

  Widget _buildAllowancesCard(List<Map<String, dynamic>> allowances, bool isDark) {
    final cardColor = isDark ? const Color(0xFF122030) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E3A4A) : AppColors.border;
    final dividerColor = isDark ? const Color(0xFF1E3A4A) : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: allowances.asMap().entries.map((entry) {
          final i = entry.key;
          final allowance = entry.value;
          final isLast = i == allowances.length - 1;
          final name = (allowance['member_name'] ?? allowance['member_mail'] ?? 'Member').toString();
          final money = (allowance['money_amount'] ?? 0).toDouble();
          final spent = (allowance['spent_amount'] ?? 0).toDouble();
          final progress = money > 0 ? (spent / money).clamp(0.0, 1.0) : 0.0;
          final isWarn = progress >= 0.85;
          final colors = _memberColors[i % _memberColors.length];
          final initials = name.trim().split(RegExp(r'\s+')).take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(
                  bottom: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: colors['bg'],
                    shape: BoxShape.circle,
                    border: Border.all(color: colors['border']! as Color, width: 1.5),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: TextStyle(
                            fontSize: _sp(10), fontWeight: FontWeight.w700,
                            color: colors['text'] as Color)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: _sp(11), fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE0F2F1) : AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark
                              ? const Color(0xFF1E3A4A)
                              : AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isWarn
                                  ? AppColors.error
                                  : (colors['text'] as Color)),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(spent)}/${NumberFormat.currency(symbol: '', decimalDigits: 0).format(money)}',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(9), fontWeight: FontWeight.w600,
                      color: isWarn ? AppColors.error : AppColors.textSecondary),
                ),
                if (isWarn) ...[
                  const SizedBox(width: 4),
                  const Text('⚠️', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Pending expense requests ───────────────────────────────────────────────

  Widget _buildPendingSection(bool isDark) {
    final cardColor = isDark ? const Color(0xFF122030) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E3A4A) : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel('EXPENSE REQUESTS', isDark),
            if (_pendingRequests.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                child: Text('${_pendingRequests.length}',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(9), fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (_pendingLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ))
        else if (_pendingRequests.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text('No pending expense requests',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(12), color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: _pendingRequests.asMap().entries.map((entry) {
                final i = entry.key;
                final req = entry.value;
                final isLast = i == _pendingRequests.length - 1;
                final id = (req['_id'] ?? '').toString();
                final memberName = (req['member_name'] ?? req['member_mail'] ?? 'Member').toString();
                final amount = (req['amount'] ?? 0).toDouble();
                final title = (req['title'] ?? req['description'] ?? 'Expense').toString();
                final category = (req['category_name'] ?? req['category'] ?? '').toString();
                final colors = _memberColors[i % _memberColors.length];
                final initials = memberName.split(' ').take(2)
                    .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                        bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E3A4A) : AppColors.borderLight,
                            width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: colors['bg'],
                          shape: BoxShape.circle,
                          border: Border.all(color: colors['border']! as Color, width: 1.5),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: TextStyle(
                                  fontSize: _sp(10), fontWeight: FontWeight.w700,
                                  color: colors['text'] as Color)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$title · ${NumberFormat.currency(symbol: '', decimalDigits: 0).format(amount)} EGP',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(11), fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFE0F2F1)
                                      : AppColors.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text('$memberName${category.isNotEmpty ? ' · $category' : ''}',
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(10), color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Approve
                      GestureDetector(
                        onTap: () => _approveRequest(id),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(9)),
                          child: const Center(
                            child: Text('✓',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Reject
                      GestureDetector(
                        onTap: () => _rejectRequest(id),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(9)),
                          child: const Center(
                            child: Text('✕',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Action row ─────────────────────────────────────────────────────────────

  Widget _buildActionRow(BuildContext context, FamilyBudgetProvider provider,
      Map<String, dynamic> budget, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              provider.selectBudget(budget['_id']);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(budget: budget)));
            },
            icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
            label: Text('Add Expense',
                style: GoogleFonts.poppins(
                    fontSize: _sp(12), color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              await provider.selectBudget(budget['_id']);
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BudgetAnalyticsScreen(budgetId: budget['_id'])));
              }
            },
            icon: const Icon(Icons.pie_chart_outline, size: 16, color: Colors.white),
            label: Text('Analytics',
                style: GoogleFonts.poppins(
                    fontSize: _sp(12), color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, FamilyBudgetProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No budgets yet',
                style: GoogleFonts.poppins(
                    fontSize: _sp(18), fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Create a budget to start tracking your family spending.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: _sp(12), color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async => await _showCreateBudgetSheet(context, provider),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Create Budget',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(13), color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context, FamilyBudgetProvider provider) {
    return GestureDetector(
      onTap: () async => await _showCreateBudgetSheet(context, provider),
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: _sp(9),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ALL LOGIC METHODS BELOW ARE 100% UNCHANGED
  // ══════════════════════════════════════════════════════════════════════════

  Widget _amountChip(String label, double amount, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 2),
      Text(
        NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    ]);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }

  Future<void> _showCreateBudgetSheet(BuildContext context, FamilyBudgetProvider provider) async {
    await provider.loadReferenceData();

    final titleCtrl = TextEditingController(text: 'Family Budget');
    final totalCtrl = TextEditingController();
    String periodType = 'monthly';
    double emergencyPct = 10;
    bool isLoading = false;

    final categories = provider.inventoryCategories.map((category) {
      return {
        'inventory_category_id': category['_id']?.toString(),
        'name': (category['title'] ?? 'Uncategorized').toString(),
        'allocated_amount': 0.0,
        'threshold_percentage': 15.0,
        'color': '#4CAF50',
      };
    }).toList();

    final categoryControllers = categories.map((_) => TextEditingController()).toList();
    final allowanceControllers = provider.familyMembers.map((member) {
      return {
        'member_id': member['_id']?.toString(),
        'member_mail': (member['mail'] ?? '').toString(),
        'name': (member['username'] ?? member['mail'] ?? 'Member').toString(),
        'moneyCtrl': TextEditingController(),
      };
    }).toList();

    if (provider.inventoryCategories.isEmpty || provider.familyMembers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading family inventories and members...')),
        );
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('Create Budget',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Budget Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Period', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                for (final p in ['weekly', 'monthly', 'yearly'])
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _typeChip(ctx, p.capitalize(), p, periodType,
                        (v) => setSheet(() => periodType = v)),
                  )),
              ]),
              const SizedBox(height: 16),
              Text('Emergency Fund: ${emergencyPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: emergencyPct,
                min: 0, max: 30, divisions: 30,
                activeColor: const Color(0xFF388E3C),
                label: '${emergencyPct.toStringAsFixed(0)}%',
                onChanged: (v) => setSheet(() => emergencyPct = v),
              ),
              const SizedBox(height: 16),
              const Text('Inventory Categories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No inventory categories found. Create categories in Inventory first.'),
                )
              else
                ...List.generate(categories.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text((categories[i]['name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: categoryControllers[i],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) {
                          categories[i]['allocated_amount'] = double.tryParse(v) ?? 0;
                        },
                      ),
                    ),
                  ]),
                )),
              const SizedBox(height: 16),
              const Text('Current Inventory Snapshot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (provider.familyInventoryItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No inventory items found yet.'),
                )
              else
                ...provider.familyInventoryItems.map((item) {
                  final name = (item['item_name'] ?? 'Item').toString();
                  final quantity = (item['quantity'] ?? 0).toString();
                  final unit = item['unit'] is Map ? (item['unit']['unit_name'] ?? '').toString() : '';
                  final categoryName = item['item_category'] is Map
                      ? (item['item_category']['title'] ?? 'Uncategorized').toString()
                      : 'Uncategorized';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('$categoryName • $quantity ${unit.isNotEmpty ? unit : ''}'.trim(),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              const Text('Member Allowances',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (allowanceControllers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No family members found.'),
                )
              else
                ...List.generate(allowanceControllers.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(allowanceControllers[i]['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: allowanceControllers[i]['moneyCtrl'] as TextEditingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Money allowance',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final total = double.tryParse(totalCtrl.text.trim());
                    if (total == null || total <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid total amount')));
                      return;
                    }
                    final endDate = switch (periodType) {
                      'weekly' => DateTime.now().add(const Duration(days: 7)),
                      'yearly' => DateTime.now().add(const Duration(days: 365)),
                      _ => DateTime.now().add(const Duration(days: 30)),
                    };

                    setSheet(() => isLoading = true);
                    try {
                      await provider.createBudget({
                        'title': titleCtrl.text.trim(),
                        'period_type': periodType,
                        'start_date': DateTime.now().toIso8601String(),
                        'end_date': endDate.toIso8601String(),
                        'total_amount': total,
                        'threshold_percentage': emergencyPct,
                        'allocations': categories
                          .where((c) => ((c['allocated_amount'] ?? 0) as num) > 0 && (c['inventory_category_id']?.toString().isNotEmpty ?? false))
                            .map((c) => {
                              'inventory_category_id': c['inventory_category_id'],
                              'allocated_amount': c['allocated_amount'],
                              'threshold_percentage': 15,
                            })
                            .toList(),
                        'allowances': allowanceControllers
                            .where((m) {
                              final money = double.tryParse((m['moneyCtrl'] as TextEditingController).text.trim()) ?? 0;
                              return money > 0;
                            })
                            .map((m) => {
                              'member_id': m['member_id'],
                              'member_mail': m['member_mail'],
                              'period_type': periodType,
                              'allowance_currency': 'money',
                              'money_amount': double.tryParse((m['moneyCtrl'] as TextEditingController).text.trim()) ?? 0,
                            })
                            .toList(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Budget created!'),
                            backgroundColor: Color(0xFF388E3C),
                          ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red));
                      }
                    } finally {
                      setSheet(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Create Budget',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(BuildContext ctx, String label, String value, String current,
      Function(String) onTap) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF388E3C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? const Color(0xFF388E3C) : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
