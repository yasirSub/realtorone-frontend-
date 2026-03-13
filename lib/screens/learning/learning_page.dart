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

  int _getTierWeight(String tier) {
    switch (tier.toLowerCase()) {
      case 'titan':
        return 3;
      case 'rainmaker':
        return 2;
      case 'consultant':
        return 1;
      case 'free':
        return 0;
      default:
        return 1; // Default to consultant for safety
    }
  }

  bool _isTierUnlocked(String requiredTier) {
    return _getTierWeight(_userTier) >= _getTierWeight(requiredTier);
  }

  String _resolveAssetUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final host = ApiEndpoints.baseUrl.replaceAll('/api', '');
    if (trimmed.startsWith('/')) {
      return '$host$trimmed';
    }

    return '$host/storage/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // MISSION CONTROL VAULT HEADER
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF020617)],
                      ),
                    ),
                  ),
                  // HUD BARS
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTacticalBadge(
                                'KNOWLEDGE VAULT',
                                const Color(0xFF4ECDC4).withOpacity(0.8),
                              ),
                              _buildTacticalBadge(
                                _userTier.toUpperCase(),
                                const Color(0xFFFFB347),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'UNLOCKED STRATEGY VAULT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'TIERED ASSETS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6366F1),
              child: _isLoading
                  ? const Center(child: EliteLoader())
                  : _buildTieredList(),
            ),
          ),
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
            color: Colors.grey.withOpacity(0.3),
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

  Widget _buildTieredList() {
    final List<String> tiers = ['Consultant', 'Rainmaker', 'Titan'];

    // Gather all courses from all modules
    final allCourses = <CourseModel>[];
    for (var module in _modules) {
      allCourses.addAll(module.courses);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      itemCount: tiers.length,
      itemBuilder: (context, index) {
        final tier = tiers[index];

        // Filter courses by their OWN minTier property
        final tierCourses = allCourses
            .where((c) => c.minTier.toLowerCase() == tier.toLowerCase())
            .toList();

        if (tierCourses.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TIER HEADER (The User wants Tiers as the separation)
            _buildTierSectionHeader(tier),
            const SizedBox(height: 12),
            // Courses under this Tier
            ...tierCourses.map((course) {
              return _buildCourseCard(course, _getTierColor(tier));
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'titan':
        return const Color(0xFFF59E0B);
      case 'rainmaker':
        return const Color(0xFF6366F1);
      case 'consultant':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366f1);
    }
  }

  Widget _buildTierSectionHeader(String tier) {
    final color = _getTierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            '${tier.toUpperCase()} LEVEL ASSETS',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradePrompt(String tierName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'UPGRADE TO ${tierName.toUpperCase()} TO UNLOCK',
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
  }

  Widget _buildCourseCard(CourseModel course, Color moduleColor) {
    final bool isLocked = course.isLocked && !_isTierUnlocked(course.minTier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 90, // Fixed height for absolute rendering stability
      decoration: BoxDecoration(
        color: isLocked ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openCourse(course),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Fixed Size Side Thumbnail
              Container(
                width: 100,
                height: 90,
                color: moduleColor.withOpacity(0.1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (course.thumbnailUrl != null &&
                        course.thumbnailUrl!.isNotEmpty)
                      Image.network(
                        _resolveAssetUrl(course.thumbnailUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey,
                            ),
                      )
                    else
                      Center(
                        child: Icon(
                          isLocked
                              ? Icons.lock_outline_rounded
                              : Icons.play_circle_fill_rounded,
                          color: moduleColor.withOpacity(0.4),
                          size: 32,
                        ),
                      ),
                    if (isLocked)
                      Container(
                        color: Colors.white.withOpacity(0.3),
                        child: const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF64748B),
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Course Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: isLocked
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTierPill(course.minTier, isLocked: isLocked),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        style: TextStyle(
                          color: isLocked ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 10,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isLocked && course.progressPercent > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: course.progressPercent / 100,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              moduleColor,
                            ),
                            minHeight: 2,
                          ),
                        ),
                      ],
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

  Widget _buildTierPill(String tier, {bool isLocked = false}) {
    Color color;
    switch (tier.toLowerCase()) {
      case 'titan':
        color = const Color(0xFFF59E0B); // Amber
        break;
      case 'rainmaker':
        color = const Color(0xFF6366F1); // Indigo
        break;
      case 'consultant':
        color = const Color(0xFF10B981); // Emerald
        break;
      default:
        color = const Color(0xFF64748B); // Slate
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLocked
              ? Colors.grey.withOpacity(0.2)
              : color.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: isLocked ? Colors.grey : color,
          fontSize: 7,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
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
    final bool isLocked = course.isLocked && !_isTierUnlocked(course.minTier);
    if (isLocked) {
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

    // Navigate to course curriculum
    Navigator.pushNamed(
      context,
      AppRoutes.courseCurriculum,
      arguments: {'courseId': course.id, 'courseTitle': course.title},
    );
  }
}
