import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

import '../config/meta_app_events_config.dart';

/// Meta (Facebook) App Events for ad measurement and campaign optimization.
class MetaAppEventsService {
  MetaAppEventsService._();

  static final MetaAppEventsService instance = MetaAppEventsService._();

  final FacebookAppEvents _sdk = FacebookAppEvents();
  bool _initialized = false;

  bool get isConfigured =>
      MetaAppEventsConfig.clientToken != 'REPLACE_WITH_META_CLIENT_TOKEN';

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    if (!isConfigured) {
      debugPrint(
        '[MetaAppEvents] Skipped: set MetaAppEventsConfig.clientToken and '
        'native FacebookClientToken before enabling event delivery.',
      );
      return;
    }

    try {
      if (kDebugMode) {
        await _sdk.setDebugLoggingEnabled(true);
      }
      await _sdk.setAutoLogAppEventsEnabled(true);
      await _sdk.setAdvertiserIdCollectionEnabled(true);
      await _sdk.activateApp();
      _initialized = true;
      debugPrint('[MetaAppEvents] Initialized (app ${MetaAppEventsConfig.appId})');
    } catch (e, st) {
      debugPrint('[MetaAppEvents] initialize failed: $e\n$st');
    }
  }

  Future<void> trackLogin({
    required String method,
    Map<String, dynamic>? user,
  }) async {
    if (!_initialized) return;

    try {
      await _applyUserContext(user);
      await _sdk.logEvent(
        name: 'fb_mobile_login',
        parameters: {'fb_login_method': method},
      );
    } catch (e) {
      debugPrint('[MetaAppEvents] trackLogin failed: $e');
    }
  }

  Future<void> trackRegistration({required String method}) async {
    if (!_initialized) return;

    try {
      await _sdk.logCompletedRegistration(registrationMethod: method);
    } catch (e) {
      debugPrint('[MetaAppEvents] trackRegistration failed: $e');
    }
  }

  Future<void> trackSubscriptionPurchase({
    required String orderId,
    required double amount,
    required String currency,
    String? contentId,
    int? numItems,
  }) async {
    if (!_initialized) return;

    try {
      await _sdk.logSubscribe(
        price: amount,
        currency: currency,
        orderId: orderId,
        parameters: {
          if (contentId != null) 'fb_content_id': contentId,
          if (numItems != null) 'fb_num_items': numItems,
        },
      );
    } catch (e) {
      debugPrint('[MetaAppEvents] trackSubscriptionPurchase failed: $e');
    }
  }

  Future<void> trackInitiatedCheckout({
    required double amount,
    required String currency,
    String? contentId,
  }) async {
    if (!_initialized) return;

    try {
      await _sdk.logInitiatedCheckout(
        totalPrice: amount,
        currency: currency,
        contentId: contentId,
        numItems: 1,
        paymentInfoAvailable: true,
      );
    } catch (e) {
      debugPrint('[MetaAppEvents] trackInitiatedCheckout failed: $e');
    }
  }

  Future<void> clearUser() async {
    if (!_initialized) return;
    try {
      await _sdk.clearUserID();
      await _sdk.clearUserData();
    } catch (e) {
      debugPrint('[MetaAppEvents] clearUser failed: $e');
    }
  }

  Future<void> _applyUserContext(Map<String, dynamic>? user) async {
    if (user == null) return;

    final id = user['id']?.toString();
    if (id != null && id.isNotEmpty) {
      await _sdk.setUserID(id);
    }

    final email = user['email']?.toString();
    final phone = user['mobile']?.toString() ?? user['phone']?.toString();
    if ((email != null && email.isNotEmpty) ||
        (phone != null && phone.isNotEmpty)) {
      await _sdk.setUserData(
        email: email,
        phone: phone,
        externalId: id,
      );
    }
  }

  /// Parses server pricing payload after subscription activation.
  static ({double amount, String currency})? pricingFromActivation(
    Map<String, dynamic>? pricing,
  ) {
    if (pricing == null) return null;

    final amountRaw = pricing['amount_paid'] ?? pricing['total_amount'];
    final amount = double.tryParse(amountRaw?.toString() ?? '');
    if (amount == null || amount <= 0) return null;

    final currency = pricing['currency']?.toString().trim();
    return (
      amount: amount,
      currency: currency != null && currency.isNotEmpty ? currency : 'AED',
    );
  }

  static bool get supportsNativeTracking => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
}
