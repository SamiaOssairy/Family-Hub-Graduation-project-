import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class CombinedAnalyticsScreen extends StatefulWidget {
  const CombinedAnalyticsScreen({super.key});

  @override
  State<CombinedAnalyticsScreen> createState() => _CombinedAnalyticsScreenState();
}

class _CombinedAnalyticsScreenState extends State<CombinedAnalyticsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isParent = false;
  bool _isExporting = false;
  String _selectedPeriod = 'Month'; // Week / Month / Year (UI-only state)

  Map<String, dynamic> _analytics = {};
  Map<String, dynamic> _taskRewardsSummary = {};

  final Map<String, Map<String, dynamic>> _memberCombinedById = {};

  static const List<Color> _chartColors = [
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF5E35B1),
    Color(0xFFF57C00),
    Color(0xFFD81B60),
    Color(0xFF1E88E5),
  ];

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _isParent = await _apiService.isParent();

      final analytics = await _apiService.getCombinedAnalytics();

      Map<String, dynamic> taskSummary = {};
      try {
        taskSummary = await _apiService.getTaskRewardsSummary(period: 'monthly');
      } catch (_) {
        taskSummary = {};
      }

      final members = await _apiService.getAllMembers();
      final children = members.where((m) {
        final type = m['member_type_id'];
        if (type is Map) {
          return (type['type'] ?? '').toString() != 'Parent';
        }
        return true;
      }).toList();

      final childBalanceFutures = children.map((member) async {
        final id = (member['_id'] ?? '').toString();
        if (id.isEmpty) return;

        try {
          final combined = await _apiService.getCombinedBalance(memberId: id);
          _memberCombinedById[id] = combined;
        } catch (_) {
          _memberCombinedById[id] = {};
        }
      }).toList();

      await Future.wait(childBalanceFutures);

      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _taskRewardsSummary = taskSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load analytics: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportCombinedReportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final doc = pw.Document();
      final overview = _analytics['overview'] as Map<String, dynamic>? ?? {};
      final monthlySummary = _analytics['monthly_summary_for_parents'] as Map<String, dynamic>? ?? {};
        final personalBudgetSummary = _analytics['personal_budget_summary'] as Map<String, dynamic>? ?? {};
      final memberSummaries = ((_analytics['member_summaries'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final budgetHealth = _analytics['budget_health'] as Map<String, dynamic>? ?? {};

      pw.Widget kvRow(String k, String v) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontSize: 11))),
              pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text('Family Hub - Combined Analytics Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 16),

            pw.Text('Overview', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            kvRow('Total Family Spending', '${_money(overview['total_family_spending'])} EGP'),
            kvRow('Total Points Earned', _num(overview['total_points_earned'])),
            kvRow('Total Points Redeemed', _num(overview['total_points_redeemed'])),
            kvRow('Money Given as Allowance/Rewards', '${_money(overview['total_money_given_as_allowance_rewards'])} EGP'),

            pw.SizedBox(height: 12),
            pw.Text('Monthly Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            kvRow('Month', (monthlySummary['month'] ?? '-').toString()),
            kvRow('Money Spent This Month', '${_money(monthlySummary['money_spent_this_month'])} EGP'),
            kvRow('Personal Money Spent This Month', '${_money(monthlySummary['personal_money_spent_this_month'])} EGP'),
            kvRow('Points Earned This Month', _num(monthlySummary['points_earned_this_month'])),
            kvRow('Points Redeemed This Month', _num(monthlySummary['points_redeemed_this_month'])),

            pw.SizedBox(height: 12),
            pw.Text('Personal Budget Tracker', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            kvRow('Tracked budget amount', '${_money(personalBudgetSummary['total_budget_amount'])} EGP'),
            kvRow('Tracked spent amount', '${_money(personalBudgetSummary['total_spent_amount'])} EGP'),
            kvRow('Tracked remaining amount', '${_money(personalBudgetSummary['total_remaining_amount'])} EGP'),
            kvRow('Expenses tracked this month', _num(personalBudgetSummary['tracked_expenses'])),

            pw.SizedBox(height: 12),
            pw.Text('Member Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...memberSummaries.map((m) {
              final id = (m['member_id'] ?? '').toString();
              final combined = _memberCombinedById[id] ?? {};
              final currentSaved = ((combined['money_balance'] ?? m['current_money_saved'] ?? 0) as num).toDouble();

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text((m['member_name'] ?? 'Member').toString(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.SizedBox(height: 2),
                    kvRow('Money received', '${_money(m['money_received'])} EGP'),
                    kvRow('Points earned', _num(m['points_earned'])),
                    kvRow('Points redeemed', _num(m['points_redeemed'])),
                    kvRow('Current money saved', '${_money(currentSaved)} EGP'),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 12),
            pw.Text('Budget Health', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            kvRow(
              'Rewards (spent / budget)',
              '${_money((budgetHealth['rewards'] as Map<String, dynamic>? ?? {})['spent_amount'])} / ${_money((budgetHealth['rewards'] as Map<String, dynamic>? ?? {})['budget_amount'])} EGP',
            ),
            kvRow(
              'Allowances (spent / budget)',
              '${_money((budgetHealth['allowances'] as Map<String, dynamic>? ?? {})['spent_amount'])} / ${_money((budgetHealth['allowances'] as Map<String, dynamic>? ?? {})['budget_amount'])} EGP',
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Analytics',
            style: GoogleFonts.poppins(
                fontSize: _sp(17), fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _loadData,
              icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _isExporting ? null : _exportCombinedReportPdf,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPeriodTabs(),
                  const SizedBox(height: 14),
                  _buildOverviewCards(),
                  const SizedBox(height: 14),
                  _buildChartsSection(),
                  const SizedBox(height: 14),
                  _buildMemberSummariesSection(),
                  const SizedBox(height: 14),
                  _buildBudgetHealthSection(),
                  const SizedBox(height: 14),
                  _buildExportSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodTabs() {
    const periods = ['Week', 'Month', 'Year'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: periods.map((p) {
          final isActive = _selectedPeriod == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: _sp(12),
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final overview = _analytics['overview'] as Map<String, dynamic>? ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _overviewCard(
          'Total Family Spending',
          '${_money(overview['total_family_spending'])} EGP',
          Icons.payments,
          const Color(0xFFB71C1C),
        ),
        _overviewCard(
          'Total Points Earned',
          _num(overview['total_points_earned']),
          Icons.star,
          const Color(0xFFEF6C00),
        ),
        _overviewCard(
          'Total Points Redeemed',
          _num(overview['total_points_redeemed']),
          Icons.redeem,
          const Color(0xFF1565C0),
        ),
        _overviewCard(
          'Money as Allowance/Rewards',
          '${_money(overview['total_money_given_as_allowance_rewards'])} EGP',
          Icons.volunteer_activism,
          const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _overviewCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: math.max(160, (MediaQuery.of(context).size.width - 48) / 2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: _sp(16), fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: _sp(10), color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    final charts = _analytics['charts'] as Map<String, dynamic>? ?? {};

    final spendingByCategory = ((charts['spending_by_category'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final pointsByMember = ((charts['points_earned_vs_redeemed_by_member'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rewardsOverTime = ((charts['rewards_spending_over_time'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return _panel(
      title: 'Charts Section',
      child: Column(
        children: [
          _chartTitle('Pie Chart: Spending by Category'),
          SizedBox(height: 230, child: _buildSpendingPieChart(spendingByCategory)),
          const SizedBox(height: 18),

          _chartTitle('Bar Chart: Points Earned vs Redeemed per Member'),
          SizedBox(height: 260, child: _buildPointsBarChart(pointsByMember)),
          const SizedBox(height: 18),

          _chartTitle('Line Chart: Money spent on Rewards over time'),
          SizedBox(height: 240, child: _buildRewardsLineChart(rewardsOverTime)),
        ],
      ),
    );
  }

  Widget _buildSpendingPieChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _emptyChart('No spending data yet');
    }

    final total = data.fold<double>(0, (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble());

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < data.length; i++) {
      final amount = ((data[i]['amount'] ?? 0) as num).toDouble();
      final pct = total <= 0 ? 0 : (amount / total) * 100;
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${pct.toStringAsFixed(0)}%',
          color: _chartColors[i % _chartColors.length],
          radius: 68,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: List.generate(data.length, (i) {
            final label = (data[i]['category'] ?? 'Category').toString();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: _chartColors[i % _chartColors.length]),
                const SizedBox(width: 4),
                Text(label, style: GoogleFonts.poppins(fontSize: 11)),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPointsBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _emptyChart('No points activity yet');
    }

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final earned = ((data[i]['points_earned'] ?? 0) as num).toDouble();
      final redeemed = ((data[i]['points_redeemed'] ?? 0) as num).toDouble();
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(toY: earned, width: 10, color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(3)),
            BarChartRodData(toY: redeemed, width: 10, color: const Color(0xFFEF6C00), borderRadius: BorderRadius.circular(3)),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barGroups: groups,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final name = (data[i]['member_name'] ?? 'Member').toString();
                final short = name.length > 8 ? '${name.substring(0, 8)}…' : name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: GoogleFonts.poppins(fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsLineChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _emptyChart('No rewards spending yet');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), ((data[i]['amount'] ?? 0) as num).toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                if (i % 2 != 0) return const SizedBox.shrink();
                final raw = (data[i]['date'] ?? '').toString();
                final d = DateTime.tryParse(raw);
                final label = d == null ? raw : DateFormat('MM/dd').format(d);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: GoogleFonts.poppins(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF1565C0),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1565C0).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSummariesSection() {
    final summaries = ((_analytics['member_summaries'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return _panel(
      title: 'Member Summary Cards',
      child: summaries.isEmpty
          ? _emptyInline('No child member summaries found')
          : Column(
              children: summaries.map((summary) {
                final id = (summary['member_id'] ?? '').toString();
                final combined = _memberCombinedById[id] ?? {};

                final moneyReceived = ((summary['money_received'] ?? 0) as num).toDouble();
                final pointsEarned = ((summary['points_earned'] ?? 0) as num).toDouble();
                final pointsRedeemed = ((summary['points_redeemed'] ?? 0) as num).toDouble();
                final saved = ((combined['money_balance'] ?? summary['current_money_saved'] ?? 0) as num).toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (summary['member_name'] ?? 'Member').toString(),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      _kv('Money received (allowance + task rewards)', '${moneyReceived.toStringAsFixed(2)} EGP'),
                      _kv('Personal budget', '${((summary['personal_budget_amount'] ?? 0) as num).toDouble().toStringAsFixed(2)} EGP'),
                      _kv('Personal budget spent', '${((summary['personal_budget_spent'] ?? 0) as num).toDouble().toStringAsFixed(2)} EGP'),
                      _kv('Personal budget remaining', '${((summary['personal_budget_remaining'] ?? 0) as num).toDouble().toStringAsFixed(2)} EGP'),
                      _kv('Points earned', pointsEarned.toStringAsFixed(0)),
                      _kv('Points redeemed', pointsRedeemed.toStringAsFixed(0)),
                      _kv('Current money saved', '${saved.toStringAsFixed(2)} EGP'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBudgetHealthSection() {
    final budgetHealth = _analytics['budget_health'] as Map<String, dynamic>? ?? {};
    final rewards = budgetHealth['rewards'] as Map<String, dynamic>? ?? {};
    final allowances = budgetHealth['allowances'] as Map<String, dynamic>? ?? {};
    final personalBudget = budgetHealth['personal_budget'] as Map<String, dynamic>? ?? {};
    final alerts = ((_analytics['alerts'] ?? []) as List).map((e) => e.toString()).toList();

    Widget budgetCard(String title, Map<String, dynamic> data, Color color) {
      final budget = ((data['budget_amount'] ?? 0) as num).toDouble();
      final spent = ((data['spent_amount'] ?? 0) as num).toDouble();
      final over = data['over_budget'] == true;
      final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: over ? Colors.red : color.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Spent: ${spent.toStringAsFixed(2)} / ${budget.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(fontSize: 12)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(over ? Colors.red : color),
            ),
            if (over) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Text('Over budget', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return _panel(
      title: 'Budget Health Indicators',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          budgetCard('Rewards category', rewards, const Color(0xFF6A1B9A)),
          budgetCard('Allowances category', allowances, const Color(0xFF00897B)),
          budgetCard('Personal budget tracker', personalBudget, const Color(0xFF1565C0)),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...alerts.map((alert) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(alert, style: GoogleFonts.poppins(color: Colors.orange[900]))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    final summary = _analytics['monthly_summary_for_parents'] as Map<String, dynamic>? ?? {};
    final personalBudgetSummary = _analytics['personal_budget_summary'] as Map<String, dynamic>? ?? {};

    return _panel(
      title: 'Export Combined Report',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PDF with all money and points activity, including monthly summary for parents.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          _kv('Month', (summary['month'] ?? '-').toString()),
          _kv('Money spent this month', '${_money(summary['money_spent_this_month'])} EGP'),
          _kv('Personal money spent this month', '${_money(summary['personal_money_spent_this_month'])} EGP'),
          _kv('Points earned this month', _num(summary['points_earned_this_month'])),
          _kv('Tracked personal budget', '${_money(personalBudgetSummary['total_budget_amount'])} EGP'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportCombinedReportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(_isExporting ? 'Exporting...' : 'Export PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: _sp(14),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Divider(height: 16, color: AppColors.borderLight),
          child,
        ],
      ),
    );
  }

  Widget _chartTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Color(0xFF1B5E20), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart(String text) {
    return Center(
      child: Text(text, style: GoogleFonts.poppins(color: Colors.grey[600])),
    );
  }

  Widget _emptyInline(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: GoogleFonts.poppins(color: Colors.grey[600])),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(key, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]))),
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _money(dynamic value) {
    final numValue = (value as num?)?.toDouble() ?? 0;
    return numValue.toStringAsFixed(2);
  }

  String _num(dynamic value) {
    final numValue = (value as num?)?.toDouble() ?? 0;
    return numValue.toStringAsFixed(0);
  }
}
