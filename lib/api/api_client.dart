import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

class ApiClient {
  static String? _token;

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
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
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

  // GET request with internal caching
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
    bool useCache = false,
  }) async {
    final cacheKey = 'cache_$endpoint';

    // Attempt to return cached data first for speed
    if (useCache) {
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        // We return the cached data immediately, but the caller should usually
        // handle a second update if they want fresh data.
        // For simplicity in this implementation, we'll fetch fresh in background
        // if we want, but usually, the pattern is to return cache THEN fetch.
        // To keep it simple for now, we'll return cache if available.
        return cachedData;
      }
    }

    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      debugPrint('----------------------------------------------');
      debugPrint('[API CONNECT] URL: ${ApiEndpoints.baseUrl}$endpoint');
      debugPrint('----------------------------------------------');
      final response = await http
          .get(Uri.parse('${ApiEndpoints.baseUrl}$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _handleResponse(response);

      // Save to cache if successful
      if (useCache && data['status'] != 'error') {
        _saveToCache(cacheKey, data);
      }

      return data;
    } catch (e) {
      // If network fails, try cache as fallback even if useCache was false
      // as a safety measure for performance
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) return cachedData;

      return {'status': 'error', 'message': e.toString()};
    }
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

  static Future<Map<String, dynamic>?> _getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString(key);
      if (cachedStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedStr);
        // Optional: Add TTL (Time To Live) check here if needed
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

  // POST request
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _buildHeaders(includeAuth: requiresAuth);
      debugPrint('----------------------------------------------');
      debugPrint('[API CONNECT] URL: ${ApiEndpoints.baseUrl}$endpoint');
      debugPrint('----------------------------------------------');
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
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
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      return _handleResponse(response);
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
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to parse response',
        'statusCode': response.statusCode,
      };
    }
  }
}
