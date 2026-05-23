import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app_frontend/core/services/api_service.dart';
import 'package:app_frontend/core/theme/app_theme.dart';
import 'package:app_frontend/core/theme/theme_provider.dart';
import 'package:app_frontend/core/widgets/app_bottom_nav.dart';

class CombinedWalletScreen extends StatefulWidget {
  const CombinedWalletScreen({super.key});

  @override
  State<CombinedWalletScreen> createState() => _CombinedWalletScreenState();
}

class _CombinedWalletScreenState extends State<CombinedWalletScreen>
    with SingleTickerProviderStateMixin {
  // ── State (ALL UNCHANGED) ─────────────────────────────────────────────────
  final ApiService _apiService = ApiService();
  final PageController _cardController = PageController(viewportFraction: 0.92);
  late TabController _tabController;

  bool _isLoading = true;
  bool _isParent = false;

  List<dynamic> _members = [];
  String? _selectedMemberId;
  String? _selectedMemberMail;

  Map<String, dynamic> _balance = {};
  List<Map<String, dynamic>> _transactions = [];

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Logic (ALL UNCHANGED) ─────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _isParent = await _apiService.isParent();
      final currentMemberId = await _apiService.getCurrentMemberId();
      final currentMemberMail = await _apiService.getCurrentMemberMail();

      if (_isParent) {
        _members = await _apiService.getAllMembers();
        final children = _members.where((m) {
          final type = (m['member_type_id'] is Map)
              ? (m['member_type_id']['type'] ?? '').toString()
              : '';
          return type != 'Parent';
        }).toList();

        if (children.isNotEmpty) {
          final selected = children.firstWhere(
            (m) => m['_id']?.toString() == _selectedMemberId,
            orElse: () => children.first,
          );
          _selectedMemberId = selected['_id']?.toString();
          _selectedMemberMail = selected['mail']?.toString();
        } else {
          _selectedMemberId = currentMemberId;
          _selectedMemberMail = currentMemberMail;
        }
      } else {
        _selectedMemberId = currentMemberId;
        _selectedMemberMail = currentMemberMail;
      }

      final balance = await _apiService.getCombinedBalance(memberId: _selectedMemberId);
      final pointHistory = _isParent && _selectedMemberMail != null
          ? await _apiService.getMemberPointHistory(_selectedMemberMail!)
          : await _apiService.getMyPointHistory();

      setState(() {
        _balance = balance;
        _transactions = _buildCombinedTransactions(pointHistory, balance);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load wallet data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _buildCombinedTransactions(
    List<dynamic> pointHistory,
    Map<String, dynamic> balance,
  ) {
    final conversionRate = _pointsToMoneyRate(balance);
    final list = <Map<String, dynamic>>[];

    for (final raw in pointHistory) {
      if (raw is! Map<String, dynamic>) continue;
      final reason = (raw['reason_type'] ?? '').toString();
      final description = (raw['description'] ?? 'Points update').toString();
      final pointsAmount = (raw['points_amount'] ?? 0).toDouble();
      final createdAt = DateTime.tryParse((raw['createdAt'] ?? '').toString());

      final isPositive = pointsAmount >= 0;
      final isConversion = reason == 'conversion';

      list.add({
        'kind': isConversion ? 'conversion' : 'points',
        'title': description,
        'subtitle': isConversion ? 'Points conversion' : 'Points activity',
        'amountText': '${isPositive ? '+' : '-'}${pointsAmount.abs().toStringAsFixed(0)} pts',
        'isPositive': isPositive,
        'date': createdAt,
      });

      if (isConversion) {
        final moneyEquivalent = pointsAmount.abs() * conversionRate;
        final moneyPositive = pointsAmount < 0;
        list.add({
          'kind': 'money',
          'title': description,
          'subtitle': 'Money side (conversion)',
          'amountText': '${moneyPositive ? '+' : '-'}${moneyEquivalent.toStringAsFixed(2)} EGP',
          'isPositive': moneyPositive,
          'date': createdAt,
        });
      }
    }

    list.sort((a, b) {
      final da = (a['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = (b['date'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return list;
  }

  Future<void> _openConversionSheet({required bool moneyToPoints}) async {
    final moneyBalance = (_balance['money_balance'] ?? 0).toDouble();
    final pointsBalance = (_balance['points_balance'] ?? 0).toDouble();

    final maxValue = moneyToPoints ? moneyBalance : pointsBalance;
    if (maxValue <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moneyToPoints
              ? 'No money available to convert.'
              : 'No points available to convert.'),
        ),
      );
      return;
    }

    double sliderValue = math.min(maxValue, maxValue > 1 ? 1 : maxValue);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final m2p = _moneyToPointsRate(_balance);
            final p2m = _pointsToMoneyRate(_balance);
            final converted = moneyToPoints
                ? sliderValue * m2p
                : sliderValue * p2m;

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    moneyToPoints ? 'Convert Money to Points' : 'Convert Points to Money',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(18), fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1 EGP = ${m2p.toStringAsFixed(2)} pts  ·  1 pt = ${p2m.toStringAsFixed(2)} EGP',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(11), color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  // Result preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'You receive',
                          style: GoogleFonts.poppins(
                              fontSize: _sp(12), color: AppColors.textSecondary),
                        ),
                        Text(
                          moneyToPoints
                              ? '${converted.toStringAsFixed(0)} pts'
                              : '${converted.toStringAsFixed(2)} EGP',
                          style: GoogleFonts.poppins(
                              fontSize: _sp(16), fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'for ${sliderValue.toStringAsFixed(moneyToPoints ? 2 : 0)} '
                      '${moneyToPoints ? 'EGP' : 'pts'}',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(11), color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      inactiveTrackColor: AppColors.border,
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 0,
                      max: maxValue,
                      divisions: 100,
                      label: sliderValue.toStringAsFixed(2),
                      onChanged: (v) => setModalState(() => sliderValue = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Confirm Conversion',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                              content: Text(
                                moneyToPoints
                                    ? 'Convert ${sliderValue.toStringAsFixed(2)} EGP to ${converted.toStringAsFixed(2)} points?'
                                    : 'Convert ${sliderValue.toStringAsFixed(2)} points to ${converted.toStringAsFixed(2)} EGP?',
                                style: GoogleFonts.poppins(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel',
                                      style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Confirm',
                                      style: GoogleFonts.poppins(color: Colors.white)),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!ok) return;

                      try {
                        if (moneyToPoints) {
                          await _apiService.convertMoneyToPoints(sliderValue);
                        } else {
                          await _apiService.convertPointsToMoney(sliderValue);
                        }
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Conversion completed successfully.')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                              content: Text('Conversion failed: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text('Confirm Conversion',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(14), fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _moneyToPointsRate(Map<String, dynamic> balance) {
    final r = balance['conversionRate'];
    if (r is Map && r['money_to_points_rate'] != null) {
      return (r['money_to_points_rate'] as num).toDouble();
    }
    return 10;
  }

  double _pointsToMoneyRate(Map<String, dynamic> balance) {
    final r = balance['conversionRate'];
    if (r is Map && r['points_to_money_rate'] != null) {
      return (r['points_to_money_rate'] as num).toDouble();
    }
    return 0.05;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? const Color(0xFF0A1628) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final border = isDark ? const Color(0xFF1E3A4A) : AppColors.border;

    final moneyBalance    = (_balance['money_balance']     ?? 0).toDouble();
    final pointsBalance   = (_balance['points_balance']    ?? 0).toDouble();
    final totalValueMoney = (_balance['total_value_in_money'] ?? 0).toDouble();

    final lifetimePointsEarned = _transactions
        .where((tx) => tx['kind'] != 'money' && (tx['isPositive'] == true))
        .fold<double>(0, (sum, tx) {
      final text = (tx['amountText'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '');
      return sum + (double.tryParse(text) ?? 0);
    });

    final lifetimeMoneySaved = _transactions
        .where((tx) => tx['kind'] == 'money' && (tx['isPositive'] == true))
        .fold<double>(0, (sum, tx) {
      final text = (tx['amountText'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '');
      return sum + (double.tryParse(text) ?? 0);
    });

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('My Wallet',
            style: GoogleFonts.poppins(
                fontSize: _sp(17), fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 1),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                    children: [
                      // Child selector (parent only)
                      if (_isParent && _members.isNotEmpty) ...[
                        _buildChildSelector(cardBg, border, isDark),
                        const SizedBox(height: 12),
                      ],

                      // Both wallet cards always visible
                      _buildMoneyCard(moneyBalance, lifetimeMoneySaved),
                      const SizedBox(height: 10),
                      _buildPointsCard(pointsBalance, lifetimePointsEarned),
                      const SizedBox(height: 12),

                      // Total value
                      _buildTotalValue(totalValueMoney, cardBg, border, isDark),
                      const SizedBox(height: 14),

                      // Recent transactions
                      _buildSectionLabel('RECENT TRANSACTIONS', isDark),
                      const SizedBox(height: 8),
                      _buildTransactionsList(cardBg, border, isDark),
                      const SizedBox(height: 14),

                      // Conversion panel
                      _buildSectionLabel('CONVERT', isDark),
                      const SizedBox(height: 8),
                      _buildConversionButtons(cardBg, border, isDark),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── Child selector ─────────────────────────────────────────────────────────

  Widget _buildChildSelector(Color cardBg, Color border, bool isDark) {
    final children = _members.where((m) {
      final type = (m['member_type_id'] is Map)
          ? (m['member_type_id']['type'] ?? '').toString()
          : '';
      return type != 'Parent';
    }).toList();

    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMemberId,
          isExpanded: true,
          dropdownColor: cardBg,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          hint: Text('Select member',
              style: GoogleFonts.poppins(
                  fontSize: _sp(13), color: AppColors.textHint)),
          items: children.map<DropdownMenuItem<String>>((member) {
            return DropdownMenuItem<String>(
              value: member['_id']?.toString(),
              child: Text(
                (member['username'] ?? member['mail'] ?? 'Member').toString(),
                style: GoogleFonts.poppins(
                    fontSize: _sp(13),
                    color: isDark
                        ? const Color(0xFFE0F2F1)
                        : AppColors.textPrimary),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;
            final selected =
                children.firstWhere((m) => m['_id']?.toString() == value);
            setState(() {
              _selectedMemberId  = value;
              _selectedMemberMail = selected['mail']?.toString();
            });
            await _loadData();
          },
        ),
      ),
    );
  }

  // ── Money card ─────────────────────────────────────────────────────────────

  Widget _buildMoneyCard(double moneyBalance, double lifetimeMoneySaved) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💵 Money Wallet',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(11), color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 4),
              Text(
                '${moneyBalance.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(26), fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.5),
              ),
              Text(
                'Saved lifetime: ${lifetimeMoneySaved.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), color: Colors.white.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openConversionSheet(moneyToPoints: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Convert to Points →',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(11), fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Points card ────────────────────────────────────────────────────────────

  Widget _buildPointsCard(double pointsBalance, double lifetimePointsEarned) {
    final m2p = _moneyToPointsRate(_balance);
    final p2m = _pointsToMoneyRate(_balance);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⭐ Points Wallet',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(11), color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 4),
              Text(
                '${pointsBalance.toStringAsFixed(0)} pts',
                style: GoogleFonts.poppins(
                    fontSize: _sp(26), fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.5),
              ),
              Text(
                'Rate: ${m2p.toStringAsFixed(0)} EGP = 100 pts  ·  1 pt = ${p2m.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(9), color: Colors.white.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openConversionSheet(moneyToPoints: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Convert to Money →',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(11), fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Total value ────────────────────────────────────────────────────────────

  Widget _buildTotalValue(double totalValueMoney, Color cardBg, Color border, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Value',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(11), color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Money + Points combined',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(9), color: AppColors.textHint)),
            ],
          ),
          Text(
            '${totalValueMoney.toStringAsFixed(2)} EGP',
            style: GoogleFonts.poppins(
                fontSize: _sp(20), fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  // ── Transaction list ───────────────────────────────────────────────────────

  Widget _buildTransactionsList(Color cardBg, Color border, bool isDark) {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Text('No transactions yet',
                style: GoogleFonts.poppins(
                    fontSize: _sp(12), color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final divider = isDark ? const Color(0xFF1E3A4A) : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: _transactions.take(10).toList().asMap().entries.map((entry) {
          final i   = entry.key;
          final tx  = entry.value;
          final isLast   = i == (_transactions.length < 10
              ? _transactions.length - 1 : 9);
          final kind      = (tx['kind'] ?? 'points').toString();
          final isPositive = tx['isPositive'] == true;
          final amountText = (tx['amountText'] ?? '').toString();

          // Icon config
          final Color iconBg;
          final Widget iconChild;
          if (kind == 'conversion') {
            iconBg = AppColors.primarySurface;
            iconChild = const Text('⭐', style: TextStyle(fontSize: 15));
          } else if (kind == 'money') {
            iconBg = isPositive
                ? AppColors.primarySurface
                : const Color(0xFFFFEBEE);
            iconChild = Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: isPositive ? AppColors.primary : AppColors.error,
            );
          } else {
            // points
            iconBg = isPositive
                ? AppColors.primarySurface
                : const Color(0xFFFFEBEE);
            iconChild = isPositive
                ? const Text('⭐', style: TextStyle(fontSize: 14))
                : const Text('🎁', style: TextStyle(fontSize: 14));
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(color: divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: iconChild),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (tx['title'] ?? 'Transaction').toString(),
                        style: GoogleFonts.poppins(
                            fontSize: _sp(12), fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFE0F2F1)
                                : AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _dateLabel(tx['date'] as DateTime?),
                        style: GoogleFonts.poppins(
                            fontSize: _sp(10), color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: _sp(12), fontWeight: FontWeight.w700,
                    color: isPositive ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Conversion buttons ─────────────────────────────────────────────────────

  Widget _buildConversionButtons(Color cardBg, Color border, bool isDark) {
    final m2p = _moneyToPointsRate(_balance);
    final p2m = _pointsToMoneyRate(_balance);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10)),
            child: Text(
              '1 EGP = ${m2p.toStringAsFixed(0)} pts  ·  1 pt = ${p2m.toStringAsFixed(2)} EGP',
              style: GoogleFonts.poppins(
                  fontSize: _sp(11), color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openConversionSheet(moneyToPoints: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF00897B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text('Money → Points',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(11), fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openConversionSheet(moneyToPoints: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF00ACC1).withValues(alpha: 0.25),
                            blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text('Points → Money',
                            style: GoogleFonts.poppins(
                                fontSize: _sp(11), fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: _sp(9), fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: AppColors.textSecondary,
    ),
  );
}
