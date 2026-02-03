import 'api_client.dart';
import 'api_endpoints.dart';

class AuthApi {
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await ApiClient.post(ApiEndpoints.login, {
      'email': email,
      'password': password,
    });

    // Save token if login successful
    if (response['status'] == 'ok' && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }

    return response;
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await ApiClient.post(ApiEndpoints.register, {
      'name': name,
      'email': email,
      'password': password,
    });

    // Save token if registration successful and token provided
    if (response['status'] == 'ok' && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }

    return response;
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await ApiClient.post(
      ApiEndpoints.logout,
      {},
      requiresAuth: true,
    );
    await ApiClient.clearToken();
    return response;
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await ApiClient.post(ApiEndpoints.forgotPassword, {'email': email});
  }

  static Future<Map<String, dynamic>> resetPassword(
    String token,
    String newPassword,
  ) async {
    return await ApiClient.post(ApiEndpoints.resetPassword, {
      'token': token,
      'password': newPassword,
    });
  }

  static Future<Map<String, dynamic>> verifyEmail(String email) async {
    return await ApiClient.post(ApiEndpoints.verifyEmail, {'email': email});
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    return await ApiClient.get(ApiEndpoints.health);
  }
}
