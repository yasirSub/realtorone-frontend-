import 'api_client.dart';
import 'api_endpoints.dart';

class ChatApi {
  /// Send a message and receive AI reply.
  /// Returns [reply] and [sessionId] on success.
  static Future<Map<String, dynamic>> sendMessage(
    String message, {
    int? sessionId,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (sessionId != null) body['session_id'] = sessionId;
    return ApiClient.post(
      ApiEndpoints.chat,
      body,
      requiresAuth: true,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Get chat history for a session.
  static Future<Map<String, dynamic>> getHistory(int sessionId) async {
    return ApiClient.get(
      ApiEndpoints.chatHistorySession(sessionId),
      requiresAuth: true,
    );
  }

  /// List user's chat sessions.
  static Future<Map<String, dynamic>> listSessions() async {
    return ApiClient.get(
      ApiEndpoints.chatHistory,
      requiresAuth: true,
    );
  }

  /// Delete a chat session.
  static Future<Map<String, dynamic>> deleteSession(int sessionId) async {
    return ApiClient.delete(
      ApiEndpoints.chatDeleteSession(sessionId),
      requiresAuth: true,
    );
  }
}
