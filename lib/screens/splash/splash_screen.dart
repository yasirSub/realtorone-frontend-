import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
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
import '../../services/app_passcode_service.dart';

bool _configFlag(Map<dynamic, dynamic> data, String key, {required bool fallback}) {
  if (!data.containsKey(key)) return fallback;
  final value = data[key];
  return value != false && value != 0 && value?.toString() != 'false';
}

bool _versionControlEnabledForPlatform(Map<dynamic, dynamic> data) {
  final legacy = _configFlag(data, 'version_control_enabled', fallback: true);
  final android = _configFlag(
    data,
    'version_control_android_enabled',
    fallback: legacy,
  );
  final ios = _configFlag(
    data,
    'version_control_ios_enabled',
    fallback: legacy,
  );
  if (defaultTargetPlatform == TargetPlatform.android) return android;
  if (defaultTargetPlatform == TargetPlatform.iOS) return ios;
  return legacy;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _installMarkerPrefsKey = 'app_install_marker_v1';
  static const String _installMarkerFileName = 'install_marker_v1.txt';
  int _loadingProgress = 0;
  String _statusMessage = 'INITIALIZING SYSTEM';
  bool _didNavigate = false;

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

  void _navigateOnce(String routeName, {Object? arguments}) {
    if (!mounted || _didNavigate) return;
    _didNavigate = true;
    Navigator.pushReplacementNamed(
      context,
      routeName,
      arguments: arguments,
    );
  }

  Future<bool> _canBypassMaintenance(
    String? token, {
    List<String> testerIdentifiers = const [],
  }) async {
    if (token == null || token.isEmpty) return false;
    try {
      final response = await ApiClient.get('/user/profile', requiresAuth: true);
      final isSuccess = response['success'] == true || response['status'] == 'ok';
      if (!isSuccess) return false;
      final userData = response['data'] ?? response['user'] ?? response;
      if (userData is! Map) return false;
      final isAdmin = userData['is_admin'] == true;
      final isTestUser = userData['is_test_user'] == true;
      if (isAdmin || isTestUser) return true;

      final normalizedAllowList = testerIdentifiers
          .map((v) => v.trim().toLowerCase())
          .where((v) => v.isNotEmpty)
          .toSet();
      if (normalizedAllowList.isEmpty) return false;

      final email = (userData['email'] ?? '').toString().trim().toLowerCase();
      final mobile = (userData['mobile'] ?? '').toString().trim().toLowerCase();
      final phone = (userData['phone_number'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final userId = (userData['id'] ?? '').toString().trim().toLowerCase();

      return normalizedAllowList.contains(email) ||
          normalizedAllowList.contains(mobile) ||
          normalizedAllowList.contains(phone) ||
          normalizedAllowList.contains(userId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncInstallMarker(SharedPreferences prefs) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final markerFile = File('${supportDir.path}/$_installMarkerFileName');
      final hasFileMarker = await markerFile.exists();
      final hasPrefsMarker = prefs.getBool(_installMarkerPrefsKey) ?? false;

      if (!hasFileMarker && !hasPrefsMarker) {
        if (prefs.getString('token') != null) {
          debugPrint(
            'Splash: Reinstall detected with restored session — clearing stale token.',
          );
          await ApiClient.clearToken();
          await prefs.clear();
        }
        await markerFile.parent.create(recursive: true);
        await markerFile.writeAsString('1');
        await prefs.setBool(_installMarkerPrefsKey, true);
        return;
      }

      if (!hasFileMarker) {
        await markerFile.parent.create(recursive: true);
        await markerFile.writeAsString('1');
      }
      if (!hasPrefsMarker) {
        await prefs.setBool(_installMarkerPrefsKey, true);
      }
    } catch (e) {
      debugPrint('Splash: install marker sync failed: $e');
    }
  }

  Future<void> _navigateFallbackIfNeeded({required String reason}) async {
    if (!mounted || _didNavigate) return;

    debugPrint('Splash: fallback navigation triggered ($reason)');
    setState(() {
      _statusMessage = 'INITIALIZATION STALLED - REDIRECTING';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _didNavigate) return;

      final token = prefs.getString('token');
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (!hasSeenOnboarding) {
        _navigateOnce(AppRoutes.onboarding);
      } else if (token == null) {
        _navigateOnce(AppRoutes.login);
      } else {
        _navigateOnce(AppRoutes.main);
      }
    } catch (e) {
      debugPrint('Splash: fallback navigation failed: $e');
      if (!mounted || _didNavigate) return;
      _navigateOnce(AppRoutes.main);
    }
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

    // If init navigation never happened (e.g. a future hung), redirect so
    // users never get stuck at 100% loading.
    await _navigateFallbackIfNeeded(reason: 'progress reached 100%');
  }

  Future<void> _checkLoginStatus() async {
    debugPrint('Splash: _checkLoginStatus started');
    final prefs = await SharedPreferences.getInstance();

    // iOS: ask notification permission early (required for Firebase phone OTP silent push).
    if (Platform.isIOS && mounted) {
      await _prepareIosNotificationPermission();
    }

    // --- Fresh install / reinstall detection ---
    // iOS can restore SharedPreferences from iCloud after reinstall, but must not
    // treat a normal tmp-directory purge as a fresh install (that was logging users out).
    await _syncInstallMarker(prefs);

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
        final bypass = await _canBypassMaintenance(
          token,
          testerIdentifiers: config.maintenanceTesterIdentifiers,
        );
        if (!mounted) return;
        if (!bypass) {
          debugPrint('Splash: maintenance enabled, redirecting');
          final args = await SupportContactService.maintenanceRouteArgs(
            message: config.maintenanceMessage,
            kind: 'maintenance',
          );
          if (!mounted) return;
          _navigateOnce(AppRoutes.maintenance, arguments: args);
          return;
        }
        debugPrint('Splash: maintenance enabled, bypass granted for tester/admin');
      }

      if (config.serviceUnavailable) {
        debugPrint('Splash: app-config unavailable, redirecting to maintenance');
        final args = await SupportContactService.maintenanceRouteArgs(
          message:
              'We could not reach the RealtorOne service. Please try again shortly or contact support below.',
          kind: 'unavailable',
        );
        if (!mounted) return;
        _navigateOnce(AppRoutes.maintenance, arguments: args);
        return;
      }

      if (config.requiresUpdate) {
        debugPrint('Splash: update required, redirecting');
        _navigateOnce(AppRoutes.updateRequired, arguments: {
            'minVersion': config.minVersionForPlatform,
            'maxVersion': config.maxVersionForPlatform,
            'storeUrl': config.storeUrlForPlatform,
            'apkUrl': config.apkUrl,
            'platformLabel': defaultTargetPlatform == TargetPlatform.iOS
                ? 'iOS'
                : 'Android',
          });
        return;
      }
    } catch (e) {
      debugPrint('Splash: error fetching config: $e');
      // Fail open: continue with normal flow if config cannot be fetched or parsed.
    }

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      debugPrint('Splash: redirecting to onboarding');
      _navigateOnce(AppRoutes.onboarding);
      return;
    }

    if (token == null) {
      debugPrint('Splash: redirecting to login');
      _navigateOnce(AppRoutes.login);
      return;
    }

    debugPrint('Splash: syncing push notification token...');
    await PushNotificationService.syncTokenWithBackend();
    debugPrint('Splash: push notification token synced');

    try {
      debugPrint('Splash: fetching user profile...');
      var response = await ApiClient.get('/user/profile', requiresAuth: true);
      debugPrint('Splash: profile fetched: $response');
      if (mounted) {
        var isSuccess =
            response['success'] == true || response['status'] == 'ok';

        if (!isSuccess) {
          final statusCode = response['statusCode'];
          final message = (response['message'] ?? '').toString().toLowerCase();
          final isAuthError =
              statusCode == 401 ||
              message.contains('unauthorized') ||
              message.contains('token') ||
              message.contains('forbidden');

          if (isAuthError) {
            final refreshed = await ApiClient.tryRefreshSession();
            if (refreshed) {
              response = await ApiClient.get('/user/profile', requiresAuth: true);
              isSuccess =
                  response['success'] == true || response['status'] == 'ok';
            }
          }
        }

        if (isSuccess) {
          final userData = response['data'] ?? response['user'] ?? response;
          final hasBasicProfile =
              userData['name'] != null && userData['email'] != null;

          if (hasBasicProfile) {
            final isProfileComplete = userData['is_profile_complete'] == true;
            if (!isProfileComplete) {
              debugPrint('Splash: redirecting to profile setup');
              _navigateOnce(AppRoutes.profileSetup);
              return;
            }

            final hasDiagnosis = userData['has_completed_diagnosis'] == true;
            if (!hasDiagnosis) {
              debugPrint('Splash: redirecting to diagnosis');
              _navigateOnce(AppRoutes.diagnosis);
              return;
            }

            AppPasscodeService.instance.configureFromProfile(
              Map<String, dynamic>.from(userData as Map),
            );
            await AppPasscodeService.instance.lockIfExpired();
            if (AppPasscodeService.instance.needsLock) {
              debugPrint('Splash: redirecting to app passcode lock');
              _navigateOnce(AppRoutes.appPasscodeLock);
              return;
            }

            debugPrint('Splash: redirecting to main');
            _navigateOnce(AppRoutes.main);
            return;
          }

          debugPrint('Splash: redirecting to profile setup (no basic profile)');
          _navigateOnce(AppRoutes.profileSetup);
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
              _navigateOnce(AppRoutes.login);
            }
            return;
          }

          // Non-auth API failures should not force logout.
          debugPrint('Splash: API failure, redirecting to main anyway');
          _navigateOnce(AppRoutes.main);
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
        _navigateOnce(AppRoutes.main);
        return;
      }

      if (mounted) {
        debugPrint('Splash: generic error, returning to login');
        _navigateOnce(AppRoutes.login);
      }
    }
  }

  /// iOS only — explain why notifications are needed, then request permission + APNs.
  Future<void> _prepareIosNotificationPermission() async {
    if (!Platform.isIOS || !mounted) return;

    try {
      final settings = await PushNotificationService.messagingSettings();
      final status = settings.authorizationStatus;

      if (status == AuthorizationStatus.notDetermined) {
        final allow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Enable notifications'),
            content: const Text(
              'RealtorOne uses a secure Apple notification to verify your phone number with Firebase OTP.\n\n'
              'Please tap Allow on the next screen so phone verification works on iPhone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (allow != true || !mounted) return;
      }

      await PushNotificationService.prepareIosNotificationsAtStartup();
    } catch (e) {
      debugPrint('Splash: iOS notification prep failed: $e');
    }
  }

  Future<_AppRuntimeConfig> _fetchAppConfig() async {
    try {
      await ApiClient.invalidateEndpointCache('/app-config');
      final response = await ApiClient.getPublic(
        '/app-config?_=${DateTime.now().millisecondsSinceEpoch}',
        useCache: false,
        revalidateInBackground: false,
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
      final maintenanceTesterIdentifiers =
          data['maintenance_tester_identifiers'] is List
          ? (data['maintenance_tester_identifiers'] as List)
                .map((v) => v.toString().trim().toLowerCase())
                .where((v) => v.isNotEmpty)
                .toList()
          : const <String>[];
      final minAndroid = (data['min_android_version'] as String?)?.trim() ?? '';
      final minIos = (data['min_ios_version'] as String?)?.trim() ?? '';
      final maxAndroid = (data['max_android_version'] as String?)?.trim() ?? '';
      final maxIos = (data['max_ios_version'] as String?)?.trim() ?? '';
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
      final String maxForPlatform = isAndroid
          ? maxAndroid
          : isIos
          ? maxIos
          : '';
      final String storeForPlatform = isAndroid
          ? androidStore
          : isIos
          ? iosStore
          : '';

      final versionControlEnabled = _versionControlEnabledForPlatform(data);
      final requiresUpdate = isVersionUpdateRequired(
        versionControlEnabled: versionControlEnabled,
        currentVersion: currentVersion,
        minVersion: minForPlatform,
        maxVersion: maxForPlatform,
      );

      return _AppRuntimeConfig(
        maintenanceEnabled: maintenanceEnabled,
        maintenanceMessage: maintenanceMessage,
        maintenanceTesterIdentifiers: maintenanceTesterIdentifiers,
        serviceUnavailable: false,
        minAndroidVersion: minAndroid,
        minIosVersion: minIos,
        maxAndroidVersion: maxAndroid,
        maxIosVersion: maxIos,
        androidStoreUrl: androidStore,
        iosStoreUrl: iosStore,
        currentVersion: currentVersion,
        requiresUpdate: requiresUpdate,
        minVersionForPlatform: minForPlatform,
        maxVersionForPlatform: maxForPlatform,
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
      maintenanceTesterIdentifiers: const [],
      serviceUnavailable: false,
      minAndroidVersion: '',
      minIosVersion: '',
      maxAndroidVersion: '',
      maxIosVersion: '',
      androidStoreUrl: '',
      iosStoreUrl: '',
      currentVersion: info.version,
      requiresUpdate: false,
      minVersionForPlatform: '',
      maxVersionForPlatform: '',
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
    required this.maintenanceTesterIdentifiers,
    required this.serviceUnavailable,
    required this.minAndroidVersion,
    required this.minIosVersion,
    required this.maxAndroidVersion,
    required this.maxIosVersion,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.currentVersion,
    required this.requiresUpdate,
    required this.minVersionForPlatform,
    required this.maxVersionForPlatform,
    required this.storeUrlForPlatform,
    required this.apkUrl,
  });

  factory _AppRuntimeConfig.unavailable() {
    return _AppRuntimeConfig(
      maintenanceEnabled: false,
      maintenanceMessage: '',
      maintenanceTesterIdentifiers: const [],
      serviceUnavailable: true,
      minAndroidVersion: '',
      minIosVersion: '',
      maxAndroidVersion: '',
      maxIosVersion: '',
      androidStoreUrl: '',
      iosStoreUrl: '',
      currentVersion: '',
      requiresUpdate: false,
      minVersionForPlatform: '',
      maxVersionForPlatform: '',
      storeUrlForPlatform: '',
      apkUrl: '',
    );
  }

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final List<String> maintenanceTesterIdentifiers;
  final bool serviceUnavailable;
  final String minAndroidVersion;
  final String minIosVersion;
  final String maxAndroidVersion;
  final String maxIosVersion;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String currentVersion;
  final bool requiresUpdate;
  final String minVersionForPlatform;
  final String maxVersionForPlatform;
  final String storeUrlForPlatform;
  final String apkUrl;
}
