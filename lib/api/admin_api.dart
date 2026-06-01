import 'api_client.dart';

class AdminApi {
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    return ApiClient.get(
      '/admin/users/search?q=${Uri.encodeQueryComponent(query)}',
      requiresAuth: true,
      useCache: false,
    );
  }

  static Future<Map<String, dynamic>> previewSubscriptionPricing({
    required int userId,
    required String tierName,
    int? months,
    double? amountPaid,
    String? couponCode,
    int? couponId,
  }) async {
    return ApiClient.post(
      '/admin/users/$userId/subscription-pricing-preview',
      {
        'tier_name': tierName,
        if (months != null) 'months': months,
        if (amountPaid != null) 'amount_paid': amountPaid,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode.trim().toUpperCase(),
        if (couponId != null) 'coupon_id': couponId,
      },
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> grantSubscription({
    required int userId,
    required String tierName,
    int? months,
    double? amountPaid,
    String? couponCode,
    int? couponId,
    String? adminNote,
  }) async {
    return ApiClient.post('/admin/users/$userId/grant-subscription', {
      'tier_name': tierName,
      if (months != null) 'months': months,
      if (amountPaid != null) 'amount_paid': amountPaid,
      if (couponCode != null && couponCode.isNotEmpty)
        'coupon_code': couponCode.trim().toUpperCase(),
      if (couponId != null) 'coupon_id': couponId,
      if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
    }, requiresAuth: true);
  }
}
