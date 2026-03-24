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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  static const String _storeKey = 'notification_history_v1';

  static bool _firebaseReady = false;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _foregroundListening = false;
  static bool _tokenRefreshListening = false;

  static void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static Future<bool> initializeApp() async {
    if (_firebaseReady) return true;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await _refreshUnreadCount();
      _firebaseReady = true;
      return true;
    } catch (e, st) {
      debugPrint('Firebase.initializeApp failed: $e\n$st');
      return false;
    }
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

      final data = message.data;
      final recurrenceType = (data['recurrence_type'] ?? '').toString();
      final styleFromPayload = (data['display_style'] ?? 'standard').toString();
      final style = _applyDailySurfaceStyleIfNeeded(recurrenceType, styleFromPayload);
      final titleBase = message.notification?.title ?? data['title'] ?? 'RealtorOne';
      final title = _applyGreetingIfNeeded(recurrenceType, titleBase.toString());
      final body = message.notification?.body ?? data['body'] ?? '';
      final deepLink = (data['deep_link'] ?? '').trim();
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
                if (deepLink.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(deepLink);
                      ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
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
              action: (deepLink.isNotEmpty)
                  ? SnackBarAction(
                      label: cta.toUpperCase(),
                      onPressed: () async {
                        final uri = Uri.tryParse(deepLink);
                        if (uri == null) return;
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    )
                  : null,
            ),
          );
        }
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await storeNotificationFromMessage(message);
    });
  }

  static Future<void> syncTokenWithBackend() async {
    if (!_firebaseReady) return;

    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
      }

      _ensureForegroundListener();

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await storeNotificationFromMessage(initial);
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final platform = (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';
      await ApiClient.post('/user/push-token', {'token': token, 'platform': platform}, requiresAuth: true);

      if (!_tokenRefreshListening) {
        _tokenRefreshListening = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await ApiClient.post('/user/push-token', {'token': newToken, 'platform': platform}, requiresAuth: true);
        });
      }
    } catch (e, st) {
      debugPrint('PushNotificationService.syncTokenWithBackend: $e\n$st');
    }
  }

  static Future<void> unregisterBackendToken() async {
    if (!_firebaseReady) return;
    try {
      await ApiClient.delete('/user/push-token', requiresAuth: true);
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
