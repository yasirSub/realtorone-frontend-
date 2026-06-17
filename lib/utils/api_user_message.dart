/// Safe user-facing text from API / SDK error payloads.
class ApiUserMessage {
  ApiUserMessage._();

  static const String defaultError =
      'Something went wrong. Please try again.';
  static const String connectionError =
      'Connection error. Please check your network and try again.';

  /// Pull message from common API response keys.
  static String fromResponse(
    Map<String, dynamic>? response, {
    String fallback = defaultError,
  }) {
    if (response == null) return fallback;

    final direct = response['message'] ?? response['error'] ?? response['msg'];
    if (direct != null) {
      return sanitize(direct.toString(), fallback: fallback);
    }

    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return sanitize(first.first.toString(), fallback: fallback);
      }
      return sanitize(first.toString(), fallback: fallback);
    }

    final statusCode = response['statusCode'];
    if (statusCode == 401) {
      return 'Session expired. Please sign in again.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again.';
    }

    return fallback;
  }

  /// Never show null, undefined, or raw exception blobs to users.
  static String sanitize(
    String? raw, {
    required String fallback,
  }) {
    if (raw == null) return fallback;
    final text = raw.trim();
    if (text.isEmpty) return fallback;

    final lower = text.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'nan' ||
        lower == 'unauthorized') {
      return fallback;
    }

    if (text.startsWith('Instance of ') ||
        text.contains('FormatException') ||
        (text.contains('Exception') && text.length > 80)) {
      return fallback;
    }

    return text;
  }
}
