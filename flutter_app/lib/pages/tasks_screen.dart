import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';

// Task Model
class TaskItem {
  String id;
  String title;
  String description;
  bool isMandatory;
  String status;
  int points;
  String? deadline;
  double progress;
  bool isSelectedToDelete;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    this.isMandatory = false,
    this.status = 'assigned',
    this.points = 0,
    this.deadline,
    this.progress = 0.0,
    this.isSelectedToDelete = false,
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
      deadline: json['deadline'],
      progress: progress,
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  late TabController _tabController;
  bool _isDeleteMode = false;
  bool _isLoading = true;

  final _taskNameController = TextEditingController();
  final _taskDescriptionController = TextEditingController();

  List<TaskItem> _mandatoryTasks = [];
  List<TaskItem> _availableTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _apiService.getMyTasks();
      final mandatory = <TaskItem>[];
      final available = <TaskItem>[];
      
      for (var task in tasks) {
        final taskItem = TaskItem.fromJson(task);
        if (taskItem.isMandatory) {
          mandatory.add(taskItem);
        } else {
          available.add(taskItem);
        }
      }
      
      setState(() {
        _mandatoryTasks = mandatory;
        _availableTasks = available;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markTaskComplete(TaskItem task) async {
    try {
      await _apiService.completeTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" marked as complete!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTasks(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskNameController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

  void _deleteSelectedTasks() {
    setState(() {
      _mandatoryTasks.removeWhere((task) => task.isSelectedToDelete);
      _availableTasks.removeWhere((task) => task.isSelectedToDelete);
      _isDeleteMode = false;
    });
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      for (var task in _mandatoryTasks) {
        task.isSelectedToDelete = false;
      }
      for (var task in _availableTasks) {
        task.isSelectedToDelete = false;
      }
    });
  }

  void _addNewTask() {
    if (_taskNameController.text.isNotEmpty) {
      // For now, add locally - in production, call API
      setState(() {
        final newTask = TaskItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _taskNameController.text,
          description: _taskDescriptionController.text,
          isMandatory: _tabController.index == 0,
          progress: 0.0,
        );

        if (_tabController.index == 0) {
          _mandatoryTasks.add(newTask);
        } else {
          _availableTasks.add(newTask);
        }
      });

      _taskNameController.clear();
      _taskDescriptionController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tasks',
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: Icon(
              _isDeleteMode ? Icons.close : Icons.delete_outline,
              color: _isDeleteMode ? Colors.red : Colors.green,
            ),
            onPressed: _toggleDeleteMode,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(16),
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
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Mandatory'),
                Tab(text: 'Available'),
              ],
            ),
          ),

          // Header with count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tabController.index == 0 ? 'Mandatory Tasks' : 'Available Tasks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_tabController.index == 0 ? _mandatoryTasks.length : _availableTasks.length} tasks',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Task Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_mandatoryTasks),
                _buildTaskList(_availableTasks),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isDeleteMode ? _buildDeleteModeButtons() : _buildNormalButtons(),
    );
  }

  Widget _buildNormalButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showAddTaskModal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Task',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteModeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteSelectedTasks,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                'Delete Selected',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add New Task',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskNameController,
                decoration: InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taskDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              onPressed: _addNewTask,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskList(List<TaskItem> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No tasks in this section!",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return GestureDetector(
          onTap: () {
            if (_isDeleteMode) {
              setState(() {
                task.isSelectedToDelete = !task.isSelectedToDelete;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDeleteMode && task.isSelectedToDelete
                  ? Colors.red[50]
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: _isDeleteMode && task.isSelectedToDelete
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            task.description,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDeleteMode)
                      Icon(
                        task.isSelectedToDelete
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: task.isSelectedToDelete ? Colors.red : Colors.grey,
                      )
                    else
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: task.progress >= 1.0
                            ? Icon(Icons.check, color: Colors.green[700], size: 20)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 6,
                  color: Colors.green,
                  backgroundColor: Colors.grey[200],
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete: ${(task.progress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
