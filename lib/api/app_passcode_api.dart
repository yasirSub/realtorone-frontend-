import 'api_client.dart';
import 'api_endpoints.dart';

void _invalidateProfileCache() {
  ApiClient.invalidateEndpointCache(ApiEndpoints.userProfile);
}

class AppPasscodeApi {
  static Future<Map<String, dynamic>> setPasscode({
    required String passcode,
    String? currentPasscode,
  }) async {
    final result = await ApiClient.post(
      ApiEndpoints.appPasscodeSet,
      {
        'passcode': passcode,
        if (currentPasscode != null && currentPasscode.isNotEmpty)
          'current_passcode': currentPasscode,
      },
      requiresAuth: true,
    );
    if (result['success'] == true) {
      _invalidateProfileCache();
    }
    return result;
  }

  static Future<Map<String, dynamic>> verifyPasscode(String passcode) async {
    return ApiClient.post(
      ApiEndpoints.appPasscodeVerify,
      {'passcode': passcode},
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> disablePasscode({
    String? passcode,
    String? idToken,
  }) async {
    final result = await ApiClient.post(
      ApiEndpoints.appPasscodeDisable,
      {
        if (passcode != null && passcode.isNotEmpty) 'passcode': passcode,
        if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
      },
      requiresAuth: true,
    );
    if (result['success'] == true) {
      _invalidateProfileCache();
    }
    return result;
  }

  static Future<Map<String, dynamic>> forgotPasscodeEmail() async {
    return ApiClient.post(
      ApiEndpoints.appPasscodeForgotEmail,
      const {},
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> resetPasscodeEmail({
    required String token,
    required String passcode,
  }) async {
    final result = await ApiClient.post(
      ApiEndpoints.appPasscodeResetEmail,
      {'token': token, 'passcode': passcode},
      requiresAuth: true,
    );
    if (result['success'] == true) {
      _invalidateProfileCache();
    }
    return result;
  }

  static Future<Map<String, dynamic>> forgotPasscodePhone(String mobile) async {
    return ApiClient.post(
      ApiEndpoints.appPasscodeForgotPhone,
      {'mobile': mobile},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> resetPasscodePhone({
    required String idToken,
    required String passcode,
  }) async {
    final result = await ApiClient.post(
      ApiEndpoints.appPasscodeResetPhone,
      {'id_token': idToken, 'passcode': passcode},
      requiresAuth: true,
    );
    if (result['success'] == true) {
      _invalidateProfileCache();
    }
    return result;
  }
}
