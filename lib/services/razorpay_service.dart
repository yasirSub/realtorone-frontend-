import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'app_passcode_service.dart';
import '../utils/api_user_message.dart';

typedef RazorpaySuccessHandler = Future<void> Function(
  String paymentId,
  String orderId,
  String signature,
);

typedef RazorpayErrorHandler = void Function(String message);

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._();
  factory RazorpayService() => _instance;
  RazorpayService._();

  Razorpay? _razorpay;
  RazorpaySuccessHandler? _onSuccess;
  RazorpayErrorHandler? _onError;
  Completer<void>? _checkoutCompleter;

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  Future<void> openCheckout({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String currency,
    required String description,
    String? email,
    String? contact,
    required RazorpaySuccessHandler onSuccess,
    RazorpayErrorHandler? onError,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Use website checkout on web');
    }

    _onSuccess = onSuccess;
    _onError = onError;
    _checkoutCompleter = Completer<void>();

    AppPasscodeService.instance.beginSuppressLock();

    _razorpay?.clear();
    _razorpay = Razorpay();
    _razorpay!
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amountPaise,
      'currency': currency,
      'name': 'RealtorOne',
      'description': description,
      'order_id': orderId,
      if (email != null && email.isNotEmpty) 'prefill': {
        'email': email,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      },
      'theme': {'color': '#6366F1'},
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      AppPasscodeService.instance.endSuppressLock();
      _checkoutCompleter?.completeError(e);
      rethrow;
    }

    return _checkoutCompleter!.future;
  }

  void _finishCheckout() {
    AppPasscodeService.instance.endSuppressLock();
    _razorpay?.clear();
    _razorpay = null;
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? '';
    final signature = response.signature ?? '';

    if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      _onError?.call('Incomplete payment response from Razorpay.');
      _checkoutCompleter?.complete();
      _finishCheckout();
      return;
    }

    try {
      await _onSuccess?.call(paymentId, orderId, signature);
      _checkoutCompleter?.complete();
    } catch (e) {
      _onError?.call(e.toString());
      _checkoutCompleter?.completeError(e);
    } finally {
      _finishCheckout();
    }
  }

  void _handleError(PaymentFailureResponse response) {
    final message = ApiUserMessage.sanitize(
      response.message,
      fallback: 'Payment failed. Please try again.',
    );
    if (!message.toLowerCase().contains('cancel')) {
      _onError?.call(message);
    }
    _checkoutCompleter?.complete();
    _finishCheckout();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet: ${response.walletName}');
  }
}
