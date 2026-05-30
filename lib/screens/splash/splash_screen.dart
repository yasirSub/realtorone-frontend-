import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../api/api_client.dart';
import '../../routes/app_routes.dart';
import '../../services/push_notification_service.dart';
import '../../services/support_contact_service.dart';
import '../../utils/version_utils.dart';

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
      if (!mounted) return;
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
    debugPrint('Splash: _checkLoginStatus started');
    final prefs = await SharedPreferences.getInstance();

    // --- Fresh Install Detection ---
    // On iOS, SharedPreferences can be restored from iCloud backup after reinstall.
    // To ensure a clean session on fresh install, we check a file in the temporary directory
    // which is NOT backed up and is cleared on uninstall.
    try {
      final tempDir = await getTemporaryDirectory();
      final installFlagFile = File('${tempDir.path}/install_flag.txt');
      if (!await installFlagFile.exists()) {
        debugPrint(
          'Splash: Fresh install detected (or cache cleared). Cleaning session.',
        );
        await ApiClient.clearToken();
        await prefs.clear();
        await installFlagFile.create();
      }
    } catch (e) {
      debugPrint('Splash: Error checking install flag: $e');
    }


    final token = prefs.getString('token');
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    debugPrint(
      'Splash: prefs loaded. Token: ${token != null ? "exists" : "null"}, hasSeenOnboarding: $hasSeenOnboarding',
    );

    // Splash duration coordinated with animation - Reduced for speed
    await Future.delayed(const Duration(milliseconds: 1500));

    debugPrint('Splash: fetching app config...');
    // Fetch remote app config (maintenance + min versions) before deciding navigation.
    try {
      final config = await _fetchAppConfig();
      if (!mounted) {
        debugPrint('Splash: not mounted after config fetch');
        return;
      }

      if (config.maintenanceEnabled) {
        debugPrint('Splash: maintenance enabled, redirecting');
        final args = await SupportContactService.maintenanceRouteArgs(
          message: config.maintenanceMessage,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.maintenance,
          arguments: args,
        );
        return;
      }

      if (config.serviceUnavailable) {
        debugPrint('Splash: app-config unavailable, redirecting to maintenance');
        final args = await SupportContactService.maintenanceRouteArgs(
          message:
              'We could not reach the RealtorOne service. Please try again shortly or contact support below.',
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.maintenance,
          arguments: args,
        );
        return;
      }

      if (config.requiresUpdate) {
        debugPrint('Splash: update required, redirecting');
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.updateRequired,
          arguments: {
            'minVersion': config.minVersionForPlatform,
            'storeUrl': config.storeUrlForPlatform,
            'apkUrl': config.apkUrl,
            'platformLabel': defaultTargetPlatform == TargetPlatform.iOS
                ? 'iOS'
                : 'Android',
          },
        );
        return;
      }
    } catch (e) {
      debugPrint('Splash: error fetching config: $e');
      // Fail open: continue with normal flow if config cannot be fetched or parsed.
    }

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      debugPrint('Splash: redirecting to onboarding');
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      return;
    }

    if (token == null) {
      debugPrint('Splash: redirecting to login');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    debugPrint('Splash: syncing push notification token...');
    await PushNotificationService.syncTokenWithBackend();
    debugPrint('Splash: push notification token synced');

    try {
      debugPrint('Splash: fetching user profile...');
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      debugPrint('Splash: profile fetched: $response');
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
              debugPrint('Splash: redirecting to profile setup');
              Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
              return;
            }

            final hasDiagnosis = userData['has_completed_diagnosis'] == true;
            if (!hasDiagnosis) {
              debugPrint('Splash: redirecting to diagnosis');
              Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
              return;
            }

            debugPrint('Splash: redirecting to main');
            Navigator.pushReplacementNamed(context, AppRoutes.main);
            return;
          }

          debugPrint('Splash: redirecting to profile setup (no basic profile)');
          Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
        } else {
          final statusCode = response['statusCode'];
          final message = (response['message'] ?? '').toString().toLowerCase();
          final isAuthError =
              statusCode == 401 ||
              message.contains('unauthorized') ||
              message.contains('token') ||
              message.contains('forbidden');

          if (isAuthError) {
            debugPrint('Splash: auth error, clearing token');
            await ApiClient.clearToken();
            if (mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
            return;
          }

          // Non-auth API failures should not force logout.
          debugPrint('Splash: API failure, redirecting to main anyway');
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      }
    } catch (e) {
      debugPrint('Splash: error checking login status: $e');
      final err = e.toString().toLowerCase();
      final isNetworkIssue =
          e is SocketException ||
          e is TimeoutException ||
          err.contains('socket') ||
          err.contains('timed out') ||
          err.contains('failed host lookup') ||
          err.contains('connection closed');

      if (mounted && isNetworkIssue) {
        debugPrint('Splash: network issue, proceeding to main');
        // Keep signed-in users in app on transient connectivity issues.
        Navigator.pushReplacementNamed(context, AppRoutes.main);
        return;
      }

      if (mounted) {
        debugPrint('Splash: generic error, returning to login');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  Future<_AppRuntimeConfig> _fetchAppConfig() async {
    try {
      final response = await ApiClient.getPublic(
        '/app-config?_=${DateTime.now().millisecondsSinceEpoch}',
      );
      final statusCode = response['statusCode'] as int? ?? 0;
      final serviceUnavailable = response['service_unavailable'] == true ||
          statusCode == 404 ||
          statusCode >= 502;
      if (serviceUnavailable) {
        return _AppRuntimeConfig.unavailable();
      }

      final data = (response['data'] as Map?) ?? <String, dynamic>{};
      if (data.isNotEmpty) {
        await SupportContactService.cacheFromAppConfig(
          Map<String, dynamic>.from(data),
        );
      }
      final maintenanceEnabled = data['maintenance_enabled'] == true ||
          data['maintenance_enabled'] == 1 ||
          data['maintenance_enabled']?.toString() == 'true';
      final maintenanceMessage = (data['maintenance_message'] as String?) ?? '';
      final minAndroid = (data['min_android_version'] as String?)?.trim() ?? '';
      final minIos = (data['min_ios_version'] as String?)?.trim() ?? '';
      final androidStore = (data['android_store_url'] as String?)?.trim() ?? '';
      final iosStore = (data['ios_store_url'] as String?)?.trim() ?? '';
      final apkUrl = (data['apk_url'] as String?)?.trim() ?? '';

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
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

      final versionControlEnabled = data['version_control_enabled'] != false &&
          data['version_control_enabled'] != 0 &&
          data['version_control_enabled']?.toString() != 'false';
      final requiresUpdate = versionControlEnabled &&
          minForPlatform.isNotEmpty &&
          compareSemanticVersions(currentVersion, minForPlatform) < 0;

      return _AppRuntimeConfig(
        maintenanceEnabled: maintenanceEnabled,
        maintenanceMessage: maintenanceMessage,
        serviceUnavailable: false,
        minAndroidVersion: minAndroid,
        minIosVersion: minIos,
        androidStoreUrl: androidStore,
        iosStoreUrl: iosStore,
        currentVersion: currentVersion,
        requiresUpdate: requiresUpdate,
        minVersionForPlatform: minForPlatform,
        storeUrlForPlatform: storeForPlatform,
        apkUrl: apkUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[app-config] failed to load or parse: $e');
      }
    }

    final info = await PackageInfo.fromPlatform();
    return _AppRuntimeConfig(
      maintenanceEnabled: false,
      maintenanceMessage: '',
      serviceUnavailable: false,
      minAndroidVersion: '',
      minIosVersion: '',
      androidStoreUrl: '',
      iosStoreUrl: '',
      currentVersion: info.version,
      requiresUpdate: false,
      minVersionForPlatform: '',
      storeUrlForPlatform: '',
      apkUrl: '',
    );
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
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(0.96, 0.96),
                                end: const Offset(1.04, 1.04),
                                duration: 2.seconds,
                              )
                              .shimmer(delay: 1.seconds, duration: 2.seconds),
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
    required this.serviceUnavailable,
    required this.minAndroidVersion,
    required this.minIosVersion,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.currentVersion,
    required this.requiresUpdate,
    required this.minVersionForPlatform,
    required this.storeUrlForPlatform,
    required this.apkUrl,
  });

  factory _AppRuntimeConfig.unavailable() {
    return _AppRuntimeConfig(
      maintenanceEnabled: false,
      maintenanceMessage: '',
      serviceUnavailable: true,
      minAndroidVersion: '',
      minIosVersion: '',
      androidStoreUrl: '',
      iosStoreUrl: '',
      currentVersion: '',
      requiresUpdate: false,
      minVersionForPlatform: '',
      storeUrlForPlatform: '',
      apkUrl: '',
    );
  }

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool serviceUnavailable;
  final String minAndroidVersion;
  final String minIosVersion;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String currentVersion;
  final bool requiresUpdate;
  final String minVersionForPlatform;
  final String storeUrlForPlatform;
  final String apkUrl;
}
