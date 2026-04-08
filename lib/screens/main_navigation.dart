import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home/home_page.dart';
import 'activities/activities_page.dart';
import 'learning/learning_page.dart';
import 'profile/profile_page.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../l10n/app_localizations.dart';
import '../theme/realtorone_brand.dart';

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
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const String _tourSeenKey = 'hasSeenAppTourV2';
  static const String _tourSeenLegacyKey = 'hasSeenAppTourV1';
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
    _activitiesTourSync = ValueNotifier<ActivitiesTourSync?>(null);
    _tourActive = ValueNotifier<bool>(false);
    _pages = [
      const HomePage(),
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
    _maybeShowTourGuide();
  }

  @override
  void dispose() {
    _activitiesTourSync.dispose();
    _tourActive.dispose();
    super.dispose();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTourGuide();
    });
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
    return Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height)
        .inflate(inflate);
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
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.52),
        ),
      ),
    );
  }

  /// Spotlight mask + tooltip anchored above the bottom nav (see-through hole
  /// on the active tab so it stays tappable like your reference).
  Widget _buildTourSpotlightLayer() {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final hole = _tourHighlightRect()?.intersect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    final navBox = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    final double navTop = navBox != null && navBox.hasSize
        ? navBox.localToGlobal(Offset.zero).dy
        : size.height - 88;
    final double tooltipBottom =
        math.max(pad.bottom + 8, size.height - navTop + 12);

    final l10n = AppLocalizations.of(context)!;
    final themeWrapper = Semantics(
      label: l10n.tourSemantics(
        _tourStep + 1,
        _kTourStepConfigs.length,
        _tourTitleForStep(_tourStep, l10n),
      ),
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: false,
        ),
        child: _buildTourCard(),
      ),
    );

    final children = <Widget>[
      if (hole == null)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        )
      else ...[
        _dimRegion(
          left: 0,
          top: 0,
          width: size.width,
          height: math.max(0, hole.top),
        ),
        _dimRegion(
          left: 0,
          top: hole.bottom,
          width: size.width,
          height: math.max(0, size.height - hole.bottom),
        ),
        _dimRegion(
          left: 0,
          top: hole.top,
          width: math.max(0, hole.left),
          height: hole.height,
        ),
        _dimRegion(
          left: hole.right,
          top: hole.top,
          width: math.max(0, size.width - hole.right),
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
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: RealtorOneBrand.accentTeal,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RealtorOneBrand.accentTeal.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      if (hole != null &&
          (_tourStep == 1 || _tourStep == 2) &&
          hole.bottom <= navTop - 32)
        Positioned(
          left: 16,
          right: 16,
          top: (hole.bottom + 14).clamp(
            pad.top + 8.0,
            math.max(pad.top + 48, navTop - 100),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(140, navTop - hole.bottom - 16),
            ),
            child: SingleChildScrollView(child: themeWrapper),
          ),
        )
      else
        Positioned(
          left: 16,
          right: 16,
          bottom: tooltipBottom,
          child: themeWrapper,
        ),
    ];

    return Stack(fit: StackFit.expand, children: children);
  }

  Widget _buildTourCard() {
    final l10n = AppLocalizations.of(context)!;
    final isLast = _tourStep == _kTourStepConfigs.length - 1;
    final step = _kTourStepConfigs[_tourStep];
    final progress = (_tourStep + 1) / _kTourStepConfigs.length;
    final title = _tourTitleForStep(_tourStep, l10n);
    final body = _tourBodyForStep(_tourStep, l10n);

    Future<void> skipTour() => _completeTourFlow();

    Future<void> advanceTour() async {
      if (!isLast) {
        _setTourStep(_tourStep + 1);
        return;
      }
      await _completeTourFlow();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xE6162E5C),
                Color(0xE60B1224),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tourQuickLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(_kTourStepConfigs.length, (i) {
                            final done = i < _tourStep;
                            final active = i == _tourStep;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: (done || active)
                                        ? RealtorOneBrand.splashGradient
                                        : null,
                                    color: (done || active)
                                        ? null
                                        : Colors.white.withValues(alpha: 0.12),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: RealtorOneBrand.accentTeal
                                                  .withValues(alpha: 0.45),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: skipTour,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.08),
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(40, 40),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: l10n.tourSkipTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: RealtorOneBrand.splashGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: RealtorOneBrand.accentTeal.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(step.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tourStepCounter(
                            _tourStep + 1,
                            _kTourStepConfigs.length,
                          ),
                          style: TextStyle(
                            color: RealtorOneBrand.accentTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: RealtorOneBrand.splashGradient,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _tourStep > 0
                    ? TextButton(
                        onPressed: () => _setTourStep(_tourStep - 1),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.tourBack,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : const SizedBox(height: 2),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: advanceTour,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: RealtorOneBrand.splashGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: RealtorOneBrand.accentIndigo.withValues(
                              alpha: 0.38,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isLast ? l10n.tourGetStarted : l10n.tourContinue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: skipTour,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white38,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  l10n.tourSkipEntire,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                            _buildNavItem(2, Icons.school_rounded, l10n.navLearn),
                            _buildNavItem(3, Icons.person_rounded, l10n.navProfile),
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
      onTap: () => setState(() => _currentIndex = index),
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
