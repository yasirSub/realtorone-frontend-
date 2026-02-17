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

  /// Validate a coupon code
  static Future<Map<String, dynamic>> validateCoupon(String code) async {
    return await ApiClient.post(ApiEndpoints.validateCoupon, {
      'code': code,
    }, requiresAuth: true);
  }

  /// Purchase a subscription
  static Future<Map<String, dynamic>> purchaseSubscription({
    required int packageId,
    required int months,
    required String paymentId,
    int? couponId,
  }) async {
    return await ApiClient.post(ApiEndpoints.purchaseSubscription, {
      'package_id': packageId,
      'months': months,
      'payment_id': paymentId,
      if (couponId != null) 'coupon_id': couponId,
    }, requiresAuth: true);
  }
}
