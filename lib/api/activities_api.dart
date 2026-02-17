import 'api_client.dart';
import 'api_endpoints.dart';

class ActivitiesApi {
  /// Get activities for a specific date
  static Future<Map<String, dynamic>> getActivities({String? date}) async {
    String endpoint = ApiEndpoints.activities;
    if (date != null) {
      endpoint += '?date=$date';
    }
    return await ApiClient.get(endpoint, requiresAuth: true, useCache: true);
  }

  /// Create a new activity
  static Future<Map<String, dynamic>> createActivity({
    required String title,
    String? description,
    required String type,
    required String category,
    int? durationMinutes,
    String? scheduledAt,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'type': type,
      'category': category,
    };
    if (description != null) data['description'] = description;
    if (durationMinutes != null) data['duration_minutes'] = durationMinutes;
    if (scheduledAt != null) data['scheduled_at'] = scheduledAt;

    return await ApiClient.post(
      ApiEndpoints.activities,
      data,
      requiresAuth: true,
    );
  }

  /// Mark an activity as complete
  static Future<Map<String, dynamic>> completeActivity(int activityId) async {
    return await ApiClient.put(
      ApiEndpoints.completeActivity(activityId),
      {},
      requiresAuth: true,
    );
  }

  /// Get today's progress summary
  static Future<Map<String, dynamic>> getProgress() async {
    return await ApiClient.get(
      ApiEndpoints.activitiesProgress,
      requiresAuth: true,
      useCache: true,
    );
  }

  /// Log an activity (Momentum Style)
  static Future<Map<String, dynamic>> logActivity({
    required String type,
    required String category,
    int? quantity,
    double? value,
    String? notes,
  }) async {
    final data = <String, dynamic>{'type': type, 'category': category};
    if (quantity != null) data['quantity'] = quantity;
    if (value != null) data['value'] = value;
    if (notes != null) data['notes'] = notes;

    return await ApiClient.post(
      ApiEndpoints.logActivity,
      data,
      requiresAuth: true,
    );
  }

  /// Get available activity types
  static Future<Map<String, dynamic>> getActivityTypes() async {
    return await ApiClient.get(ApiEndpoints.activityTypes, requiresAuth: true);
  }

  /// Get today's key tasks
  static Future<Map<String, dynamic>> getTodayTasks() async {
    return await ApiClient.get(ApiEndpoints.todayTasks, requiresAuth: true);
  }
}
