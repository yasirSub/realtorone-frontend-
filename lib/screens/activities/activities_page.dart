import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/activities_api.dart';
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
  int _tasksCompleted = 0;
  int _tasksTotal = 0;
  int _mindsetCompleted = 0;
  int _mindsetTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final activitiesResponse = await ActivitiesApi.getActivities();
      final progressResponse = await ActivitiesApi.getProgress();
      if (mounted) {
        setState(() {
          if (activitiesResponse['success'] == true) {
            _todayActivities = List<Map<String, dynamic>>.from(
              activitiesResponse['data'] ?? [],
            );
          }
          if (progressResponse['success'] == true) {
            final data = progressResponse['data'];
            _tasksCompleted = data['tasks_completed'] ?? 0;
            _tasksTotal = data['tasks_total'] ?? 0;
            _mindsetCompleted = data['subconscious_completed'] ?? 0;
            _mindsetTotal = data['subconscious_total'] ?? 0;
            _currentStreak = data['current_streak'] ?? 0;
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
    final response = await ActivitiesApi.completeActivity(activityId);
    if (response['success'] == true) {
      _loadActivities();
      if (mounted) {
        _showCompletionFeedback('+50 XP Gained!');
      }
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
                'EXECUTION HUB',
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
                  Tab(text: 'OPERATIONS'),
                  Tab(text: 'MINDSET'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildOperationsTab(), _buildMindsetTab()],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddActivitySheet(context),
          backgroundColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'LOG OPERATION',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ).animate().scale(delay: 500.ms),
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

  Widget _buildOperationsTab() {
    final taskActivities = _todayActivities
        .where((a) => a['category'] == 'task')
        .toList();
    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: const Color(0xFF667eea),
      backgroundColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
        children: [
          _buildProgressStats(
            'Daily Operational Quota',
            _tasksCompleted,
            _tasksTotal > 0 ? _tasksTotal : 5,
            const Color(0xFF667eea),
          ),
          const SizedBox(height: 32),
          const Text(
            'PRIORITY TARGETS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Color(0xFF64748B),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const SkillSkeleton(itemCount: 3)
          else if (taskActivities.isEmpty)
            _buildEmptyState(
              'No operational tasks logged. Start by adding a high-ROI activity.',
            )
          else
            ...taskActivities.asMap().entries.map(
              (entry) => _buildActivityCard(entry.value)
                  .animate()
                  .fadeIn(delay: (entry.key * 100).ms)
                  .slideX(begin: 0.05),
            ),
        ],
      ),
    );
  }

  Widget _buildMindsetTab() {
    final mindsetActivities = _todayActivities
        .where((a) => a['category'] == 'subconscious')
        .toList();

    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: const Color(0xFF667eea),
      backgroundColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
        children: [
          _buildProgressStats(
            'Subconscious Recalibration',
            _mindsetCompleted,
            _mindsetTotal > 0
                ? _mindsetTotal
                : (mindsetActivities.isEmpty ? 3 : mindsetActivities.length),
            const Color(0xFFf093fb),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const SkillSkeleton(itemCount: 3)
          else if (mindsetActivities.isEmpty) ...[
            _buildRitualCard(
              'Morning Priming',
              'Peak State Protocol • 10 min',
              Icons.wb_sunny_rounded,
              const Color(0xFFFFB347),
              false,
              onTap: () => _handleRitualTap('Morning Priming'),
            ),
            _buildRitualCard(
              'Confidence Rewiring',
              'Neuro-Linguistic Audio • 8 min',
              Icons.psychology_rounded,
              const Color(0xFF4ECDC4),
              false,
              onTap: () => _handleRitualTap('Confidence Rewiring'),
            ),
            _buildRitualCard(
              'Evening Reflection',
              'Review & Visualize • 5 min',
              Icons.nightlight_round,
              const Color(0xFF667eea),
              false,
              onTap: () => _handleRitualTap('Evening Reflection'),
            ),
          ] else
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
          const SizedBox(height: 32),
        ],
      ),
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

  Future<void> _handleRitualTap(String ritualName) async {
    // If it's a hardcoded one, we creates it in the backend first
    setState(() => _isLoading = true);
    try {
      final type = ritualName.contains('Morning')
          ? 'morningPriming'
          : ritualName.contains('Confidence')
          ? 'focusDrill'
          : 'eveningReflection';

      final response = await ActivitiesApi.createActivity(
        title: ritualName,
        type: type,
        category: 'subconscious',
        durationMinutes: 10,
      );

      if (response['success'] == true) {
        final newId = response['data']['id'];
        await ActivitiesApi.completeActivity(newId);
        await _loadActivities();
      }
    } catch (e) {
      debugPrint('Error creating ritual: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProgressStats(
    String title,
    int completed,
    int total,
    Color color,
  ) {
    final progress = total > 0 ? completed / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toInt()}% towards peak state',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final bool done =
        activity['is_completed'] == true || activity['is_completed'] == 1;
    final int id = activity['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (done ? const Color(0xFF4ECDC4) : const Color(0xFF667eea))
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getActivityIcon(activity['type']),
            color: done ? const Color(0xFF4ECDC4) : const Color(0xFF667eea),
            size: 22,
          ),
        ),
        title: Text(
          activity['title'] ?? 'Task',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1E293B),
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${activity['duration_minutes'] ?? 30} MIN • ${activity['type']?.toUpperCase() ?? 'OP'}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        trailing: Checkbox(
          value: done,
          onChanged: (v) => _toggleActivityComplete(id, done),
          activeColor: const Color(0xFF4ECDC4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onTap: () => _toggleActivityComplete(id, done),
      ),
    );
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.assignment_rounded,
            size: 64,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'leadOutreach':
        return Icons.phone_rounded;
      case 'followUp':
        return Icons.message_rounded;
      case 'meeting':
        return Icons.people_rounded;
      case 'siteVisit':
        return Icons.location_on_rounded;
      case 'negotiation':
        return Icons.handshake_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  void _showAddActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'LOG NEW OPERATION',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: 2,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildQuickAddTile(
                    'High-Stakes Call',
                    'Outreach & Prospecting',
                    Icons.phone_rounded,
                    const Color(0xFF667eea),
                    'leadOutreach',
                  ),
                  _buildQuickAddTile(
                    'Elite Meeting',
                    'Negotiation / Closing',
                    Icons.people_rounded,
                    const Color(0xFF4ECDC4),
                    'meeting',
                  ),
                  _buildQuickAddTile(
                    'Field Analysis',
                    'Site Visit / Valuation',
                    Icons.location_on_rounded,
                    const Color(0xFFFFB347),
                    'siteVisit',
                  ),
                  _buildQuickAddTile(
                    'Deal Prep',
                    'Contracting & Admin',
                    Icons.description_rounded,
                    const Color(0xFF764ba2),
                    'followUp',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddTile(
    String title,
    String sub,
    IconData icon,
    Color color,
    String type,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        onTap: () async {
          Navigator.pop(context);
          setState(() => _isLoading = true);
          try {
            final response = await ActivitiesApi.createActivity(
              title: title,
              type: type,
              category: 'task',
              durationMinutes: 30,
            );
            if (response['success'] == true) {
              await _loadActivities();
              _showCompletionFeedback('Operation Logged Successfully!');
            }
          } catch (e) {
            debugPrint('Error logging operation: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      ),
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
