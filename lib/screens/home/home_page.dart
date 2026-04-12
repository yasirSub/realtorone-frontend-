import 'package:flutter/material.dart';
import 'dart:convert';
import '../../api/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'growth_report_widget.dart';
import 'home_activity_log_widget.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/elite_loader.dart';
import '../chatbot/chatbot_floating_button.dart';
import '../../services/push_notification_service.dart';
import 'notifications_history_page.dart';
import '../../routes/app_routes.dart';
import 'home_webinar_carousel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _todayTotal = 0;
  int _todayDone = 0;
  int _hotLeads = 0;
  int _atRiskFour = 0;
  int _nurtureCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    PushNotificationService.markAllAsRead();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      final tasksRes = await ApiClient.get('/tasks/today', requiresAuth: true);
      final hotLeadRes = await ApiClient.get(
        '/results?type=hot_lead',
        requiresAuth: true,
      );

      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
          }
          _applyTaskStats(tasksRes);
          _applyPipelineStats(hotLeadRes);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyTaskStats(Map<String, dynamic> res) {
    int total = 0;
    int done = 0;
    final data = res['data'];
    if (data is List) {
      total = data.length;
      for (final item in data) {
        if (item is Map &&
            (item['is_completed'] == true || item['completed'] == true)) {
          done++;
        }
      }
    } else if (data is Map) {
      final t = data['total'];
      final d = data['completed'];
      if (t is num) total = t.toInt();
      if (d is num) done = d.toInt();
      if (total == 0 && data['tasks'] is List) {
        final tasks = data['tasks'] as List;
        total = tasks.length;
        for (final item in tasks) {
          if (item is Map &&
              (item['is_completed'] == true || item['completed'] == true)) {
            done++;
          }
        }
      }
    }
    _todayTotal = total;
    _todayDone = done;
  }

  void _applyPipelineStats(Map<String, dynamic> res) {
    int hotLeads = 0;
    int atRisk = 0;
    int nurture = 0;
    final data = res['data'];
    if (data is List) {
      hotLeads = data.length;
      for (final c in data) {
        if (c is! Map) continue;
        final notesRaw = c['notes'];
        if (notesRaw is! String || notesRaw.trim().isEmpty) continue;
        try {
          final notes = jsonDecode(notesRaw);
          if (notes is! Map) continue;
          final cc = notes['cold_calling'];
          if (cc is Map) {
            final callA = int.tryParse((cc['call_attempt'] ?? '0').toString()) ?? 0;
            final waA = int.tryParse((cc['wa_attempt'] ?? '0').toString()) ?? 0;
            if ((callA > waA ? callA : waA) >= 4) atRisk++;
            final bucket = (cc['bucket'] ?? '').toString().toLowerCase();
            if (bucket == 'nurture_whatsapp' ||
                bucket == 'retargeting' ||
                bucket == 'stalled') {
              nurture++;
            }
          }
        } catch (_) {}
      }
    }
    _hotLeads = hotLeads;
    _atRiskFour = atRisk;
    _nurtureCount = nurture;
  }

  Widget _overviewCard(AppLocalizations l10n, bool isDark) {
    final remaining = (_todayTotal - _todayDone).clamp(0, _todayTotal);
    final pct = _todayTotal == 0 ? 0 : ((_todayDone / _todayTotal) * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeTodayFocus,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.homeTasksProgress(_todayDone, _todayTotal, pct),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _todayTotal == 0 ? 0 : (_todayDone / _todayTotal),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF667EEA)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(l10n.homeHotLeads, _hotLeads, const Color(0xFF2563EB)),
              _metricChip(l10n.homeAtRisk4x, _atRiskFour, const Color(0xFFEF4444)),
              _metricChip(l10n.homeNurture, _nurtureCount, const Color(0xFFEA580C)),
              _metricChip(l10n.homeRemaining, remaining, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.activities),
              child: Text(l10n.homeOpenTasks),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
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
                  title: Image.asset(
                    'assets/images/logo.png',
                    height: 32,
                    fit: BoxFit.contain,
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
                                tooltip: l10n.homeNotificationsTooltip,
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
                                  l10n.homeWelcomeBack,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5,
                                  ),
                                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['name']?.toString().toUpperCase() ??
                                      l10n.homeGuestName,
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
                                  l10n.homePerformanceReady,
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
                      const HomeWebinarCarousel().animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),
                      const SizedBox(height: 20),
                      const GrowthReportWidget().animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                      const SizedBox(height: 20),
                      const HomeActivityLogWidget().animate().fadeIn(delay: 420.ms).slideY(begin: 0.1),
                      const SizedBox(height: 20),
                      _overviewCard(l10n, isDark).animate().fadeIn(delay: 520.ms).slideY(begin: 0.1),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading && _userData == null) EliteLoader.top(color: _getTierColor(_userData?['membership_tier'])),
          const Positioned(right: 16, bottom: 140, child: ChatbotFloatingButton()),
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
