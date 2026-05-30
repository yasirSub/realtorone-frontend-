import 'api_client.dart';
import 'api_endpoints.dart';

class AuthApi {
  static bool isEmailIdentifier(String value) => value.contains('@');

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    final cleaned = identifier.trim();
    final response = await ApiClient.post(ApiEndpoints.login, {
      if (isEmailIdentifier(cleaned)) 'email': cleaned,
      if (!isEmailIdentifier(cleaned)) 'mobile': cleaned,
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
    String identifier,
    String password,
  ) async {
    final cleaned = identifier.trim();
    final response = await ApiClient.post(ApiEndpoints.register, {
      'name': name,
      if (isEmailIdentifier(cleaned)) 'email': cleaned,
      if (!isEmailIdentifier(cleaned)) 'mobile': cleaned,
      'password': password,
    });

    // Save token if registration successful and token provided
    if (response['status'] == 'ok' && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }

    return response;
  }

  static Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    final response = await ApiClient.post(ApiEndpoints.googleLogin, {
      'id_token': idToken,
      if (email != null && email.isNotEmpty) 'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
    });
    
    if (response['status'] == 'ok' && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }

    return response;
  }

  static Future<Map<String, dynamic>> loginWithApple({
    required String identityToken,
    String? email,
    String? firstName,
    String? lastName,
    String? userIdentifier,
  }) async {
    final response = await ApiClient.post('/auth/apple/callback', {
      'identity_token': identityToken,
      if (email != null && email.isNotEmpty) 'email': email,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (userIdentifier != null && userIdentifier.isNotEmpty) 'user_identifier': userIdentifier,
    });

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

  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final cleaned = identifier.trim();
    return await ApiClient.post(ApiEndpoints.forgotPassword, {
      if (isEmailIdentifier(cleaned)) 'email': cleaned,
      if (!isEmailIdentifier(cleaned)) 'mobile': cleaned,
    });
  }

  static Future<Map<String, dynamic>> verifyToken(String email, String token) async {
    return await ApiClient.post(ApiEndpoints.verifyToken, {
      'email': email,
      'token': token,
    });
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    return await ApiClient.post(ApiEndpoints.resetPassword, {
      'email': email,
      'token': token,
      'password': newPassword,
    });
  }

  static Future<Map<String, dynamic>> loginWithPhoneOtp({
    required String idToken,
    String? email,
  }) async {
    final response = await ApiClient.post(ApiEndpoints.loginPhoneOtp, {
      'id_token': idToken,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    if (response['status'] == 'ok' && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }
    return response;
  }

  static Future<Map<String, dynamic>> forgotPasswordPhone(String mobile) async {
    return await ApiClient.post(ApiEndpoints.forgotPasswordPhone, {
      'mobile': mobile,
    });
  }

  static Future<Map<String, dynamic>> resetPasswordPhone({
    required String idToken,
    required String newPassword,
    String? email,
  }) async {
    return await ApiClient.post(ApiEndpoints.resetPasswordPhone, {
      'id_token': idToken,
      'password': newPassword,
      if (email != null && email.isNotEmpty) 'email': email,
    });
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    return await ApiClient.get(ApiEndpoints.health);
  }
}
