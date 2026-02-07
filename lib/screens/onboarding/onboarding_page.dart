import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../routes/app_routes.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'PRECISION\nEXECUTION',
      subtitle: 'OPERATING SYSTEM',
      description:
          'Calibrate your real estate career with military-grade diagnostics and AI-driven growth protocols.',
      assetPath: 'assets/images/onboarding_execution.png',
      gradient: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
    ),
    OnboardingData(
      title: 'TACTICAL\nANALYSIS',
      subtitle: 'DIAGNOSIS ENGINE',
      description:
          'Identify critical performance blockers: Lead Gen, Confidence, Closing, or Discipline.',
      assetPath: 'assets/images/onboarding_diagnosis.png',
      gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
    ),
    OnboardingData(
      title: 'MISSION\nREADY',
      subtitle: 'INITIATE PROTOCOL',
      description:
          'Discover your elite profile and execute a personalized dominance path tailored to your market.',
      assetPath: 'assets/images/onboarding_growth.png',
      gradient: [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Ultra Deep Slate
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Texture Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/welcome.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Tactical Grid Overlay
          IgnorePointer(
            child: CustomPaint(
              painter: GridPainter(color: Colors.white.withValues(alpha: 0.03)),
            ),
          ),

          // 3. Page View Content
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // 4. Mission Control Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BRIEFING IN PROGRESS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SEQUENCE 0${_currentPage + 1}',
                      style: TextStyle(
                        color: _pages[_currentPage].gradient[0],
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: const Text(
                    'SKIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: -0.2),

          // 5. Bottom Navigation Console
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Column(
              children: [
                // Premium Tactical Indicators (Slider)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: _currentPage == index ? 48 : 12,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? _pages[index].gradient[0]
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: _currentPage == index
                                ? [
                                    BoxShadow(
                                      color: _pages[index].gradient[0]
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        if (_currentPage == index)
                          Container(
                                width: 52,
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: _pages[index].gradient[0].withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.1, 1.2),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Strategic Action Button (Next Sequence)
                GestureDetector(
                  onTap: _nextPage,
                  child: Container(
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          _pages[_currentPage].gradient[0],
                          _pages[_currentPage].gradient[1].withValues(
                            alpha: 0.8,
                          ),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _pages[_currentPage].gradient[0].withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Button Inner Highlight
                        Positioned(
                          top: 2,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.4),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Button Content
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'INITIATE PLATFORM'
                                    : 'NEXT SEQUENCE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.black12,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  )
                                  .animate(onPlay: (c) => c.repeat())
                                  .moveX(
                                    begin: -2,
                                    end: 2,
                                    duration: 1.seconds,
                                    curve: Curves.easeInOut,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Data Container
          Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Atmospheric Outer Ring
                      Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: data.gradient[0].withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 20.seconds),

                      // The Illustration with specialized glow
                      Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: data.gradient[0].withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 80,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(120),
                              child: Image.asset(
                                data.assetPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                            begin: -10,
                            end: 10,
                            duration: 3.seconds,
                            curve: Curves.easeInOut,
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.05, 1.05),
                            duration: 5.seconds,
                          ),

                      // Scanning Line Overlay
                      Positioned(
                            top: 0,
                            child: Container(
                              width: 240,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    data.gradient[0].withValues(alpha: 0),
                                    data.gradient[0].withValues(alpha: 0.5),
                                    data.gradient[0].withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .moveY(begin: 30, end: 270, duration: 4.seconds),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 1.seconds)
              .scale(duration: 800.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 60),

          // Tactical Typography
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: data.gradient[0], width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: data.gradient[0],
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideX(),
                const SizedBox(height: 8),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            data.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 80), // Space for bottom navigation
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const double step = 40;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final String assetPath;
  final List<Color> gradient;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.assetPath,
    required this.gradient,
  });
}
