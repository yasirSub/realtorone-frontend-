import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/activities_api.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import 'dart:ui';

class ReviewTrackerPage extends StatefulWidget {
  const ReviewTrackerPage({super.key});

  @override
  State<ReviewTrackerPage> createState() => _ReviewTrackerPageState();
}

class _ReviewTrackerPageState extends State<ReviewTrackerPage> {
  bool _isLoading = true;
  int _currentStreak = 0;
  int _todayPoints = 0;
  int _resultsScore = 0;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _todayActivities = [];
  int _tasksCompleted = 0;
  int _tasksTotal = 0;
  int _clientInteractions = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMomentum(),
      _loadResults(),
      _loadActivities(),
      _loadTasks(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadMomentum() async {
    try {
      final res = await ApiClient.get(
        ApiEndpoints.momentumDashboard,
        requiresAuth: true,
      );
      if (res['success'] == true && res['data'] != null) {
        final d = res['data'];
        setState(() {
          _resultsScore = (d['results'] ?? 0).toInt();
          _todayPoints = (d['momentum_score'] ?? 0).toInt();
          _currentStreak = (d['streak'] ?? 0).toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadResults() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.results, requiresAuth: true);
      if (res['success'] == true) {
        setState(() => _summary = res['summary'] ?? {});
      }
    } catch (_) {}
  }

  Future<void> _loadActivities() async {
    try {
      final res = await ActivitiesApi.getActivities();
      if (res['success'] == true) {
        final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
        int clientCount = 0;
        for (var a in list) {
          final type = (a['type'] ?? '').toString().toLowerCase();
          if (type.contains('client') ||
              type.contains('meeting') ||
              type.contains('follow')) {
            clientCount++;
          }
        }
        setState(() {
          _todayActivities = list;
          _clientInteractions = clientCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    try {
      final res = await UserApi.getTodayTasks();
      if (res['success'] == true) {
        final tasks = List<Map<String, dynamic>>.from(res['tasks'] ?? []);
        final completed = tasks
            .where((t) => t['is_completed'] == true || t['is_completed'] == 1)
            .length;
        setState(() {
          _tasksTotal = tasks.length;
          _tasksCompleted = completed;
        });
      }
    } catch (_) {}
  }

  int get _hotLeads => _summary['hot_leads'] ?? 0;
  int get _dealsClosed => _summary['deals_closed'] ?? 0;
  double get _commission => (_summary['total_commission'] ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)),
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'REVIEW TRACKER',
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
                              Icons.analytics_rounded,
                              size: 160,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                            child: Row(
                              children: [
                                _buildBadge(
                                  'STREAK: $_currentStreak',
                                  const Color(0xFFFFB347),
                                ),
                                const SizedBox(width: 10),
                                _buildBadge(
                                  'POINTS: $_todayPoints',
                                  const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                _buildBadge(
                                  'RESULTS: $_resultsScore/15',
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
              ],
              body: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF667eea),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildResultsTrackerSection(isDark),
                    const SizedBox(height: 24),
                    _buildLiveActivitySection(isDark),
                    const SizedBox(height: 24),
                    _buildLogResultButton(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildResultsTrackerSection(bool isDark) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'RESULTS TRACKER',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Max Score: 15',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildResultRow(
                isDark,
                '🔥 Hot Leads Added',
                '$_hotLeads',
                '+2 per lead (Cap 10)',
                const Color(0xFFFF6B35),
              ),
              const SizedBox(height: 12),
              _buildResultRow(
                isDark,
                '🤝 Deals Closed',
                '$_dealsClosed',
                '+8 per deal (Cap 16)',
                const Color(0xFF00D4AA),
              ),
              const SizedBox(height: 12),
              _buildResultRow(
                isDark,
                '💰 Commission Earned',
                '${_commission.toStringAsFixed(0)} AED',
                'No Daily Points',
                const Color(0xFFFFD700),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _buildResultRow(
    bool isDark,
    String label,
    String value,
    String hint,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                hint,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveActivitySection(bool isDark) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE ACTIVITY TRACKING',
                style: TextStyle(
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildLiveActivityCard(
                  isDark,
                  'Leads Created',
                  '$_hotLeads',
                  Icons.person_add_rounded,
                  const Color(0xFFFF6B35),
                  route: AppRoutes.resultsTracker,
                ),
                _buildLiveActivityCard(
                  isDark,
                  'Deals Created',
                  '$_dealsClosed',
                  Icons.handshake_rounded,
                  const Color(0xFF00D4AA),
                  route: AppRoutes.resultsTracker,
                ),
                _buildLiveActivityCard(
                  isDark,
                  'Activities Logged',
                  '${_todayActivities.length}',
                  Icons.check_circle_rounded,
                  const Color(0xFF667eea),
                  route: AppRoutes.activities,
                ),
                _buildLiveActivityCard(
                  isDark,
                  'Tasks Completed',
                  '$_tasksCompleted / $_tasksTotal',
                  Icons.task_alt_rounded,
                  const Color(0xFF10B981),
                  route: AppRoutes.activities,
                ),
                _buildLiveActivityCard(
                  isDark,
                  'Client Interactions',
                  '$_clientInteractions',
                  Icons.people_rounded,
                  const Color(0xFF9B59B6),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.05, end: 0, delay: 200.ms, curve: Curves.easeOut);
  }

  Widget _buildLiveActivityCard(
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? route,
  }) {
    return GestureDetector(
      onTap: () {
        if (route != null) {
          Navigator.pushNamed(context, route);
        } else if (label == 'Leads Created' || label == 'Deals Created') {
          Navigator.pushNamed(context, AppRoutes.resultsTracker);
        }
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogResultButton() {
    return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.resultsTracker),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_chart_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Log Result / View Full Pipeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms)
        .slideY(begin: 0.05, end: 0, delay: 400.ms, curve: Curves.easeOut);
  }
}
