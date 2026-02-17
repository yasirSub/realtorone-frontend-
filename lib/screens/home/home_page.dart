import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'growth_report_widget.dart';
import 'momentum_hub_widget.dart';
import 'daily_tasks_widget.dart';
import '../../api/activities_api.dart';
import '../../widgets/elite_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
            debugPrint('HOME_DEBUG: User Email: ${_userData?['email']}');
            debugPrint(
              'HOME_DEBUG: Membership Tier: ${_userData?['membership_tier']}',
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadUserData,
            color: const Color(0xFF667eea),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // MISSION CONTROL TOP BAR
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  stretch: true,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                  elevation: 0,
                  centerTitle: false,
                  title: const Text(
                    'REALTORONE',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Main Background Gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1E293B),
                                Color(0xFF334155),
                                Color(0xFF0F172A),
                              ],
                            ),
                          ),
                        ),

                        // Decorative Mesh / Grid Overlay
                        Opacity(
                          opacity: 0.1,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: const AssetImage(
                                  'assets/images/welcome.png',
                                ), // Using existing asset as a ghost texture
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.white.withValues(alpha: 0.1),
                                  BlendMode.dstIn,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Rocket Glyph
                        Positioned(
                          right: -40,
                          top: 60,
                          child:
                              Opacity(
                                    opacity: 0.05,
                                    child: const Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 300,
                                      color: Colors.white,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 1500.ms)
                                  .scale(begin: const Offset(0.8, 0.8)),
                        ),

                        // Content Layout
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 60, 28, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4ECDC4,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF4ECDC4,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: const Text(
                                            'SYSTEM ONLINE',
                                            style: TextStyle(
                                              color: Color(0xFF4ECDC4),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(delay: 200.ms)
                                        .slideX(begin: -0.2),
                                    const SizedBox(width: 12),
                                    Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white10,
                                            ),
                                          ),
                                          child: const Text(
                                            'SYNC: 100%',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(delay: 300.ms)
                                        .slideX(begin: -0.2),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                      'Elite Focus Requested,',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.5,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 400.ms)
                                    .slideY(begin: 0.1),
                                const SizedBox(height: 4),
                                Text(
                                      _userData?['name']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'REALTOR ALPHA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -2,
                                        height: 0.9,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 500.ms)
                                    .slideY(begin: 0.1),
                                const Spacer(),

                                // Tactical HUD Badge
                                GestureDetector(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.rewards,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 15,
                                            sigmaY: 15,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                24,
                                              ),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _buildHudItem(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  'STREAK',
                                                  '${_userData?['current_streak'] ?? 0} DAYS',
                                                  const Color(0xFFFFB347),
                                                ),
                                                Container(
                                                  width: 1,
                                                  height: 30,
                                                  color: Colors.white10,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                      ),
                                                ),
                                                _buildHudItem(
                                                  Icons.auto_awesome_rounded,
                                                  'POINTS',
                                                  '${_userData?['total_rewards'] ?? 0}',
                                                  const Color(0xFF4ECDC4),
                                                ),
                                                const Spacer(),
                                                const Icon(
                                                  Icons.arrow_forward_ios_rounded,
                                                  color: Colors.white24,
                                                  size: 14,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 700.ms)
                                    .scale(begin: const Offset(0.95, 0.95)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // MISSION COMMAND CENTER CONTENT
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. MOMENTUM INTELLIGENCE HUB
                      const MomentumHubWidget()
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: 32),

                      // 2. DAILY EXECUTION PRIORITIES
                      DailyTasksWidget(
                        onTaskUpdated: () {
                          _loadUserData();
                        },
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                      const SizedBox(height: 20),

                      // QUICK ACTIONS ROW
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.resultsTracker,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFFFF6B35,
                                      ).withValues(alpha: 0.15),
                                      const Color(
                                        0xFFFF6B35,
                                      ).withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF6B35,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Text('📊', style: TextStyle(fontSize: 28)),
                                    SizedBox(height: 6),
                                    Text(
                                      'Results',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Track & Log',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.badges,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.15),
                                      const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Text('🏆', style: TextStyle(fontSize: 28)),
                                    SizedBox(height: 6),
                                    Text(
                                      'Badges',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Collection',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),

                      // 3. GROWTH PULSE & ANALYTICS
                      const GrowthReportWidget()
                          .animate()
                          .fadeIn(delay: 700.ms)
                          .slideY(begin: 0.1),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading && _userData == null)
            EliteLoader.top(
              color: _getTierColor(_userData?['membership_tier']),
            ),
        ],
      ),
    );
  }

  Widget _buildHudItem(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Color _getTierColor(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF7C3AED);
      case 'platinum':
        return const Color(0xFFD946EF);
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'silver':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF64748B);
    }
  }
}
