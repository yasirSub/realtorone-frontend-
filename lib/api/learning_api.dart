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
    bool? isCompleted,
    int? progressSeconds,
  }) async {
    final Map<String, dynamic> data = {};
    if (isCompleted != null) data['is_completed'] = isCompleted;
    if (progressSeconds != null) data['progress_seconds'] = progressSeconds;

    return await ApiClient.post(
      '${ApiEndpoints.courses}/materials/$materialId/progress',
      data,
      requiresAuth: true,
    );
  }

  /// Mark course progress (e.g. 100% and completed when all modules done)
  static Future<Map<String, dynamic>> updateCourseProgress({
    required int courseId,
    required int progressPercent,
    bool isCompleted = false,
  }) async {
    return await ApiClient.post(
      ApiEndpoints.courseProgress(courseId),
      {
        'progress_percent': progressPercent,
        'is_completed': isCompleted,
      },
      requiresAuth: true,
    );
  }

  /// Get course exam (only after course is completed)
  static Future<Map<String, dynamic>> getCourseExam(int courseId) async {
    return await ApiClient.get(
      ApiEndpoints.courseExam(courseId),
      requiresAuth: true,
    );
  }

  /// Submit exam answers
  static Future<Map<String, dynamic>> submitCourseExam({
    required int courseId,
    required List<Map<String, dynamic>> answers,
    String? startedAt,
  }) async {
    return await ApiClient.post(
      ApiEndpoints.courseExamSubmit(courseId),
      {
        'answers': answers,
        if (startedAt != null) 'started_at': startedAt,
      },
      requiresAuth: true,
    );
  }
}
