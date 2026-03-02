import 'api_client.dart';
import 'api_endpoints.dart';

class LearningApi {
  /// Get learning categories
  static Future<Map<String, dynamic>> getCategories() async {
    return await ApiClient.get(
      ApiEndpoints.learningCategories,
      requiresAuth: true,
    );
  }

  /// Get courses based on user tier
  static Future<Map<String, dynamic>> getCourses() async {
    return await ApiClient.get(ApiEndpoints.courses, requiresAuth: true);
  }

  /// Get detailed course curriculum
  static Future<Map<String, dynamic>> getCourseDetails(int id) async {
    return await ApiClient.get('${ApiEndpoints.courses}/$id', requiresAuth: true);
  }

  /// Get learning content, optionally filtered by category
  static Future<Map<String, dynamic>> getContent({String? category}) async {
    String endpoint = ApiEndpoints.learningContent;
    if (category != null) {
      endpoint += '?category=$category';
    }
    return await ApiClient.get(endpoint, requiresAuth: true);
  }

  /// Update progress for a learning content item
  static Future<Map<String, dynamic>> updateProgress({
    required int contentId,
    required int progressPercent,
  }) async {
    return await ApiClient.post(ApiEndpoints.learningProgress, {
      'content_id': contentId,
      'progress_percent': progressPercent,
    }, requiresAuth: true);
  }

  /// Update material completion status
  static Future<Map<String, dynamic>> updateMaterialProgress({
    required int materialId,
    required bool isCompleted,
  }) async {
    return await ApiClient.post(
      '${ApiEndpoints.courses}/materials/$materialId/progress',
      {'is_completed': isCompleted},
      requiresAuth: true,
    );
  }
}
