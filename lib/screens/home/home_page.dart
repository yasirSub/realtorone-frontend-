import 'package:flutter/material.dart';
import 'dart:convert';
import '../../api/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'growth_report_widget.dart';
import 'home_activity_log_widget.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/elite_loader.dart';
import '../../services/push_notification_service.dart';
import 'notifications_history_page.dart';
import '../../routes/app_routes.dart';
import 'home_webinar_carousel.dart';
import '../../utils/responsive_helper.dart';
import '../../theme/realtorone_brand.dart';
import '../../widgets/marquee_text.dart';
import '../../services/app_preferences_service.dart';
import '../../services/app_runtime_config_service.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenActivitiesTab});

  /// Switches bottom nav to Activities and opens BELIEF (0) or FOCUS (1).
  final void Function(int activitiesTabIndex, {int? revenueSubTab})?
  onOpenActivitiesTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _homeStreak = 0;
  String? _homeBannerMessage;
  String _homeBannerType = 'info';
  int _todayTotal = 0;
  int _todayDone = 0;
  int _hotLeads = 0;
  int _atRiskFour = 0;
  int _nurtureCount = 0;
  bool _weeklyReportsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppPreferences();
    AppPreferencesService.weeklyReportsEnabled.addListener(
      _onWeeklyReportsPreferenceChanged,
    );
    PushNotificationService.markAllAsRead();
  }

  @override
  void dispose() {
    AppPreferencesService.weeklyReportsEnabled.removeListener(
      _onWeeklyReportsPreferenceChanged,
    );
    super.dispose();
  }

  Future<void> _loadAppPreferences() async {
    await AppPreferencesService.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _weeklyReportsEnabled = AppPreferencesService.weeklyReportsEnabled.value;
    });
  }

  void _onWeeklyReportsPreferenceChanged() {
    if (!mounted) return;
    final enabled = AppPreferencesService.weeklyReportsEnabled.value;
    if (_weeklyReportsEnabled == enabled) return;
    setState(() => _weeklyReportsEnabled = enabled);
  }

  Future<void> _loadUserData({bool forceAppConfig = false}) async {
    try {
      final results = await Future.wait([
        ApiClient.get('/user/profile', requiresAuth: true, useCache: false),
        ApiClient.get(
          '/activities/progress',
          requiresAuth: true,
          useCache: false,
        ),
        ApiClient.get(
          '/tasks/today',
          requiresAuth: true,
          useCache: true,
          cacheMaxAge: const Duration(minutes: 10),
        ),
        ApiClient.get('/results?type=hot_lead', requiresAuth: true),
        AppRuntimeConfigService.refresh(force: forceAppConfig),
      ]);

      final response = results[0] as Map<String, dynamic>;
      final progressRes = results[1] as Map<String, dynamic>;
      final tasksRes = results[2] as Map<String, dynamic>;
      final hotLeadRes = results[3] as Map<String, dynamic>;
      final configData = results[4];

      String? bannerMessage;
      String bannerType = 'info';
      if (configData != null &&
          _configFlagEnabled(configData['home_banner_enabled'])) {
        final raw = configData['home_banner_message']?.toString().trim();
        if (raw != null && raw.isNotEmpty) {
          bannerMessage = raw;
          bannerType = _normalizeBannerType(configData['home_banner_type']);
        }
      }

      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
            _homeStreak = _resolveHomeStreak(
              profile: response['data'],
              progress: progressRes['data'],
            );
          } else {
            _homeStreak = 0;
          }
          _homeBannerMessage = bannerMessage;
          _homeBannerType = bannerType;
          _applyTaskStats(tasksRes);
          _applyPipelineStats(hotLeadRes);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _resolveHomeStreak({dynamic profile, dynamic progress}) {
    int? parse(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    int? fromMap(dynamic m, String key) {
      if (m is! Map) return null;
      return parse(m[key]);
    }

    final streak =
        fromMap(profile, 'app_open_streak') ??
        fromMap(progress, 'app_open_streak') ??
        fromMap(progress, 'current_streak') ??
        fromMap(profile, 'current_streak') ??
        0;
    return streak < 0 ? 0 : streak;
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
            final callA =
                int.tryParse((cc['call_attempt'] ?? '0').toString()) ?? 0;
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
    final pct = _todayTotal == 0
        ? 0
        : ((_todayDone / _todayTotal) * 100).round();
    final progressValue = _todayTotal == 0 ? 0.0 : (_todayDone / _todayTotal);
    final onOpenTasks = widget.onOpenActivitiesTab != null
        ? () => widget.onOpenActivitiesTab!(0)
        : () => Navigator.pushNamed(context, AppRoutes.activities);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final tileSurface = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFF8FAFC);
    final tileBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    const accent = Color(0xFF667EEA);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      RealtorOneBrand.seed.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.checklist_rtl_rounded,
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeTasksProgress(_todayDone, _todayTotal, pct),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.homeOpenFocusHint,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progressValue,
                      strokeWidth: 5,
                      backgroundColor:
                          isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(accent),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _focusMetricTile(
                  label: l10n.homeHotLeads,
                  value: _hotLeads,
                  color: const Color(0xFF2563EB),
                  icon: Icons.local_fire_department_rounded,
                  surface: tileSurface,
                  border: tileBorder,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _focusMetricTile(
                  label: l10n.homeAtRisk4x,
                  value: _atRiskFour,
                  color: const Color(0xFFEF4444),
                  icon: Icons.warning_amber_rounded,
                  surface: tileSurface,
                  border: tileBorder,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _focusMetricTile(
                  label: l10n.homeNurture,
                  value: _nurtureCount,
                  color: const Color(0xFFEA580C),
                  icon: Icons.eco_rounded,
                  surface: tileSurface,
                  border: tileBorder,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _focusMetricTile(
                  label: l10n.homeRemaining,
                  value: remaining,
                  color: const Color(0xFF10B981),
                  icon: Icons.pending_actions_rounded,
                  surface: tileSurface,
                  border: tileBorder,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenTasks,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      RealtorOneBrand.seed.withValues(alpha: isDark ? 0.22 : 0.14),
                      accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: RealtorOneBrand.seed.withValues(alpha: 0.28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.homeOpenTasks,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _todayTotal == 0
                                  ? 'Start your daily pipeline work'
                                  : remaining == 0
                                      ? 'All tasks complete — great job'
                                      : '$remaining task${remaining == 1 ? '' : 's'} left today',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: RealtorOneBrand.seed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: RealtorOneBrand.seed.withValues(
                                alpha: isDark ? 0.28 : 0.22,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusMetricTile({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
    required Color surface,
    required Color border,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(AppLocalizations l10n, bool isDark) {
    if (!_weeklyReportsEnabled && widget.onOpenActivitiesTab == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_weeklyReportsEnabled) const GrowthReportWidget(),
        if (widget.onOpenActivitiesTab != null) ...[
          const SizedBox(height: 12),
          _buildFocusShortcut(l10n, isDark),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusShortcut(AppLocalizations l10n, bool isDark) {
    final open = widget.onOpenActivitiesTab!;
    const accent = RealtorOneBrand.accentTeal;
    final surface = isDark ? RealtorOneBrand.surfaceDark : Colors.white;
    final border = isDark ? const Color(0xFF334155) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => open(1, revenueSubTab: 0),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.06 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.hub_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeOpenPipeline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.homeOpenFocusHint,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: accent.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsHistoryPage()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final showPerformanceSection =
        _weeklyReportsEnabled || widget.onOpenActivitiesTab != null;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadUserData(forceAppConfig: true),
            color: const Color(0xFF667eea),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: _homeBannerMessage != null ? 178 : 154,
                  pinned: true,
                  stretch: false,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                  elevation: 0,
                  centerTitle: false,
                  title: const SizedBox.shrink(),
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
                                icon: const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 7,
                                  top: 7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : unread.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
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
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
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
                                Color(0xFF334155),
                                Color(0xFF0F172A),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                42,
                                20,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _userData?['name']
                                                        ?.toString() ??
                                                    l10n.homeGuestName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 31,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.4,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(
                                              Icons
                                                  .local_fire_department_rounded,
                                              size: 18,
                                              color: Color(0xFFF59E0B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_homeStreak < 0 ? 0 : _homeStreak}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                                  const SizedBox(height: 8),
                                  if (_homeBannerMessage != null) ...[
                                    const SizedBox(height: 5),
                                    _buildCompactHomeAnnouncement(),
                                  ] else ...[
                                    const SizedBox(height: 5),
                                    Text(
                                          l10n.homePerformanceReady,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            height: 1.3,
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(delay: 550.ms)
                                        .slideY(begin: 0.1),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: ResponsiveHelper.contentPadding(
                    context,
                    top: 4,
                    bottom: 120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ResponsiveHelper.constrainWidth(
                        child: Column(
                          children: [
                            const HomeWebinarCarousel()
                                .animate()
                                .fadeIn(delay: 260.ms)
                                .slideY(begin: 0.1),
                            const SizedBox(height: 18),
                            if (showPerformanceSection) ...[
                              _buildSectionHeader(
                                icon: Icons.auto_graph_rounded,
                                title: _weeklyReportsEnabled
                                    ? l10n.growthPotential
                                    : l10n.homeOpenPipeline,
                                isDark: isDark,
                              ),
                              _buildPerformanceSection(l10n, isDark)
                                  .animate()
                                  .fadeIn(delay: 300.ms)
                                  .slideY(begin: 0.1),
                              const SizedBox(height: 18),
                            ],
                            _buildSectionHeader(
                              icon: Icons.bolt_rounded,
                              title: l10n.activityLogTitle,
                              isDark: isDark,
                            ),
                            HomeActivityLogWidget(
                                  onOpenActivities:
                                      widget.onOpenActivitiesTab != null
                                      ? () => widget.onOpenActivitiesTab!(0)
                                      : null,
                                )
                                .animate()
                                .fadeIn(delay: 420.ms)
                                .slideY(begin: 0.1),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              icon: Icons.insights_rounded,
                              title: l10n.homeTodayFocus,
                              isDark: isDark,
                            ),
                            Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.14 : 0.035,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: _overviewCard(l10n, isDark),
                                )
                                .animate()
                                .fadeIn(delay: 520.ms)
                                .slideY(begin: 0.1),
                          ],
                        ),
                      ),
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

  static bool _configFlagEnabled(dynamic value) {
    if (value == true || value == 1) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static String _normalizeBannerType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? 'info';
    if (raw == 'news' || raw == 'warning' || raw == 'info') return raw;
    return 'info';
  }

  _HomeAnnouncementVisual _announcementVisualFor(String type) {
    switch (_normalizeBannerType(type)) {
      case 'news':
        return const _HomeAnnouncementVisual(
          accent: Color(0xFF0EA5E9),
          fill: Color(0xFF082F49),
          icon: Icons.campaign_outlined,
          label: 'News',
        );
      case 'warning':
        return const _HomeAnnouncementVisual(
          accent: Color(0xFFF59E0B),
          fill: Color(0xFF451A03),
          icon: Icons.warning_amber_rounded,
          label: 'Warning',
        );
      default:
        return const _HomeAnnouncementVisual(
          accent: Color(0xFF8B5CF6),
          fill: Color(0xFF2E1065),
          icon: Icons.info_outline_rounded,
          label: 'Info',
        );
    }
  }

  Widget _buildCompactHomeAnnouncement() {
    final message = _homeBannerMessage ?? '';
    final visual = _announcementVisualFor(_homeBannerType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: visual.fill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: visual.accent.withValues(alpha: 0.85),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(visual.icon, size: 14, color: visual.accent),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              visual.label.toUpperCase(),
              style: TextStyle(
                color: visual.accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 18,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarqueeText(
                  text: message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
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

class _HomeAnnouncementVisual {
  const _HomeAnnouncementVisual({
    required this.accent,
    required this.fill,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final Color fill;
  final IconData icon;
  final String label;
}
