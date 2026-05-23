import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isParent = false;
  List<Map<String, dynamic>> _taskHistory = [];
  List<dynamic> _familyRanking = [];
  int _completedCount = 0;
  int _inProgressCount = 0;
  int _pendingCount = 0;

  // ─── Theme constants ────────────────────────────────────────────────────────
  static const _primary = Color(0xFF00897B);
  static const _primaryLight = Color(0xFF00ACC1);
  static const _bgLight = Color(0xFFE8F5F5);
  static const _bgDark = Color(0xFF0A1628);
  static const _cardDark = Color(0xFF122030);
  static const _borderLight = Color(0xFFB2DFDB);
  static const _borderDark = Color(0xFF1E3A4A);
  static const _textPrimaryLight = Color(0xFF00352E);
  static const _textPrimaryDark = Color(0xFFE0F2F1);
  static const _textSecLight = Color(0xFF4DB6AC);
  static const _textSecDark = Color(0xFF80CBC4);

  @override
  void initState() {
    super.initState();
    _loadTaskStatus();
  }

  // ─── Logic (existing, unchanged) ───────────────────────────────────────────
  Future<void> _loadTaskStatus() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _apiService.getAllAssignedTasks();

      int completed = 0;
      int inProgress = 0;
      int pending = 0;
      final historyList = <Map<String, dynamic>>[];

      for (var task in tasks) {
        final status = task['status'] ?? 'assigned';
        final taskTitle = task['task_id']?['title'] ?? 'Unknown Task';
        final memberMail = task['member_mail'] ?? '';
        final points = task['assigned_points'] ?? 0;
        final penaltyPts = task['penalty_points'] ?? 0;
        final createdAt = DateTime.tryParse(task['createdAt'] ?? '');

        if (status == 'completed' || status == 'approved') {
          completed++;
        } else if (status == 'in_progress' || status == 'pending_approval') {
          inProgress++;
        } else {
          pending++;
        }

        historyList.add({
          'task': taskTitle,
          'member': memberMail.split('@').first,
          'status': status,
          'points': points,
          'penalty': penaltyPts,
          'date': _formatDate(createdAt),
        });
      }

      // Load parent-specific data
      try {
        _isParent = await _apiService.isParent();
      } catch (_) {}

      if (_isParent) {
        try {
          _familyRanking = await _apiService.getPointsRanking();
        } catch (_) {}
      }

      setState(() {
        _taskHistory = historyList;
        _completedCount = completed;
        _inProgressCount = inProgress;
        _pendingCount = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading status: $e'),
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

  // ─── Avatar helper ─────────────────────────────────────────────────────────
  static const _avatarPalette = [
    {'bg': Color(0xFFE3F2FD), 'text': Color(0xFF1565C0), 'border': Color(0xFF90CAF9)},
    {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFE65100), 'border': Color(0xFFFFCC80)},
    {'bg': Color(0xFFFCE4EC), 'text': Color(0xFFC2185B), 'border': Color(0xFFF48FB1)},
    {'bg': Color(0xFFE0F2F1), 'text': Color(0xFF00695C), 'border': Color(0xFF80CBC4)},
    {'bg': Color(0xFFF3E5F5), 'text': Color(0xFF7B1FA2), 'border': Color(0xFFCE93D8)},
    {'bg': Color(0xFFE8F5F5), 'text': Color(0xFF00897B), 'border': Color(0xFFB2DFDB)},
  ];

  Widget _buildAvatar(String name, {double size = 36}) {
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final idx =
        name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length;
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
            fontSize: size * 0.33,
            fontWeight: FontWeight.w700,
            color: c['text'] as Color,
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? _bgDark : _bgLight;
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
          'Family Status',
          style: GoogleFonts.poppins(
              color: textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primary),
            onPressed: _loadTaskStatus,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadTaskStatus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 3 stat cards ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                '✅',
                                'Completed',
                                _completedCount,
                                const Color(0xFF00BFA5),
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                '⏳',
                                'In Progress',
                                _inProgressCount,
                                const Color(0xFF1E88E5),
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                '📋',
                                'Pending',
                                _pendingCount,
                                const Color(0xFFFB8C00),
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Activity history ──────────────────────────
                        Text(
                          'Activity History',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _taskHistory.isEmpty
                            ? _buildEmptyState(isDark, textSec)
                            : ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: _taskHistory.length,
                                itemBuilder: (_, i) => _buildHistoryRow(
                                  _taskHistory[i],
                                  isDark,
                                  textPrimary,
                                  textSec,
                                ),
                              ),

                        // ── Member score cards (parent only) ──────────
                        if (_isParent && _familyRanking.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Member Scores',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._familyRanking.asMap().entries.map(
                                (e) => _buildMemberScoreCard(
                                    e.value, e.key, isDark),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─── Stat card ──────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    String emoji,
    String title,
    int count,
    Color color,
    bool isDark,
  ) {
    final cardColor = isDark ? _cardDark : Colors.white;
    final border = isDark ? _borderDark : _borderLight;
    final textSec = isDark ? _textSecDark : _textSecLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
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
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 9, color: textSec),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark, Color textSec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.task_alt,
                size: 60,
                color: const Color(0xFF4DB6AC).withValues(alpha: 0.45)),
            const SizedBox(height: 16),
            Text('No tasks assigned yet',
                style: GoogleFonts.poppins(color: textSec)),
          ],
        ),
      ),
    );
  }

  // ─── History row ────────────────────────────────────────────────────────────
  Widget _buildHistoryRow(
    Map<String, dynamic> task,
    bool isDark,
    Color textPrimary,
    Color textSec,
  ) {
    final status = task['status'] as String;
    final memberName = task['member'] as String;
    final points = task['points'] as int;
    final penalty = task['penalty'] as int;

    Color statusBg;
    Color statusTextColor;
    String statusLabel;
    String ptsLabel;
    Color ptsColor;

    switch (status) {
      case 'approved':
        statusBg = const Color(0xFFE0F2F1);
        statusTextColor = const Color(0xFF00695C);
        statusLabel = 'Approved';
        ptsLabel = '+$points pts';
        ptsColor = _primary;
        break;
      case 'rejected':
        statusBg = const Color(0xFFFFEBEE);
        statusTextColor = const Color(0xFFC62828);
        statusLabel = 'Rejected';
        ptsLabel = '0 pts';
        ptsColor = Colors.grey;
        break;
      case 'late':
        statusBg = const Color(0xFFFFEBEE);
        statusTextColor = const Color(0xFFC62828);
        statusLabel = 'Late';
        ptsLabel = penalty > 0 ? '-$penalty pts' : '0 pts';
        ptsColor = const Color(0xFFE53935);
        break;
      case 'in_progress':
        statusBg = const Color(0xFFE3F2FD);
        statusTextColor = const Color(0xFF1565C0);
        statusLabel = 'Active';
        ptsLabel = '—';
        ptsColor = textSec;
        break;
      case 'completed':
        statusBg = const Color(0xFFE3F2FD);
        statusTextColor = const Color(0xFF1565C0);
        statusLabel = 'Waiting';
        ptsLabel = '—';
        ptsColor = textSec;
        break;
      default:
        statusBg = const Color(0xFFFFF3E0);
        statusTextColor = const Color(0xFFE65100);
        statusLabel = 'Pending';
        ptsLabel = '—';
        ptsColor = textSec;
    }

    // If penalty was applied regardless of status
    if (penalty > 0 && status == 'approved') {
      ptsLabel = '-$penalty pts';
      ptsColor = const Color(0xFFE53935);
      statusBg = const Color(0xFFFFF3E0);
      statusTextColor = const Color(0xFFE65100);
      statusLabel = 'Penalty';
    }

    final cardColor = isDark ? _cardDark : Colors.white;
    final border = isDark ? _borderDark : _borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
          _buildAvatar(memberName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['task'] as String,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 11, color: textSec),
                    const SizedBox(width: 3),
                    Text(memberName,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: textSec)),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: textSec),
                    const SizedBox(width: 3),
                    Text(task['date'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: textSec)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? statusTextColor.withValues(alpha: 0.15)
                      : statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusTextColor),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ptsLabel,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ptsColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Member score card (parent only) ───────────────────────────────────────
  Widget _buildMemberScoreCard(
      dynamic member, int index, bool isDark) {
    final rank = (member['rank'] ?? (index + 1)) as int;
    final username = (member['username'] ?? 'Unknown').toString();
    final memberType = (member['member_type'] ?? '').toString();
    final totalPoints =
        ((member['total_points'] ?? 0) as num).toInt();

    const medalEmoji = ['🥇', '🥈', '🥉'];
    const medalColors = [
      Color(0xFFFB8C00),
      Color(0xFF78909C),
      Color(0xFF8D6E63),
    ];

    final isTop3 = rank <= 3;
    final isFirst = rank == 1;
    final ptsColor =
        isTop3 ? medalColors[rank - 1] : _primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isFirst
            ? LinearGradient(
                colors: [Color(0xFF00695C), _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isFirst ? null : (isDark ? _cardDark : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFirst
              ? const Color(0xFF00897B)
              : (isDark ? _borderDark : _borderLight),
        ),
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
          // Rank medal or number
          SizedBox(
            width: 28,
            child: Text(
              isTop3 ? medalEmoji[rank - 1] : '$rank',
              style: GoogleFonts.poppins(
                fontSize: isTop3 ? 20 : 13,
                fontWeight: FontWeight.w700,
                color: isFirst
                    ? Colors.white
                    : (isDark ? _textPrimaryDark : _textPrimaryLight),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          _buildAvatar(username, size: 38),
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
                    color: isFirst
                        ? Colors.white
                        : (isDark ? _textPrimaryDark : _textPrimaryLight),
                  ),
                ),
                if (memberType.isNotEmpty)
                  Text(
                    memberType,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isFirst
                          ? Colors.white70
                          : (isDark ? _textSecDark : _textSecLight),
                    ),
                  ),
              ],
            ),
          ),
          // Points
          Text(
            '$totalPoints pts',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isFirst ? Colors.white : ptsColor,
            ),
          ),
        ],
      ),
    );
  }
}
