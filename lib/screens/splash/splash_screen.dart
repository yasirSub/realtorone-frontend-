import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../api/api_client.dart';
import '../../routes/app_routes.dart';
import '../../services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  int _loadingProgress = 0;
  String _statusMessage = 'INITIALIZING SYSTEM';

  final List<String> _tacticalMessages = [
    'BOOTING STRATEGIC ENGINE',
    'SYNCING OPERATIONAL DATA',
    'CALIBRATING MINDSET PROTOCOLS',
    'OPTIMIZING EXECUTION PATHS',
    'ESTABLISHING SECURE UPLINK',
    'PREPARING ELITE DASHBOARD',
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _animateProgress();
  }

  Future<void> _animateProgress() async {
    for (int i = 0; i <= 100; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 15));
      setState(() {
        _loadingProgress = i;
        // Cycle messages based on progress
        int messageIndex = (i / (100 / _tacticalMessages.length)).floor();
        if (messageIndex < _tacticalMessages.length) {
          _statusMessage = _tacticalMessages[messageIndex];
        }
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Splash duration coordinated with animation - Reduced for speed
    await Future.delayed(const Duration(milliseconds: 1500));

    // Fetch remote app config (maintenance + min versions) before deciding navigation.
    try {
      final config = await _fetchAppConfig();
      if (!mounted) return;

      if (config.maintenanceEnabled) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.maintenance,
          arguments: {'message': config.maintenanceMessage},
        );
        return;
      }

      if (config.requiresUpdate) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.updateRequired,
          arguments: {
            'minVersion': config.minVersionForPlatform,
            'storeUrl': config.storeUrlForPlatform,
            'platformLabel': defaultTargetPlatform == TargetPlatform.iOS
                ? 'iOS'
                : 'Android',
          },
        );
        return;
      }
    } catch (e) {
      // Fail open: continue with normal flow if config cannot be fetched or parsed.
    }

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      return;
    }

    if (token == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    await PushNotificationService.syncTokenWithBackend();

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
            return;
          }

          Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
        } else {
          await ApiClient.clearToken();
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  Future<_AppRuntimeConfig> _fetchAppConfig() async {
    try {
      final response = await ApiClient.getPublic('/app-config');
      if (response is Map<String, dynamic>) {
        final data = (response['data'] as Map?) ?? <String, dynamic>{};
        final maintenanceEnabled = data['maintenance_enabled'] == true;
        final maintenanceMessage =
            (data['maintenance_message'] as String?) ?? '';
        final minAndroid =
            (data['min_android_version'] as String?)?.trim() ?? '';
        final minIos = (data['min_ios_version'] as String?)?.trim() ?? '';
        final androidStore =
            (data['android_store_url'] as String?)?.trim() ?? '';
        final iosStore = (data['ios_store_url'] as String?)?.trim() ?? '';

        final info = await PackageInfo.fromPlatform();
        final currentVersion = info.version;

        final bool isAndroid =
            defaultTargetPlatform == TargetPlatform.android;
        final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;

        final String minForPlatform = isAndroid
            ? minAndroid
            : isIos
                ? minIos
                : '';
        final String storeForPlatform = isAndroid
            ? androidStore
            : isIos
                ? iosStore
                : '';

        final requiresUpdate = minForPlatform.isNotEmpty &&
            _compareSemanticVersion(currentVersion, minForPlatform) < 0;

        return _AppRuntimeConfig(
          maintenanceEnabled: maintenanceEnabled,
          maintenanceMessage: maintenanceMessage,
          minAndroidVersion: minAndroid,
          minIosVersion: minIos,
          androidStoreUrl: androidStore,
          iosStoreUrl: iosStore,
          currentVersion: currentVersion,
          requiresUpdate: requiresUpdate,
          minVersionForPlatform: minForPlatform,
          storeUrlForPlatform: storeForPlatform,
        );
      }
    } catch (_) {
      // Swallow errors; app will continue with normal startup.
    }

    final info = await PackageInfo.fromPlatform();
    return _AppRuntimeConfig(
      maintenanceEnabled: false,
      maintenanceMessage: '',
      minAndroidVersion: '',
      minIosVersion: '',
      androidStoreUrl: '',
      iosStoreUrl: '',
      currentVersion: info.version,
      requiresUpdate: false,
      minVersionForPlatform: '',
      storeUrlForPlatform: '',
    );
  }

  int _compareSemanticVersion(String a, String b) {
    List<int> parseParts(String v) {
      return v.split('.').map((e) {
        final n = int.tryParse(e);
        return n ?? 0;
      }).toList();
    }

    final pa = parseParts(a);
    final pb = parseParts(b);
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
          ),

          // 2. Animated Ambient Orbs
          ...List.generate(4, (index) {
            return Positioned(
                  top: [-100.0, 400.0, 100.0, -200.0][index],
                  left: [-150.0, -100.0, 300.0, 200.0][index],
                  child: _buildGradientOrb(
                    [
                      const Color(0xFF6366F1),
                      const Color(0xFF4ECDC4),
                      const Color(0xFF8B5CF6),
                      const Color(0xFF3B82F6),
                    ][index],
                    [500.0, 400.0, 350.0, 600.0][index],
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(
                  begin: Offset.zero,
                  end: Offset(
                    [20.0, -30.0, 40.0, -10.0][index],
                    [30.0, 50.0, -20.0, 40.0][index],
                  ),
                  duration: Duration(seconds: 5 + index),
                  curve: Curves.easeInOut,
                );
          }),

          // 3. Scanline/CRT Overlay Effect
          IgnorePointer(
            child: Opacity(
              opacity: 0.05,
              child: ListView.builder(
                itemBuilder: (context, index) => Container(
                  height: 2,
                  color: index.isEven ? Colors.black : Colors.transparent,
                ),
              ),
            ),
          ),

          // 4. Main Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Premium Logo Core
                Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating ring
                          Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat())
                              .rotate(duration: 10.seconds),

                          // Secondary decorative ring
                          Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF4ECDC4,
                                    ).withValues(alpha: 0.1),
                                    width: 2,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  ),
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat())
                              .rotate(duration: 15.seconds, begin: 1, end: 0),

                          // Brand logo (replaces default rocket icon)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ),
                          )
                              .animate(
                                onPlay: (c) => c.repeat(reverse: true),
                              )
                              .scale(
                                begin: const Offset(0.96, 0.96),
                                end: const Offset(1.04, 1.04),
                                duration: 2.seconds,
                              )
                              .shimmer(
                                delay: 1.seconds,
                                duration: 2.seconds,
                              ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 1.seconds)
                    .scale(curve: Curves.easeOutBack),

                const Spacer(flex: 1),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Text(
                    'STRATEGIC EXECUTION INTERFACE',
                    style: TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5),

                const Spacer(flex: 3),

                // Tactical Loading Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    children: [
                      // Modern Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 2,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 2,
                            width:
                                (MediaQuery.of(context).size.width - 100) *
                                (_loadingProgress / 100),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4ECDC4)],
                              ),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Status & Percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            '$_loadingProgress%',
                            style: const TextStyle(
                              color: Color(0xFF4ECDC4),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 1.seconds),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // 5. Ambient Particles
          ...List.generate(15, (index) {
            return Positioned(
                  top: (index * 73.0) % MediaQuery.of(context).size.height,
                  left: (index * 137.0) % MediaQuery.of(context).size.width,
                  child: Container(
                    width: 1,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 1.seconds)
                .moveY(begin: 0, end: -50, duration: 5.seconds)
                .fadeOut(delay: 4.seconds);
          }),
        ],
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
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AppRuntimeConfig {
  _AppRuntimeConfig({
    required this.maintenanceEnabled,
    required this.maintenanceMessage,
    required this.minAndroidVersion,
    required this.minIosVersion,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.currentVersion,
    required this.requiresUpdate,
    required this.minVersionForPlatform,
    required this.storeUrlForPlatform,
  });

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final String minAndroidVersion;
  final String minIosVersion;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String currentVersion;
  final bool requiresUpdate;
  final String minVersionForPlatform;
  final String storeUrlForPlatform;
}

