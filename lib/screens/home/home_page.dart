import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'growth_report_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _tasksData;
  bool _isLoadingTasks = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodayTasks();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadTodayTasks() async {
    try {
      final response = await UserApi.getTodayTasks();
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _tasksData = response;
          }
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
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
              backgroundColor: const Color(0xFF1E293B),
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
                                        borderRadius: BorderRadius.circular(8),
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
                                        borderRadius: BorderRadius.circular(8),
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
                                    color: Colors.white.withValues(alpha: 0.5),
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
                            ClipRRect(
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
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildHudItem(
                                            Icons.local_fire_department_rounded,
                                            'STREAK',
                                            '12 DAYS',
                                            const Color(0xFFFFB347),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 30,
                                            color: Colors.white10,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                          ),
                                          _buildHudItem(
                                            Icons.auto_awesome_rounded,
                                            'BALANCE',
                                            '2,450 XP',
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

            // Dashboard Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const GrowthReportWidget(),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Today\'s Priorities'),
                  const SizedBox(height: 16),
                  _buildPremiumFocusCard()
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Quick Actions'),
                  const SizedBox(height: 16),
                  _buildQuickActionGrid(),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Recent Activity'),
                  const SizedBox(height: 16),
                  _buildActivityTimeline()
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .slideY(begin: 0.1),
                ]),
              ),
            ),
          ],
        ),
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

  Widget _buildSectionHeader(String title, {String? tag}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        if (tag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumFocusCard() {
    if (_isLoadingTasks) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
      );
    }

    final tasks = _tasksData?['tasks'] as List? ?? [];
    final completionRate = (_tasksData?['completion_rate'] ?? 0) / 100.0;

    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF4ECDC4),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No tasks for today',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Text(
                'HIGH ROI PROTOCOL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...tasks.map((task) {
            return _buildFocusListItem(
              task['title'] ?? 'Untitled Task',
              task['is_completed'] ?? false,
            );
          }).toList(),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ECDC4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusListItem(String title, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF4ECDC4) : Colors.white24,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: done ? Colors.white54 : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/belief-rewiring'),
            child: _buildActionItem(
              Icons.psychology_rounded,
              'Mindset',
              const Color(0xFFf093fb),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // TODO: Navigate to add deal page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Deal feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: _buildActionItem(
              Icons.add_business_rounded,
              'New Deal',
              const Color(0xFF667eea),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/reports'),
            child: _buildActionItem(
              Icons.analytics_rounded,
              'Reports',
              const Color(0xFF4ECDC4),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildActionItem(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          _buildActivityItem(
            'High-Stakes Call',
            'Emerald Hills - Followup',
            '2h ago',
            const Color(0xFF10B981),
          ),
          const Divider(height: 40, thickness: 0.5),
          _buildActivityItem(
            'Field Inspection',
            'Palm Jumeirah Villa',
            '5h ago',
            Colors.indigo,
          ),
          const Divider(height: 40, thickness: 0.5),
          _buildActivityItem(
            'Protocol Clear',
            'Morning Priming Complete',
            'Morning',
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String sub,
    String time,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
