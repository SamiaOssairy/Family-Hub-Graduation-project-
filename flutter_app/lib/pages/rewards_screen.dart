import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/app_bottom_nav.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final ApiService _apiService = ApiService();

  int _totalPoints = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rewardsHistory = [];
  List<Map<String, dynamic>> _wishlistItems = [];
  List<dynamic> _familyRanking = [];
  int _earnedThisWeek = 0;
  int _redeemedTotal = 0;
  double _pointsToMoneyRate = 0.05;

  // ─── Theme constants ────────────────────────────────────────────────────────
  static const _primary = Color(0xFF00897B);
  static const _primaryLight = Color(0xFF00ACC1);
  static const _bgLight = Color(0xFFE8F5F5);
  static const _bgDark = Color(0xFF0A1628);
  static const _cardDark = Color(0xFF122030);
  static const _borderLight = Color(0xFFB2DFDB);
  static const _borderDark = Color(0xFF1E3A4A);
  static const _borderInner = Color(0xFFE0F2F1);
  static const _textPrimaryLight = Color(0xFF00352E);
  static const _textPrimaryDark = Color(0xFFE0F2F1);
  static const _textSecLight = Color(0xFF4DB6AC);
  static const _textSecDark = Color(0xFF80CBC4);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await _apiService.getMyWallet();

      List<dynamic> history = [];
      try {
        history = await _apiService.getMyPointHistory();
      } catch (e) {
        debugPrint('Failed to load history: $e');
      }

      try {
        _familyRanking = await _apiService.getPointsRanking();
      } catch (e) {
        debugPrint('Failed to load ranking: $e');
        _familyRanking = [];
      }

      List<dynamic> wishlistRaw = [];
      try {
        wishlistRaw = await _apiService.getMyWishlistItems();
      } catch (e) {
        debugPrint('Failed to load wishlist items: $e');
      }

      double pointsToMoneyRate = _pointsToMoneyRate;
      try {
        final memberId = await _apiService.getCurrentMemberId();
        if (memberId != null && memberId.isNotEmpty) {
          final combined =
              await _apiService.getCombinedBalance(memberId: memberId);
          final conversion = combined['conversionRate'];
          if (conversion is Map<String, dynamic>) {
            final rate = conversion['points_to_money_rate'];
            if (rate is num && rate > 0) {
              pointsToMoneyRate = rate.toDouble();
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to load conversion rate: $e');
      }

      int earned = 0;
      int redeemed = 0;
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final historyList = <Map<String, dynamic>>[];
      for (var item in history) {
        final points = item['points_amount'] ?? 0;
        final createdAt = DateTime.tryParse(item['createdAt'] ?? '');

        if (points > 0) {
          if (createdAt != null && createdAt.isAfter(weekAgo)) {
            earned += points as int;
          }
        } else {
          redeemed += (points as int).abs();
        }

        historyList.add({
          'title': item['description'] ?? item['reason_type'] ?? 'Points',
          'points': (points as int).abs(),
          'date': _formatDate(createdAt),
          'type': points > 0 ? 'earned' : 'redeemed',
        });
      }

      setState(() {
        _totalPoints = wallet['total_points'] ?? 0;
        _rewardsHistory = historyList.take(10).toList();
        _wishlistItems = wishlistRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _earnedThisWeek = earned;
        _redeemedTotal = redeemed;
        _pointsToMoneyRate = pointsToMoneyRate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ─── Avatar helpers ──────────────────────────────────────────────────────
  static const _avatarPalette = [
    {'bg': Color(0xFFE3F2FD), 'text': Color(0xFF1565C0), 'border': Color(0xFF90CAF9)},
    {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFE65100), 'border': Color(0xFFFFCC80)},
    {'bg': Color(0xFFFCE4EC), 'text': Color(0xFFC2185B), 'border': Color(0xFFF48FB1)},
    {'bg': Color(0xFFE0F2F1), 'text': Color(0xFF00695C), 'border': Color(0xFF80CBC4)},
    {'bg': Color(0xFFF3E5F5), 'text': Color(0xFF7B1FA2), 'border': Color(0xFFCE93D8)},
    {'bg': Color(0xFFE8F5F5), 'text': Color(0xFF00897B), 'border': Color(0xFFB2DFDB)},
  ];

  Widget _buildAvatar(String name, {double size = 38}) {
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length;
    final c = _avatarPalette[idx];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c['bg'] as Color,
        shape: BoxShape.circle,
        border: Border.all(color: c['border'] as Color, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
              color: c['text'] as Color),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? _bgDark : _bgLight;
    final cardColor = isDark ? _cardDark : Colors.white;
    final border = isDark ? _borderDark : _borderLight;
    final textPrimary = isDark ? _textPrimaryDark : _textPrimaryLight;
    final textSec = isDark ? _textSecDark : _textSecLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rewards',
          style: GoogleFonts.poppins(
              color: textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/redeem'),
            icon: Icon(Icons.card_giftcard, color: _primary),
            label: Text(
              'Redeem',
              style: GoogleFonts.poppins(
                  color: _primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 1),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Points hero card ───────────────────────────
                        _buildHeroCard(isDark),
                        const SizedBox(height: 20),

                        // ── Quick stats ────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Earned This Week',
                                '+$_earnedThisWeek',
                                Icons.trending_up,
                                const Color(0xFF00897B),
                                isDark,
                                cardColor,
                                border,
                                textSec,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Redeemed',
                                '-$_redeemedTotal',
                                Icons.redeem,
                                const Color(0xFFFB8C00),
                                isDark,
                                cardColor,
                                border,
                                textSec,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Wishlist rewards ───────────────────────────
                        Text(
                          'Wishlist Rewards',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _wishlistItems.isEmpty
                            ? _buildEmptyCard(
                                'No wishlist items yet.\nAdd rewards from wishlist to redeem.',
                                isDark,
                                cardColor,
                                border,
                                textSec,
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _wishlistItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => _buildWishlistRewardCard(
                                    _wishlistItems[i],
                                    isDark,
                                    cardColor,
                                    border,
                                    textPrimary,
                                    textSec),
                              ),
                        const SizedBox(height: 24),

                        // ── Family leaderboard ─────────────────────────
                        if (_familyRanking.isNotEmpty) ...[
                          Text(
                            'Family Leaderboard',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLeaderboard(
                              isDark, cardColor, border, textPrimary, textSec),
                          const SizedBox(height: 24),
                        ],

                        // ── Points history ─────────────────────────────
                        Text(
                          'Points History',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _rewardsHistory.isEmpty
                            ? _buildEmptyCard(
                                'No point history yet.',
                                isDark,
                                cardColor,
                                border,
                                textSec,
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _rewardsHistory.length,
                                itemBuilder: (_, i) => _buildHistoryCard(
                                    _rewardsHistory[i],
                                    isDark,
                                    cardColor,
                                    border,
                                    textPrimary,
                                    textSec),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─── Hero card ─────────────────────────────────────────────────────────────
  Widget _buildHeroCard(bool isDark) {
    final moneyEquiv =
        (_totalPoints * _pointsToMoneyRate).toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00695C), _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative top-right bubble
          Row(
            children: [
              Text(
                'Your Points Balance',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_totalPoints pts',
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          // Stat chips row
          Row(
            children: [
              _buildHeroChip('↑ $_earnedThisWeek this week'),
              const SizedBox(width: 8),
              _buildHeroChip('= $moneyEquiv EGP'),
            ],
          ),
          const SizedBox(height: 14),
          // Redeem button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/redeem'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Redeem Points',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  // ─── Stat card ──────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color cardColor,
    Color border,
    Color textSec,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: textSec,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty placeholder card ─────────────────────────────────────────────────
  Widget _buildEmptyCard(
    String message,
    bool isDark,
    Color cardColor,
    Color border,
    Color textSec,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(color: textSec, fontSize: 13),
      ),
    );
  }

  // ─── Leaderboard ────────────────────────────────────────────────────────────
  Widget _buildLeaderboard(
    bool isDark,
    Color cardColor,
    Color border,
    Color textPrimary,
    Color textSec,
  ) {
    final medalEmoji = ['🥇', '🥈', '🥉'];
    final pointsColors = [
      const Color(0xFFFB8C00), // gold-ish
      const Color(0xFF78909C), // silver
      const Color(0xFF8D6E63), // bronze
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _familyRanking.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: isDark ? _borderDark : _borderInner),
        itemBuilder: (_, index) {
          final member = _familyRanking[index];
          final rank = (member['rank'] ?? (index + 1)) as int;
          final username = (member['username'] ?? 'Unknown').toString();
          final memberType = (member['member_type'] ?? '').toString();
          final points = member['total_points'] ?? 0;

          final isTop3 = rank <= 3;
          final pointsColor =
              isTop3 ? pointsColors[rank - 1] : _primary;

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Medal or rank number
                SizedBox(
                  width: 30,
                  child: Text(
                    isTop3 ? medalEmoji[rank - 1] : '$rank',
                    style: GoogleFonts.poppins(
                      fontSize: isTop3 ? 20 : 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar initials circle
                _buildAvatar(username),
                const SizedBox(width: 10),
                // Name + role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                      if (memberType.isNotEmpty)
                        Text(
                          memberType,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: textSec),
                        ),
                    ],
                  ),
                ),
                // Points badge
                Text(
                  '$points pts',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pointsColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── History card ───────────────────────────────────────────────────────────
  Widget _buildHistoryCard(
    Map<String, dynamic> item,
    bool isDark,
    Color cardColor,
    Color border,
    Color textPrimary,
    Color textSec,
  ) {
    final isEarned = item['type'] == 'earned';
    final accentColor =
        isEarned ? const Color(0xFF00897B) : const Color(0xFFE53935);
    final bgColor = isEarned ? _borderInner : const Color(0xFFFFEBEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? accentColor.withValues(alpha: 0.18)
                  : bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                isEarned ? Icons.check : Icons.card_giftcard_outlined,
                color: accentColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'].toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['date'].toString(),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: textSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isEarned ? '+' : '-'}${item['points']}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wishlist reward card ───────────────────────────────────────────────────
  Widget _buildWishlistRewardCard(
    Map<String, dynamic> item,
    bool isDark,
    Color cardColor,
    Color border,
    Color textPrimary,
    Color textSec,
  ) {
    final title = (item['item_name'] ?? 'Reward').toString();
    final details = (item['description'] ?? '').toString();
    final points =
        ((item['required_points'] ?? 0) as num).toDouble();
    final moneyOnly =
        double.parse((points * _pointsToMoneyRate).toStringAsFixed(2));
    final splitPoints = (points / 2).round();
    final splitMoney =
        double.parse((moneyOnly / 2).toStringAsFixed(2));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textPrimary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              details,
              style: GoogleFonts.poppins(fontSize: 11, color: textSec),
            ),
          ],
          const SizedBox(height: 10),
          // Pricing options
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2F42) : _borderInner,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isDark ? _borderDark : _borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriceRow('⭐', '${points.toStringAsFixed(0)} pts',
                    _primary),
                const SizedBox(height: 4),
                _buildPriceRow('💰', '${moneyOnly.toStringAsFixed(2)} EGP',
                    const Color(0xFF00ACC1)),
                const SizedBox(height: 4),
                _buildPriceRow(
                    '⭐💰',
                    '$splitPoints pts + ${splitMoney.toStringAsFixed(2)} EGP',
                    const Color(0xFFFB8C00)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/redeem',
                arguments: {'prefillItem': item},
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                shadowColor: _primary.withValues(alpha: 0.4),
              ),
              icon: Icon(Icons.card_giftcard, size: 18),
              label: Text(
                'Redeem This',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String emoji, String label, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
