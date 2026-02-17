import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/activities_api.dart';
import '../../api/user_api.dart';
import '../../models/activity_model.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/skill_skeleton.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentStreak = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _todayActivities = [];
  List<Map<String, dynamic>> _activityTypes = [];
  final Set<String> _interactedKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
    _loadActivities();
  }

  List<Map<String, dynamic>> _consciousTasks = [];
  List<Map<String, dynamic>> _subconsciousTasks = [];

  Future<void> _loadTasks() async {
    try {
      final response = await UserApi.getTodayTasks();
      if (mounted && response['success'] == true) {
        final List<Map<String, dynamic>> allTasks =
            List<Map<String, dynamic>>.from(response['tasks'] ?? []);

        setState(() {
          // Categorize tasks based on their type mapping
          _consciousTasks = [];
          _subconsciousTasks = [];

          for (var task in allTasks) {
            final typeKey = task['type'];
            // Map types to subconscious, everything else is conscious
            if ([
              'visualization',
              'affirmations',
              'gratitude',
              'mindset_training',
              'audio_reprogramming',
              'webinar',
              'belief_exercise',
              'calm_reset',
              'identity_statement',
              'morning_ritual',
              'custom',
            ].contains(typeKey)) {
              _subconsciousTasks.add(task);
            } else {
              _consciousTasks.add(task);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks in activities page: $e');
    }
  }

  Future<void> _loadActivities() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final activitiesResponse = await ActivitiesApi.getActivities();
      final progressResponse = await ActivitiesApi.getProgress();
      final typesResponse = await ActivitiesApi.getActivityTypes();

      if (mounted) {
        setState(() {
          if (activitiesResponse['success'] == true) {
            _todayActivities = List<Map<String, dynamic>>.from(
              activitiesResponse['data'] ?? [],
            );
            // Sync local state with server
            for (var a in _todayActivities) {
              if (a['type'] != null) _interactedKeys.add(a['type']);
            }
          }
          if (typesResponse['success'] == true) {
            _activityTypes = List<Map<String, dynamic>>.from(
              typesResponse['data'] ?? [],
            );
            debugPrint('Activity Types Loaded: ${_activityTypes.length}');
            debugPrint(
              'Conscious Types: ${_activityTypes.where((t) => t['category'] == 'conscious').length}',
            );
          }
          if (progressResponse['success'] == true) {
            _currentStreak = progressResponse['data']['current_streak'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActivityComplete(
    int activityId,
    bool currentStatus,
  ) async {
    if (currentStatus) return;

    // Optimistic Update
    if (mounted) {
      setState(() {
        final index = _todayActivities.indexWhere((a) => a['id'] == activityId);
        if (index != -1) {
          _todayActivities[index]['is_completed'] = 1; // Mark as done locally
        }
      });
    }

    try {
      final response = await ActivitiesApi.completeActivity(activityId);
      if (response['success'] == true) {
        // Silent refresh in background to sync streak/etc
        final progressResponse = await ActivitiesApi.getProgress();
        if (mounted && progressResponse['success'] == true) {
          setState(() {
            _currentStreak = progressResponse['data']['current_streak'] ?? 0;
          });
        }
        if (mounted) {
          _showCompletionFeedback('+50 XP Gained!');
        }
      }
    } catch (e) {
      debugPrint('Error completing activity: $e');
      // Rollback would happen on next manual refresh or navigation
    }
  }

  void _showCompletionFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 110, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // MISSION CONTROL STYLE HEADER
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'LIVE ACTIVITY LOG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E293B), Color(0xFF764ba2)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    bottom: 20,
                    child: Opacity(
                      opacity: 0.1,
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 180,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // HUD Overlay
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMiniBadge(
                            'STREAK: $_currentStreak',
                            const Color(0xFFFFB347),
                          ),
                          const SizedBox(width: 12),
                          _buildMiniBadge(
                            'LIVE: OPERATIONAL',
                            const Color(0xFF4ECDC4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF667eea),
                indicatorWeight: 4,
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
                tabs: const [
                  Tab(text: 'CONSCIOUS'),
                  Tab(text: 'SUBCONSCIOUS'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildConsciousTab(), _buildSubconsciousTab()],
        ),
      ),
    );
  }

  Widget _buildTaskInteractionItem(Map<String, dynamic> task) {
    final bool isCompleted =
        task['is_completed'] == true || task['is_completed'] == 1;
    final String title = task['title'] ?? 'Untitled';
    final int id = task['id'] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_off_rounded,
            color: isCompleted ? const Color(0xFF10B981) : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isCompleted ? Colors.grey : const Color(0xFF1E293B),
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (!isCompleted)
            Row(
              children: [
                _buildActionBtn('NO', Colors.red, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Priority deferred')),
                  );
                }),
                const SizedBox(width: 8),
                _buildActionBtn('YES', const Color(0xFF10B981), () async {
                  // Optimistic UI
                  setState(() {
                    // Check both lists for optimistic update
                    int idx = _consciousTasks.indexWhere((t) => t['id'] == id);
                    if (idx != -1) {
                      _consciousTasks[idx]['is_completed'] = true;
                    } else {
                      idx = _subconsciousTasks.indexWhere((t) => t['id'] == id);
                      if (idx != -1) {
                        _subconsciousTasks[idx]['is_completed'] = true;
                      }
                    }
                  });

                  try {
                    final res = await UserApi.completeTask(id);
                    if (res['success'] == true) {
                      _showCompletionFeedback(
                        'Priority Executed! +Points Added',
                      );
                      _loadTasks(); // Sync
                    }
                  } catch (e) {
                    debugPrint('Error completing task: $e');
                  }
                }),
              ],
            )
          else
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildConsciousTab() {
    final consciousTypes = _activityTypes
        .where((t) => t['category'] == 'conscious')
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTasks();
        await _loadActivities();
      },
      color: const Color(0xFF667eea),
      backgroundColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
        children: [
          // Priorities Section
          if (_consciousTasks.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CORE PRIORITIES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${_consciousTasks.where((t) => t['is_completed'] == true || t['is_completed'] == 1).length}/${_consciousTasks.length} DONE',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._consciousTasks.asMap().entries.map(
              (entry) => _buildTaskInteractionItem(entry.value)
                  .animate()
                  .fadeIn(delay: (entry.key * 50).ms)
                  .slideX(begin: 0.05),
            ),
            const SizedBox(height: 32),
          ],

          const Text(
            'LOG OPERATIONS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Color(0xFF64748B),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading && consciousTypes.isEmpty)
            const SkillSkeleton(itemCount: 3)
          else if (consciousTypes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No conscious operations available.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...consciousTypes.asMap().entries.map(
              (entry) => _buildActivityTypeCard(entry.value)
                  .animate()
                  .fadeIn(delay: (entry.key * 50).ms)
                  .slideX(begin: 0.05),
            ),
        ],
      ),
    );
  }

  Widget _buildSubconsciousTab() {
    final mindsetActivities = _todayActivities
        .where((a) => a['category'] == 'subconscious')
        .toList();
    final subconsciousTypes = _activityTypes
        .where((t) => t['category'] == 'subconscious')
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTasks();
          await _loadActivities();
        },
        color: const Color(0xFF667eea),
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
          children: [
            // Priorities Section
            if (_subconsciousTasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CORE PRIORITIES',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '${_subconsciousTasks.where((t) => t['is_completed'] == true || t['is_completed'] == 1).length}/${_subconsciousTasks.length} DONE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._subconsciousTasks.asMap().entries.map(
                (entry) => _buildTaskInteractionItem(entry.value)
                    .animate()
                    .fadeIn(delay: (entry.key * 50).ms)
                    .slideX(begin: 0.05),
              ),
              const SizedBox(height: 32),
            ],

            // Operations List
            const Text(
              'LOG OPERATIONS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading && subconsciousTypes.isEmpty)
              const SkillSkeleton(itemCount: 3)
            else if (subconsciousTypes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No subconscious operations available.'),
                ),
              )
            else
              ...subconsciousTypes.asMap().entries.map(
                (entry) => _buildActivityTypeCard(entry.value)
                    .animate()
                    .fadeIn(delay: (entry.key * 50).ms)
                    .slideX(begin: 0.05),
              ),

            // Today's Progress Log
            if (mindsetActivities.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                'COMPLETED LOGS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              ...mindsetActivities.map(
                (a) => _buildRitualCard(
                  a['title'],
                  '${a['duration_minutes'] ?? 10} min • ${a['type']?.toUpperCase() ?? 'MINDSET'}',
                  _getMindsetIcon(a['type']),
                  _getMindsetColor(a['type']),
                  a['is_completed'] == true || a['is_completed'] == 1,
                  onTap: () => _toggleActivityComplete(
                    a['id'],
                    a['is_completed'] == true || a['is_completed'] == 1,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubconsciousActivity,
        backgroundColor: const Color(0xFFf093fb),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ).animate().scale(delay: 300.ms),
    );
  }

  IconData _getMindsetIcon(String? type) {
    if (type == 'morningPriming') return Icons.wb_sunny_rounded;
    if (type == 'focusDrill') return Icons.bolt_rounded;
    if (type == 'eveningReflection') return Icons.nightlight_round;
    return Icons.psychology_rounded;
  }

  Color _getMindsetColor(String? type) {
    if (type == 'morningPriming') return const Color(0xFFFFB347);
    if (type == 'focusDrill') return const Color(0xFF4ECDC4);
    if (type == 'eveningReflection') return const Color(0xFF667eea);
    return const Color(0xFFf093fb);
  }

  Widget _buildActivityTypeCard(Map<String, dynamic> activityType) {
    final String name = activityType['name'] ?? 'Activity';
    final int points = activityType['points'] ?? 5;
    final String category = activityType['category'] ?? '';
    final Color color = category == 'conscious'
        ? const Color(0xFF667eea)
        : const Color(0xFFf093fb);

    final Map<String, dynamic> existingLog = _todayActivities.firstWhere(
      (a) => a['type'] == activityType['type_key'],
      orElse: () => <String, dynamic>{},
    );

    final String typeKey = activityType['type_key'] ?? '';
    final bool isInteracted =
        existingLog.isNotEmpty || _interactedKeys.contains(typeKey);
    final bool isCompleted =
        (existingLog.isNotEmpty &&
        (existingLog['is_completed'] == true ||
            existingLog['is_completed'] == 1));

    return Opacity(
      opacity: isInteracted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isInteracted ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isInteracted
                ? Colors.black.withValues(alpha: 0.01)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInteracted
                      ? (isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1))
                      : color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isInteracted
                      ? (isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded)
                      : _getIconForType(activityType['type_key']),
                  color: isInteracted
                      ? (isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                      : color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isInteracted
                            ? const Color(0xFF64748B)
                            : const Color(0xFF1E293B),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInteracted
                          ? (isCompleted ? 'COMPLETED' : 'SKIPPED')
                          : '+$points POINTS',
                      style: TextStyle(
                        color: isInteracted
                            ? (isCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444))
                            : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isInteracted)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted && existingLog.isNotEmpty
                          ? Icons.check_circle_rounded
                          : (isInteracted && existingLog.isEmpty
                                ? Icons.hourglass_top_rounded
                                : Icons.cancel_rounded),
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : (existingLog.isEmpty
                                ? Colors.grey
                                : const Color(0xFFEF4444)),
                      size: 28,
                    ),
                    if (isInteracted)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isCompleted
                                      ? const Color(0xFF10B981)
                                      : Colors.orange)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : Colors.orange,
                          ),
                        ),
                      ),
                  ],
                )
              else
                // YES/NO Buttons
                Row(
                  children: [
                    // NO Button
                    GestureDetector(
                      onTap: () =>
                          _logActivityType(activityType, completed: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'NO',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // YES Button
                    GestureDetector(
                      onTap: () =>
                          _logActivityType(activityType, completed: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'YES',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String? typeKey) {
    return _getActivityTypeIcon(typeKey);
  }

  Widget _buildRitualCard(
    String title,
    String sub,
    IconData icon,
    Color color,
    bool done, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: done
            ? const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4ECDC4),
                size: 30,
              )
            : Icon(Icons.play_circle_filled_rounded, color: color, size: 36),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  IconData _getActivityTypeIcon(String? typeKey) {
    switch (typeKey) {
      // Conscious
      case 'cold_calling':
        return Icons.phone_rounded;
      case 'content_creation':
        return Icons.camera_alt_rounded;
      case 'content_posting':
        return Icons.share_rounded;
      case 'dm_conversations':
        return Icons.message_rounded;
      case 'whatsapp_broadcast':
        return Icons.send_rounded;
      case 'mass_emailing':
        return Icons.email_rounded;
      case 'client_meetings':
        return Icons.people_rounded;
      case 'prospecting':
        return Icons.search_rounded;
      case 'follow_ups':
        return Icons.refresh_rounded;
      case 'deal_negotiation':
        return Icons.handshake_rounded;
      case 'client_servicing':
        return Icons.support_agent_rounded;
      case 'crm_update':
        return Icons.storage_rounded;
      case 'site_visits':
        return Icons.location_on_rounded;
      case 'referral_ask':
        return Icons.person_add_rounded;
      case 'skill_training':
        return Icons.school_rounded;
      // Subconscious
      case 'visualization':
        return Icons.visibility_rounded;
      case 'affirmations':
        return Icons.repeat_rounded;
      case 'gratitude':
        return Icons.favorite_rounded;
      case 'mindset_training':
        return Icons.psychology_rounded;
      case 'audio_reprogramming':
        return Icons.headphones_rounded;
      case 'webinar':
        return Icons.video_library_rounded;
      case 'belief_exercise':
        return Icons.edit_rounded;
      case 'calm_reset':
        return Icons.air_rounded;
      case 'identity_statement':
        return Icons.verified_user_rounded;
      case 'morning_ritual':
        return Icons.wb_sunny_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Future<void> _logActivityType(
    Map<String, dynamic> activityType, {
    bool completed = false,
  }) async {
    final String typeKey = activityType['type_key'] ?? '';
    final String name = activityType['name'] ?? 'Unknown';
    if (_interactedKeys.contains(typeKey)) return;

    debugPrint(
      'ACTIVITY_LOG_DEBUG: [1] Clicked ${completed ? "YES" : "NO"} for activity: $name ($typeKey)',
    );

    // Optimistic UI Update: Add to interacted keys immediately and don't block with loader
    if (mounted) {
      setState(() {
        _interactedKeys.add(typeKey);
      });
    }

    try {
      debugPrint(
        'ACTIVITY_LOG_DEBUG: [2] Sending createActivity request to API...',
      );
      final response = await ActivitiesApi.createActivity(
        title: name,
        type: typeKey,
        category: activityType['category'],
        durationMinutes: 30,
      );

      debugPrint(
        'ACTIVITY_LOG_DEBUG: [3] Create response received: success=${response['success']}',
      );

      if (response['success'] == true && completed) {
        final activityId = response['data']?['id'];
        debugPrint(
          'ACTIVITY_LOG_DEBUG: [4] Marking activity $activityId as completed...',
        );
        final completeRes = await ActivitiesApi.completeActivity(activityId);
        debugPrint(
          'ACTIVITY_LOG_DEBUG: [5] Completion response: success=${completeRes['success']}',
        );
      }

      if (response['success'] == true) {
        debugPrint(
          'ACTIVITY_LOG_DEBUG: [6] Triggering silent background refresh...',
        );
        // Silent refresh in background
        final activitiesResponse = await ActivitiesApi.getActivities();
        if (mounted && activitiesResponse['success'] == true) {
          setState(() {
            _todayActivities = List<Map<String, dynamic>>.from(
              activitiesResponse['data'] ?? [],
            );
          });
          debugPrint('ACTIVITY_LOG_DEBUG: [7] Local state synced with server.');
        }
        _showCompletionFeedback(
          completed
              ? '$name completed! +${activityType['points']} points'
              : '$name logged successfully!',
        );
      }
    } catch (e) {
      debugPrint('ACTIVITY_LOG_DEBUG: ERROR logging activity: $e');
    }
  }

  void _showAddSubconsciousActivity() {
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
                'ADD CUSTOM ACTIVITY',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add your own subconscious activity',
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
                  hintText: 'Activity name...',
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
                      final response = await ActivitiesApi.createActivity(
                        title: title,
                        type: 'custom',
                        category: 'subconscious',
                        durationMinutes: 10,
                      );
                      if (response['success'] == true) {
                        _loadActivities();
                        _showCompletionFeedback('Activity added successfully!');
                      }
                    } catch (e) {
                      debugPrint('Error creating activity: $e');
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf093fb),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ADD ACTIVITY',
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
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: const Color(0xFFF1F5F9), child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
