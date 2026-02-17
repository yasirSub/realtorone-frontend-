import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/learning_model.dart';
import '../../routes/app_routes.dart';
import '../../api/learning_api.dart';
import '../../widgets/skill_skeleton.dart';
import '../../widgets/elite_loader.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _userTier = 'Free';
  List<CourseModel> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch filtered courses from the new tier-aware endpoint
      final courseRes = await LearningApi.getCourses();
      if (courseRes['success'] == true) {
        final List<dynamic> data = courseRes['data'] ?? [];
        _courses = data.map((json) => CourseModel.fromJson(json)).toList();

        // Sort: Unlocked first, then by tier/id
        _courses.sort((a, b) {
          if (a.isLocked != b.isLocked) {
            return a.isLocked ? 1 : -1;
          }
          return a.id.compareTo(b.id);
        });

        _userTier = courseRes['user_tier'] ?? 'Free';
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
              : _courses.isEmpty
              ? _buildEmptyState()
              : _buildCoursesList(),
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

  Widget _buildCoursesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return _buildCourseCard(
          course,
        ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
      },
    );
  }

  Widget _buildCourseCard(CourseModel course) {
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
                child: Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.play_circle_fill_rounded,
                  color: isLocked ? Colors.grey : const Color(0xFF6366f1),
                  size: isLocked ? 24 : 32,
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

  void _openCourse(CourseModel course) {
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

    if (course.url != null && course.url!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accessing: ${course.url}'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blueprint details loading...')),
      );
    }
  }
}
