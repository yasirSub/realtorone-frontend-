import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/activities_api.dart';
import '../../api/user_api.dart';

class DailyTasksWidget extends StatefulWidget {
  final VoidCallback? onTaskUpdated;
  const DailyTasksWidget({super.key, this.onTaskUpdated});

  @override
  State<DailyTasksWidget> createState() => _DailyTasksWidgetState();
}

class _DailyTasksWidgetState extends State<DailyTasksWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  int _completionRate = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await UserApi.getTodayTasks();
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _tasks = List<Map<String, dynamic>>.from(response['tasks'] ?? []);
            _completionRate = response['completion_rate'] ?? 0;
            _totalTasks = response['total'] ?? 0;
            _completedTasks = response['completed'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTask(int id, bool currentStatus) async {
    if (currentStatus) return;

    // Optimistic UI Update
    final originalTasks = List<Map<String, dynamic>>.from(_tasks);
    final originalCompleted = _completedTasks;
    final originalRate = _completionRate;

    setState(() {
      final taskIndex = _tasks.indexWhere((t) => t['id'] == id);
      if (taskIndex != -1) {
        _tasks[taskIndex]['is_completed'] = true;
        _completedTasks++;
        _completionRate = ((_completedTasks / _totalTasks) * 100).round();
      }
    });

    try {
      final response = await UserApi.completeTask(id);
      if (response['success'] == true) {
        // Refresh silently to sync with server
        final freshData = await UserApi.getTodayTasks();
        if (mounted && freshData['success'] == true) {
          setState(() {
            _tasks = List<Map<String, dynamic>>.from(freshData['tasks'] ?? []);
            _completionRate = freshData['completion_rate'] ?? 0;
            _totalTasks = freshData['total'] ?? 0;
            _completedTasks = freshData['completed'] ?? 0;
          });
        }
        widget.onTaskUpdated?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF4ECDC4)),
                  SizedBox(width: 10),
                  Text(
                    'Task Completed!',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Rollback
        setState(() {
          _tasks = originalTasks;
          _completedTasks = originalCompleted;
          _completionRate = originalRate;
        });
      }
    } catch (e) {
      debugPrint('Error completing task: $e');
      // Rollback
      setState(() {
        _tasks = originalTasks;
        _completedTasks = originalCompleted;
        _completionRate = originalRate;
      });
    }
  }

  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ADD TASK',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add a new task to today\'s priorities',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(context);

                    setState(() => _isLoading = true);
                    try {
                      final now = DateTime.now().toIso8601String();
                      final response = await ActivitiesApi.createActivity(
                        title: title,
                        type: 'custom_task',
                        category: 'task',
                        durationMinutes: 30,
                        scheduledAt: now,
                      );
                      if (response['success'] == true) {
                        _loadTasks();
                        widget.onTaskUpdated?.call();
                      }
                    } catch (e) {
                      debugPrint('Error creating task: $e');
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ADD TASK',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE PROGRESS',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_completedTasks/$_totalTasks DONE',
                          style: const TextStyle(
                            color: Color(0xFF4ECDC4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_completionRate%',
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showAddTaskSheet,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _completionRate / 100.0,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(
                _completionRate >= 100
                    ? const Color(0xFF10B981)
                    : const Color(0xFF667eea),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Task list
          if (_isLoading)
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF667eea)),
              ),
            )
          else if (_tasks.isEmpty)
            _buildEmptyState(isDark)
          else
            ..._tasks.asMap().entries.map((entry) {
              final i = entry.key;
              final task = entry.value;
              return _buildTaskItem(task, isDark)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * i))
                  .slideX(begin: 0.05);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 48,
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 14),
          Text(
            'No tasks for today',
            style: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showAddTaskSheet,
            child: const Text(
              'Tap + to add your first task',
              style: TextStyle(
                color: Color(0xFF667eea),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, bool isDark) {
    final bool isCompleted = task['is_completed'] ?? false;
    final String title = task['title'] ?? 'Untitled';
    final int id = task['id'] ?? 0;
    final String type = task['type'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? (isDark
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFF10B981).withValues(alpha: 0.05))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.task_alt_rounded,
                color: isCompleted ? const Color(0xFF10B981) : Colors.grey[500],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isCompleted
                          ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (type.isNotEmpty)
                    Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
            if (!isCompleted)
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Logic for NO - for now we just show a snackbar or ignore
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task deferred')),
                      );
                    },
                    child: _buildActionButton(
                      'NO',
                      const Color(0xFFEF4444),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleTask(id, isCompleted),
                    child: _buildActionButton(
                      'YES',
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
