import 'api_client.dart';
import 'api_endpoints.dart';

class DashboardApi {
  /// Get dashboard statistics
  static Future<Map<String, dynamic>> getStats() async {
    return await ApiClient.get(ApiEndpoints.dashboardStats, requiresAuth: true);
  }
}
