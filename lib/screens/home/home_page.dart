import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'growth_report_widget.dart';
import 'home_activity_log_widget.dart';
import '../../widgets/elite_loader.dart';
import '../chatbot/chatbot_floating_button.dart';
import '../../services/push_notification_service.dart';
import 'notifications_history_page.dart';

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
    PushNotificationService.markAllAsRead();
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsHistoryPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadUserData,
            color: const Color(0xFF667eea),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  stretch: true,
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                  elevation: 0,
                  centerTitle: false,
                  title: const Text(
                    'REALTORONE',
                    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                  actions: [
                    ValueListenableBuilder<int>(
                      valueListenable: PushNotificationService.unreadCount,
                      builder: (context, unread, _) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                tooltip: 'Notifications',
                                onPressed: _openNotifications,
                                icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 7,
                                  top: 7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 18),
                                    child: Text(
                                      unread > 99 ? '99+' : unread.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)],
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: 0.1,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: const AssetImage('assets/images/welcome.png'),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.1), BlendMode.dstIn),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -40,
                          top: 36,
                          child: Opacity(
                            opacity: 0.05,
                            child: const Icon(Icons.rocket_launch_rounded, size: 220, color: Colors.white),
                          ).animate().fadeIn(duration: 1500.ms).scale(begin: const Offset(0.8, 0.8)),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 52, 28, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5,
                                  ),
                                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['name']?.toString().toUpperCase() ?? 'REALTOR ALPHA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 0.9,
                                  ),
                                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                                const SizedBox(height: 10),
                                Text(
                                  'Your performance report is ready.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const GrowthReportWidget().animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                      const SizedBox(height: 20),
                      const HomeActivityLogWidget().animate().fadeIn(delay: 420.ms).slideY(begin: 0.1),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading && _userData == null) EliteLoader.top(color: _getTierColor(_userData?['membership_tier'])),
          const Positioned(right: 16, bottom: 100, child: ChatbotFloatingButton()),
        ],
      ),
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
