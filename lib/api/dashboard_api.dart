import 'api_client.dart';
import 'api_endpoints.dart';

class DashboardApi {
  /// Get dashboard statistics
  static Future<Map<String, dynamic>> getStats() async {
    return await ApiClient.get(ApiEndpoints.dashboardStats, requiresAuth: true);
  }

  /// Get momentum dashboard data
  static Future<Map<String, dynamic>> getMomentumData() async {
    return await ApiClient.get(
      ApiEndpoints.momentumDashboard,
      requiresAuth: true,
    );
  }

  /// Get momentum leaders
  static Future<Map<String, dynamic>> getMomentumLeaders() async {
    return await ApiClient.get(
      ApiEndpoints.momentumLeaders,
      requiresAuth: true,
    );
  }

  /// Get growth report
  static Future<Map<String, dynamic>> getGrowthReport({
    String period = 'week',
  }) async {
    return await ApiClient.get(
      '${ApiEndpoints.growthReport}?period=$period',
      requiresAuth: true,
    );
  }
}
