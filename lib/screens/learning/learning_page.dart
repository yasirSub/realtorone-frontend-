import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/learning_model.dart';
import '../../routes/app_routes.dart';
import '../../api/learning_api.dart';
import '../../widgets/skill_skeleton.dart';
import '../../widgets/elite_loader.dart';
import '../../api/api_endpoints.dart';
import '../../api/api_client.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _userTier = 'Consultant';
  List<ModuleModel> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch modules with courses from the new endpoint
      final courseRes = await LearningApi.getCourses();
      if (courseRes['success'] == true) {
        final List<dynamic> data = courseRes['data'] ?? [];
        _modules = data.map((json) => ModuleModel.fromJson(json)).toList();
        _userTier = courseRes['user_tier'] ?? 'Consultant';
      }

      // Simulate real API latency for the "Wow" animation factor
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading learning data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isPremium => _userTier.toLowerCase() != 'free';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // MISSION CONTROL VAULT HEADER
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'KNOWLEDGE VAULT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
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
                        colors: [Color(0xFF1E293B), Color(0xFF1e3a8a)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -30,
                    bottom: 20,
                    child: Opacity(
                      opacity: 0.1,
                      child: const Icon(
                        Icons.school_rounded,
                        size: 200,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // HUD BARS
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildTacticalBadge(
                                'LIBRARY: ENCRYPTED',
                                const Color(0xFF4ECDC4),
                              ),
                              const SizedBox(width: 12),
                              _buildTacticalBadge(
                                'TIER: ${_userTier.toUpperCase()}',
                                _isPremium
                                    ? const Color(0xFFFFB347)
                                    : Colors.white38,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'UNLOCKED MISSION BLUEPRINTS',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!_isPremium)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 16,
                    top: 12,
                    bottom: 12,
                  ),
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.subscriptionPlans,
                    ),
                    icon: const Icon(
                      Icons.security_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    label: const Text(
                      'UPGRADE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ).animate().scale(delay: 400.ms),
            ],
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF667eea),
          child: _isLoading
              ? const Center(child: EliteLoader())
              : _modules.isEmpty
              ? _buildEmptyState()
              : _buildModulesList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO BLUEPRINTS UNLOCKED',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to the next tier for new content.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final module = _modules[index];
        return _buildModuleSection(module, index);
      },
    );
  }

  Widget _buildModuleSection(ModuleModel module, int moduleIndex) {
    final moduleColors = [
      const Color(0xFF6366f1), // Module 1 - Purple
      const Color(0xFFF59E0B), // Module 2 - Gold
      const Color(0xFF7C3AED), // Module 3 - Purple
    ];
    final moduleIndexColor = module.moduleNumber - 1;
    Color moduleColor;
    if (moduleIndexColor >= 0 && moduleIndexColor < moduleColors.length) {
      moduleColor = moduleColors[moduleIndexColor];
    } else {
      moduleColor = const Color(0xFF6366f1);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Module Header
        Padding(
          padding: EdgeInsets.only(bottom: 16, top: moduleIndex > 0 ? 32 : 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: module.isLocked 
                      ? Colors.grey.withValues(alpha: 0.1)
                      : moduleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: module.isLocked 
                        ? Colors.grey.withValues(alpha: 0.3)
                        : moduleColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      module.isLocked ? Icons.lock_outline_rounded : Icons.auto_awesome_rounded,
                      size: 16,
                      color: module.isLocked ? Colors.grey : moduleColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      module.moduleName.toUpperCase(),
                      style: TextStyle(
                        color: module.isLocked ? Colors.grey : moduleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (module.isLocked) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showUpgradePrompt(module),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'UPGRADE TO ${module.requiredTier.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Courses in Module
        ...module.courses.asMap().entries.map((entry) {
          final courseIndex = entry.key;
          final course = entry.value;
          return _buildCourseCard(course, moduleColor)
              .animate()
              .fadeIn(delay: ((moduleIndex * 100) + (courseIndex * 50)).ms)
              .slideY(begin: 0.1);
        }),
      ],
    );
  }

  void _showUpgradePrompt(ModuleModel module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'UPGRADE TO ${module.requiredTier.toUpperCase()} TO UNLOCK ${module.moduleName.toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VIEW PLANS',
          textColor: const Color(0xFF4ECDC4),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.subscriptionPlans),
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course, Color moduleColor) {
    final bool isLocked = course.isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isLocked ? Colors.white.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openCourse(course),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.grey.withValues(alpha: 0.1)
                      : const Color(0xFF6366f1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      isLocked
                          ? Icons.lock_outline_rounded
                          : course.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: isLocked ? Colors.grey : moduleColor,
                      size: isLocked ? 24 : 32,
                    ),
                    if (!isLocked && course.progressPercent > 0 && !course.isCompleted)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: moduleColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isLocked
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _buildTierPill(course.minTier, isLocked: isLocked),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.description,
                      style: TextStyle(
                        color: isLocked ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isLocked && course.progressPercent > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: course.progressPercent / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(moduleColor),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.progressPercent}% Complete',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierPill(String tier, {bool isLocked = false}) {
    Color color;
    switch (tier.toLowerCase()) {
      case 'diamond':
        color = const Color(0xFF0EA5E9);
        break;
      case 'gold':
        color = const Color(0xFFF59E0B);
        break;
      case 'silver':
        color = const Color(0xFF64748B);
        break;
      default:
        color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.grey.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLocked
              ? Colors.grey.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: isLocked ? Colors.grey : color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTacticalBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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

  Future<void> _openCourse(CourseModel course) async {
    if (course.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.security_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'UPGRADE TO ${course.minTier.toUpperCase()} TO UNLOCK',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW PLANS',
            textColor: const Color(0xFF4ECDC4),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.subscriptionPlans),
          ),
        ),
      );
      return;
    }

    // Update progress when course is accessed
    try {
      await ApiClient.post(
        '${ApiEndpoints.courses}/${course.id}/progress',
        {
          'progress_percent': course.progressPercent > 0 ? course.progressPercent : 5,
          'is_completed': course.isCompleted,
        },
        requiresAuth: true,
      );
      // Reload to update progress
      if (mounted) _loadData();
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }

    if (course.url != null && course.url!.isNotEmpty) {
      // Open URL in browser or webview
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.open_in_new_rounded, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Opening: ${course.title}'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: const Color(0xFF4ECDC4),
            onPressed: () {
              // You can use url_launcher package here
              // launchUrl(Uri.parse(course.url!));
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course content coming soon...')),
      );
    }
  }
}
