import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/app_bottom_nav.dart';

class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  // ── State (ALL UNCHANGED) ─────────────────────────────────────────────────
  final ApiService _apiService = ApiService();

  bool _isParent = false;
  int _userPoints = 0;
  double _moneyBalance = 0;
  double _pointsToMoneyRate = 0.05;
  bool _isLoading = true;
  bool _initializedArgs = false;
  List<Map<String, dynamic>> _wishlistItems = [];
  List<Map<String, dynamic>> _pendingRedemptions = [];
  String? _prefillItemId;

  // UI-only: highlighted payment pill on the main screen
  String _paymentHint = 'points';

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  static final _itemBgColors = [
    Color(0xFFE0F2F1), Color(0xFFFFF8E1), Color(0xFFFCE4EC),
    Color(0xFFE3F2FD), Color(0xFFE8F5F5), Color(0xFFF3E5F5),
  ];
  static final _itemIconColors = [
    AppColors.primary, Color(0xFFF9A825), Color(0xFFE91E63),
    Color(0xFF1565C0), Color(0xFF00897B), Color(0xFF7B1FA2),
  ];
  static final _memberColors = [
    {'bg': Color(0xFFE3F2FD), 'text': Color(0xFF1565C0), 'border': Color(0xFF90CAF9)},
    {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFE65100),  'border': Color(0xFFFFCC80)},
    {'bg': Color(0xFFFCE4EC), 'text': Color(0xFFC2185B),  'border': Color(0xFFF48FB1)},
    {'bg': Color(0xFFE0F2F1), 'text': Color(0xFF00695C),  'border': Color(0xFF80CBC4)},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedArgs) return;
    _initializedArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['prefillItem'] is Map) {
      final prefillItem = Map<String, dynamic>.from(args['prefillItem']);
      _prefillItemId = prefillItem['_id']?.toString();
    }
  }

  // ── Logic (ALL UNCHANGED) ─────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _isParent = await _apiService.isParent();
      final wallet = await _apiService.getMyWallet();
      final memberId = await _apiService.getCurrentMemberId();
      if (memberId != null && memberId.isNotEmpty) {
        final combined = await _apiService.getCombinedBalance(memberId: memberId);
        _moneyBalance = ((combined['money_balance'] ?? 0) as num).toDouble();
        final conversionRate = combined['conversionRate'];
        if (conversionRate is Map<String, dynamic>) {
          final rate = conversionRate['points_to_money_rate'];
          if (rate is num && rate > 0) _pointsToMoneyRate = rate.toDouble();
        }
      }
      if (_isParent) {
        final pending = await _apiService.getPendingRedemptions();
        _pendingRedemptions = pending
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        final wishlist = await _apiService.getMyWishlistItems();
        _wishlistItems = wishlist
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      setState(() {
        _userPoints = wallet['total_points'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading redeem data: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openPaymentSelector(Map<String, dynamic> item) async {
    final itemTitle       = (item['item_name'] ?? 'Reward').toString();
    final itemDescription = (item['description'] ?? '').toString();
    final pointsPrice     = ((item['required_points'] ?? 0) as num).toDouble();
    final moneyPrice =
        double.parse((pointsPrice * _pointsToMoneyRate).toStringAsFixed(2));

    String paymentMethod = 'points';
    double splitMoney    = double.parse((moneyPrice / 2).toStringAsFixed(2));
    bool isSubmitting    = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final splitPoints = pointsPrice - (splitMoney / _pointsToMoneyRate);
            final pointsToUse = paymentMethod == 'points'
                ? pointsPrice
                : paymentMethod == 'money'
                    ? 0
                    : splitPoints.clamp(0, pointsPrice);
            final moneyToUse = paymentMethod == 'points'
                ? 0.0
                : paymentMethod == 'money'
                    ? moneyPrice
                    : splitMoney;
            final hasEnoughPoints = _userPoints >= pointsToUse.ceil();
            final hasEnoughMoney  = _moneyBalance >= moneyToUse;
            final canSubmit       = hasEnoughPoints && hasEnoughMoney && !isSubmitting;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  Text(itemTitle,
                      style: GoogleFonts.poppins(
                          fontSize: _sp(17), fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (itemDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(itemDescription,
                        style: GoogleFonts.poppins(
                            fontSize: _sp(12), color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 14),
                  Text('Payment Method',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(12), fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _modalPayPill('Points', 'points', paymentMethod,
                          () => setModalState(() => paymentMethod = 'points')),
                      const SizedBox(width: 6),
                      _modalPayPill('Money', 'money', paymentMethod,
                          () => setModalState(() => paymentMethod = 'money')),
                      const SizedBox(width: 6),
                      _modalPayPill('Split', 'mixed', paymentMethod,
                          () => setModalState(() => paymentMethod = 'mixed')),
                    ],
                  ),
                  if (paymentMethod == 'mixed') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Money portion: ${splitMoney.toStringAsFixed(2)} EGP',
                      style: GoogleFonts.poppins(
                          fontSize: _sp(11), color: AppColors.textSecondary),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        thumbColor: AppColors.primary,
                        inactiveTrackColor: AppColors.border,
                        overlayColor: AppColors.primary.withOpacity(0.12),
                      ),
                      child: Slider(
                        min: 0, max: moneyPrice,
                        value: splitMoney.clamp(0, moneyPrice),
                        onChanged: (value) => setModalState(
                            () => splitMoney = double.parse(value.toStringAsFixed(2))),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildCalcRow('Points to use', '${pointsToUse.ceil()} pts'),
                        _buildCalcRow('Money to use', '${moneyToUse.toStringAsFixed(2)} EGP'),
                        _buildCalcRow('Remaining points',
                            '${(_userPoints - pointsToUse.ceil()).clamp(0, 1 << 30)} pts'),
                        _buildCalcRow('Remaining money',
                            '${(_moneyBalance - moneyToUse).toStringAsFixed(2)} EGP'),
                      ],
                    ),
                  ),
                  if (!hasEnoughPoints || !hasEnoughMoney) ...[
                    const SizedBox(height: 8),
                    Text('Insufficient balance for this payment split.',
                        style: GoogleFonts.poppins(
                            color: AppColors.error, fontWeight: FontWeight.w600,
                            fontSize: _sp(11))),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: canSubmit
                        ? () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              final requestBody = {
                                'wishlist_item_id': item['_id'],
                                'request_details': itemTitle,
                                'payment_method': paymentMethod,
                                'point_deduction': pointsPrice.ceil(),
                                'points_used': pointsToUse.ceil(),
                                'money_used': double.parse(moneyToUse.toStringAsFixed(2)),
                              };
                              if (paymentMethod == 'points') {
                                await _apiService.requestRedemption(requestBody);
                              } else {
                                await _apiService.requestRedemptionWithMoney(requestBody);
                              }
                              if (!mounted) return;
                              Navigator.pop(context);
                              await _showCelebrationDialog(itemTitle);
                              await _loadData();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Redemption failed: $e'),
                                  backgroundColor: Colors.red));
                            } finally {
                              if (mounted) setModalState(() => isSubmitting = false);
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: canSubmit
                            ? LinearGradient(
                                colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : null,
                        color: canSubmit ? null : AppColors.border,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: canSubmit
                            ? [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Confirm Redemption',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: _sp(13),
                                    color: canSubmit
                                        ? Colors.white
                                        : AppColors.textHint)),
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

  Widget _modalPayPill(
      String label, String value, String current, VoidCallback onTap) {
    final isActive = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: 0.8),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: _sp(11), fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

  Future<void> _showCelebrationDialog(String title) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Request Sent',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Icon(Icons.celebration,
                  color: Colors.orange, size: 56),
            ),
            const SizedBox(height: 10),
            Text(
              '$title redemption request submitted. Waiting for parent approval.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: _sp(12)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/rewards');
            },
            child: Text('Back to Rewards',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePending(Map<String, dynamic> redeem,
      {bool forceApprove = false}) async {
    final redeemId = redeem['_id']?.toString();
    if (redeemId == null || redeemId.isEmpty) return;
    try {
      final response = await _apiService.parentApproveRedemption(redeemId, true,
          forceApprove: forceApprove);
      final status = (response['status'] ?? '').toString();
      if (status == 'warning' && !forceApprove) {
        final warningData = response['data'] as Map<String, dynamic>?;
        final requiredAmount   = warningData?['required_amount']   ?? 0;
        final remainingBudget  = warningData?['remaining_budget']  ?? 0;
        if (!mounted) return;
        final proceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Budget Warning',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                content: Text(
                  'Rewards budget is low. Remaining: $remainingBudget EGP, required: $requiredAmount EGP. Approve anyway?',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: GoogleFonts.poppins())),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Force Approve',
                        style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              ),
            ) ??
            false;
        if (proceed) await _approvePending(redeem, forceApprove: true);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redemption approved', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.primary),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectPending(Map<String, dynamic> redeem) async {
    final redeemId = redeem['_id']?.toString();
    if (redeemId == null || redeemId.isEmpty) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Reject Redemption',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: GoogleFonts.poppins())),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reject',
                    style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _apiService.parentApproveRedemption(redeemId, false,
          note: controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Redemption rejected'), backgroundColor: Colors.orange),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejection failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCalcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: _sp(11), color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: _sp(11), fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? const Color(0xFF0A1628) : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isParent ? 'Approve Redemptions' : 'Redeem',
          style: GoogleFonts.poppins(
              fontSize: _sp(17), fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 0),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: _isParent ? _buildParentView(isDark) : _buildChildView(isDark),
                ),
              ),
            ),
    );
  }

  // ── Child view ─────────────────────────────────────────────────────────────

  Widget _buildChildView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final border = isDark ? const Color(0xFF1E3A4A) : AppColors.border;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
      children: [
        // Balance card
        _buildBalanceCard(),
        const SizedBox(height: 14),

        // Payment method pills (UI hint only)
        _sectionLabel('PAYMENT METHOD', isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            _payPill('Points only', 'points', isDark),
            const SizedBox(width: 6),
            _payPill('Money only', 'money', isDark),
            const SizedBox(width: 6),
            _payPill('Split', 'mixed', isDark),
          ],
        ),
        const SizedBox(height: 14),

        // Wishlist items
        _sectionLabel('MY WISHLIST', isDark),
        const SizedBox(height: 8),
        if (_wishlistItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard_outlined,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 10),
                Text('No wishlist items available for redemption.',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(12), color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          ..._wishlistItems.asMap().entries
              .map((e) => _buildWishlistCard(e.value, e.key, isDark)),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final m2pRate = 1 / _pointsToMoneyRate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16, offset: const Offset(0, 6),
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
                  color: Colors.white.withOpacity(0.07)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Points
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Points',
                        style: GoogleFonts.poppins(
                            fontSize: _sp(10),
                            color: Colors.white.withOpacity(0.7))),
                    Text('$_userPoints pts',
                        style: GoogleFonts.poppins(
                            fontSize: _sp(22), fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.3)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                        width: 1, height: 40,
                        color: Colors.white.withOpacity(0.25)),
                  ),
                  // Money
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Money',
                        style: GoogleFonts.poppins(
                            fontSize: _sp(10),
                            color: Colors.white.withOpacity(0.7))),
                    Text('${_moneyBalance.toStringAsFixed(2)} EGP',
                        style: GoogleFonts.poppins(
                            fontSize: _sp(22), fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.3)),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rate: ${m2pRate.toStringAsFixed(0)} EGP = 100 pts  ·  1 pt = ${_pointsToMoneyRate.toStringAsFixed(2)} EGP',
                style: GoogleFonts.poppins(
                    fontSize: _sp(9),
                    color: Colors.white.withOpacity(0.65)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payPill(String label, String value, bool isDark) {
    final isActive = _paymentHint == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentHint = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : (isDark ? const Color(0xFF122030) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: 0.8),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: _sp(11), fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> item, int index, bool isDark) {
    final title       = (item['item_name'] ?? 'Reward').toString();
    final itemId      = item['_id']?.toString();
    final points      = ((item['required_points'] ?? 0) as num).toDouble();
    final money       = double.parse((points * _pointsToMoneyRate).toStringAsFixed(2));
    final fundedAmt   = ((item['funded_amount'] ?? 0) as num).toDouble();
    final estimatedP  = ((item['estimated_price'] ?? points) as num).toDouble();
    final progress    = estimatedP > 0
        ? (fundedAmt / estimatedP).clamp(0.0, 1.0)
        : 0.0;
    final highlighted = _prefillItemId != null && itemId == _prefillItemId;
    final canAfford   = _userPoints >= points.ceil() || _moneyBalance >= money;
    final cardBg      = isDark ? const Color(0xFF122030) : Colors.white;
    final border      = highlighted
        ? AppColors.primary
        : (isDark ? const Color(0xFF1E3A4A) : AppColors.border);
    final iconBg    = _itemBgColors[index % _itemBgColors.length];
    final iconColor = _itemIconColors[index % _itemIconColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: border, width: highlighted ? 1.5 : 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.card_giftcard_outlined,
                color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: _sp(12), fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFE0F2F1)
                            : AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${points.toStringAsFixed(0)} pts  ·  ${money.toStringAsFixed(2)} EGP',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(10), color: AppColors.textSecondary),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark
                        ? const Color(0xFF1E3A4A)
                        : AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% funded',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(9), color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _openPaymentSelector(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: canAfford
                    ? LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: canAfford ? null : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: canAfford
                    ? [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 6, offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Text('Redeem',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(11), fontWeight: FontWeight.w700,
                      color: canAfford
                          ? Colors.white
                          : AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Parent view ────────────────────────────────────────────────────────────

  Widget _buildParentView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF122030) : Colors.white;
    final border = isDark ? const Color(0xFF1E3A4A) : AppColors.border;
    final divider = isDark ? const Color(0xFF1E3A4A) : AppColors.borderLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
      children: [
        _sectionLabel('PENDING APPROVALS', isDark),
        const SizedBox(height: 8),
        if (_pendingRedemptions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text('No pending redemptions right now.',
                    style: GoogleFonts.poppins(
                        fontSize: _sp(12), color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 0.8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: _pendingRedemptions.asMap().entries.map((entry) {
                final i      = entry.key;
                final redeem = entry.value;
                final isLast = i == _pendingRedemptions.length - 1;
                final details = (redeem['request_details'] ?? 'Redemption').toString();
                final points = ((redeem['points_used'] ?? redeem['point_deduction'] ?? 0) as num).toDouble();
                final money  = ((redeem['money_used'] ?? 0) as num).toDouble();
                final requesterRaw = redeem['requester'];
                final requesterStr = requesterRaw is Map
                    ? (requesterRaw['username'] ?? requesterRaw['mail'] ?? 'Member').toString()
                    : requesterRaw?.toString() ?? 'Member';
                final colors = _memberColors[i % _memberColors.length];
                final initials = requesterStr.trim().split(RegExp(r'\s+')).take(2)
                    .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(bottom: BorderSide(color: divider, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: colors['bg'],
                          shape: BoxShape.circle,
                          border: Border.all(color: colors['border']!, width: 1.5),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: TextStyle(
                                  fontSize: _sp(11), fontWeight: FontWeight.w700,
                                  color: colors['text'] as Color)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(details,
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(12), fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFE0F2F1)
                                        : AppColors.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              '$requesterStr  ·  ${points.toStringAsFixed(0)} pts${money > 0 ? '  ·  ${money.toStringAsFixed(2)} EGP' : ''}',
                              style: GoogleFonts.poppins(
                                  fontSize: _sp(10),
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _rejectPending(redeem),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(9)),
                          child: Center(
                            child: Text('✕',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _approvePending(redeem),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(9)),
                          child: Center(
                            child: Text('✓',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: _sp(9), fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: AppColors.textSecondary,
    ),
  );
}
