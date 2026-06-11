import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../firebase_options.dart';
import '../routes/app_routes.dart';
import '../screens/chatbot/reven_chat_page.dart';
import '../utils/phone_otp_debug_log.dart';
import 'ios_phone_auth_apns_bridge.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolates have their own Dart context, so Firebase.apps may be
  // empty even if the main isolate already initialized. Guard to prevent
  // "invalid reuse after initialization failure" on re-entrant calls.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  await PushNotificationService.storeNotificationFromMessage(message);
  debugPrint('Background message: ${message.messageId}');
}

Color _parseBannerAccent(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF6366F1);
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  try {
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return const Color(0xFF6366F1);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final ValueNotifier<bool> notificationsEnabled = ValueNotifier<bool>(true);

  static const String _storeKey = 'notification_history_v1';
  static const String _globalTopic = 'all_users';

  static bool _firebaseReady = false;
  // Tracks whether initializeApp() was ever called, regardless of success.
  // This prevents "invalid reuse after initialization failure" — Firebase
  // throws that error if initializeApp() is called a second time on an app
  // instance that previously failed to initialize.
  static bool _initAttempted = false;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _foregroundListening = false;
  static bool _tokenRefreshListening = false;

  static void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Map<String, dynamic>? _pendingLaunchData;

  static void _queuePendingLaunch(Map<String, dynamic> data) {
    _pendingLaunchData = Map<String, dynamic>.from(data);
  }

  /// Called after splash/main is ready (cold start from notification tap).
  static Future<void> handlePendingLaunchNavigation() async {
    final data = _pendingLaunchData;
    if (data == null) return;
    _pendingLaunchData = null;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await openPushTarget(data);
  }

  static bool hasNavigablePayload(Map<String, dynamic> data) {
    final deepLink = (data['deep_link'] ?? '').toString().trim();
    final type = (data['type'] ?? '').toString();
    final automation = (data['automation'] ?? '').toString();
    final kind = (data['kind'] ?? '').toString();
    return deepLink.isNotEmpty ||
        kind == 'home_announcement' ||
        kind == 'app_version' ||
        type.isNotEmpty ||
        automation.isNotEmpty;
  }

  static Future<void> openPushTarget(Map<String, dynamic> data) async {
    final deepLink = (data['deep_link'] ?? '').toString().trim();
    final type = (data['type'] ?? '').toString();
    final automation = (data['automation'] ?? '').toString();
    final kind = (data['kind'] ?? '').toString();
    final sessionId = int.tryParse((data['session_id'] ?? '').toString());

    if (type == 'ai_chat_human' ||
        deepLink.contains('reven-chat') ||
        deepLink.contains('reven_chat')) {
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        await RevenChatPage.show(ctx, sessionId: sessionId);
      }
      return;
    }

    if (type == 'momentum_reminder' ||
        automation == 'missed_activity' ||
        deepLink.contains('activities')) {
      _openMainTab(initialIndex: 1, activitiesTabIndex: 0);
      return;
    }

    if (automation == 'crm_reminder' || deepLink.contains('crm')) {
      _openMainTab(
        initialIndex: 1,
        activitiesTabIndex: 1,
        revenueSubTab: 0,
      );
      return;
    }

    if (kind == 'home_announcement') {
      _navigatorKey?.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.main,
        (_) => false,
      );
      return;
    }

    if (kind == 'app_version' || deepLink.contains('app-version')) {
      _navigatorKey?.currentState?.pushNamed(AppRoutes.appVersion);
      return;
    }

    if (type == 'ai_nudge' || deepLink == 'dashboard') {
      _openMainTab(initialIndex: 0);
      return;
    }

    final uri = Uri.tryParse(deepLink);
    if (uri != null && uri.scheme == 'realtorone') {
      if (uri.host == 'reven-chat' || uri.path.contains('reven-chat')) {
        final sid = int.tryParse(uri.queryParameters['session_id'] ?? '') ??
            sessionId;
        final ctx = _navigatorKey?.currentContext;
        if (ctx != null && ctx.mounted) {
          await RevenChatPage.show(ctx, sessionId: sid);
        }
        return;
      }
      if (uri.host == 'app-version' || uri.path.contains('app-version')) {
        _navigatorKey?.currentState?.pushNamed(AppRoutes.appVersion);
        return;
      }
      if (uri.host == 'home' ||
          uri.host == 'main' ||
          uri.path == '/home' ||
          uri.path == '/main') {
        final tab = int.tryParse(uri.queryParameters['tab'] ?? '');
        final activitiesTab =
            int.tryParse(uri.queryParameters['activities_tab'] ?? '');
        final revenueSub =
            int.tryParse(uri.queryParameters['revenue_sub_tab'] ?? '');
        _openMainTab(
          initialIndex: tab ?? 0,
          activitiesTabIndex: activitiesTab,
          revenueSubTab: revenueSub,
        );
        return;
      }
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _openMainTab({
    int initialIndex = 0,
    int? activitiesTabIndex,
    int? revenueSubTab,
  }) {
    _navigatorKey?.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.main,
      (_) => false,
      arguments: {
        'initialIndex': initialIndex,
        if (activitiesTabIndex != null)
          'activitiesTabIndex': activitiesTabIndex,
        if (revenueSubTab != null) 'revenueSubTab': revenueSubTab,
      },
    );
  }

  static Future<void> openFromStoredNotification(
    Map<String, dynamic> item,
  ) async {
    await openPushTarget({
      'deep_link': (item['deep_link'] ?? '').toString(),
      'type': (item['type'] ?? '').toString(),
      'automation': (item['automation'] ?? '').toString(),
      'kind': (item['kind'] ?? '').toString(),
      'session_id': (item['session_id'] ?? '').toString(),
      'client_id': (item['client_id'] ?? '').toString(),
    });
  }

  static Future<bool> initializeApp() async {
    if (_firebaseReady) return true;
    // If we already attempted (and possibly failed) do not call initializeApp
    // again — Firebase will throw "invalid reuse after initialization failure".
    if (!_initAttempted) {
      _initAttempted = true;
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform);
        }
      } catch (e) {
        if (!e.toString().contains('duplicate-app')) {
          debugPrint('Firebase.initializeApp failed: $e');
          return false;
        }
      }
    } else if (Firebase.apps.isEmpty) {
      // A prior attempt failed and left no app — bail out.
      debugPrint('Firebase.initializeApp skipped: prior attempt failed.');
      return false;
    }

    try {
      await _refreshUnreadCount();
      await _loadSettings();
      if (!kIsWeb && Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      _firebaseReady = true;
      return true;
    } catch (e, st) {
      debugPrint('PushNotification setup failed: $e\n$st');
      return false;
    }
  }

  /// iOS Firebase Phone Auth needs APNs (silent push) before [verifyPhoneNumber].
  /// Android does not — this mirrors the extra native setup iOS requires.
  static Future<bool> ensureIosReadyForPhoneAuth() async {
    if (kIsWeb || !Platform.isIOS) return true;

    if (!_firebaseReady) {
      final ok = await initializeApp();
      if (!ok) return false;
    }

    try {
      final settings = await _messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 12));

      final status = settings.authorizationStatus;
      PhoneOtpDebugLog.log('notification permission', status.name);
      final authorized =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      if (!authorized) {
        PhoneOtpDebugLog.error('notification permission', 'denied ($status)');
        return false;
      }

      await _messaging.setAutoInitEnabled(true);
      final fcmToken = await _messaging.getToken().timeout(const Duration(seconds: 12));
      PhoneOtpDebugLog.log(
        'FCM token',
        fcmToken == null ? 'null' : '${fcmToken.substring(0, 8)}…',
      );

      for (var attempt = 0; attempt < 8; attempt++) {
        final apns = await _messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          PhoneOtpDebugLog.log(
            'APNs (messaging)',
            'ready attempt ${attempt + 1} ${apns.substring(0, 8)}…',
          );
          return true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      PhoneOtpDebugLog.log(
        'APNs (messaging)',
        'pending after 8 attempts — native AppDelegate may still register',
      );

      await IosPhoneAuthApnsBridge.syncApnsToAuth();
      final native = await IosPhoneAuthApnsBridge.debugStatus();
      if (native['authHasApnsToken'] == true) {
        return true;
      }
      PhoneOtpDebugLog.error(
        'APNs (messaging)',
        'no token after sync — check Push capability + notification permission',
      );
      return false;
    } catch (e) {
      PhoneOtpDebugLog.error('ensureIosReadyForPhoneAuth', e);
      return false;
    }
  }

  /// Call on splash / app start (iOS). Registers for APNs before phone OTP is needed.
  static Future<bool> prepareIosNotificationsAtStartup() async {
    if (kIsWeb || !Platform.isIOS) return true;
    PhoneOtpDebugLog.log('startup', 'preparing iOS notifications for Firebase OTP');
    final ok = await ensureIosReadyForPhoneAuth();
    final status = await IosPhoneAuthApnsBridge.debugStatus();
    PhoneOtpDebugLog.log('startup APNs status', status.toString());
    return ok;
  }

  static Future<NotificationSettings> messagingSettings() =>
      _messaging.getNotificationSettings();

  static Future<void> ensureSettingsLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled.value = prefs.getBool('notifications_enabled') ?? true;
  }

  static Future<void> _loadSettings() => ensureSettingsLoaded();

  static Future<void> toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notificationsEnabled.value = value;
  }

  static Future<List<Map<String, dynamic>>> getStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeKey);
    unreadCount.value = 0;
  }

  static Future<void> markAllAsRead() async {
    final items = await getStoredNotifications();
    bool changed = false;
    for (final item in items) {
      if (item['read'] != true) {
        item['read'] = true;
        changed = true;
      }
    }
    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, jsonEncode(items));
    }
    await _refreshUnreadCount();
  }

  static Future<void> _refreshUnreadCount() async {
    final items = await getStoredNotifications();
    unreadCount.value = items.where((e) => e['read'] != true).length;
  }

  static Future<void> storeNotificationFromMessage(RemoteMessage message) async {
    final data = message.data;
    final recurrenceType = (data['recurrence_type'] ?? '').toString();
    final titleBase = message.notification?.title ?? (data['title'] ?? 'RealtorOne').toString();
    final body = message.notification?.body ?? (data['body'] ?? '').toString();
    final title = _applyGreetingIfNeeded(recurrenceType, titleBase);
    final styleFromPayload = (data['display_style'] ?? 'standard').toString();
    final style = _applyDailySurfaceStyleIfNeeded(recurrenceType, styleFromPayload);

    final item = <String, dynamic>{
      'id': message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'style': style,
      'deep_link': (data['deep_link'] ?? '').toString(),
      'type': (data['type'] ?? '').toString(),
      'automation': (data['automation'] ?? '').toString(),
      'kind': (data['kind'] ?? '').toString(),
      'session_id': (data['session_id'] ?? '').toString(),
      'client_id': (data['client_id'] ?? '').toString(),
      'recurrence_type': recurrenceType,
      'banner_subtitle': (data['banner_subtitle'] ?? '').toString(),
      'banner_cta_label': (data['banner_cta_label'] ?? '').toString(),
      'banner_accent_color': (data['banner_accent_color'] ?? '').toString(),
      'banner_image_url': (data['banner_image_url'] ?? '').toString(),
      'received_at': DateTime.now().toIso8601String(),
      'read': false,
    };

    final list = await getStoredNotifications();
    list.removeWhere((e) => e['id'] == item['id']);
    list.insert(0, item);
    if (list.length > 200) {
      list.removeRange(200, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, jsonEncode(list));
    await _refreshUnreadCount();
  }

  static void _ensureForegroundListener() {
    if (!_firebaseReady || _foregroundListening) return;
    _foregroundListening = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await storeNotificationFromMessage(message);

      if (!notificationsEnabled.value) return;

      final data = message.data;
      final recurrenceType = (data['recurrence_type'] ?? '').toString();
      final styleFromPayload = (data['display_style'] ?? 'standard').toString();
      final style = _applyDailySurfaceStyleIfNeeded(recurrenceType, styleFromPayload);
      final titleBase = message.notification?.title ?? data['title'] ?? 'RealtorOne';
      final title = _applyGreetingIfNeeded(recurrenceType, titleBase.toString());
      final body = message.notification?.body ?? data['body'] ?? '';
      final cta = (data['banner_cta_label'] ?? 'Open').toString().trim().isNotEmpty ? (data['banner_cta_label'] ?? 'Open').toString().trim() : 'Open';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _navigatorKey?.currentContext;
        if (ctx == null || !ctx.mounted) return;

        if (style == 'banner') {
          final subtitle = (data['banner_subtitle'] ?? '').trim().isNotEmpty
              ? data['banner_subtitle']!.trim()
              : body;
          final cta = (data['banner_cta_label'] ?? 'Open').trim().isNotEmpty
              ? data['banner_cta_label']!.trim()
              : 'Open';
          final accent = _parseBannerAccent(data['banner_accent_color']);
          final imageUrl = (data['banner_image_url'] ?? '').trim();
          // banner already uses deepLink above

          ScaffoldMessenger.of(ctx).clearMaterialBanners();
          ScaffoldMessenger.of(ctx).showMaterialBanner(
            MaterialBanner(
              backgroundColor: accent.withValues(alpha: 0.14),
              leading: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.notifications_active, color: accent),
                      ),
                    )
                  : Icon(Icons.notifications_active, color: accent),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (hasNavigablePayload(data))
                  TextButton(
                    onPressed: () async {
                      ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
                      await openPushTarget(data);
                    },
                    child: Text(cta.toUpperCase()),
                  ),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner(),
                  child: const Text('DISMISS'),
                ),
              ],
            ),
          );
        } else if (style != 'silent') {
          final messenger = ScaffoldMessenger.of(ctx);
          messenger.showSnackBar(
            SnackBar(
              content: Text('$title: $body'),
              behavior: SnackBarBehavior.floating,
              action: hasNavigablePayload(data)
                  ? SnackBarAction(
                      label: cta.toUpperCase(),
                      onPressed: () async => openPushTarget(data),
                    )
                  : null,
            ),
          );
        }
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await storeNotificationFromMessage(message);
      final data = message.data;
      if (hasNavigablePayload(data)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          openPushTarget(data);
        });
      }
    });
  }

  static Future<void> syncTokenWithBackend() async {
    debugPrint('PushNotificationService: syncTokenWithBackend started');
    if (!_firebaseReady) {
      debugPrint('PushNotificationService: not ready, returning');
      return;
    }

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        debugPrint('PushNotificationService: requesting notification permission');
        await _messaging
            .requestPermission(alert: true, badge: true, sound: true)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw Exception('requestPermission timeout'),
            );
      }

      debugPrint('PushNotificationService: ensuring foreground listener');
      _ensureForegroundListener();

      debugPrint('PushNotificationService: getting initial message');
      final initial = await FirebaseMessaging.instance.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
           debugPrint('PushNotificationService: getInitialMessage timed out');
           return null;
        }
      );
      if (initial != null) {
        await storeNotificationFromMessage(initial);
        if (hasNavigablePayload(initial.data)) {
          _queuePendingLaunch(initial.data);
        }
      }

      debugPrint('PushNotificationService: getting token');
      // Add timeout to prevent hanging on iOS simulators without APNs config
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('PushNotificationService: getToken() timed out.');
          return null;
        },
      );
      if (token == null || token.isEmpty) {
        debugPrint('PushNotificationService: token is null or empty');
        return;
      }

      debugPrint('PushNotificationService: syncing token to backend');
      final platform = (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';
      await ApiClient.post('/user/push-token', {'token': token, 'platform': platform}, requiresAuth: true);
      try {
        await _messaging.subscribeToTopic(_globalTopic);
      } catch (e) {
        debugPrint('PushNotificationService: subscribe topic failed: $e');
      }

      if (!_tokenRefreshListening) {
        _tokenRefreshListening = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await ApiClient.post('/user/push-token', {'token': newToken, 'platform': platform}, requiresAuth: true);
          try {
            await _messaging.subscribeToTopic(_globalTopic);
          } catch (e) {
            debugPrint('PushNotificationService: topic resubscribe failed: $e');
          }
        });
      }
      debugPrint('PushNotificationService: syncTokenWithBackend done');
    } catch (e, st) {
      debugPrint('PushNotificationService.syncTokenWithBackend: $e\n$st');
    }
  }

  static Future<void> unregisterBackendToken() async {
    if (!_firebaseReady) return;
    try {
      await ApiClient.delete('/user/push-token', requiresAuth: true);
      try {
        await _messaging.unsubscribeFromTopic(_globalTopic);
      } catch (_) {}
      await _messaging.deleteToken();
    } catch (_) {}
  }

  static String _applyGreetingIfNeeded(String recurrenceType, String title) {
    // Only auto-generate greetings for daily recurring broadcasts.
    if (recurrenceType != 'daily') return title;

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    // Avoid double-prefix if the admin already used a greeting.
    final t = title.trim();
    if (t.startsWith(greeting)) return title;
    return '$greeting: $title';
  }

  static String _applyDailySurfaceStyleIfNeeded(String recurrenceType, String styleFromPayload) {
    if (recurrenceType != 'daily') return styleFromPayload;
    if (styleFromPayload == 'silent') return 'silent';

    final hour = DateTime.now().hour;
    // Morning: banner, Afternoon: snackbar, Evening: banner.
    if (hour < 12) return 'banner';
    if (hour < 17) return 'standard';
    return 'banner';
  }
}
