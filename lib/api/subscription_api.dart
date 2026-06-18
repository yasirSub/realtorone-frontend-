import 'api_client.dart';
import 'api_endpoints.dart';

class SubscriptionApi {
  /// Fetch all available subscription packages
  static Future<Map<String, dynamic>> getPackages() async {
    return await ApiClient.get(
      ApiEndpoints.packages,
      requiresAuth: true,
      useCache: false, // Disable cache to get fresh tier names
    );
  }

  /// Fetch current user's active subscription
  static Future<Map<String, dynamic>> getMySubscription() async {
    return await ApiClient.get(ApiEndpoints.mySubscription, requiresAuth: true);
  }

  /// Validate a coupon code for the selected subscription length (months).
  static Future<Map<String, dynamic>> validateCoupon(
    String code, {
    required int months,
    int? packageId,
    String? tierName,
  }) async {
    return await ApiClient.post(ApiEndpoints.validateCoupon, {
      'code': code.trim().toUpperCase(),
      'months': months,
      if (packageId != null) 'package_id': packageId,
      if (tierName != null) 'tier_name': tierName,
    }, requiresAuth: true);
  }

  /// Purchase a subscription
  static Future<Map<String, dynamic>> purchaseSubscription({
    required int packageId,
    required int months,
    required String paymentId,
    int? couponId,
    String? productId,
    String? platform,
  }) async {
    return await ApiClient.post(ApiEndpoints.purchaseSubscription, {
      'package_id': packageId,
      'months': months,
      'payment_id': paymentId,
      'product_id': ?productId,
      'platform': ?platform,
      ...(couponId != null ? {'coupon_id': couponId} : {}),
    }, requiresAuth: true);
  }

  /// Purchase a subscription by tier name (used for Apple/Google IAP verification)
  static Future<Map<String, dynamic>> purchaseSubscriptionByTier({
    required String tierName,
    required int months,
    required String paymentId,
    String? receipt,
    String? productId,
    String? platform,
    int? couponId,
  }) async {
    return await ApiClient.post(ApiEndpoints.purchaseSubscription, {
      'tier_name': tierName,
      'months': months,
      'payment_id': paymentId,
      if (receipt != null && receipt.isNotEmpty) 'receipt': receipt,
      'product_id': ?productId,
      'platform': ?platform,
      ...(couponId != null ? {'coupon_id': couponId} : {}),
    }, requiresAuth: true);
  }

  static Future<Map<String, dynamic>> getRazorpayConfig() async {
    return await ApiClient.get(
      ApiEndpoints.razorpayConfig,
      requiresAuth: true,
      useCache: false,
    );
  }

  static Future<Map<String, dynamic>> createRazorpayOrder({
    required int packageId,
    required int months,
    int? couponId,
    String? iapProductId,
    int? iapAmountPaise,
  }) async {
    return await ApiClient.post(ApiEndpoints.razorpayCreateOrder, {
      'package_id': packageId,
      'months': months,
      if (couponId != null) 'coupon_id': couponId,
      if (iapProductId != null && iapProductId.isNotEmpty)
        'iap_product_id': iapProductId,
      if (iapAmountPaise != null) 'iap_amount_paise': iapAmountPaise,
    }, requiresAuth: true);
  }

  static Future<Map<String, dynamic>> getPaymentSettings() async {
    return await ApiClient.get(
      ApiEndpoints.paymentSettings,
      requiresAuth: false,
      useCache: false,
    );
  }

  static Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return await ApiClient.post(ApiEndpoints.razorpayVerify, {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    }, requiresAuth: true);
  }

  /// Server-side price quote (AED list + location-based INR for Razorpay).
  static Future<Map<String, dynamic>> getPricingQuote({
    required int packageId,
    required int months,
    int? couponId,
    String? countryCode,
  }) async {
    return await ApiClient.post(ApiEndpoints.pricingQuote, {
      'package_id': packageId,
      'months': months,
      if (couponId != null) 'coupon_id': couponId,
      if (countryCode != null && countryCode.isNotEmpty)
        'country_code': countryCode.toUpperCase(),
    }, requiresAuth: true);
  }
}
