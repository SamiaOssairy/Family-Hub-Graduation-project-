import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/guarded_button.dart';

// ─── Task Model ────────────────────────────────────────────────────────────────
class TaskItem {
  String id;
  String title;
  String description;
  bool isMandatory;
  String status;
  int points;
  String rewardType;
  double moneyReward;
  String? deadline;
  double progress;
  bool isSelectedToDelete;
  String notes;
  bool assignmentApproved;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    this.isMandatory = false,
    this.status = 'assigned',
    this.points = 0,
    this.rewardType = 'points',
    this.moneyReward = 0,
    this.deadline,
    this.progress = 0.0,
    this.isSelectedToDelete = false,
    this.notes = '',
    this.assignmentApproved = true,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    double progress = 0.0;
    String status = json['status'] ?? 'assigned';
    if (status == 'completed' || status == 'approved') {
      progress = 1.0;
    } else if (status == 'pending_approval') {
      progress = 0.8;
    } else if (status == 'in_progress') {
      progress = 0.5;
    }

    return TaskItem(
      id: json['_id'] ?? '',
      title: json['task_id']?['title'] ?? json['title'] ?? 'Unknown Task',
      description: json['task_id']?['description'] ?? json['description'] ?? '',
      isMandatory: json['task_id']?['is_mandatory'] ?? json['is_mandatory'] ?? false,
      status: status,
      points: json['assigned_points'] ?? 0,
      rewardType: json['task_id']?['reward_type'] ?? json['reward_type'] ?? 'points',
      moneyReward: ((json['task_id']?['money_reward'] ?? json['money_reward'] ?? 0) as num).toDouble(),
      deadline: json['deadline'],
      progress: progress,
      notes: json['notes'] ?? '',
      assignmentApproved: json['assignment_approved'] ?? true,
    );
  }

  String get rewardLabel {
    if (rewardType == 'money') return '${moneyReward.toStringAsFixed(2)} EGP';
    if (rewardType == 'both') return '$points pts + ${moneyReward.toStringAsFixed(2)} EGP';
    return '$points pts';
  }

  String get rewardEmoji {
    if (rewardType == 'money') return '💰';
    if (rewardType == 'both') return '⭐💰';
    return '⭐';
  }

  bool get canComplete =>
      assignmentApproved && (status == 'assigned' || status == 'in_progress');
  bool get isWaitingApproval => assignmentApproved && status == 'completed';
  bool get isRejected => assignmentApproved && status == 'rejected';
  bool get isDone => status == 'approved';
}

// ─── Screen ────────────────────────────────────────────────────────────────────
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  bool _isDeleteMode = false;
  bool _isLoading = true;

  // Member info
  String _memberName = '';
  String _memberType = '';
  String _currentMail = '';

  // Categories for the "Add Task" flow
  List<dynamic> _taskCategories = [];

  final _taskNameController = TextEditingController();
  final _taskDescriptionController = TextEditingController();

  List<TaskItem> _mandatoryTasks = [];
  List<TaskItem> _availableTasks = [];

  // ─── Theme constants ─────────────────────────────────────────────────────────
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
  static const _textSecondaryLight = Color(0xFF4DB6AC);
  static const _textSecondaryDark = Color(0xFF80CBC4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadTasks();
  }

  // ─── API: load tasks + member info ────────────────────────────────────────
  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _apiService.getMyTasks();
      final mandatory = <TaskItem>[];
      final available = <TaskItem>[];

      // Extract current member's mail from first task
      String memberMail = '';
      if (tasks.isNotEmpty) {
        memberMail = (tasks.first['member_mail'] is String)
            ? tasks.first['member_mail'] as String
            : '';
      }

      for (var task in tasks) {
        final taskItem = TaskItem.fromJson(task);
        if (taskItem.isMandatory) {
          mandatory.add(taskItem);
        } else {
          available.add(taskItem);
        }
      }

      // Fall back to wallet to get email when no tasks exist yet
      if (memberMail.isEmpty) {
        try {
          final wallet = await _apiService.getMyWallet();
          memberMail = wallet['member_mail']?.toString() ?? '';
        } catch (_) {}
      }

      // Resolve display name + save current email
      if (memberMail.isNotEmpty) {
        try {
          final members = await _apiService.getAllMembers();
          final match = members.firstWhere(
            (m) => m['mail'] == memberMail,
            orElse: () => <String, dynamic>{},
          );
          if (match is Map && match.isNotEmpty) {
            setState(() {
              _currentMail = memberMail;
              _memberName = match['username']?.toString() ??
                  memberMail.split('@').first;
              _memberType =
                  match['member_type_id']?['type']?.toString() ?? '';
            });
          } else {
            setState(() {
              _currentMail = memberMail;
              _memberName = memberMail.split('@').first;
            });
          }
        } catch (_) {
          setState(() {
            _currentMail = memberMail;
            _memberName = memberMail.split('@').first;
          });
        }
      }

      // Load task categories for the "Add Task" flow
      try {
        final cats = await _apiService.getAllTaskCategories();
        setState(() => _taskCategories = cats);
      } catch (_) {}

      setState(() {
        _mandatoryTasks = mandatory;
        _availableTasks = available;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading tasks: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskNameController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

  // ─── Logic: delete mode ────────────────────────────────────────────────────
  void _deleteSelectedTasks() {
    setState(() {
      _mandatoryTasks.removeWhere((t) => t.isSelectedToDelete);
      _availableTasks.removeWhere((t) => t.isSelectedToDelete);
      _isDeleteMode = false;
    });
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      for (var t in _mandatoryTasks) {
        t.isSelectedToDelete = false;
      }
      for (var t in _availableTasks) {
        t.isSelectedToDelete = false;
      }
    });
  }

  // ─── Logic: create task + self-assign via API ─────────────────────────────
  Future<void> _addNewTask(String? categoryId) async {
    final title = _taskNameController.text.trim();
    if (title.isEmpty || categoryId == null || _currentMail.isEmpty) return;

    try {
      // 1. Create task template
      final taskResp = await _apiService.createTask({
        'title': title,
        'description': _taskDescriptionController.text.trim(),
        'category_id': categoryId,
        'is_mandatory': _tabController.index == 0,
        'reward_type': 'points',
        'money_reward': 0,
      });

      final taskId = taskResp['data']?['task']?['_id']?.toString() ?? '';
      if (taskId.isEmpty) throw Exception('Task creation failed');

      // 2. Assign to self
      await _apiService.assignTask({
        'task_id': taskId,
        'member_mail': _currentMail,
        'assigned_points': 10,
        'penalty_points': 0,
        'deadline':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'priority': 0,
      });

      _taskNameController.clear();
      _taskDescriptionController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task added and assigned to you!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Logic: complete task via API ─────────────────────────────────────────
  Future<void> _completeTask(TaskItem task) async {
    final isDark = context.read<ThemeProvider>().isDark;
    final cardColor = isDark ? _cardDark : Colors.white;
    final textPrimary = isDark ? _textPrimaryDark : _textPrimaryLight;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: _primary),
            const SizedBox(width: 10),
            Text('Complete Task',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark "${task.title}" as completed?',
              style: GoogleFonts.poppins(fontSize: 13, color: textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2F42) : _borderInner,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderLight),
              ),
              child: Text(
                'Reward: ${task.rewardLabel}',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: _textSecondaryLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Complete!',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final response = await _apiService.completeTask(task.id);
      final rewardSummary = response['data']?['rewardSummary'];
      if (mounted && rewardSummary is Map<String, dynamic>) {
        await _showRewardDialog(rewardSummary);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task completed! Rewards applied.'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
      }
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRewardDialog(Map<String, dynamic> rewardSummary) async {
    final points =
        ((rewardSummary['points_awarded'] ?? 0) as num).toDouble();
    final money =
        ((rewardSummary['money_awarded'] ?? 0) as num).toDouble();
    final type = (rewardSummary['reward_type'] ?? 'points').toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('🎉 Reward Applied!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (type == 'points' || type == 'both') ...[
              const Text('⭐', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 6),
              Text('+${points.toStringAsFixed(0)} pts',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ],
            if (type == 'both') const SizedBox(width: 14),
            if (type == 'money' || type == 'both') ...[
              const Text('💰', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 6),
              Text('+${money.toStringAsFixed(2)} EGP',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Nice!',
                style: GoogleFonts.poppins(color: _primary)),
          ),
        ],
      ),
    );
  }

  // ─── Status helpers ────────────────────────────────────────────────────────
  Color _statusDotColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF00BFA5);
      case 'completed':
      case 'pending_approval':
      case 'in_progress':
        return const Color(0xFF1E88E5);
      case 'rejected':
      case 'late':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFFFB8C00);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Done ✓';
      case 'pending_approval':
        return 'Waiting';
      case 'completed':
        return 'Waiting ⏳';
      case 'in_progress':
        return 'Active';
      case 'rejected':
        return 'Rejected ✕';
      case 'late':
        return 'Late';
      default:
        return 'Pending';
    }
  }

  String _formatDeadlineShort(String? deadline) {
    if (deadline == null) return '';
    try {
      final date = DateTime.parse(deadline);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.isNegative) return 'Overdue';
      if (diff.inHours < 24) return '${diff.inHours}h left';
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
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

  Widget _buildAvatar(String name, {double size = 40}) {
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
    final textPrimary = isDark ? _textPrimaryDark : _textPrimaryLight;
    final textSec = isDark ? _textSecondaryDark : _textSecondaryLight;
    final border = isDark ? _borderDark : _borderLight;
    final totalTasks = _mandatoryTasks.length + _availableTasks.length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Tasks',
            style: GoogleFonts.poppins(
                color: textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primary),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: Icon(
              _isDeleteMode ? Icons.close : Icons.delete_outline,
              color: _isDeleteMode ? Colors.red : _primary,
            ),
            onPressed: _toggleDeleteMode,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // ── Member header ─────────────────────────────────────
                    if (_memberName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildAvatar(_memberName, size: 42),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00897B),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: bg, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _memberName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _memberType.isNotEmpty
                                        ? '$_memberType · $totalTasks tasks'
                                        : '$totalTasks tasks',
                                    style: GoogleFonts.poppins(
                                        fontSize: 10, color: textSec),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Tab Bar ───────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A2F42)
                            : _borderInner,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: textSec,
                        labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 12),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Mandatory',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                if (_mandatoryTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _buildTabBadge(
                                      _mandatoryTasks.length,
                                      isRed: true),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Available',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                if (_availableTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _buildTabBadge(
                                      _availableTasks.length,
                                      isRed: false),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Section header ────────────────────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tabController.index == 0
                                ? 'Mandatory Tasks'
                                : 'Available Tasks',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A2F42)
                                  : _borderInner,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              '${_tabController.index == 0 ? _mandatoryTasks.length : _availableTasks.length} tasks',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: textSec,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Task lists ────────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTaskList(_mandatoryTasks, isDark,
                              textPrimary, textSec, border),
                          _buildTaskList(_availableTasks, isDark,
                              textPrimary, textSec, border),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          _isDeleteMode ? _buildDeleteModeButtons() : _buildNormalFab(),
    );
  }

  Widget _buildTabBadge(int count, {required bool isRed}) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: isRed ? const Color(0xFFE53935) : _primaryLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final dotColor = _statusDotColor(status);
    final isRejected = status == 'rejected' || status == 'late';
    final isWaiting = status == 'completed';
    final borderCol = isRejected
        ? const Color(0xFFFFCDD2)
        : isWaiting
            ? const Color(0xFFBBDEFB)
            : dotColor.withValues(alpha: 0.3);
    final bgCol = isRejected
        ? const Color(0xFFFFEBEE)
        : isWaiting
            ? const Color(0xFFE3F2FD)
            : dotColor.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w600, color: dotColor),
      ),
    );
  }

  // ─── Gradient FAB (normal mode) ────────────────────────────────────────────
  Widget _buildNormalFab() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _showAddTaskModal,
          child: Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildDeleteModeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteSelectedTasks,
              icon: Icon(Icons.delete, color: Colors.white),
              label: Text('Delete Selected',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskModal() {
    final isDark = context.read<ThemeProvider>().isDark;
    final cardColor = isDark ? _cardDark : Colors.white;
    final textPrimary = isDark ? _textPrimaryDark : _textPrimaryLight;
    String? selectedCategoryId =
        _taskCategories.isNotEmpty ? _taskCategories.first['_id']?.toString() : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('Add New Task',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Task name
              TextField(
                controller: _taskNameController,
                style: GoogleFonts.poppins(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Task Name *',
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondaryLight),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _borderLight)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _primary, width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              TextField(
                controller: _taskDescriptionController,
                style: GoogleFonts.poppins(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle:
                      GoogleFonts.poppins(color: _textSecondaryLight),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _borderLight)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _primary, width: 2)),
                ),
              ),
              // Category picker — only shown when categories are loaded
              if (_taskCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    labelStyle:
                        GoogleFonts.poppins(color: _textSecondaryLight),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _borderLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  dropdownColor: cardColor,
                  items: _taskCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['_id']?.toString(),
                      child: Text(
                        (cat['title'] ?? 'Unknown').toString(),
                        style: GoogleFonts.poppins(
                            color: textPrimary, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCategoryId = v),
                ),
              ],
              // Warning when no categories or email available
              if (_taskCategories.isEmpty || _currentMail.isEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    _taskCategories.isEmpty
                        ? 'No categories available. Ask a parent to create one first.'
                        : 'Could not identify your account. Please refresh.',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.orange[800]),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskNameController.clear();
                _taskDescriptionController.clear();
                Navigator.pop(ctx);
              },
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: _textSecondaryLight)),
            ),
            GuardedElevatedButton(
              onPressed: (_taskCategories.isEmpty || _currentMail.isEmpty)
                  ? null
                  : () async {
                      if (_taskNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Please enter a task name')),
                        );
                        return;
                      }
                      await _addNewTask(selectedCategoryId);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text('Add',
                  style:
                      GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Task List ──────────────────────────────────────────────────────────────
  Widget _buildTaskList(
    List<TaskItem> tasks,
    bool isDark,
    Color textPrimary,
    Color textSec,
    Color border,
  ) {
    final cardColor = isDark ? _cardDark : Colors.white;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt,
                size: 60,
                color:
                    const Color(0xFF4DB6AC).withValues(alpha: 0.45)),
            const SizedBox(height: 16),
            Text('No tasks in this section!',
                style: GoogleFonts.poppins(color: textSec)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
          left: 16, right: 16, top: 8, bottom: 88),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final dotColor = _statusDotColor(task.status);
        final isSelected = _isDeleteMode && task.isSelectedToDelete;

        // Border color based on state
        final cardBorder = task.isWaitingApproval
            ? const Color(0xFF1E88E5)
            : task.isRejected
                ? const Color(0xFFE53935)
                : border;
        final cardBorderWidth =
            (task.isWaitingApproval || task.isRejected) ? 2.0 : 1.0;

        return GestureDetector(
          onTap: () {
            if (_isDeleteMode) {
              setState(
                  () => task.isSelectedToDelete = !task.isSelectedToDelete);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.red.withValues(alpha: 0.08)
                  : cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? Colors.red : cardBorder,
                width: isSelected ? 2 : cardBorderWidth,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ───────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.description,
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: textSec),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (task.deadline != null) ...[
                                Icon(Icons.schedule,
                                    size: 10, color: textSec),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDeadlineShort(task.deadline),
                                  style: GoogleFonts.poppins(
                                      fontSize: 9, color: textSec),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(task.rewardEmoji,
                                  style:
                                      const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                task.rewardLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isDeleteMode)
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color:
                            isSelected ? Colors.red : textSec,
                        size: 22,
                      )
                    else
                      _buildStatusBadge(task.status),
                  ],
                ),

                // ── Progress bar ─────────────────────────────────────
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? const Color(0xFF1E3A4A)
                        : _borderInner,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(dotColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete: ${(task.progress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: dotColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // ── Notes / reason box ───────────────────────────────
                if (task.notes.isNotEmpty && !_isDeleteMode) ...[
                  const SizedBox(height: 8),
                  if (task.isRejected) ...[
                    // Red rejection reason box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFCDD2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejected by parent:',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFC62828),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.notes,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Amber notes box for other states
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note,
                              size: 13, color: Colors.amber[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.notes,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.amber[900]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                // ── Waiting approval info box ────────────────────────
                if (task.isWaitingApproval && !_isDeleteMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top,
                            size: 14,
                            color: Color(0xFF1E88E5)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Submitted for approval — waiting for parent',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF1565C0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Mark Complete button ─────────────────────────────
                if (task.canComplete && !_isDeleteMode) ...[
                  const SizedBox(height: 10),
                  _buildCompleteButton('Mark Complete', task),
                ],

                // ── Mark Complete Again (rejected) ───────────────────
                if (task.isRejected && !_isDeleteMode) ...[
                  const SizedBox(height: 10),
                  _buildCompleteButton('Mark Complete Again', task),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompleteButton(String label, TaskItem task) {
    return GestureDetector(
      onTap: () => _completeTask(task),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
