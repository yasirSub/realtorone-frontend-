import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart' show WaveformExtractionController;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/activities_api.dart';
import '../../api/user_api.dart';
import '../../models/activity_model.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/skill_skeleton.dart';
import 'activity_waveform_download.dart';
import '../deal_room/deal_room_widget.dart';
import '../deal_room/revenue_tracker_widget.dart';
import '../learning/learning_page.dart';

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
  // Track which activity types the user has interacted with today
  final Set<String> _interactedKeys = {};
  // Track which activity types are completed (for instant UI feedback)
  final Set<String> _completedKeys = {};
  int _revenueSubTab = 0; // 0 = Clients, 1 = Revenue
  int _revenueRefreshTrigger = 0;
  bool _isCheckingConsciousIntro = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _maybeShowConsciousIntroDialog();
      }
    });
    _loadTasks();
    _loadActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            for (var a in _todayActivities) {
              final type = a['type'];
              if (type != null) {
                _interactedKeys.add(type);
                if (a['is_completed'] == true || a['is_completed'] == 1) {
                  _completedKeys.add(type);
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

  Future<void> _maybeShowConsciousIntroDialog() async {
    if (!mounted || _isCheckingConsciousIntro) {
      return;
    }

    _isCheckingConsciousIntro = true;
    try {
      final response = await ApiClient.get(
        ApiEndpoints.clientsStatus,
        requiresAuth: true,
      );

      final bool hasClients =
          response['success'] == true &&
          (response['has_clients'] == true ||
              (response['clients_count'] ?? 0) > 0);

      if (!mounted || hasClients) return;

      await _showConsciousIntroDialog();
    } catch (_) {
      // Fail silently; no popup if client status cannot be determined.
    } finally {
      _isCheckingConsciousIntro = false;
    }
  }

  Future<void> _showConsciousIntroDialog() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What is your current situation?',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This helps us guide your next best revenue actions.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSituationOption(
                  label: 'I already have active clients',
                  subtitle: 'Focus on serving and expanding your client base.',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildSituationOption(
                  label: 'I have some leads but no deals yet',
                  subtitle:
                      'Prioritize follow-ups and deal conversion actions.',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildSituationOption(
                  label: "I don't have any leads yet",
                  subtitle: 'Start with prospecting and learning foundations.',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LearningPage()),
                    );
                  },
                  isDark: isDark,
                  isPrimary: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSituationOption({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isPrimary = false,
  }) {
    final Color accent = isPrimary
        ? const Color(0xFF667eea)
        : const Color(0xFF0EA5E9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: isPrimary ? 0.6 : 0.25),
            width: isPrimary ? 1.6 : 1.1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPrimary ? Icons.bolt_rounded : Icons.check_circle_rounded,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
          ],
        ),
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
                  Tab(text: 'SUBCONSCIOUS'),
                  Tab(text: 'CONSCIOUS'),
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

  Widget _buildActionBtn(
    String label,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : const Color(0xFF94A3B8);
    return AbsorbPointer(
      absorbing: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _revenueTabButton(
                    icon: Icons.people_alt_rounded,
                    label: 'CLIENTS',
                    active: _revenueSubTab == 0,
                    onTap: () => setState(() => _revenueSubTab = 0),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _revenueTabButton(
                    icon: Icons.attach_money_rounded,
                    label: 'REVENUE',
                    active: _revenueSubTab == 1,
                    onTap: () => setState(() {
                      _revenueSubTab = 1;
                      _revenueRefreshTrigger++;
                    }),
                    isDark: isDark,
                  ),
                ),
              ],
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
    final activeColor = isDark ? Colors.white : const Color(0xFF2563EB);
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? activeColor : inactiveColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? activeColor : inactiveColor,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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
            // Backend-driven identity sections
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
              ..._buildBackendDrivenSections(subconsciousTypes),
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

  List<Widget> _buildBackendDrivenSections(List<Map<String, dynamic>> types) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final sectionOrder = <String, int>{};

    final sortedTypes = [...types]
      ..sort((a, b) {
        final aSectionOrder = (a['section_order'] as num?)?.toInt() ?? 999;
        final bSectionOrder = (b['section_order'] as num?)?.toInt() ?? 999;
        if (aSectionOrder != bSectionOrder) {
          return aSectionOrder.compareTo(bSectionOrder);
        }

        final aItemOrder = (a['item_order'] as num?)?.toInt() ?? 999;
        final bItemOrder = (b['item_order'] as num?)?.toInt() ?? 999;
        if (aItemOrder != bItemOrder) {
          return aItemOrder.compareTo(bItemOrder);
        }

        final aName = (a['name'] ?? '') as String;
        final bName = (b['name'] ?? '') as String;
        return aName.compareTo(bName);
      });

    for (final type in sortedTypes) {
      final title =
          ((type['section_title'] as String?)?.trim().isNotEmpty ?? false)
          ? (type['section_title'] as String).toUpperCase()
          : 'IDENTITY CONDITIONING';
      grouped.putIfAbsent(title, () => []);
      grouped[title]!.add(type);
      sectionOrder.putIfAbsent(
        title,
        () => (type['section_order'] as num?)?.toInt() ?? 999,
      );
    }

    final orderedSections = grouped.entries.toList()
      ..sort(
        (a, b) =>
            (sectionOrder[a.key] ?? 999).compareTo(sectionOrder[b.key] ?? 999),
      );

    final widgets = <Widget>[];
    for (int index = 0; index < orderedSections.length; index++) {
      final entry = orderedSections[index];
      widgets.add(_buildSubcategorySection(entry.key, entry.value, index * 50));
      if (index < orderedSections.length - 1) {
        widgets.add(const SizedBox(height: 24));
      }
    }

    return widgets;
  }

  Widget _buildActivityTypeCard(Map<String, dynamic> activityType) {
    final String name = activityType['name'] ?? 'Activity';
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
      child: InkWell(
        onTap: isInteracted ? null : () => _showActivityTaskPopup(activityType),
        borderRadius: BorderRadius.circular(24),
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
                      if (isInteracted) ...[
                        const SizedBox(height: 2),
                        Text(
                          isCompleted ? 'COMPLETED' : 'SKIPPED',
                          style: TextStyle(
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
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
                  // Open details popup first, then YES/NO inside it.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'OPEN',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String? typeKey) {
    return _getActivityTypeIcon(typeKey);
  }

  Future<void> _showActivityTaskPopup(Map<String, dynamic> activityType) async {
    final String name = activityType['name'] ?? 'Activity';
    final int todayDay =
        (activityType['today_day_number'] as num?)?.toInt() ?? 1;
    final String taskDescription =
        (activityType['task_description'] ?? activityType['description'] ?? '')
            .toString()
            .trim();
    final String scriptIdea =
        (activityType['video_reel_script_idea'] ??
                activityType['script_idea'] ??
                '')
            .toString()
            .trim();
    final String feedback = (activityType['daily_feedback'] ?? '')
        .toString()
        .trim();
    String audioUrl =
        (activityType['daily_audio_url'] ?? activityType['audio_url'] ?? '')
            .toString()
            .trim();
    if (audioUrl.isNotEmpty && !audioUrl.startsWith('http')) {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      audioUrl = base + (audioUrl.startsWith('/') ? audioUrl : '/$audioUrl');
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ActivityTaskModalContent(
        name: name,
        todayDay: todayDay,
        taskDescription: taskDescription,
        scriptIdea: scriptIdea,
        feedback: feedback,
        audioUrl: audioUrl,
        activityType: activityType,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: (String userResponse) {
          Navigator.of(context).pop();
          _logActivityType(
            activityType,
            completed: true,
            userResponse: userResponse,
          );
        },
        buildPopupInfoCard: _buildPopupInfoCard,
        buildActionBtn: _buildActionBtn,
      ),
    );
  }

  Widget _buildPopupInfoCard({
    required String title,
    required String text,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
    String? userResponse,
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
        description: userResponse,
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
            _completedKeys.clear();
            for (final a in _todayActivities) {
              final type = a['type'];
              if (type != null &&
                  (a['is_completed'] == true || a['is_completed'] == 1)) {
                _completedKeys.add(type);
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

/// Waveform-style seek bar: [barHeights] from decoded audio RMS, or synthetic fallback.
class _WaveformSeekBar extends StatelessWidget {
  const _WaveformSeekBar({
    required this.progress,
    required this.isDark,
    this.onSeek,
    this.barHeights,
  });

  final double progress;
  final bool isDark;
  final void Function(double)? onSeek;
  /// Normalized 0–1 heights from real audio (one per bar); null uses synthetic shape.
  final List<double>? barHeights;

  static const int _fallbackBarCount = 48;
  static final List<double> _syntheticHeights =
      List<double>.generate(_fallbackBarCount, (i) {
    final t = i / (_fallbackBarCount - 1);
    final wave = 0.4 +
        0.35 * (1 - (t - 0.2).abs() * 2.5).clamp(0.0, 1.0) +
        0.35 * (1 - (t - 0.5).abs() * 2.5).clamp(0.0, 1.0) +
        0.35 * (1 - (t - 0.8).abs() * 2.5).clamp(0.0, 1.0);
    return (0.25 + wave * 0.75).clamp(0.25, 1.0);
  });

  List<double> get _heights {
    final h = barHeights;
    if (h != null && h.isNotEmpty) return h;
    return _syntheticHeights;
  }

  @override
  Widget build(BuildContext context) {
    const barColor = Color(0xFF667eea);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1);
    const barSpacing = 2.0;
    const minBarHeight = 3.0;
    const maxBarHeight = 14.0;
    final heights = _heights;
    final barCount = heights.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth =
            (width - barSpacing * (barCount - 1)) / barCount;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(d.globalPosition);
                  final p = (local.dx / width).clamp(0.0, 1.0);
                  onSeek!(p);
                },
          onTapDown: onSeek == null
              ? null
              : (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final local = box.globalToLocal(d.globalPosition);
                  final p = (local.dx / width).clamp(0.0, 1.0);
                  onSeek!(p);
                },
          child: SizedBox(
            height: maxBarHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (int i = 0; i < barCount; i++) ...[
                  if (i > 0) SizedBox(width: barSpacing),
                  Container(
                    width: barWidth,
                    height: minBarHeight +
                        heights[i].clamp(0.0, 1.0) *
                            (maxBarHeight - minBarHeight),
                    decoration: BoxDecoration(
                      color: (i + 0.5) / barCount <= progress
                          ? barColor
                          : inactiveColor,
                      borderRadius: BorderRadius.circular(barWidth / 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskAudioPlayer extends StatefulWidget {
  const _TaskAudioPlayer({required this.audioUrl, required this.isDark});

  final String audioUrl;
  final bool isDark;

  @override
  State<_TaskAudioPlayer> createState() => _TaskAudioPlayerState();
}

class _TaskAudioPlayerState extends State<_TaskAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDisposed = false;
  bool _hasStartedPlayback =
      false; // Only show timer/progress after user taps play
  double _playbackRate = 1.0;
  Timer? _progressPollTimer;
  /// RMS peaks from native decode ([audio_waveforms]); null until loaded or on failure.
  List<double>? _waveformHeights;
  int _waveformLoadToken = 0;

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1)}:${s.toString().padLeft(2, '0')}';
  }

  void _startWaveformExtraction() {
    if (widget.audioUrl.isEmpty) return;
    final token = ++_waveformLoadToken;
    unawaited(_extractWaveform(token));
  }

  Future<void> _extractWaveform(int token) async {
    try {
      final path = await downloadActivityAudioForWaveform(widget.audioUrl);
      if (path == null || token != _waveformLoadToken || _isDisposed || !mounted) {
        return;
      }

      final extractor = WaveformExtractionController();
      final raw = await extractor.extractWaveformData(
        path: path,
        noOfSamples: 56,
      );
      await extractor.stopWaveformExtraction();

      if (token != _waveformLoadToken || _isDisposed || !mounted) return;
      var maxV = 1e-9;
      for (final v in raw) {
        if (v > maxV) maxV = v;
      }
      final norm = List<double>.generate(raw.length, (i) {
        final r = raw[i] / maxV;
        return (0.18 + 0.82 * r).clamp(0.18, 1.0);
      });
      if (token != _waveformLoadToken || _isDisposed || !mounted) return;
      setState(() => _waveformHeights = norm);
    } catch (e, st) {
      debugPrint('Activity audio waveform extract failed: $e\n$st');
    }
  }

  Future<void> _syncProgressFromPlayer() async {
    if (_isDisposed || !mounted) return;
    try {
      final pos = await _player.getCurrentPosition();
      final dur = await _player.getDuration();
      if (_isDisposed || !mounted) return;
      setState(() {
        if (pos != null) _position = pos;
        if (dur != null && dur > Duration.zero) _duration = dur;
      });
    } catch (_) {}
  }

  void _startProgressPolling() {
    _progressPollTimer?.cancel();
    _progressPollTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _syncProgressFromPlayer(),
    );
    unawaited(_syncProgressFromPlayer());
  }

  void _stopProgressPolling() {
    _progressPollTimer?.cancel();
    _progressPollTimer = null;
    unawaited(_syncProgressFromPlayer());
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (_isDisposed || !mounted) return;
      setState(() => _playerState = state);
      if (state == PlayerState.playing) {
        _startProgressPolling();
      } else {
        _stopProgressPolling();
      }
    });
    _player.onDurationChanged.listen((d) {
      if (!_isDisposed && mounted && d > Duration.zero) {
        setState(() => _duration = d);
      }
    });
    _player.onPositionChanged.listen((p) {
      if (!_isDisposed && mounted) setState(() => _position = p);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startWaveformExtraction());
  }

  @override
  void didUpdateWidget(covariant _TaskAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      setState(() => _waveformHeights = null);
      _startWaveformExtraction();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _progressPollTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      setState(() => _hasStartedPlayback = true);
      await _player.setPlaybackRate(_playbackRate);
      await _player.play(UrlSource(widget.audioUrl));
      for (final delay in [
        Duration.zero,
        const Duration(milliseconds: 400),
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]) {
        Future.delayed(delay, _syncProgressFromPlayer);
      }
    }
  }

  Future<void> _toggle2x() async {
    if (_isDisposed || !mounted) return;
    setState(() => _playbackRate = _playbackRate == 2.0 ? 1.0 : 2.0);
    await _player.setPlaybackRate(_playbackRate);
  }

  Future<void> _seekTo(double progress) async {
    final totalSec = _duration.inSeconds;
    if (totalSec <= 0) return;
    final sec = (progress.clamp(0.0, 1.0) * totalSec).round();
    await _player.seek(Duration(seconds: sec));
    if (mounted) setState(() => _position = Duration(seconds: sec));
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = _duration.inSeconds;
    final posSec = _position.inSeconds;
    final progress = totalSec > 0 ? posSec / totalSec : 0.0;
    final showProgress =
        _hasStartedPlayback; // Only show timer/progress after user taps play

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePlay,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _togglePlay,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playerState == PlayerState.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22,
                        color: const Color(0xFF667eea),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _playerState == PlayerState.playing
                              ? 'Playing'
                              : 'Day audio',
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _hasStartedPlayback
                              ? 'Tap to pause'
                              : 'Tap to listen',
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.white60
                                : const Color(0xFF64748B),
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  GestureDetector(
                    onTap: _toggle2x,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _playbackRate == 2.0
                            ? const Color(0xFF667eea).withValues(alpha: 0.3)
                            : (widget.isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '2×',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _playbackRate == 2.0
                              ? const Color(0xFF667eea)
                              : (widget.isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showProgress)
                GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              totalSec > 0 ? _formatDuration(_duration) : '--:--',
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _WaveformSeekBar(
                          progress: totalSec > 0
                              ? progress.clamp(0.0, 1.0)
                              : 0.0,
                          isDark: widget.isDark,
                          onSeek: totalSec > 0 ? _seekTo : null,
                          barHeights: _waveformHeights,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTaskModalContent extends StatefulWidget {
  const _ActivityTaskModalContent({
    required this.name,
    required this.todayDay,
    required this.taskDescription,
    required this.scriptIdea,
    required this.feedback,
    required this.audioUrl,
    required this.activityType,
    required this.onCancel,
    required this.onSubmit,
    required this.buildPopupInfoCard,
    required this.buildActionBtn,
  });

  final String name;
  final int todayDay;
  final String taskDescription;
  final String scriptIdea;
  final String feedback;
  final String audioUrl;
  final Map<String, dynamic> activityType;
  final VoidCallback onCancel;
  final void Function(String userResponse) onSubmit;
  final Widget Function({
    required String title,
    required String text,
    required bool isDark,
  })
  buildPopupInfoCard;
  final Widget Function(
    String label,
    Color color,
    VoidCallback onTap, {
    bool enabled,
  })
  buildActionBtn;

  @override
  State<_ActivityTaskModalContent> createState() =>
      _ActivityTaskModalContentState();
}

class _ActivityTaskModalContentState extends State<_ActivityTaskModalContent> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userText = _textController.text.trim();
    final wordCount = userText.isEmpty
        ? 0
        : userText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final canSubmit = wordCount >= 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DAY ${widget.todayDay} TASK',
                            style: const TextStyle(
                              color: Color(0xFF667eea),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.taskDescription.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text(
                                'Task Description',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              content: Text(
                                widget.taskDescription,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          ),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Show audio player first when available (primary media for Audio Reprogramming, etc.)
                if (widget.audioUrl.isNotEmpty) ...[
                  _TaskAudioPlayer(audioUrl: widget.audioUrl, isDark: isDark),
                  const SizedBox(height: 12),
                ],
                if (widget.scriptIdea.isNotEmpty) ...[
                  widget.buildPopupInfoCard(
                    title: 'Video/Reel Script Idea',
                    text: widget.scriptIdea,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.feedback.isNotEmpty) ...[
                  widget.buildPopupInfoCard(
                    title: 'Feedback',
                    text: widget.feedback,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.taskDescription.isEmpty &&
                    widget.scriptIdea.isEmpty &&
                    widget.feedback.isEmpty &&
                    widget.audioUrl.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Text(
                      'No day-wise note set yet. Write your response below and tap Submit.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _textController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Write your response... (min 2 words to submit)',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF667eea),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: widget.buildActionBtn(
                        'CANCEL',
                        const Color(0xFFEF4444),
                        widget.onCancel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: widget.buildActionBtn(
                        'SUBMIT',
                        const Color(0xFF10B981),
                        () => widget.onSubmit(_textController.text.trim()),
                        enabled: canSubmit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
