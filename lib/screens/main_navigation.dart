import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home/home_page.dart';
import 'activities/activities_page.dart';
import 'learning/learning_page.dart';
import 'profile/profile_page.dart';
import 'dart:ui';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const ActivitiesPage(),
    const LearningPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        .withValues(alpha: 0.0),
                    (isDark ? const Color(0xFF020617) : Colors.white)
                        .withValues(alpha: 0.8),
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
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF0F172A))
                                  .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, 'HOME'),
                            _buildNavItem(
                              1,
                              Icons.check_circle_rounded,
                              'TASKS',
                            ),
                            _buildNavItem(2, Icons.school_rounded, 'LEARN'),
                            _buildNavItem(3, Icons.person_rounded, 'PROFILE'),
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
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? const Color(0xFF667eea)
        : Colors.white.withValues(alpha: 0.45);

    return GestureDetector(
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
                      color: const Color(0xFF667eea).withValues(alpha: 0.6),
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
