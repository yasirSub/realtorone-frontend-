import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

class ApiClient {
  static String? _token;

  /// Called when an authenticated request returns 401 (session expired / logged out).
  static Future<void> Function()? onSessionExpired;

  /// Called when the API appears unavailable (404 route/HTML, 502–504).
  static Future<void> Function(int statusCode, String endpoint)? onServiceUnavailable;
  static bool _handlingSessionExpiry = false;
  static bool _handlingServiceUnavailable = false;
  /// Suppress full-app maintenance navigation during silent cache refresh.
  static int _backgroundFetchDepth = 0;
  static const Set<String> _preservedLocalKeys = {
    'hasSeenOnboarding',
    'hasSeenAppTourV2',
    'hasSeenAppTourV1',
    'hasAddedDealRoomClient',
  };

  /// Optional hook (e.g. remove FCM token from backend before clearing session).
  static Future<void> Function()? beforeClearToken;

  // Get token from storage (public for file uploads)
  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  // Set token
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Clear token
  static Future<void> clearToken() async {
    try {
      await beforeClearToken?.call();
    } catch (_) {}
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  /// Clear local session data while preserving first-install tutorial flags.
  static Future<void> clearLocalSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final preservedValues = <String, Object>{};
    for (final key in _preservedLocalKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      if (value != null) {
        preservedValues[key] = value;
      }
    }

    await prefs.clear();

    for (final entry in preservedValues.entries) {
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }

  // Build headers
  static Future<Map<String, String>> _buildHeaders({
    bool includeAuth = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static String _cacheStorageKey(String endpoint) {
    final path = endpoint.split('?').first;
    return 'cache_$path';
  }

  static bool _isCacheableSuccess(Map<String, dynamic> data) {
    if (data['service_unavailable'] == true) return false;
    return data['success'] == true || data['status'] == 'ok';
  }

  // GET request with TTL cache + optional background refresh
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
    bool useCache = false,
    Duration cacheMaxAge = const Duration(hours: 6),
    bool revalidateInBackground = true,
  }) async {
    final cacheKey = _cacheStorageKey(endpoint);

    if (useCache) {
      final fresh = await _getCachedData(cacheKey, maxAge: cacheMaxAge);
      if (fresh != null) {
        if (revalidateInBackground) {
          unawaited(
            _refreshCache(
              endpoint: endpoint,
              requiresAuth: requiresAuth,
              cacheKey: cacheKey,
            ),
          );
        }
        return fresh;
      }

      final stale = await _getCachedData(cacheKey);
      if (stale != null) {
        if (revalidateInBackground) {
          unawaited(
            _refreshCache(
              endpoint: endpoint,
              requiresAuth: requiresAuth,
              cacheKey: cacheKey,
            ),
          );
        }
        return stale;
      }
    }

    try {
      final data = await _fetchGet(endpoint, requiresAuth: requiresAuth);
      if (useCache && _isCacheableSuccess(data)) {
        await _saveToCache(cacheKey, data);
      }
      return data;
    } catch (e) {
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) return cachedData;
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _fetchGet(
    String endpoint, {
    required bool requiresAuth,
  }) async {
    final headers = await _buildHeaders(includeAuth: requiresAuth);
    final url =
        '${(endpoint.startsWith('http')) ? '' : ApiEndpoints.baseUrl}$endpoint';

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 30));

    return _handleResponse(
      response,
      sessionRequired: requiresAuth,
      endpoint: endpoint,
    );
  }

  static Future<void> _refreshCache({
    required String endpoint,
    required bool requiresAuth,
    required String cacheKey,
  }) async {
    _backgroundFetchDepth++;
    try {
      final data = await _fetchGet(endpoint, requiresAuth: requiresAuth);
      if (_isCacheableSuccess(data)) {
        await _saveToCache(cacheKey, data);
      }
    } catch (_) {}
    finally {
      if (_backgroundFetchDepth > 0) _backgroundFetchDepth--;
    }
  }

  /// Only startup-critical routes should replace the whole app with maintenance UI.
  static bool _isBootstrapEndpoint(String endpoint) {
    final path = endpoint.split('?').first.toLowerCase();
    return path.contains('app-config') || path.endsWith('/health');
  }

  /// Public GET (e.g. app-config). Cached on device to reduce server reads.
  static Future<Map<String, dynamic>> getPublic(
    String endpoint, {
    bool useCache = true,
    Duration cacheMaxAge = const Duration(minutes: 15),
    bool revalidateInBackground = true,
  }) {
    return get(
      endpoint,
      requiresAuth: false,
      useCache: useCache,
      cacheMaxAge: cacheMaxAge,
      revalidateInBackground: revalidateInBackground,
    );
  }

  static Future<void> _saveToCache(
    String key,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('Cache Save Error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getCachedData(
    String key, {
    Duration? maxAge,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString(key);
      if (cachedStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedStr);
        final ts = decoded['timestamp'];
        if (maxAge != null && ts is int) {
          final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
          if (ageMs > maxAge.inMilliseconds) {
            return null;
          }
        }
        return decoded['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Cache Read Error: $e');
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> invalidateEndpointCache(String endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheStorageKey(endpoint));
    } catch (e) {
      debugPrint('Cache Invalidate Error: $e');
    }
  }

  /// Fetch active webinars for the authenticated user.
  static Future<Map<String, dynamic>> getWebinars() async {
    return get('/webinars', requiresAuth: true, useCache: true);
  }

  /// Momentum AI Advisor consultation
  static Future<Map<String, dynamic>> consultMomentumAi({
    required String taskTitle,
    String? taskDescription,
    String? scriptIdea,
  }) async {
    return post(
      '/momentum/ai-advisor',
      {
        'task_title': taskTitle,
        'task_description': taskDescription,
        'script_idea': scriptIdea,
      },
      requiresAuth: true,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Multipart upload (e.g. Excel import). Field name must match API (`file`).
  static Future<Map<String, dynamic>> postMultipartFile(
    String endpoint, {
    required String filePath,
    String fieldName = 'file',
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (requiresAuth) {
        final token = await getToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(
        response,
        sessionRequired: requiresAuth,
        endpoint: endpoint,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // POST request
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requiresAuth = false,
    Duration? timeout,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      final url = '${(endpoint.startsWith('http')) ? '' : ApiEndpoints.baseUrl}$endpoint';
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(timeout ?? const Duration(seconds: 30));
      return _handleResponse(
        response,
        sessionRequired: requiresAuth,
        endpoint: endpoint,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      final url = '${(endpoint.startsWith('http')) ? '' : ApiEndpoints.baseUrl}$endpoint';
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(data),
      );
      return _handleResponse(
        response,
        sessionRequired: requiresAuth,
        endpoint: endpoint,
      );
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // PATCH request
  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      final url = '${(endpoint.startsWith('http')) ? '' : ApiEndpoints.baseUrl}$endpoint';
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(data),
      );
      return _handleResponse(
        response,
        sessionRequired: requiresAuth,
        endpoint: endpoint,
      );
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      final url = '${(endpoint.startsWith('http')) ? '' : ApiEndpoints.baseUrl}$endpoint';
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      return _handleResponse(
        response,
        sessionRequired: requiresAuth,
        endpoint: endpoint,
      );
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static bool _isInfrastructureFailure(
    int statusCode,
    String endpoint,
    String body,
  ) {
    if (!{404, 502, 503, 504}.contains(statusCode)) {
      return false;
    }
    if (endpoint.contains('app-config')) {
      return true;
    }
    final lower = body.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<html')) {
      return true;
    }
    if (statusCode == 404 && lower.contains('could not be found')) {
      return true;
    }
    return statusCode >= 502;
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    bool sessionRequired = false,
    String endpoint = '',
  }) {
    if (sessionRequired && response.statusCode == 401) {
      _triggerSessionExpired();
    }

    final infrastructureFailure = _isInfrastructureFailure(
      response.statusCode,
      endpoint,
      response.body,
    );
    if (infrastructureFailure) {
      _triggerServiceUnavailable(response.statusCode, endpoint);
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return {
          ...data,
          'statusCode': response.statusCode,
          if (infrastructureFailure) 'service_unavailable': true,
        };
      }
      return {
        'statusCode': response.statusCode,
        'data': data,
        if (infrastructureFailure) 'service_unavailable': true,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to parse response',
        'statusCode': response.statusCode,
        if (infrastructureFailure) 'service_unavailable': true,
      };
    }
  }

  static void _triggerServiceUnavailable(int statusCode, String endpoint) {
    if (_backgroundFetchDepth > 0) return;
    if (!_isBootstrapEndpoint(endpoint)) return;
    if (statusCode == 404 && !endpoint.contains('app-config')) {
      return;
    }
    if (_handlingServiceUnavailable) return;
    final handler = onServiceUnavailable;
    if (handler == null) return;
    _handlingServiceUnavailable = true;
    Future<void>(() async {
      try {
        await handler(statusCode, endpoint);
      } finally {
        _handlingServiceUnavailable = false;
      }
    });
  }

  static void _triggerSessionExpired() {
    if (_handlingSessionExpiry) return;
    _handlingSessionExpiry = true;
    Future<void>(() async {
      try {
        final hadToken = await getToken();
        if (hadToken != null) {
          await clearLocalSessionData();
        }
        await onSessionExpired?.call();
      } finally {
        _handlingSessionExpiry = false;
      }
    });
  }
}
