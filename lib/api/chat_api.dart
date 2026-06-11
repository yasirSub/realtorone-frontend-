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
    final timeout = voiceReply || voiceMode
        ? const Duration(seconds: 150)
        : const Duration(seconds: 120);
    return ApiClient.post(
      ApiEndpoints.chat,
      body,
      requiresAuth: true,
      timeout: timeout,
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

  /// Cloud TTS for a reply (after /chat returns text — avoids slow combined requests).
  static Future<Map<String, dynamic>> synthesizeVoice(
    String text, {
    String? voiceId,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      body['voice_id'] = voiceId.trim();
    }
    return ApiClient.post(
      ApiEndpoints.chatVoiceAudio,
      body,
      requiresAuth: true,
      timeout: const Duration(seconds: 90),
    );
  }

  /// Delete a chat session.
  static Future<Map<String, dynamic>> deleteSession(int sessionId) async {
    return ApiClient.delete(
      ApiEndpoints.chatDeleteSession(sessionId),
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> getFeedbackCategories() async {
    return ApiClient.get(
      ApiEndpoints.chatFeedbackCategories,
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> submitFeedback({
    required String category,
    required String message,
    int? sessionId,
  }) async {
    final body = <String, dynamic>{
      'category': category,
      'message': message,
    };
    if (sessionId != null) body['session_id'] = sessionId;
    return ApiClient.post(
      ApiEndpoints.chatFeedback,
      body,
      requiresAuth: true,
    );
  }
}
