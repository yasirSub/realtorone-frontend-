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
      assetPath: 'assets/images/welcome.png',
      gradient: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
    ),
    OnboardingData(
      title: 'TACTICAL\nANALYSIS',
      subtitle: 'DIAGNOSIS ENGINE',
      description:
          'Identify critical performance blockers: Lead Gen, Confidence, Closing, or Discipline.',
      assetPath: 'assets/images/diagnosis.png',
      gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
    ),
    OnboardingData(
      title: 'MISSION\nREADY',
      subtitle: 'INITIATE PROTOCOL',
      description:
          'Discover your elite profile and execute a personalized dominance path tailored to your market.',
      assetPath: 'assets/images/growth.png',
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
      Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
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
          // Global Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/images/welcome.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Page View
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

          // Tactical Header (Skip)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 24,
            child: InkWell(
              onTap: _skip,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SKIP BRIEFING',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),

          // Bottom Command Center
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Tactical Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? _pages[_currentPage].gradient[0]
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: _currentPage == index
                            ? [
                                BoxShadow(
                                  color: _pages[_currentPage].gradient[0]
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Primary Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF020617),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                        elevation: 10,
                        shadowColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'INITIALIZE SYSTEM'
                                : 'NEXT SEQUENCE',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
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
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    data.gradient[0].withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: data.gradient[0].withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: data.gradient[0].withValues(alpha: 0.2),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset(data.assetPath, fit: BoxFit.contain)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 4.seconds,
                      ),
                ),
              ),
            ),
          ).animate().fadeIn().scale(
            duration: 800.ms,
            curve: Curves.easeOutBack,
          ),

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
