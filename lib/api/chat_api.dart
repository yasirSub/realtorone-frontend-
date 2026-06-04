import 'api_client.dart';
import 'api_endpoints.dart';

class ChatApi {
  /// Token usage vs tier limits (profile / chat header).
  static Future<Map<String, dynamic>> getAiQuota() async {
    return ApiClient.get(
      ApiEndpoints.chatAiQuota,
      requiresAuth: true,
    );
  }

  /// Send a message and receive AI reply.
  /// Returns [reply] and [sessionId] on success.
  static Future<Map<String, dynamic>> sendMessage(
    String message, {
    int? sessionId,
    bool voiceReply = false,
    bool voiceMode = false,
    String? voiceId,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (sessionId != null) body['session_id'] = sessionId;
    if (voiceReply) body['voice_reply'] = true;
    if (voiceMode) body['voice_mode'] = true;
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      body['voice_id'] = voiceId.trim();
    }
    return ApiClient.post(
      ApiEndpoints.chat,
      body,
      requiresAuth: true,
      timeout: const Duration(seconds: 120),
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
