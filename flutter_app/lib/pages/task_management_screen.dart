import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Task Management',
              style: GoogleFonts.poppins(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Task Management',
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black87,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 11),
              isScrollable: true,
              tabs: [
                const Tab(text: 'My Tasks'),
                const Tab(text: 'Assign Task'),
                const Tab(text: 'Templates'),
                if (_isParent) const Tab(text: 'Approvals'),
                if (_isParent) const Tab(text: 'History'),
              ],
            ),
          ),

          // Tab Views
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
            color: Colors.grey.withOpacity(0.15),
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
              color: statusColor.withOpacity(0.1),
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.star, color: Colors.amber[600], size: 18),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reward',
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
                                    Text('+$assignedPoints pts',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700])),
                                  ],
                                ),
                              ],
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
                              color: _getPriorityColor(priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getPriorityColor(priority).withOpacity(0.3)),
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
                        backgroundColor: Colors.green[600],
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
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.green[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Great job! You earned +$assignedPoints points!',
                            style: GoogleFonts.poppins(
                              fontSize: 12, 
                              color: Colors.green[700],
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 10),
            Text('Complete Task', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you have completed this task? It will be sent to parent for approval.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: Text('Yes, I completed it',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.completeTask(taskDetailId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Task marked as completed! Waiting for approval.'),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isParent
                        ? 'As a parent, your task assignments are automatically approved.'
                        : 'Your task assignments will need parent approval.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.blue[700]),
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
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          Text('Quick Stats',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800])),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
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
                  Icon(Icons.add_task, color: Colors.green[700]),
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
                ElevatedButton(
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
                      backgroundColor: Colors.green[700]),
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
                  onPressed: _showCreateTaskTemplateDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text('Create Task Template',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMandatory
                                  ? Colors.red[50]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMandatory
                                  ? Icons.priority_high
                                  : Icons.task_alt,
                              color: isMandatory
                                  ? Colors.red[700]
                                  : Colors.green[700],
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
                                            fontSize: 15),
                                      ),
                                    ),
                                    if (isMandatory)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text('Mandatory',
                                            style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                if (task['description']?.isNotEmpty ?? false)
                                  Text(
                                    task['description'],
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[600]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.folder_outlined,
                                        size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      category?['title'] ?? 'No Category',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: Colors.grey[500]),
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

  void _showCreateTaskTemplateDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedCategoryId;
    bool isMandatory = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Create Task Template',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Title *',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Clean Room',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Description',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Task description...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Category *',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        hint: const Text('Select category'),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat['_id'],
                            child: Text(cat['title'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedCategoryId = v),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Checkbox(
                            value: isMandatory,
                            onChanged: (v) =>
                                setDialogState(() => isMandatory = v ?? false),
                            activeColor: Colors.green[700],
                          ),
                          Text('Mandatory Task',
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill required fields')),
                      );
                      return;
                    }

                    try {
                      await _apiService.createTask({
                        'title': titleController.text,
                        'description': descriptionController.text,
                        'category_id': selectedCategoryId,
                        'is_mandatory': isMandatory,
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task template created!'),
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
                      backgroundColor: Colors.green[700]),
                  child: Text('Create',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
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
            ElevatedButton(
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
                  ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black87,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 12),
              tabs: [
                Tab(
                    text:
                        'Assignment Requests (${_pendingAssignments.length})'),
                Tab(
                    text:
                        'Completion Requests (${_tasksWaitingApproval.length})'),
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
    if (_pendingAssignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No pending assignment requests',
                style: GoogleFonts.poppins(color: Colors.grey)),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.pending_actions,
                        color: Colors.orange[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task?['title'] ?? 'Unknown Task',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          'Assigned by: ${assignedBy?['username'] ?? assignedBy ?? 'Unknown'}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Assign To',
                        assignedTo?['username'] ?? assignedTo ?? 'Unknown'),
                    _buildInfoRow(Icons.star, 'Reward Points',
                        '${assignment['assigned_points']} pts'),
                    _buildInfoRow(Icons.remove_circle_outline, 'Penalty',
                        '${assignment['penalty_points'] ?? 0} pts'),
                    _buildInfoRow(Icons.calendar_today, 'Deadline',
                        _formatDeadline(assignment['deadline'])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _approveAssignment(assignment['_id'], false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[700],
                      ),
                      child: Text('Reject', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _approveAssignment(assignment['_id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      child: Text('Approve',
                          style: GoogleFonts.poppins(color: Colors.white)),
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

  Widget _buildTasksWaitingApprovalList() {
    if (_tasksWaitingApproval.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No tasks waiting for approval',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasksWaitingApproval.length,
      itemBuilder: (context, index) {
        final taskDetail = _tasksWaitingApproval[index];
        final task = taskDetail['task_id'];
        final memberMail = taskDetail['member_mail'];
        
        String getMemberName(dynamic email) {
          if (email == null) return 'Unknown';
          if (email is String) return email.split('@').first;
          if (email is Map && email['username'] != null) return email['username'];
          return 'Unknown';
        }
        
        final memberName = getMemberName(memberMail);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.task_alt,
                        color: Colors.blue[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task?['title'] ?? 'Unknown Task',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          'Completed by: $memberName',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+${taskDetail['assigned_points']} pts',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _approveCompletion(taskDetail['_id'], false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[700],
                      ),
                      child: Text('Reject', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _approveCompletion(taskDetail['_id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      child: Text('Approve & Award',
                          style: GoogleFonts.poppins(color: Colors.white)),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 12)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
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

  Future<void> _approveCompletion(String taskDetailId, bool approved) async {
    try {
      await _apiService.approveTaskCompletion(taskDetailId, approved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? 'Task approved! Points awarded.'
              : 'Task completion rejected'),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );
      _loadData();
    } catch (e) {
      // Refresh data to sync with database
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e. Data refreshed - please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
            gradient: LinearGradient(
              colors: [Colors.green[700]!, Colors.green[500]!],
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
                    color: Colors.white.withOpacity(0.2),
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
              return _buildHistoryCard(taskDetail);
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
        color: isSelected ? Colors.green[700] : Colors.grey[200],
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
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey[300],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              color: statusColor.withOpacity(0.1),
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
                        valueColor: Colors.green[700],
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.remove_circle, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Apply Penalty',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Penalty Points',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.remove_circle, color: Colors.red[400]),
                ),
                onChanged: (v) => penaltyPoints = int.tryParse(v) ?? 5,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
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
            ElevatedButton(
              onPressed: () async {
                try {
                  await _apiService.applyPenalty(
                    taskDetailId,
                    penaltyPoints,
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Penalty of $penaltyPoints pts applied'),
                      backgroundColor: Colors.orange,
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              child: Text('Apply Penalty',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
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
