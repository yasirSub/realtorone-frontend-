import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../services/app_warm_cache_service.dart';
import 'home/home_page.dart';
import 'activities/activities_page.dart';
import 'learning/learning_page.dart';
import 'profile/profile_page.dart';
import 'dart:ui';
import '../l10n/app_localizations.dart';
import '../theme/realtorone_brand.dart';
import 'chatbot/reven_chat_overlay.dart';
import 'chatbot/reven_route_tracker.dart';
import '../routes/app_routes.dart';
import '../services/app_passcode_service.dart';
import '../services/app_version_gate_service.dart';
import '../services/push_notification_service.dart';

class _TourStepConfig {
  const _TourStepConfig({
    required this.icon,
    required this.navIndex,
    this.activitiesTabIndex,
    this.revenueSubTab,
  });

  final IconData icon;
  final int navIndex;
  final int? activitiesTabIndex;
  final int? revenueSubTab;
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.activitiesTabIndex,
    this.revenueSubTab,
  });

  final int initialIndex;
  final int? activitiesTabIndex;
  final int? revenueSubTab;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  static const String _tourSeenKey = 'hasSeenAppTourV2';
  static const String _tourSeenLegacyKey = 'hasSeenAppTourV1';
  static const String _dealRoomClientAddedKey = 'hasAddedDealRoomClient';
  int _currentIndex = 0;

  late final ValueNotifier<ActivitiesTourSync?> _activitiesTourSync;
  late final ValueNotifier<bool> _tourActive;
  late final List<Widget> _pages;

  bool _tourVisible = false;
  int _tourStep = 0;
  final List<GlobalKey> _navItemKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _navBarKey = GlobalKey();
  final GlobalKey _tasksSubconsciousTabKey = GlobalKey();
  final GlobalKey _tasksConsciousTabKey = GlobalKey();
  final GlobalKey _tasksDealRoomPillKey = GlobalKey();

  static const List<_TourStepConfig> _kTourStepConfigs = [
    _TourStepConfig(icon: Icons.home_rounded, navIndex: 0),
    _TourStepConfig(
      icon: Icons.nightlight_round,
      navIndex: 1,
      activitiesTabIndex: 0,
    ),
    _TourStepConfig(
      icon: Icons.hub_rounded,
      navIndex: 1,
      activitiesTabIndex: 1,
      revenueSubTab: 0,
    ),
    _TourStepConfig(icon: Icons.school_rounded, navIndex: 2),
    _TourStepConfig(icon: Icons.person_rounded, navIndex: 3),
  ];

  static String _tourTitleForStep(int step, AppLocalizations l10n) {
    return switch (step) {
      0 => l10n.tourWelcomeTitle,
      1 => l10n.tourSubconsciousTitle,
      2 => l10n.tourDealRoomTitle,
      3 => l10n.tourLearnTitle,
      4 => l10n.tourProfileTitle,
      _ => '',
    };
  }

  static String _tourBodyForStep(int step, AppLocalizations l10n) {
    return switch (step) {
      0 => l10n.tourWelcomeBody,
      1 => l10n.tourSubconsciousBody,
      2 => l10n.tourDealRoomBody,
      3 => l10n.tourLearnBody,
      4 => l10n.tourProfileBody,
      _ => '',
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppWarmCacheService.warmAfterLogin());
      final route = ModalRoute.of(context);
      if (route != null) {
        RevenRouteTracker.instance.update(route);
      }
    });
    _activitiesTourSync = ValueNotifier<ActivitiesTourSync?>(null);
    _tourActive = ValueNotifier<bool>(false);
    _currentIndex = widget.initialIndex;
    _pages = [
      HomePage(onOpenActivitiesTab: _openActivitiesTab),
      ActivitiesPage(
        tourSyncNotifier: _activitiesTourSync,
        tourActive: _tourActive,
        tourSubconsciousTabKey: _tasksSubconsciousTabKey,
        tourConsciousTabKey: _tasksConsciousTabKey,
        tourDealRoomClientsPillKey: _tasksDealRoomPillKey,
      ),
      const LearningPage(),
      const ProfilePage(),
    ];
    if (_currentIndex == 1 && widget.activitiesTabIndex != null) {
      _activitiesTourSync.value = ActivitiesTourSync(
        tabIndex: widget.activitiesTabIndex!,
        revenueSubTab: widget.revenueSubTab,
      );
    }
    _maybeShowTourGuide();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.handlePendingLaunchNavigation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activitiesTourSync.dispose();
    _tourActive.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock when the app is fully backgrounded — not on `inactive`
    // (Razorpay / Play Store / App Store sheets use inactive without leaving).
    if (state == AppLifecycleState.paused) {
      unawaited(AppPasscodeService.instance.noteBackgroundedNow());
    } else if (state == AppLifecycleState.resumed && mounted) {
      unawaited(AppVersionGate.enforceIfRequired(forceRefresh: true));
      if (AppPasscodeService.instance.hasPasscode &&
          !AppPasscodeService.instance.isLockSuppressed) {
      // Brief delay so payment sheets can call endSuppressLock first.
      Future<void>.delayed(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        final shouldLock = await AppPasscodeService.instance.shouldLockAfterResume();
        if (!mounted) return;
        if (!shouldLock ||
            AppPasscodeService.instance.isLockSuppressed) {
          return;
        }
        AppPasscodeService.instance.lock();
        Navigator.of(context).pushNamed(
          AppRoutes.appPasscodeLock,
          arguments: const {'popOnSuccess': true},
        );
      });
      }
    }
  }

  void _openActivitiesTab(int tabIndex, {int? revenueSubTab}) {
    setState(() => _currentIndex = 1);
    // Clear then re-set so repeated taps still switch tabs (ValueNotifier dedupes same value).
    _activitiesTourSync.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activitiesTourSync.value = ActivitiesTourSync(
        tabIndex: tabIndex,
        revenueSubTab: revenueSubTab,
      );
    });
  }

  void _applyTourStep(int index) {
    final step = _kTourStepConfigs[index];
    setState(() => _currentIndex = step.navIndex);
    if (step.navIndex == 1 && step.activitiesTabIndex != null) {
      _activitiesTourSync.value = ActivitiesTourSync(
        tabIndex: step.activitiesTabIndex!,
        revenueSubTab: step.revenueSubTab,
      );
    } else {
      _activitiesTourSync.value = null;
    }
  }

  Future<void> _maybeShowTourGuide() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tourSeenKey) != true &&
        (prefs.getBool(_tourSeenLegacyKey) ?? false)) {
      await prefs.setBool(_tourSeenKey, true);
    }
    final seen = prefs.getBool(_tourSeenKey) ?? false;
    if (seen || !mounted) return;

    bool hasDealRoomClient = prefs.getBool(_dealRoomClientAddedKey) ?? false;
    if (!hasDealRoomClient) {
      try {
        final statusRes = await ApiClient.get(
          ApiEndpoints.clientsStatus,
          requiresAuth: true,
        );
        hasDealRoomClient =
            statusRes['has_clients'] == true ||
            (statusRes['clients_count'] ?? 0) > 0;
        if (hasDealRoomClient) {
          await prefs.setBool(_dealRoomClientAddedKey, true);
        }
      } catch (_) {
        hasDealRoomClient = false;
      }
    }
    if (!hasDealRoomClient || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTourGuide();
    });
  }

  void _onNavTap(int index) {
    RevenChatOverlay.minimizeIfExpanded();
    setState(() => _currentIndex = index);
    _maybeShowTourGuide();
  }

  Future<void> _finishTour() async {
    _tourActive.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenKey, true);
  }

  /// Extra frames + short delay so nested Tasks tabs / Deal Room measure for spotlight.
  void _scheduleTourLayoutRefresh() {
    void tick() {
      if (mounted) setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        tick();
        Future<void>.delayed(const Duration(milliseconds: 72), () {
          if (mounted) tick();
        });
      });
    });
  }

  Future<void> _showTourGuide() async {
    if (!mounted) return;
    setState(() {
      _tourVisible = true;
      _tourStep = 0;
    });
    _tourActive.value = true;
    _applyTourStep(0);
    _scheduleTourLayoutRefresh();
  }

  void _setTourStep(int next) {
    setState(() => _tourStep = next);
    _applyTourStep(next);
    _scheduleTourLayoutRefresh();
  }

  Future<void> _completeTourFlow() async {
    await _finishTour();
    if (mounted) setState(() => _tourVisible = false);
  }

  Rect? _rectFromKey(GlobalKey key, double inflate) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final o = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      o.dx,
      o.dy,
      box.size.width,
      box.size.height,
    ).inflate(inflate);
  }

  /// Prefers in-page Tasks controls when on those steps; falls back to bottom nav.
  Rect? _tourHighlightRect() {
    if (!_tourVisible) return null;
    switch (_tourStep) {
      case 1:
        return _rectFromKey(_tasksSubconsciousTabKey, 10) ??
            _rectFromKey(_navItemKeys[1], 10);
      case 2:
        return _rectFromKey(_tasksDealRoomPillKey, 12) ??
            _rectFromKey(_tasksConsciousTabKey, 10) ??
            _rectFromKey(_navItemKeys[1], 10);
      default:
        final idx = _kTourStepConfigs[_tourStep].navIndex;
        return _rectFromKey(_navItemKeys[idx], 10);
    }
  }

  static Widget _dimRegion({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    if (width <= 0 || height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.52)),
      ),
    );
  }

  /// Spotlight mask with tour card fixed above the bottom nav.
  Widget _buildTourSpotlightLayer() {
    final size = MediaQuery.sizeOf(context);
    final hole = _tourHighlightRect()?.intersect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    final navBox = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    final double navTop = navBox != null && navBox.hasSize
        ? navBox.localToGlobal(Offset.zero).dy
        : size.height - 88;
    const double cardGap = 12;
    final double cardBottom = size.height - navTop + cardGap;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hole == null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
          )
        else ...[
          _dimRegion(left: 0, top: 0, width: size.width, height: hole.top),
          _dimRegion(
            left: 0,
            top: hole.bottom,
            width: size.width,
            height: size.height - hole.bottom,
          ),
          _dimRegion(
            left: 0,
            top: hole.top,
            width: hole.left,
            height: hole.height,
          ),
          _dimRegion(
            left: hole.right,
            top: hole.top,
            width: size.width - hole.right,
            height: hole.height,
          ),
          Positioned(
            left: hole.left,
            top: hole.top,
            width: hole.width,
            height: hole.height,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: RealtorOneBrand.accentTeal.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RealtorOneBrand.accentTeal.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        Positioned(
          left: 16,
          right: 16,
          bottom: cardBottom,
          child: _buildTourCard()
              .animate(key: ValueKey(_tourStep))
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }

  Widget _buildTourCard() {
    final l10n = AppLocalizations.of(context)!;
    final isLast = _tourStep == _kTourStepConfigs.length - 1;
    final stepConfig = _kTourStepConfigs[_tourStep];
    final title = _tourTitleForStep(_tourStep, l10n);
    final body = _tourBodyForStep(_tourStep, l10n);
    final totalSteps = _kTourStepConfigs.length;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(totalSteps, (i) {
                        final active = i <= _tourStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(
                              right: i == totalSteps - 1 ? 0 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? RealtorOneBrand.accentTeal
                                  : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _completeTourFlow,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.tourStepCounter(_tourStep + 1, totalSteps),
                style: TextStyle(
                  color: RealtorOneBrand.accentTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      gradient: RealtorOneBrand.splashGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stepConfig.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: isLast
                      ? _completeTourFlow
                      : () => _setTourStep(_tourStep + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.accentIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  child: Text(
                    isLast ? l10n.tourGetStarted : l10n.tourContinue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_tourStep > 0)
                    TextButton(
                      onPressed: () => _setTourStep(_tourStep - 1),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.55),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.tourBack),
                    )
                  else
                    TextButton(
                      onPressed: _completeTourFlow,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.tourSkipEntire),
                    ),
                  if (_tourStep > 0)
                    TextButton(
                      onPressed: _completeTourFlow,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.tourSkipEntire),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),

          // Ultra-Premium Integrated Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? const Color(0xFF020617) : Colors.white)
                        .withOpacity(0.0),
                    (isDark ? const Color(0xFF020617) : Colors.white)
                        .withOpacity(0.8),
                    (isDark ? const Color(0xFF020617) : Colors.white),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        key: _navBarKey,
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF0F172A))
                                  .withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, l10n.navHome),
                            _buildNavItem(
                              1,
                              Icons.check_circle_rounded,
                              l10n.navTasks,
                            ),
                            _buildNavItem(
                              2,
                              Icons.school_rounded,
                              l10n.navLearn,
                            ),
                            _buildNavItem(
                              3,
                              Icons.person_rounded,
                              l10n.navProfile,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(
            begin: 1,
            duration: 800.ms,
            curve: Curves.easeOutQuart,
          ),

          if (_tourVisible) Positioned.fill(child: _buildTourSpotlightLayer()),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? const Color(0xFF667eea)
        : Colors.white.withOpacity(0.45);

    return GestureDetector(
      key: _navItemKeys[index],
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()..scale(isSelected ? 1.15 : 1.0),
              transformAlignment: Alignment.center,
              child: Icon(icon, color: color, size: isSelected ? 26 : 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 6),
              width: isSelected ? 14 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
