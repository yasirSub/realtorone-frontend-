import 'api_client.dart';

class AdminApi {
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    return ApiClient.get(
      '/admin/users/search?q=${Uri.encodeQueryComponent(query)}',
      requiresAuth: true,
      useCache: false,
    );
  }

  static Future<Map<String, dynamic>> grantSubscription({
    required int userId,
    required String tierName,
    int? months,
    double? amountPaid,
    String? adminNote,
  }) async {
    return ApiClient.post('/admin/users/$userId/grant-subscription', {
      'tier_name': tierName,
      if (months != null) 'months': months,
      if (amountPaid != null) 'amount_paid': amountPaid,
      if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
    }, requiresAuth: true);
  }
}
