import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/activities_api.dart';
import '../../api/user_api.dart';
import '../../models/activity_model.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/skill_skeleton.dart';
import '../deal_room/deal_room_widget.dart';
import '../deal_room/revenue_tracker_widget.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentStreak = 0;
  int _todayPoints = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _todayActivities = [];
  List<Map<String, dynamic>> _activityTypes = [];
  // Track which activity types the user has interacted with today
  final Set<String> _interactedKeys = {};
  // Track which activity types are completed (for instant UI feedback)
  final Set<String> _completedKeys = {};
  int _revenueSubTab = 0; // 0 = Clients, 1 = Revenue
  int _revenueRefreshTrigger = 0;

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
            // Map types to Identity Conditioning (from diagram: Min 2, Max 40)
            if ([
              'journaling',
              'webinar',
              'visualization',
              'affirmations',
              'inner_game_audio',
              'guided_reset',
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

            // Sync local state with server for interacted + completed keys
            _interactedKeys.clear();
            _completedKeys.clear();
            _todayPoints = 0;
            for (var a in _todayActivities) {
              final type = a['type'];
              if (type != null) {
                _interactedKeys.add(type);
                if (a['is_completed'] == true || a['is_completed'] == 1) {
                  _completedKeys.add(type);
                  final dynamic rawPoints = a['points'];
                  if (rawPoints is num) {
                    _todayPoints += rawPoints.toInt();
                  } else if (rawPoints is String) {
                    _todayPoints += int.tryParse(rawPoints) ?? 0;
                  }
                }
              }
            }
          }
          if (typesResponse['success'] == true) {
            _activityTypes = List<Map<String, dynamic>>.from(
              typesResponse['data'] ?? [],
            );
            debugPrint('Activity Types Loaded: ${_activityTypes.length}');
            debugPrint(
              'Revenue Actions Types: ${_activityTypes.where((t) => t['category'] == 'conscious').length}',
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
              centerTitle: true,
              titlePadding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 14,
              ),
              title: innerBoxIsScrolled
                  ? Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ACTIVITY LOG',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Color(0x40000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                  color: const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$_todayPoints pts',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Text(
                      'ACTIVITY LOG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Color(0x40000000),
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
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
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF2D2348),
                          Color(0xFF764ba2),
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -24,
                    top: -20,
                    child: Opacity(
                      opacity: 0.18,
                      child: Icon(
                        Icons.bolt_rounded,
                        size: 200,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  // HUD Overlay – stats row
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMiniBadge(
                            'STREAK',
                            '$_currentStreak',
                            const Color(0xFFFFB347),
                            Icons.local_fire_department_rounded,
                          ),
                          _buildMiniBadge(
                            'POINTS',
                            '$_todayPoints',
                            const Color(0xFF10B981),
                            Icons.star_rounded,
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
                  Tab(text: 'IDENTITY CONDITIONING'),
                  Tab(text: 'REVENUE ACTIONS'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSubconsciousTab(), // Identity Conditioning first
            _buildConsciousTab(), // Revenue Actions second
          ],
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

  Widget _buildMiniBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsciousTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTasks();
        await _loadActivities();
        if (mounted) setState(() => _revenueRefreshTrigger++);
      },
      color: const Color(0xFF667eea),
      backgroundColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
        children: [
          // ── CLIENTS / REVENUE toggle ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _revenueTabButton(
                icon: Icons.people_alt_rounded,
                label: 'CLIENTS',
                active: _revenueSubTab == 0,
                onTap: () => setState(() => _revenueSubTab = 0),
                isDark: isDark,
              ),
              const SizedBox(width: 28),
              _revenueTabButton(
                icon: Icons.attach_money_rounded,
                label: 'REVENUE',
                active: _revenueSubTab == 1,
                onTap: () => setState(() {
                  _revenueSubTab = 1;
                  _revenueRefreshTrigger++;
                }),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 80,
              height: 3,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Content based on sub-tab ──
          if (_revenueSubTab == 0) ...[
            DealRoomWidget(
              onClientActionLogged: () {
                if (mounted) setState(() => _revenueRefreshTrigger++);
              },
            ),

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
          ] else ...[
            RevenueTrackerWidget(refreshTrigger: _revenueRefreshTrigger),
          ],
        ],
      ),
    );
  }

  Widget _revenueTabButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final color = active
        ? (isDark ? Colors.white : const Color(0xFF2563EB))
        : (isDark ? Colors.white30 : const Color(0xFF94A3B8));
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF))
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubconsciousTab() {
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

            // Identity Conditioning: Manual & Verified subcategories
            if (_isLoading && subconsciousTypes.isEmpty)
              const SkillSkeleton(itemCount: 3)
            else if (subconsciousTypes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No identity conditioning operations available.'),
                ),
              )
            else ...[
              // 1. Manual Identity Activities
              _buildSubcategorySection(
                'MANUAL IDENTITY ACTIVITIES',
                subconsciousTypes
                    .where((t) => t['subcategory'] == 'manual')
                    .toList(),
                0,
              ),
              const SizedBox(height: 24),
              // 2. Verified Identity Activities
              _buildSubcategorySection(
                'VERIFIED IDENTITY ACTIVITIES',
                subconsciousTypes
                    .where((t) => t['subcategory'] == 'verified')
                    .toList(),
                50,
              ),
              // Custom/other types without subcategory
              if (subconsciousTypes.any(
                (t) =>
                    t['subcategory'] != 'manual' &&
                    t['subcategory'] != 'verified',
              )) ...[
                const SizedBox(height: 24),
                _buildSubcategorySection(
                  'OTHER',
                  subconsciousTypes
                      .where(
                        (t) =>
                            t['subcategory'] != 'manual' &&
                            t['subcategory'] != 'verified',
                      )
                      .toList(),
                  100,
                ),
              ],
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

  Widget _buildSubcategorySection(
    String title,
    List<Map<String, dynamic>> types,
    int baseDelay,
  ) {
    if (types.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Color(0xFF64748B),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        ...types.asMap().entries.map(
          (entry) => _buildActivityTypeCard(entry.value)
              .animate()
              .fadeIn(delay: (baseDelay + entry.key * 50).ms)
              .slideX(begin: 0.05),
        ),
      ],
    );
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
    // Consider both server state and local optimistic completions
    final bool isCompleted =
        _completedKeys.contains(typeKey) ||
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
      // Identity Conditioning
      case 'journaling':
        return Icons.book_rounded;
      case 'webinar':
        return Icons.video_library_rounded;
      case 'visualization':
        return Icons.visibility_rounded;
      case 'affirmations':
        return Icons.repeat_rounded;
      case 'inner_game_audio':
        return Icons.headphones_rounded;
      case 'guided_reset':
        return Icons.air_rounded;
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
    final String category = (activityType['category'] == 'conscious')
        ? 'task'
        : activityType['category'];
    if (_interactedKeys.contains(typeKey)) return;

    debugPrint(
      'ACTIVITY_LOG_DEBUG: [1] Clicked ${completed ? "YES" : "NO"} for activity: $name ($typeKey)',
    );

    // Optimistic UI Update: mark as interacted (and completed if YES) immediately
    if (mounted) {
      setState(() {
        _interactedKeys.add(typeKey);
        if (completed) {
          _completedKeys.add(typeKey);
        }
      });
    }

    try {
      debugPrint(
        'ACTIVITY_LOG_DEBUG: [2] Sending createActivity request to API...',
      );
      final response = await ActivitiesApi.createActivity(
        title: name,
        type: typeKey,
        category: category,
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
            // Recalculate points from fresh server data
            _todayPoints = 0;
            _completedKeys.clear();
            for (final a in _todayActivities) {
              final type = a['type'];
              if (type != null &&
                  (a['is_completed'] == true || a['is_completed'] == 1)) {
                _completedKeys.add(type);
                final dynamic rawPoints = a['points'];
                if (rawPoints is num) {
                  _todayPoints += rawPoints.toInt();
                } else if (rawPoints is String) {
                  _todayPoints += int.tryParse(rawPoints) ?? 0;
                }
              }
            }
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
                'Add your own identity conditioning activity',
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
