import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/theme/theme_provider.dart';
import 'create_task_screen.dart';
import '../core/widgets/guarded_button.dart';

// ─── Teal theme constants ────────────────────────────────────────────────────
const _tmPrimary = Color(0xFF00897B);
const _tmPrimaryLight = Color(0xFF00ACC1);
const _tmBgLight = Color(0xFFE8F5F5);
const _tmBgDark = Color(0xFF0A1628);
const _tmCardDark = Color(0xFF122030);
const _tmBorderLight = Color(0xFFB2DFDB);
const _tmBorderDark = Color(0xFF1E3A4A);
const _tmBorderInner = Color(0xFFE0F2F1);
const _tmTextPrimaryLight = Color(0xFF00352E);
const _tmTextPrimaryDark = Color(0xFFE0F2F1);
const _tmTextSecLight = Color(0xFF4DB6AC);
const _tmTextSecDark = Color(0xFF80CBC4);

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isParent = false;

  // Data lists
  List<dynamic> _taskTemplates = [];
  List<dynamic> _categories = [];
  List<dynamic> _members = [];
  List<dynamic> _pendingAssignments = [];
  List<dynamic> _taskHistory = [];
  List<dynamic> _tasksWaitingApproval = [];
  List<dynamic> _myTasks = []; // Current member's assigned tasks

  // Tracks just-approved completion results for the success card
  final Map<String, Map<String, dynamic>> _justApproved = {};

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final isParent = await _apiService.isParent();
    setState(() {
      _isParent = isParent;
      // Parent has 5 tabs, others have 3 (My Tasks added for everyone)
      _tabController = TabController(length: isParent ? 5 : 3, vsync: this);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load data individually to handle partial failures
      try {
        _taskTemplates = await _apiService.getAllTasks();
      } catch (e) {
        print('Failed to load tasks: $e');
        _taskTemplates = [];
      }

      try {
        _categories = await _apiService.getAllTaskCategories();
      } catch (e) {
        print('Failed to load categories: $e');
        _categories = [];
      }

      try {
        _members = await _apiService.getAllMembers();
      } catch (e) {
        print('Failed to load members: $e');
        _members = [];
      }

      try {
        _taskHistory = await _apiService.getAllAssignedTasks();
      } catch (e) {
        print('Failed to load assigned tasks: $e');
        _taskHistory = [];
      }

      // Load current member's tasks
      try {
        _myTasks = await _apiService.getMyTasks();
      } catch (e) {
        print('Failed to load my tasks: $e');
        _myTasks = [];
      }

      // Parent-only data
      if (_isParent) {
        try {
          _pendingAssignments = await _apiService.getPendingAssignments();
        } catch (e) {
          print('Failed to load pending assignments: $e');
          _pendingAssignments = [];
        }

        try {
          _tasksWaitingApproval = await _apiService.getTasksWaitingApproval();
        } catch (e) {
          print('Failed to load tasks waiting approval: $e');
          _tasksWaitingApproval = [];
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Avatar helpers ──────────────────────────────────────────────────────
  Map<String, Color> _getAvatarColors(String name) {
    const sets = [
      {'bg': Color(0xFFE3F2FD), 'text': Color(0xFF1565C0), 'border': Color(0xFF90CAF9)},
      {'bg': Color(0xFFFFF3E0), 'text': Color(0xFFE65100), 'border': Color(0xFFFFCC80)},
      {'bg': Color(0xFFFCE4EC), 'text': Color(0xFFC2185B), 'border': Color(0xFFF48FB1)},
      {'bg': Color(0xFFE0F2F1), 'text': Color(0xFF00695C), 'border': Color(0xFF80CBC4)},
      {'bg': Color(0xFFF3E5F5), 'text': Color(0xFF7B1FA2), 'border': Color(0xFFCE93D8)},
      {'bg': Color(0xFFE8F5F5), 'text': Color(0xFF00897B), 'border': Color(0xFFB2DFDB)},
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % sets.length;
    return sets[idx];
  }

  Widget _buildAvatar(String name, {double size = 36}) {
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final c = _getAvatarColors(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c['bg'],
        shape: BoxShape.circle,
        border: Border.all(color: c['border']!, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
              fontSize: size * 0.33,
              fontWeight: FontWeight.w700,
              color: c['text']),
        ),
      ),
    );
  }

  Widget _buildAvatarWithDot(String name, {double size = 36}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildAvatar(name, size: size),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF00897B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? _tmBgDark : _tmBgLight;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
    final border = isDark ? _tmBorderDark : _tmBorderLight;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Manage Tasks',
              style: GoogleFonts.poppins(
                  color: textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: _tmPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _tmPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Manage Tasks',
            style: GoogleFonts.poppins(
                color: textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _tmPrimary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              // ── Scrollable tab pills ──────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2F42) : _tmBorderInner,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: _tmPrimary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: textSec,
                  labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 11),
                  dividerColor: Colors.transparent,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    const Tab(text: 'My Tasks'),
                    const Tab(text: 'Assign Task'),
                    const Tab(text: 'Templates'),
                    if (_isParent)
                      Tab(
                        child: Row(children: [
                          const Text('Approvals'),
                          if (_tasksWaitingApproval.isNotEmpty ||
                              _pendingAssignments.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_tasksWaitingApproval.length + _pendingAssignments.length}',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    if (_isParent) const Tab(text: 'History'),
                  ],
                ),
              ),

              // ── Tab views ─────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyTasksTab(),
                    _buildAssignTaskTab(),
                    _buildTaskTemplatesTab(),
                    if (_isParent) _buildApprovalsTab(),
                    if (_isParent) _buildHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TAB 1: MY TASKS ====================
  Widget _buildMyTasksTab() {
    // Filter tasks by status
    final pendingApprovalTasks = _myTasks.where((t) => 
      t['assignment_approved'] == false).toList();
    final activeTasks = _myTasks.where((t) => 
      t['assignment_approved'] == true &&
      (t['status'] == 'assigned' || t['status'] == 'in_progress')).toList();
    final completedTasks = _myTasks.where((t) => 
      t['assignment_approved'] == true && t['status'] == 'completed').toList();
    final approvedTasks = _myTasks.where((t) => 
      t['assignment_approved'] == true && t['status'] == 'approved').toList();
    final rejectedTasks = _myTasks.where((t) => 
      t['assignment_approved'] == true &&
      (t['status'] == 'rejected' || t['status'] == 'late')).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: _myTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tasks assigned to you yet',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tasks assigned to you will appear here',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMyTaskStatCard(
                          'Pending',
                          '${pendingApprovalTasks.length}',
                          Icons.schedule,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMyTaskStatCard(
                          'Active',
                          '${activeTasks.length}',
                          Icons.pending_actions,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMyTaskStatCard(
                          'Done',
                          '${approvedTasks.length}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Pending Assignment Approval Section
                  if (pendingApprovalTasks.isNotEmpty) ...[
                    _buildSectionHeader('Pending Assignment Approval', Icons.schedule, Colors.purple),
                    const SizedBox(height: 12),
                    ...pendingApprovalTasks.map((task) => _buildMyTaskCard(task, showComplete: false, isPendingAssignment: true)),
                    const SizedBox(height: 20),
                  ],

                  // Active Tasks Section
                  if (activeTasks.isNotEmpty) ...[
                    _buildSectionHeader('Active Tasks', Icons.assignment, Colors.orange),
                    const SizedBox(height: 12),
                    ...activeTasks.map((task) => _buildMyTaskCard(task)),
                    const SizedBox(height: 20),
                  ],

                  // Waiting Completion Approval Section
                  if (completedTasks.isNotEmpty) ...[
                    _buildSectionHeader('Waiting for Completion Approval', Icons.hourglass_top, Colors.blue),
                    const SizedBox(height: 12),
                    ...completedTasks.map((task) => _buildMyTaskCard(task, showComplete: false)),
                    const SizedBox(height: 20),
                  ],

                  // Approved Tasks Section
                  if (approvedTasks.isNotEmpty) ...[
                    _buildSectionHeader('Completed & Approved', Icons.check_circle, Colors.green),
                    const SizedBox(height: 12),
                    ...approvedTasks.map((task) => _buildMyTaskCard(task, showComplete: false)),
                    const SizedBox(height: 20),
                  ],

                  // Rejected Tasks Section
                  if (rejectedTasks.isNotEmpty) ...[
                    _buildSectionHeader('Rejected / Late', Icons.cancel, Colors.red),
                    const SizedBox(height: 12),
                    ...rejectedTasks.map((task) => _buildMyTaskCard(task, showComplete: false)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMyTaskStatCard(String title, String value, IconData icon, Color color) {
    final isDark = context.read<ThemeProvider>().isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? _tmCardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tmBorderLight),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: isDark ? _tmTextSecDark : _tmTextSecLight),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final isDark = context.read<ThemeProvider>().isDark;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
      ],
    );
  }

  Widget _buildMyTaskCard(Map<String, dynamic> taskDetail, {bool showComplete = true, bool isPendingAssignment = false}) {
    final task = taskDetail['task_id'];
    final category = task?['category_id'];
    final status = taskDetail['status'] ?? 'assigned';
    final assignedPoints = taskDetail['assigned_points'] ?? 0;
    final penaltyPoints = taskDetail['penalty_points'] ?? 0;
    final priority = taskDetail['priority'] ?? 0;
    final deadline = taskDetail['deadline'];
    final notes = taskDetail['notes'] ?? '';
    final isMandatory = task?['is_mandatory'] ?? false;
    final assignmentApproved = taskDetail['assignment_approved'] ?? true;
    final rewardType = (task?['reward_type'] ?? 'points').toString();
    final moneyReward = ((task?['money_reward'] ?? 0) as num).toDouble();

    // Calculate if deadline is near or passed
    bool isDeadlineNear = false;
    bool isDeadlinePassed = false;
    if (deadline != null) {
      try {
        final deadlineDate = DateTime.parse(deadline);
        final now = DateTime.now();
        final diff = deadlineDate.difference(now);
        isDeadlinePassed = diff.isNegative;
        isDeadlineNear = !isDeadlinePassed && diff.inHours < 24;
      } catch (e) {}
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    // Check if assignment is pending approval first
    if (!assignmentApproved || isPendingAssignment) {
      statusColor = Colors.purple;
      statusText = 'PENDING APPROVAL';
      statusIcon = Icons.schedule;
    } else {
      switch (status) {
        case 'approved':
          statusColor = Colors.green;
          statusText = 'APPROVED';
          statusIcon = Icons.check_circle;
          break;
        case 'completed':
          statusColor = Colors.blue;
          statusText = 'AWAITING APPROVAL';
          statusIcon = Icons.hourglass_top;
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusText = 'REJECTED';
          statusIcon = Icons.cancel;
          break;
        case 'late':
          statusColor = Colors.deepOrange;
          statusText = 'LATE';
          statusIcon = Icons.warning;
          break;
        case 'in_progress':
          statusColor = Colors.orange;
          statusText = 'IN PROGRESS';
          statusIcon = Icons.play_circle;
          break;
        default:
          statusColor = Colors.orange;
          statusText = 'TO DO';
          statusIcon = Icons.pending_actions;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task?['title'] ?? 'Unknown Task',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isMandatory)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Mandatory',
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      if (category != null)
                        Text(
                          category['title'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (task?['description']?.isNotEmpty ?? false) ...[
                  Text(
                    task['description'],
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Points and Deadline Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Points Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildRewardChip(
                              rewardType: rewardType,
                              assignedPoints: assignedPoints,
                              moneyReward: moneyReward,
                            ),
                          ),
                          if (penaltyPoints > 0)
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.remove_circle, color: Colors.red[400], size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Penalty',
                                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
                                      Text('-$penaltyPoints pts',
                                          style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[700])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Deadline and Priority Row
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDeadlinePassed 
                                        ? Colors.red[50] 
                                        : isDeadlineNear 
                                            ? Colors.orange[50] 
                                            : Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: isDeadlinePassed 
                                        ? Colors.red[700] 
                                        : isDeadlineNear 
                                            ? Colors.orange[700] 
                                            : Colors.blue[700],
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deadline',
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
                                    Text(
                                      _formatDeadlineDetailed(deadline),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDeadlinePassed 
                                            ? Colors.red[700] 
                                            : isDeadlineNear 
                                                ? Colors.orange[700] 
                                                : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getPriorityColor(priority).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 14, color: _getPriorityColor(priority)),
                                const SizedBox(width: 4),
                                Text(
                                  _getPriorityText(priority),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getPriorityColor(priority),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notes if any
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Complete Button - only for active tasks with approved assignment
                if (showComplete && assignmentApproved && (status == 'assigned' || status == 'in_progress')) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _markTaskComplete(taskDetail['_id']),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text('Mark as Completed',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                // Pending assignment approval message
                if (!assignmentApproved || isPendingAssignment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.purple[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waiting for parent to approve this task assignment',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.purple[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Info message for waiting completion approval
                if (assignmentApproved && status == 'completed') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waiting for parent to approve your completion',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Approved message
                if (assignmentApproved && status == 'approved') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB2DFDB)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.celebration, color: const Color(0xFF00897B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _buildRewardCelebrationText(
                              rewardType: rewardType,
                              assignedPoints: assignedPoints,
                              moneyReward: moneyReward,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 12, 
                              color: const Color(0xFF00897B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Rejected message
                if (assignmentApproved && status == 'rejected') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This task was rejected. Please check the notes for details.',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markTaskComplete(String taskDetailId) async {
    final taskDetail = _myTasks.firstWhere(
      (t) => t['_id'] == taskDetailId,
      orElse: () => <String, dynamic>{},
    );
    final task = taskDetail['task_id'];
    final rewardType = (task?['reward_type'] ?? 'points').toString();
    final assignedPoints = ((taskDetail['assigned_points'] ?? 0) as num).toDouble();
    final moneyReward = ((task?['money_reward'] ?? 0) as num).toDouble();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: const Color(0xFF00897B)),
            const SizedBox(width: 10),
            Text('Complete Task', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you have completed this task?',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB2DFDB)),
              ),
              child: Text(
                _buildRewardSummaryLine(
                  rewardType: rewardType,
                  points: assignedPoints,
                  money: moneyReward,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00897B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
            child: Text('Yes, I completed it',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await _apiService.completeTask(taskDetailId);
        final rewardSummary = response['data']?['rewardSummary'];
        if (mounted && rewardSummary is Map<String, dynamic>) {
          await _showRewardAppliedDialog(rewardSummary);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Task completed and rewards added!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildRewardChip({
    required String rewardType,
    required int assignedPoints,
    required double moneyReward,
  }) {
    String title = 'Reward';
    String value = '+$assignedPoints pts';
    IconData icon = Icons.star;
    Color iconColor = Colors.amber[700]!;

    if (rewardType == 'money') {
      title = 'Money Reward';
      value = '+${moneyReward.toStringAsFixed(2)} EGP';
      icon = Icons.payments;
      iconColor = Colors.teal;
    } else if (rewardType == 'both') {
      title = 'Mixed Reward';
      value = '+$assignedPoints pts + ${moneyReward.toStringAsFixed(2)} EGP';
      icon = Icons.auto_awesome;
      iconColor = Colors.deepPurple;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00897B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildRewardCelebrationText({
    required String rewardType,
    required int assignedPoints,
    required double moneyReward,
  }) {
    if (rewardType == 'money') {
      return 'Great job! You earned +${moneyReward.toStringAsFixed(2)} EGP!';
    }
    if (rewardType == 'both') {
      return 'Great job! You earned +$assignedPoints points and +${moneyReward.toStringAsFixed(2)} EGP!';
    }
    return 'Great job! You earned +$assignedPoints points!';
  }

  String _buildRewardSummaryLine({
    required String rewardType,
    required double points,
    required double money,
  }) {
    if (rewardType == 'money') {
      return 'Reward on completion: ${money.toStringAsFixed(2)} EGP';
    }
    if (rewardType == 'both') {
      return 'Reward on completion: ${points.toStringAsFixed(0)} pts + ${money.toStringAsFixed(2)} EGP';
    }
    return 'Reward on completion: ${points.toStringAsFixed(0)} pts';
  }

  Future<void> _showRewardAppliedDialog(Map<String, dynamic> rewardSummary) async {
    final points = ((rewardSummary['points_awarded'] ?? 0) as num).toDouble();
    final money = ((rewardSummary['money_awarded'] ?? 0) as num).toDouble();
    final type = (rewardSummary['reward_type'] ?? 'points').toString();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Rewards Added', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (type == 'points' || type == 'both')
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0.8, end: 1),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(scale: value, child: child),
                    child: Column(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 30)),
                        Text('+${points.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (type == 'both') const SizedBox(width: 20),
                if (type == 'money' || type == 'both')
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween(begin: 0.8, end: 1),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(scale: value, child: child),
                    child: Column(
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 30)),
                        Text('+${money.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _buildRewardSummaryLine(rewardType: type, points: points, money: money),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Nice!', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return Colors.red;
      case 2: return Colors.orange;
      case 1: return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _formatDeadlineDetailed(String? deadline) {
    if (deadline == null) return 'No deadline';
    try {
      final date = DateTime.parse(deadline);
      final now = DateTime.now();
      final diff = date.difference(now);
      
      String timeStr = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      
      if (diff.isNegative) {
        return '$timeStr (Overdue)';
      } else if (diff.inHours < 24) {
        return '$timeStr (${diff.inHours}h left)';
      } else if (diff.inDays < 7) {
        return '$timeStr (${diff.inDays}d left)';
      }
      return timeStr;
    } catch (e) {
      return deadline;
    }
  }

  // ==================== TAB 2: ASSIGN TASK ====================
  Widget _buildAssignTaskTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _tmBorderInner,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tmBorderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _tmPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isParent
                        ? 'As a parent, your task assignments are automatically approved.'
                        : 'Your task assignments will need parent approval.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _tmPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Assign Task Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAssignTaskDialog,
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: Text('Assign New Task',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tmPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: _tmPrimary.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          Text('Quick Stats',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _tmTextPrimaryLight)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Task Templates',
                  '${_taskTemplates.length}',
                  Icons.task_alt,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Categories',
                  '${_categories.length}',
                  Icons.category,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Members',
                  '${_members.length}',
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Assigned',
                  '${_taskHistory.length}',
                  Icons.assignment,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final isDark = context.read<ThemeProvider>().isDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _tmCardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _tmBorderDark : _tmBorderLight),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? _tmTextSecDark : _tmTextSecLight),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ==================== ASSIGN TASK DIALOG ====================
  void _showAssignTaskDialog() {
    String? selectedTaskId;
    String? selectedMemberMail;
    int assignedPoints = 10;
    int penaltyPoints = 0;
    int priority = 0;
    DateTime deadline = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.add_task, color: const Color(0xFF00897B)),
                  const SizedBox(width: 8),
                  Text('Assign Task', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Task Template
                      Text('Select Task *',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedTaskId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        hint: const Text('Choose a task'),
                        items: _taskTemplates.map((task) {
                          return DropdownMenuItem<String>(
                            value: task['_id'],
                            child: Text(task['title'] ?? 'Unknown',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedTaskId = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Select Member
                      Text('Assign To *',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedMemberMail,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        hint: const Text('Choose a member'),
                        items: _members.map((member) {
                          return DropdownMenuItem<String>(
                            value: member['mail'],
                            child: Text(
                                '${member['username']} (${member['mail']})',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedMemberMail = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Deadline
                      Text('Deadline *',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: deadline,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(deadline),
                            );
                            if (time != null) {
                              setDialogState(() {
                                deadline = DateTime(date.year, date.month,
                                    date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: Colors.grey[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${deadline.day}/${deadline.month}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Points Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reward Points *',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: assignedPoints.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    prefixIcon: Icon(Icons.star,
                                        color: Colors.amber[600]),
                                  ),
                                  onChanged: (v) =>
                                      assignedPoints = int.tryParse(v) ?? 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Penalty Points',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: penaltyPoints.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    prefixIcon: Icon(Icons.remove_circle,
                                        color: Colors.red[400]),
                                  ),
                                  onChanged: (v) =>
                                      penaltyPoints = int.tryParse(v) ?? 0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Priority
                      Text('Priority',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: priority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Normal')),
                          DropdownMenuItem(value: 1, child: Text('Medium')),
                          DropdownMenuItem(value: 2, child: Text('High')),
                          DropdownMenuItem(value: 3, child: Text('Urgent')),
                        ],
                        onChanged: (v) => setDialogState(() => priority = v ?? 0),
                      ),

                      if (!_isParent) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This assignment needs parent approval',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.orange[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                GuardedElevatedButton(
                  onPressed: () async {
                    if (selectedTaskId == null || selectedMemberMail == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please select task and member')),
                      );
                      return;
                    }

                    try {
                      await _apiService.assignTask({
                        'task_id': selectedTaskId,
                        'member_mail': selectedMemberMail,
                        'assigned_points': assignedPoints,
                        'penalty_points': penaltyPoints,
                        'deadline': deadline.toIso8601String(),
                        'priority': priority,
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isParent
                              ? 'Task assigned successfully!'
                              : 'Task assigned! Waiting for parent approval.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B)),
                  child: Text('Assign',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== TAB 2: TASK TEMPLATES ====================
  Widget _buildTaskTemplatesTab() {
    return Column(
      children: [
        // Create Task Template Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openCreateTaskScreen,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text('Create Task Template',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tmPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCreateCategoryDialog,
                icon: const Icon(Icons.category, color: Colors.white),
                label: Text('+ Category',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Task Templates List
        Expanded(
          child: _taskTemplates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No task templates yet',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                      Text('Create one to start assigning tasks',
                          style: GoogleFonts.poppins(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _taskTemplates.length,
                  itemBuilder: (context, index) {
                    final task = _taskTemplates[index];
                    final category = task['category_id'];
                    final isMandatory = task['is_mandatory'] ?? false;
                    final templateRewardType = (task['reward_type'] ?? 'points').toString();
                    final templateMoneyReward = ((task['money_reward'] ?? 0) as num).toDouble();

                    final isDark = context.read<ThemeProvider>().isDark;
                    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
                    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? _tmCardDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? _tmBorderDark : _tmBorderLight),
                        boxShadow: isDark
                            ? []
                            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isMandatory
                                  ? const Color(0xFFFFEBEE)
                                  : _tmBorderInner,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMandatory
                                  ? Icons.priority_high
                                  : Icons.task_alt,
                              color: isMandatory
                                  ? const Color(0xFFC62828)
                                  : _tmPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task['title'] ?? 'Unknown',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: textPrimary),
                                      ),
                                    ),
                                    if (isMandatory)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text('Mandatory',
                                            style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                color: const Color(0xFFC62828),
                                                fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                if (task['description']?.isNotEmpty ?? false)
                                  Text(
                                    task['description'],
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: textSec),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.folder_outlined,
                                        size: 13, color: textSec),
                                    const SizedBox(width: 4),
                                    Text(
                                      category?['title'] ?? 'No Category',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: textSec),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      templateRewardType == 'money'
                                          ? '💰'
                                          : templateRewardType == 'both'
                                              ? '⭐💰'
                                              : '⭐',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      templateRewardType == 'money'
                                          ? '${templateMoneyReward.toStringAsFixed(2)} EGP'
                                          : templateRewardType == 'both'
                                              ? '${templateMoneyReward.toStringAsFixed(2)} EGP + pts'
                                              : 'Points on assignment',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: _tmPrimary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_isParent)
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red[400]),
                              onPressed: () => _deleteTask(task['_id']),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openCreateTaskScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(categories: _categories),
      ),
    );

    if (created == true) {
      _loadData();
    }
  }

  void _showCreateCategoryDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Create Category',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            GuardedElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter category name')),
                  );
                  return;
                }

                try {
                  await _apiService.createTaskCategory({
                    'title': titleController.text,
                    'description': descriptionController.text,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category created!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
              child: Text('Create',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Template'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTask(taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Task deleted'), backgroundColor: Colors.green),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== TAB 3: APPROVALS (Parent Only) ====================
  Widget _buildApprovalsTab() {
    final isDark = context.read<ThemeProvider>().isDark;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2F42) : _tmBorderInner,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? _tmBorderDark : _tmBorderLight),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: _tmPrimary,
                borderRadius: BorderRadius.circular(17),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? _tmTextSecDark : _tmTextSecLight,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Assignments (${_pendingAssignments.length})'),
                Tab(text: 'Completions (${_tasksWaitingApproval.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingAssignmentsList(),
                _buildTasksWaitingApprovalList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssignmentsList() {
    final isDark = context.read<ThemeProvider>().isDark;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
    final cardColor = isDark ? _tmCardDark : Colors.white;
    final borderColor = isDark ? _tmBorderDark : _tmBorderLight;

    if (_pendingAssignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 60, color: Color(0xFF80CBC4)),
            const SizedBox(height: 16),
            Text('No pending assignment requests',
                style: GoogleFonts.poppins(color: textSec)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _pendingAssignments[index];
        final task = assignment['task_id'];
        final assignedTo = assignment['member_mail'];
        final assignedBy = assignment['assigned_by'];
        final memberName = assignedTo?['username'] ?? (assignedTo is String ? assignedTo.split('@').first : 'Unknown');
        final byName = assignedBy?['username'] ?? (assignedBy is String ? assignedBy.split('@').first : 'Unknown');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              _buildAvatarWithDot(memberName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task?['title'] ?? 'Unknown Task',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
                    Text('To: $memberName · By: $byName',
                        style: GoogleFonts.poppins(fontSize: 10, color: textSec)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFFB8C00)),
                      const SizedBox(width: 3),
                      Text('${assignment['assigned_points']} pts',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _tmPrimary)),
                      const SizedBox(width: 10),
                      Icon(Icons.schedule, size: 12, color: textSec),
                      const SizedBox(width: 3),
                      Text(_formatDeadline(assignment['deadline']),
                          style: GoogleFonts.poppins(fontSize: 11, color: textSec)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ✓ / ✕ icon buttons
              _buildApproveBtn(() => _approveAssignment(assignment['_id'], true)),
              const SizedBox(width: 6),
              _buildRejectBtn(() => _approveAssignment(assignment['_id'], false)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasksWaitingApprovalList() {
    final isDark = context.read<ThemeProvider>().isDark;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
    final cardColor = isDark ? _tmCardDark : Colors.white;
    final borderColor = isDark ? _tmBorderDark : _tmBorderLight;

    if (_tasksWaitingApproval.isEmpty && _justApproved.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, size: 60, color: Color(0xFF80CBC4)),
            const SizedBox(height: 16),
            Text('All caught up!',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            const SizedBox(height: 4),
            Text('No tasks waiting for approval',
                style: GoogleFonts.poppins(fontSize: 12, color: textSec)),
          ],
        ),
      );
    }

    // Build the list: pending tasks + already-approved success cards
    final allIds = {
      ..._tasksWaitingApproval.map((t) => t['_id'].toString()),
      ..._justApproved.keys,
    }.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allIds.length,
      itemBuilder: (context, index) {
        final id = allIds[index];

        // Show success card for just-approved tasks
        if (_justApproved.containsKey(id)) {
          final result = _justApproved[id]!;
          return _buildApprovalSuccessCard(
            result['member_name'] as String,
            result['points_awarded'] as int,
            result['new_total'] as int,
            isDark,
          );
        }

        final taskDetail = _tasksWaitingApproval
            .firstWhere((t) => t['_id'].toString() == id,
                orElse: () => <String, dynamic>{});
        if ((taskDetail as Map).isEmpty) return const SizedBox.shrink();

        final task = taskDetail['task_id'];
        final memberMail = taskDetail['member_mail'];
        final assignedPoints = taskDetail['assigned_points'] ?? 0;
        final completedAt = taskDetail['completed_at'];

        String getMemberName(dynamic email) {
          if (email == null) return 'Unknown';
          if (email is String) return email.split('@').first;
          if (email is Map && email['username'] != null) {
            return email['username'].toString();
          }
          return 'Unknown';
        }

        String formatSubmitted(dynamic dt) {
          if (dt == null) return 'Just now';
          try {
            final date = DateTime.parse(dt.toString());
            final diff = DateTime.now().difference(date);
            if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
            if (diff.inHours < 24) return '${diff.inHours}h ago';
            return '${date.day}/${date.month}/${date.year}';
          } catch (_) {
            return 'Recently';
          }
        }

        final memberName = getMemberName(memberMail);
        final submittedLabel = formatSubmitted(completedAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            children: [
              // ── Card header: avatar + info + points ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarWithDot(memberName, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task?['title'] ?? 'Unknown Task',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 11, color: textSec),
                            const SizedBox(width: 4),
                            Text(memberName,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: textSec)),
                            const SizedBox(width: 10),
                            Icon(Icons.schedule,
                                size: 11, color: textSec),
                            const SizedBox(width: 4),
                            Text(submittedLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: textSec)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Points badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _tmBorderLight),
                    ),
                    child: Text(
                      '+$assignedPoints pts',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _tmPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Action buttons ────────────────────────────────────
              Row(
                children: [
                  // Approve — teal gradient
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          _approveCompletion(taskDetail['_id'], true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _tmPrimary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 6),
                            Text('Approve',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Reject — red outlined
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          _showRejectReasonDialog(taskDetail['_id']),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFFCDD2),
                              width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.close,
                                color: Color(0xFFE53935), size: 17),
                            const SizedBox(width: 6),
                            Text('Reject',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFE53935),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                )),
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
      },
    );
  }

  Widget _buildApprovalSuccessCard(
    String memberName,
    int pointsAwarded,
    int newTotal,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A2A1A), const Color(0xFF0A2030)]
              : [const Color(0xFFE8F5F5), const Color(0xFFE0F2F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00897B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Approved!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberName received +$pointsAwarded pts'
                  '${newTotal > 0 ? ' → now $newTotal pts total' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF00897B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00897B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproveBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          shape: BoxShape.circle,
          border: Border.all(color: _tmBorderLight),
        ),
        child: const Icon(Icons.check, color: _tmPrimary, size: 18),
      ),
    );
  }

  Widget _buildRejectBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: const Icon(Icons.close, color: Color(0xFFE53935), size: 18),
      ),
    );
  }


  Future<void> _approveAssignment(String taskDetailId, bool approved) async {
    try {
      await _apiService.approveTaskAssignment(taskDetailId, approved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? 'Assignment approved!'
              : 'Assignment rejected'),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectReasonDialog(String taskDetailId) {
    final reasonController = TextEditingController();
    final isDark = context.read<ThemeProvider>().isDark;
    final cardColor = isDark ? _tmCardDark : Colors.white;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.close, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            Text('Reject Task',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE53935))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason for rejection:',
                style: GoogleFonts.poppins(fontSize: 12, color: textSec)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 12, color: textPrimary),
              decoration: InputDecoration(
                hintText: '"The floor is still dirty, please redo."',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: textSec),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _tmBorderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFE53935), width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: isDark ? _tmTextSecDark : _tmTextSecLight)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              _approveCompletion(
                taskDetailId,
                false,
                rejectionReason: reason.isNotEmpty ? reason : null,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirm Reject',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveCompletion(
    String taskDetailId,
    bool approved, {
    String? rejectionReason,
  }) async {
    try {
      final response = await _apiService.approveTaskCompletion(
        taskDetailId,
        approved,
        notes: rejectionReason,
      );

      if (approved) {
        final rewardSummary = response['data']?['rewardSummary'];
        final pointsAwarded =
            ((rewardSummary?['points_awarded'] ?? 0) as num).toInt();
        final newTotal =
            ((rewardSummary?['point_wallet']?['total_points'] ?? 0) as num)
                .toInt();
        final raw = _tasksWaitingApproval.firstWhere(
          (t) => t['_id'] == taskDetailId,
          orElse: () => <String, dynamic>{},
        );
        final mail = raw['member_mail'];
        final memberName = mail is String ? mail.split('@').first : 'Member';

        setState(() {
          _justApproved[taskDetailId] = {
            'points_awarded': pointsAwarded,
            'new_total': newTotal,
            'member_name': memberName,
          };
        });

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _justApproved.remove(taskDetailId));
            _loadData();
          }
        });
      } else {
        _loadData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved
                ? 'Task approved! Points awarded.'
                : 'Task completion rejected'),
            backgroundColor: approved
                ? const Color(0xFF00897B)
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e. Data refreshed - please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== TAB 5: HISTORY (Parent Only) ====================
  Widget _buildHistoryTab() {
    // Combine all data: approved assignments + pending assignments + task history
    final allTasks = [..._taskHistory];
    
    // Add pending assignments that might not be in task history yet
    for (var pending in _pendingAssignments) {
      final exists = allTasks.any((t) => t['_id'] == pending['_id']);
      if (!exists) {
        // Mark as pending assignment
        pending['_isPendingAssignment'] = true;
        allTasks.add(pending);
      }
    }

    // Sort by creation date (newest first)
    allTasks.sort((a, b) {
      final dateA = a['createdAt'] ?? '';
      final dateB = b['createdAt'] ?? '';
      return dateB.compareTo(dateA);
    });

    if (allTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No task history yet',
                style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('All task assignments and approvals will appear here',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Calculate stats
    final totalAssigned = allTasks.length;
    final approvedCount = allTasks.where((t) => t['status'] == 'approved').length;
    final pendingCount = allTasks.where((t) => 
      t['status'] == 'assigned' || 
      t['status'] == 'in_progress' || 
      t['status'] == 'completed' ||
      t['_isPendingAssignment'] == true).length;
    final rejectedCount = allTasks.where((t) => 
      t['status'] == 'rejected' || t['status'] == 'late').length;
    final pendingAssignmentCount = _pendingAssignments.length;
    final completionApprovalCount = _tasksWaitingApproval.length;

    return Column(
      children: [
        // Summary Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00695C), _tmPrimaryLight],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHistoryStat('Total', '$totalAssigned', Icons.assignment),
                  _buildHistoryStat('Approved', '$approvedCount', Icons.check_circle),
                  _buildHistoryStat('Pending', '$pendingCount', Icons.pending),
                  _buildHistoryStat('Rejected', '$rejectedCount', Icons.cancel),
                ],
              ),
              if (pendingAssignmentCount > 0 || completionApprovalCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$pendingAssignmentCount assignment requests • $completionApprovalCount completion requests',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', allTasks.length, true),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', approvedCount, false, color: Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', pendingCount, false, color: Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', rejectedCount, false, color: Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Task History List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allTasks.length,
            itemBuilder: (context, index) {
              final taskDetail = allTasks[index];
              return _buildCompactCard(taskDetail);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count, bool isSelected, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF00897B) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: color != null ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ─── Compact history card (current) ──────────────────────────────────────
  Widget _buildCompactCard(Map<String, dynamic> taskDetail) {
    final task = taskDetail['task_id'];
    final memberMail = taskDetail['member_mail'];
    final assignedByMail = taskDetail['assigned_by'];
    final status = taskDetail['status'] ?? 'assigned';
    final notes = taskDetail['notes'] ?? '';
    final createdAt = taskDetail['createdAt'];
    final completedAt = taskDetail['completed_at'];
    final approvedAt = taskDetail['approved_at'];
    final penaltyPoints = taskDetail['penalty_points'] ?? 0;
    final assignedPoints = taskDetail['assigned_points'] ?? 0;
    final deadline = taskDetail['deadline'];
    final isPendingAssignment = taskDetail['_isPendingAssignment'] == true ||
        taskDetail['assignment_approved'] == false;

    String getMemberName(dynamic email) {
      if (email == null) return 'Unknown';
      if (email is String) return email.split('@').first;
      if (email is Map && email['username'] != null) {
        return email['username'].toString();
      }
      return 'Unknown';
    }

    final memberName = getMemberName(memberMail);
    final assignedByName = getMemberName(assignedByMail);
    final approvedByName = getMemberName(taskDetail['approved_by']);

    Color statusColor;
    String statusLabel;
    if (isPendingAssignment) {
      statusColor = Colors.purple;
      statusLabel = 'Pending';
    } else {
      switch (status) {
        case 'approved':
          statusColor = const Color(0xFF00BFA5);
          statusLabel = 'Approved';
          break;
        case 'completed':
          statusColor = const Color(0xFF1E88E5);
          statusLabel = 'Waiting';
          break;
        case 'in_progress':
          statusColor = const Color(0xFF1E88E5);
          statusLabel = 'Active';
          break;
        case 'rejected':
          statusColor = const Color(0xFFFF5252);
          statusLabel = 'Rejected';
          break;
        case 'late':
          statusColor = const Color(0xFFFF5252);
          statusLabel = 'Late';
          break;
        default:
          statusColor = const Color(0xFFFB8C00);
          statusLabel = 'Assigned';
      }
    }

    // Late detection
    bool isLate = status == 'late';
    int daysLate = 0;
    if (!isLate && completedAt != null && deadline != null) {
      try {
        final cd = DateTime.parse(completedAt.toString());
        final dl = DateTime.parse(deadline.toString());
        if (cd.isAfter(dl)) {
          isLate = true;
          daysLate = cd.difference(dl).inDays.clamp(1, 999);
        }
      } catch (_) {}
    } else if (isLate && daysLate == 0) {
      daysLate = 1;
    }

    // Date label (newest date shown)
    String dateLabel = '';
    final dateSource = approvedAt ?? completedAt ?? createdAt;
    if (dateSource != null) {
      try {
        final date = DateTime.parse(dateSource.toString());
        final diff = DateTime.now().difference(date);
        if (diff.inDays == 0) {
          dateLabel = 'Today';
        } else if (diff.inDays == 1) {
          dateLabel = 'Yesterday';
        } else if (diff.inDays < 30) {
          dateLabel = '${diff.inDays}d ago';
        } else {
          dateLabel = '${date.day}/${date.month}/${date.year}';
        }
      } catch (_) {}
    }

    final isDark = context.read<ThemeProvider>().isDark;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
    final cardColor = isDark ? _tmCardDark : Colors.white;
    Color cardBorder = isDark ? _tmBorderDark : _tmBorderLight;
    if (status == 'approved') cardBorder = const Color(0xFFB2DFDB);
    if (status == 'rejected' || status == 'late') {
      cardBorder = const Color(0xFFFFCDD2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(memberName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task?['title'] ?? 'Unknown Task',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(memberName,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: textSec)),
                    if (dateLabel.isNotEmpty) ...[
                      Text(' · ',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: textSec)),
                      Text(dateLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: textSec)),
                    ],
                  ],
                ),
                if (isLate) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 11, color: Color(0xFFE53935)),
                      const SizedBox(width: 3),
                      Text(
                        daysLate > 0
                            ? 'Submitted $daysLate day${daysLate > 1 ? "s" : ""} late'
                            : 'Submitted late',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE53935)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'approved'
                            ? const Color(0xFFE0F2F1)
                            : isDark
                                ? const Color(0xFF1A2F42)
                                : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('+$assignedPoints pts',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: status == 'approved'
                                  ? _tmPrimary
                                  : textSec)),
                    ),
                    if (penaltyPoints > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('-$penaltyPoints pts',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE53935))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status badge + 3-dot menu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
              if (_isParent) ...[
                const SizedBox(height: 2),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      color: textSec, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    if (value == 'penalty') {
                      _showPenaltyDialog(taskDetail['_id']);
                    } else if (value == 'details') {
                      _showTaskDetailsDialog(
                        taskDetail,
                        memberName,
                        assignedByName,
                        approvedByName,
                        notes,
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'penalty',
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            color: Color(0xFFE65100), size: 18),
                        const SizedBox(width: 10),
                        Text('Apply Penalty',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFE65100))),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'details',
                      child: Row(children: [
                        const Icon(Icons.visibility_outlined,
                            color: _tmPrimary, size: 18),
                        const SizedBox(width: 10),
                        Text('View Details',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _tmPrimary)),
                      ]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showTaskDetailsDialog(
    Map<String, dynamic> taskDetail,
    String memberName,
    String assignedByName,
    String approvedByName,
    String notes,
  ) {
    final isDark = context.read<ThemeProvider>().isDark;
    final cardColor = isDark ? _tmCardDark : Colors.white;
    final textPrimary = isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
    final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;
    final task = taskDetail['task_id'];
    final status = taskDetail['status'] ?? 'assigned';
    final assignedPoints = taskDetail['assigned_points'] ?? 0;
    final penaltyPoints = taskDetail['penalty_points'] ?? 0;

    Widget detailRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 95,
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: textSec)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? textPrimary)),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 8),
        title: Row(
          children: [
            _buildAvatar(memberName, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task?['title'] ?? 'Task Details',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary)),
                  Text(memberName,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: textSec)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(
                  color: isDark
                      ? _tmBorderDark
                      : _tmBorderLight),
              const SizedBox(height: 6),
              detailRow(
                'Status',
                status.toUpperCase(),
                valueColor: status == 'approved'
                    ? _tmPrimary
                    : (status == 'rejected' || status == 'late')
                        ? Colors.red
                        : textPrimary,
              ),
              detailRow('Assigned By', assignedByName),
              if (approvedByName.isNotEmpty &&
                  status == 'approved')
                detailRow('Approved By', approvedByName,
                    valueColor: _tmPrimary),
              detailRow('Reward', '+$assignedPoints pts'),
              if (penaltyPoints > 0)
                detailRow('Penalty', '-$penaltyPoints pts',
                    valueColor: Colors.red),
              detailRow(
                  'Priority',
                  _getPriorityText(
                      taskDetail['priority'] ?? 0)),
              if (taskDetail['deadline'] != null)
                detailRow(
                    'Deadline',
                    _formatDeadlineDetailed(
                        taskDetail['deadline'].toString())),
              if (taskDetail['createdAt'] != null)
                detailRow(
                    'Assigned',
                    _formatDateTime(
                        taskDetail['createdAt'].toString())),
              if (taskDetail['completed_at'] != null)
                detailRow(
                    'Completed',
                    _formatDateTime(taskDetail['completed_at']
                        .toString())),
              if (taskDetail['approved_at'] != null)
                detailRow(
                    'Reviewed',
                    _formatDateTime(
                        taskDetail['approved_at'].toString())),
              if (task?['category_id'] != null)
                detailRow(
                    'Category',
                    (task['category_id']['title'] ?? '')
                        .toString()),
              if (notes.isNotEmpty) ...[
                Divider(
                    color: isDark
                        ? _tmBorderDark
                        : _tmBorderLight),
                const SizedBox(height: 4),
                Text('Notes',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: textSec)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2F42)
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(notes,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: textPrimary)),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: GoogleFonts.poppins(color: _tmPrimary)),
          ),
        ],
      ),
    );
  }

  // ─── Old detailed card (kept for reference, not used) ─────────────────────
  // ignore: unused_element
  Widget _buildHistoryCard(Map<String, dynamic> taskDetail) {
    final task = taskDetail['task_id'];
    final memberMail = taskDetail['member_mail'];
    final assignedByMail = taskDetail['assigned_by'];
    final status = taskDetail['status'] ?? 'assigned';
    final approvedByMail = taskDetail['approved_by'];
    final notes = taskDetail['notes'] ?? '';
    final createdAt = taskDetail['createdAt'];
    final completedAt = taskDetail['completed_at'];
    final approvedAt = taskDetail['approved_at'];
    final penaltyPoints = taskDetail['penalty_points'] ?? 0;
    final assignedPoints = taskDetail['assigned_points'] ?? 0;
    final isPendingAssignment = taskDetail['_isPendingAssignment'] == true || 
                                 taskDetail['assignment_approved'] == false;
    
    // Extract username from email
    String getMemberName(dynamic email) {
      if (email == null) return 'Unknown';
      if (email is String) return email.split('@').first;
      if (email is Map && email['username'] != null) return email['username'];
      return 'Unknown';
    }
    
    final memberName = getMemberName(memberMail);
    final assignedByName = getMemberName(assignedByMail);
    final approvedByName = getMemberName(approvedByMail);

    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    // Check if this is a pending assignment first
    if (isPendingAssignment) {
      statusColor = Colors.purple;
      statusIcon = Icons.pending_actions;
      statusText = 'AWAITING ASSIGNMENT APPROVAL';
    } else {
      switch (status) {
        case 'approved':
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'APPROVED';
          break;
        case 'completed':
          statusColor = Colors.blue;
          statusIcon = Icons.hourglass_top;
          statusText = 'AWAITING COMPLETION APPROVAL';
          break;
        case 'in_progress':
          statusColor = Colors.orange;
          statusIcon = Icons.play_circle;
          statusText = 'IN PROGRESS';
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
          statusText = 'REJECTED';
          break;
        case 'late':
          statusColor = Colors.deepOrange;
          statusIcon = Icons.warning;
          statusText = 'LATE';
          break;
        default:
          statusColor = Colors.grey;
          statusIcon = Icons.schedule;
          statusText = 'ASSIGNED';
      }
    }

    final isDark = context.read<ThemeProvider>().isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? _tmCardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task?['title'] ?? 'Unknown Task',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // ── 3-dot menu (parent only) ──────────────────────────
                if (_isParent) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white70, size: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (value) {
                      if (value == 'penalty') {
                        _showPenaltyDialog(taskDetail['_id']);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'penalty',
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: Color(0xFFE65100), size: 18),
                            const SizedBox(width: 10),
                            Text('Apply Penalty',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFE65100))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Body with details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assigned to & by
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        Icons.person,
                        'Assigned To',
                        memberName,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        Icons.person_outline,
                        'Assigned By',
                        assignedByName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Points
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        Icons.star,
                        'Reward Points',
                        '+$assignedPoints pts',
                        valueColor: const Color(0xFF00897B),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        Icons.remove_circle_outline,
                        'Penalty Points',
                        penaltyPoints > 0 ? '-$penaltyPoints pts' : '0 pts',
                        valueColor: penaltyPoints > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Deadline & Priority
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        Icons.calendar_today,
                        'Deadline',
                        _formatDeadline(taskDetail['deadline']),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        Icons.flag,
                        'Priority',
                        _getPriorityText(taskDetail['priority'] ?? 0),
                      ),
                    ),
                  ],
                ),

                // Timeline
                if (createdAt != null || completedAt != null || approvedAt != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Timeline', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (createdAt != null)
                    _buildTimelineItem('Assigned', _formatDateTime(createdAt), Colors.blue),
                  if (completedAt != null)
                    _buildTimelineItem('Completed', _formatDateTime(completedAt), Colors.orange),
                  if (approvedAt != null)
                    _buildTimelineItem(
                      status == 'approved' ? 'Approved by $approvedByName' : 'Reviewed',
                      _formatDateTime(approvedAt),
                      status == 'approved' ? Colors.green : Colors.red,
                    ),
                ],

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons for non-finalized tasks
                if (status != 'approved' && status != 'rejected') ...[
                  const SizedBox(height: 12),
                  
                  // Pending assignment approval buttons
                  if (isPendingAssignment) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveAssignment(taskDetail['_id'], true),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text('Approve Assignment', style: GoogleFonts.poppins(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveAssignment(taskDetail['_id'], false),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text('Reject', style: GoogleFonts.poppins(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red[700],
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        if (status == 'completed')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveCompletion(taskDetail['_id'], true),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text('Approve', style: GoogleFonts.poppins(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        if (status == 'completed') const SizedBox(width: 8),
                        if (status == 'completed')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveCompletion(taskDetail['_id'], false),
                              icon: const Icon(Icons.close, size: 18),
                              label: Text('Reject', style: GoogleFonts.poppins(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[100],
                                foregroundColor: Colors.red[700],
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        if (status != 'completed') const Spacer(),
                        TextButton.icon(
                          onPressed: () => _showPenaltyDialog(taskDetail['_id']),
                          icon: Icon(Icons.remove_circle, size: 18, color: Colors.red[400]),
                          label: Text('Apply Penalty', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[400])),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineItem(String event, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(event, style: GoogleFonts.poppins(fontSize: 12)),
          const Spacer(),
          Text(time, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 3: return 'Urgent';
      case 2: return 'High';
      case 1: return 'Medium';
      default: return 'Normal';
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  void _showPenaltyDialog(String taskDetailId) {
    int penaltyPoints = 5;
    final notesController = TextEditingController();
    int currentPoints = 0;
    bool pointsLoaded = false;

    // Resolve member name + mail from history or taskHistory
    final taskDetail = _taskHistory.firstWhere(
      (t) => t['_id'] == taskDetailId,
      orElse: () => <String, dynamic>{},
    );
    final memberMail = (taskDetail as Map).isNotEmpty
        ? (taskDetail['member_mail'] ?? '')
        : '';
    final memberName =
        memberMail is String && memberMail.isNotEmpty
            ? memberMail.split('@').first
            : 'Member';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Fetch current points once
            if (!pointsLoaded) {
              pointsLoaded = true;
              _apiService.getPointsRanking().then((ranking) {
                for (final m in ranking) {
                  final mail = (m['member_mail'] ?? m['mail'] ?? '').toString();
                  if (mail == memberMail) {
                    if (ctx.mounted) {
                      setDialogState(() {
                        currentPoints =
                            ((m['total_points'] ?? 0) as num).toInt();
                      });
                    }
                    break;
                  }
                }
              }).catchError((_) {});
            }

            final afterPenalty =
                (currentPoints - penaltyPoints).clamp(0, 999999);
            final isDark = context.read<ThemeProvider>().isDark;
            final cardColor = isDark ? _tmCardDark : Colors.white;
            final textPrimary =
                isDark ? _tmTextPrimaryDark : _tmTextPrimaryLight;
            final textSec = isDark ? _tmTextSecDark : _tmTextSecLight;

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Apply Penalty',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE65100))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Penalty points input ──────────────────────────
                  Text('Penalty Points',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSec)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1200)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFFCC80)),
                    ),
                    child: TextFormField(
                      initialValue: penaltyPoints.toString(),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: const Color(0xFFE65100)),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        prefixIcon: const Padding(
                          padding:
                              EdgeInsets.only(left: 12, right: 6),
                          child:
                              Text('⭐', style: TextStyle(fontSize: 20)),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0),
                        suffixText: 'pts to deduct',
                        suffixStyle: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFFFB8C00)),
                      ),
                      onChanged: (v) => setDialogState(
                          () => penaltyPoints = int.tryParse(v) ?? 5),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Reason input ──────────────────────────────────
                  Text('Reason',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSec)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1200)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFFCC80)),
                    ),
                    child: TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        hintText: '"Task was submitted 2 days late."',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFFFFB300)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Preview box (dark bg) ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF050A14)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: currentPoints == 0
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4DB6AC)),
                              ),
                              const SizedBox(width: 8),
                              Text('Loading balance...',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF4DB6AC))),
                            ],
                          )
                        : Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('$memberName: $currentPoints',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF4DB6AC),
                                      fontWeight: FontWeight.w500)),
                              const Text(' → ',
                                  style: TextStyle(
                                      color: Color(0xFF4DB6AC),
                                      fontWeight: FontWeight.bold)),
                              Text('$afterPenalty pts',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE53935))),
                              Text(' after penalty',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white54)),
                            ],
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600])),
                ),
                GestureDetector(
                  onTap: () async {
                    try {
                      await _apiService.applyPenalty(
                        taskDetailId,
                        penaltyPoints,
                        notes: notesController.text.isNotEmpty
                            ? notesController.text
                            : null,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Penalty of $penaltyPoints pts applied to $memberName'),
                            backgroundColor:
                                const Color(0xFFE65100),
                          ),
                        );
                        _loadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE65100),
                          Color(0xFFFF8F00)
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Apply Penalty',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDeadline(String? deadline) {
    if (deadline == null) return 'No deadline';
    try {
      final date = DateTime.parse(deadline);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return deadline;
    }
  }
}
