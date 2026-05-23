import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_frontend/pages/budget/budget_provider.dart';
import 'package:app_frontend/core/theme/app_theme.dart';
import 'package:app_frontend/core/theme/theme_provider.dart';

class BudgetAnalyticsScreen extends StatefulWidget {
  final String budgetId;
  const BudgetAnalyticsScreen({super.key, required this.budgetId});
  @override
  State<BudgetAnalyticsScreen> createState() => _BudgetAnalyticsScreenState();
}

class _BudgetAnalyticsScreenState extends State<BudgetAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _touchedIndex = -1;

  static final _pieColors = [
    Color(0xFF00897B), Color(0xFF00ACC1), Color(0xFFFB8C00),
    Color(0xFF4DB6AC), Color(0xFF7B1FA2), Color(0xFFE91E63),
  ];

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  // ── Lifecycle (UNCHANGED) ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FamilyBudgetProvider>().loadAnalytics(widget.budgetId);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F5F5);

    return Consumer<FamilyBudgetProvider>(builder: (context, provider, _) {
      final analytics = provider.analyticsData;

      final budget = provider.budgets.firstWhere(
        (b) => b['_id']?.toString() == widget.budgetId,
        orElse: () => {},
      );
      final budgetTitle = (budget['title'] ?? 'Budget Analytics').toString();
      String dateRange = '';
      try {
        if (budget['start_date'] != null && budget['end_date'] != null) {
          final s = DateFormat('MMM d').format(DateTime.parse(budget['start_date'].toString()));
          final e = DateFormat('MMM d, yyyy').format(DateTime.parse(budget['end_date'].toString()));
          dateRange = '$s – $e';
        }
      } catch (_) {}

      return Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            _buildHeader(isDark, budgetTitle, dateRange),
            Expanded(
              child: provider.isLoading || analytics == null
                  ? Center(
                      child: CircularProgressIndicator(color: Color(0xFF00897B)))
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildOverviewTab(analytics, isDark),
                        _buildTrendTab(analytics, isDark),
                        _buildExpensesTab(provider, isDark),
                      ],
                    ),
            ),
          ],
        ),
      );
    });
  }

  // ── Custom header with gradient + tab pills ────────────────────────────────
  Widget _buildHeader(bool isDark, String title, String dateRange) {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.poppins(
                                fontSize: _sp(17),
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        if (dateRange.isNotEmpty)
                          Text(dateRange,
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(10),
                                  color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.ios_share_outlined,
                        color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(children: [
                  _tabPill(0, 'Overview'),
                  const SizedBox(width: 6),
                  _tabPill(1, 'Trend'),
                  const SizedBox(width: 6),
                  _tabPill(2, 'Expenses'),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabPill(int index, String label) {
    final isActive = _tabCtrl.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabCtrl.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.white : Colors.white54,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: _sp(10),
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF00897B) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── Overview tab (pie chart + breakdown) ──────────────────────────────────
  Widget _buildOverviewTab(Map<String, dynamic> analytics, bool isDark) {
    final pieData =
        List<Map<String, dynamic>>.from(analytics['pie_chart_data'] ?? []);
    final totalSpent = (analytics['total_spent'] ?? 0).toDouble();
    final totalBudget = (analytics['total_budget'] ?? 0).toDouble();
    final totalRemaining = (analytics['total_remaining'] ?? 0).toDouble();
    final spentPct = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

    final overCategories = pieData.where((d) {
      final spent = (d['spent_amount'] ?? 0).toDouble();
      final alloc = (d['allocated_amount'] ?? 0).toDouble();
      return alloc > 0 && spent / alloc > 0.8;
    }).toList();

    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF1E3A4A) : const Color(0xFFB2DFDB);
    final textPrimary =
        isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);
    const textSec = Color(0xFF4DB6AC);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 3 summary cards ──
              Row(children: [
                _summaryCard('Spent', totalSpent, const Color(0xFFE53935),
                    cardBg, cardBorder, textSec),
                const SizedBox(width: 8),
                _summaryCard('Left', totalRemaining, const Color(0xFF00897B),
                    cardBg, cardBorder, textSec),
                const SizedBox(width: 8),
                _summaryCard('Total', totalBudget, textPrimary,
                    cardBg, cardBorder, textSec),
              ]),
              const SizedBox(height: 10),

              // ── Over-budget warnings ──
              ...overCategories.map((d) {
                final spent = (d['spent_amount'] ?? 0).toDouble();
                final alloc = (d['allocated_amount'] ?? 0).toDouble();
                final pct = alloc > 0 ? (spent / alloc * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d['category_name'] ?? ''} overspent!',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(10),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFC62828)),
                            ),
                            Text(
                              '${spent.toStringAsFixed(0)} EGP of '
                              '${alloc.toStringAsFixed(0)} EGP used '
                              '(${pct.toStringAsFixed(0)}%)',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(9),
                                  color: const Color(0xFFE57373)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              }),

              if (pieData.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No expenses yet',
                        style: GoogleFonts.poppins(color: textSec)),
                  ),
                )
              else ...[
                // ── Pie chart card ──
                Text('SPENDING BY CATEGORY',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(9),
                        fontWeight: FontWeight.w600,
                        color: textSec,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    // Donut
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent e,
                                  PieTouchResponse? r) {
                                setState(() {
                                  _touchedIndex =
                                      r?.touchedSection
                                              ?.touchedSectionIndex ??
                                          -1;
                                });
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: List.generate(pieData.length, (i) {
                              final d = pieData[i];
                              final isTouched = i == _touchedIndex;
                              return PieChartSectionData(
                                value: (d['spent_amount'] ?? 0).toDouble(),
                                title: '',
                                radius: isTouched ? 36 : 28,
                                color: _pieColors[i % _pieColors.length],
                              );
                            }),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${spentPct.toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(12),
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary),
                              ),
                              Text('spent',
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(8), color: textSec)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    // Legend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(pieData.length, (i) {
                          final d = pieData[i];
                          final spent = (d['spent_amount'] ?? 0).toDouble();
                          final alloc =
                              (d['allocated_amount'] ?? 0).toDouble();
                          final isOver =
                              alloc > 0 && spent / alloc > 0.8;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _pieColors[i % _pieColors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  (d['category_name'] ?? '').toString(),
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(9), color: textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${spent.toStringAsFixed(0)} EGP'
                                '${isOver ? ' ⚠️' : ''}',
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(9),
                                    fontWeight: FontWeight.w700,
                                    color: isOver
                                        ? const Color(0xFFE65100)
                                        : const Color(0xFF00695C)),
                              ),
                            ]),
                          );
                        }),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),
                // ── Category breakdown list ──
                Text('CATEGORY BREAKDOWN',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(9),
                        fontWeight: FontWeight.w600,
                        color: textSec,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                ...List.generate(pieData.length, (i) {
                  final d = pieData[i];
                  final spent = (d['spent_amount'] ?? 0).toDouble();
                  final alloc = (d['allocated_amount'] ?? 0).toDouble();
                  final pct =
                      double.tryParse(d['percentage'].toString()) ?? 0;
                  final isOver = alloc > 0 && spent / alloc > 0.8;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOver
                              ? const Color(0xFFFFCDD2)
                              : cardBorder,
                          width: isOver ? 1.5 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 1))
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _pieColors[i % _pieColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (d['category_name'] ?? '').toString(),
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(11),
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary),
                              ),
                              Text(
                                '${d['expense_count'] ?? 0} transactions',
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(9), color: textSec),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${spent.toStringAsFixed(0)} EGP',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(11),
                                  fontWeight: FontWeight.w700,
                                  color: isOver
                                      ? const Color(0xFFE53935)
                                      : textPrimary),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}% • of '
                              '${alloc.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(9), color: textSec),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color valueColor,
      Color cardBg, Color cardBorder, Color labelColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1))
          ],
        ),
        child: Column(children: [
          Text(
            amount.toStringAsFixed(0),
            style: GoogleFonts.poppins(
                fontSize: _sp(13),
                fontWeight: FontWeight.w700,
                color: valueColor),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: _sp(8), color: labelColor)),
        ]),
      ),
    );
  }

  // ── Trend tab (line chart) ─────────────────────────────────────────────────
  Widget _buildTrendTab(Map<String, dynamic> analytics, bool isDark) {
    final trend = List<Map<String, dynamic>>.from(
        analytics['daily_trend_data'] ?? []);
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF1E3A4A) : const Color(0xFFB2DFDB);
    final textPrimary =
        isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    if (trend.isEmpty) {
      return Center(
        child: Text('No spending data yet',
            style: GoogleFonts.poppins(color: const Color(0xFF4DB6AC))),
      );
    }

    // ── LOGIC UNCHANGED ──
    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      spots.add(
          FlSpot(i.toDouble(), (trend[i]['daily_spent'] ?? 0).toDouble()));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily Spending Trend',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(15),
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFE0F2F1), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(9),
                                  color: const Color(0xFF4DB6AC)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i >= 0 &&
                                  i < trend.length &&
                                  i % 3 == 0) {
                                final raw =
                                    trend[i]['_id'].toString();
                                final label = raw.length >= 5
                                    ? raw.substring(5)
                                    : raw;
                                return Text(label,
                                    style: GoogleFonts.poppins(
                                        fontSize: _sp(9),
                                        color: const Color(0xFF4DB6AC)));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF00897B),
                          barWidth: 2.5,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF00897B)
                                .withValues(alpha: 0.10),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expenses tab ──────────────────────────────────────────────────────────
  Widget _buildExpensesTab(FamilyBudgetProvider provider, bool isDark) {
    final expenses = provider.expenses;
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF1E3A4A) : const Color(0xFFB2DFDB);
    final textPrimary =
        isDark ? const Color(0xFFE0F2F1) : const Color(0xFF00352E);

    if (expenses.isEmpty) {
      return Center(
        child: Text('No expenses found for this budget period',
            style: GoogleFonts.poppins(color: const Color(0xFF4DB6AC))),
      );
    }

    const catIcons = {
      'groceries': '🛒', 'food': '🛒', 'utilities': '💡',
      'entertainment': '🎬', 'education': '📚', 'transport': '🚗',
      'healthcare': '🏥',
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            // ── LOGIC UNCHANGED ──
            final expense = expenses[index];
            final amount = (expense['amount'] ?? 0).toDouble();
            final title =
                (expense['title'] ?? expense['category'] ?? 'Expense')
                    .toString();
            final category =
                (expense['category'] ?? 'Uncategorized').toString();
            final memberMail =
                (expense['member_mail'] ?? '').toString();
            final source =
                (expense['expense_source'] ?? expense['expense_scope'] ??
                        'budget')
                    .toString();
            final description =
                (expense['description'] ?? '').toString();
            final dateValue = DateTime.tryParse(
                (expense['expense_date'] ?? '').toString());
            final formattedDate = dateValue != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(dateValue)
                : 'Unknown date';

            final catKey = category.toLowerCase();
            final icon = catIcons.entries
                .firstWhere((e) => catKey.contains(e.key),
                    orElse: () => const MapEntry('', '💰'))
                .value;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder, width: 0.8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                        child: Text(icon,
                            style: const TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: _sp(11),
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category,
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(8),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00695C))),
                          ),
                          const SizedBox(width: 4),
                          Text('• $source',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(8),
                                  color: const Color(0xFF4DB6AC))),
                        ]),
                        if (memberMail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(memberMail,
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(8),
                                  color: const Color(0xFF4DB6AC))),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(description,
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(9), color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 2),
                        Text(formattedDate,
                            style: GoogleFonts.poppins(
                                fontSize: _sp(8),
                                color: const Color(0xFF4DB6AC))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '-${amount.toStringAsFixed(0)} EGP',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(11),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE53935)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
