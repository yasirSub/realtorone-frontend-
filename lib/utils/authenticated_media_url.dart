import '../api/api_client.dart';
import '../api/app_config.dart';

/// Resolves course/media URLs and attaches auth for `/api/stream/` routes.
///
/// [SfPdfViewer.network] and external browsers do not send `Authorization`
/// headers reliably, so we append `?token=` (supported by backend `getAuthUser`).
class AuthenticatedMediaUrl {
  static String materialPathToStreamUrl(String path) {
    final root = AppConfig.apiOrigin;
    var key = path.trim();
    if (key.contains('://')) {
      final uri = Uri.tryParse(key);
      if (uri != null && uri.path.contains('/api/stream/')) {
        key = uri.path;
      } else {
        return key;
      }
    }

    if (key.startsWith('/api/stream/')) {
      key = key.substring('/api/stream/'.length);
    } else if (key.startsWith('/storage/')) {
      key = key.substring('/storage/'.length);
    } else if (key.startsWith('/')) {
      key = key.substring(1);
    }

    if (!key.contains('/') && !key.startsWith('course-assets/')) {
      key = 'course-assets/$key';
    }

    final encoded = key
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    return '$root/api/stream/$encoded';
  }

  static Future<String> resolve(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return url;

    if (!url.contains('://')) {
      url = materialPathToStreamUrl(url);
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.path.contains('/api/stream/') &&
          uri.host.isNotEmpty) {
        // Already absolute stream URL — keep host, ensure path encoded.
        url = uri.toString();
      }
    }

    if (url.contains('/api/stream/') && !_hasTokenQuery(url)) {
      final token = await ApiClient.getToken();
      if (token != null && token.isNotEmpty) {
        final sep = url.contains('?') ? '&' : '?';
        url = '$url${sep}token=${Uri.encodeQueryComponent(token)}';
      }
    }

    return url;
  }

  static Future<Map<String, String>> streamHeaders() async {
    final token = await ApiClient.getToken();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  static bool _hasTokenQuery(String url) {
    return RegExp(r'[?&]token=').hasMatch(url);
  }
}
