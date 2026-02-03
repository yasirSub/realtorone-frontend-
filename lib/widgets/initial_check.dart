import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../routes/app_routes.dart';
import 'dart:math' as math;

class InitialCheck extends StatefulWidget {
  const InitialCheck({super.key});

  @override
  State<InitialCheck> createState() => _InitialCheckState();
}

class _InitialCheckState extends State<InitialCheck>
    with TickerProviderStateMixin {
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _animateProgress();
  }

  Future<void> _animateProgress() async {
    for (int i = 0; i <= 100; i += 2) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 25));
      setState(() => _loadingProgress = i);
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Splash duration
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      return;
    }

    if (token == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    try {
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      if (mounted) {
        final isSuccess =
            response['success'] == true || response['status'] == 'ok';

        if (isSuccess) {
          final userData = response['data'] ?? response['user'] ?? response;
          final hasBasicProfile =
              userData['name'] != null && userData['email'] != null;

          if (hasBasicProfile) {
            Navigator.pushReplacementNamed(context, AppRoutes.main);
            return;
          }

          final isProfileComplete = userData['is_profile_complete'] == true;
          if (!isProfileComplete) {
            Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
            return;
          }

          final hasDiagnosis = userData['has_completed_diagnosis'] == true;
          if (!hasDiagnosis) {
            Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
            return;
          }

          Navigator.pushReplacementNamed(context, AppRoutes.main);
        } else {
          await ApiClient.clearToken();
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Deep slate
              Color(0xFF1E293B), // Slate
              Color(0xFF334155), // Lighter slate
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated gradient mesh
            ...List.generate(3, (index) {
              return Positioned(
                    top: index == 0 ? -100 : null,
                    bottom: index == 2 ? -100 : null,
                    left: index == 1 ? -150 : null,
                    right: index == 0 ? -150 : null,
                    child: _buildGradientOrb(
                      [const Color(0xFF667eea), const Color(0xFF764ba2)][index %
                          2],
                      [400.0, 350.0, 450.0][index],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveX(
                    begin: -20,
                    end: 20,
                    duration: Duration(seconds: 4 + index),
                  )
                  .moveY(
                    begin: -15,
                    end: 15,
                    duration: Duration(seconds: 5 + index),
                  );
            }),

            // Floating particles
            ...List.generate(20, (index) {
              return Positioned(
                    top: (index * 50.0) % MediaQuery.of(context).size.height,
                    left: (index * 30.0) % MediaQuery.of(context).size.width,
                    child: _buildParticle(),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 2.seconds)
                  .then()
                  .moveY(
                    begin: 0,
                    end: -100,
                    duration: Duration(seconds: 8 + index % 4),
                  )
                  .fadeOut();
            }),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),

                  // Logo container with premium glassmorphism
                  Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF667eea,
                              ).withValues(alpha: 0.3),
                              blurRadius: 60,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Center(
                          child:
                              Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFF8F9FA),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF667eea,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 30,
                                          spreadRadius: -5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 42,
                                      color: Color(0xFF667eea),
                                    ),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .rotate(
                                    begin: -0.02,
                                    end: 0.02,
                                    duration: 2.seconds,
                                  )
                                  .scale(
                                    begin: const Offset(0.98, 0.98),
                                    end: const Offset(1.02, 1.02),
                                    duration: 2.seconds,
                                  ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        curve: Curves.easeOutBack,
                        duration: 1.2.seconds,
                      ),

                  const SizedBox(height: 48),

                  // Brand name with refined typography
                  ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFE0E7FF)],
                        ).createShader(bounds),
                        child: const Text(
                          'REALTORONE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            height: 1,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 1.seconds)
                      .slideY(begin: 0.3, curve: Curves.easeOutQuart)
                      .then(delay: 2.seconds)
                      .shimmer(duration: 2.seconds),

                  const SizedBox(height: 12),

                  // Tagline
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF667eea).withValues(alpha: 0.2),
                              const Color(0xFF764ba2).withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          'ELITE EXECUTION ENGINE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 800.ms)
                      .slideY(begin: 0.5, curve: Curves.easeOut),

                  const Spacer(),

                  // Loading section
                  Column(
                    children: [
                      // Progress bar
                      Container(
                        width: 200,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _loadingProgress / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF4ECDC4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667eea,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Status text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF4ECDC4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF4ECDC4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat())
                              .fadeIn(duration: 1.seconds)
                              .then()
                              .fadeOut(duration: 1.seconds),
                          const SizedBox(width: 12),
                          Text(
                            'INITIALIZING SYSTEM',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$_loadingProgress%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(delay: 1.2.seconds),

                  const SizedBox(height: 60),
                ],
              ),
            ),

            // Bottom badge
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SECURED BY QUANTUM ENCRYPTION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 REALTORONE PLATFORM',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 2.seconds),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildParticle() {
    return Container(
      width: 2,
      height: 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.3),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 4),
        ],
      ),
    );
  }
}
