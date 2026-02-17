import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_client.dart';
import 'api_endpoints.dart';

class UserApi {
  static Future<Map<String, dynamic>> getProfile({bool useCache = true}) async {
    return await ApiClient.get(
      ApiEndpoints.userProfile,
      requiresAuth: true,
      useCache: useCache,
    );
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? mobile,
    String? city,
    String? brokerage,
    String? instagram,
    String? linkedin,
    int? yearsExperience,
    double? currentMonthlyIncome,
    double? targetMonthlyIncome,
    int? onboardingStep,
    bool? isProfileComplete,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (mobile != null) data['mobile'] = mobile;
    if (city != null) data['city'] = city;
    if (brokerage != null) data['brokerage'] = brokerage;
    if (instagram != null) data['instagram'] = instagram;
    if (linkedin != null) data['linkedin'] = linkedin;
    if (yearsExperience != null) data['years_experience'] = yearsExperience;
    if (currentMonthlyIncome != null) {
      data['current_monthly_income'] = currentMonthlyIncome;
    }
    if (targetMonthlyIncome != null) {
      data['target_monthly_income'] = targetMonthlyIncome;
    }
    if (onboardingStep != null) data['onboarding_step'] = onboardingStep;
    if (isProfileComplete != null)
      data['is_profile_complete'] = isProfileComplete;

    final result = await ApiClient.put(
      ApiEndpoints.updateProfile,
      data,
      requiresAuth: true,
    );

    // Clear cache after update to ensure fresh data on next fetch
    if (result['success'] == true || result['status'] == 'ok') {
      await ApiClient.clearCache();
    }

    return result;
  }

  static Future<Map<String, dynamic>> setupProfile({
    required String name,
    required String email,
    required String mobile,
    required String city,
    required String brokerage,
    String? instagram,
    String? linkedin,
    int? yearsExperience,
    double? currentMonthlyIncome,
    double? targetMonthlyIncome,
    int? onboardingStep,
    bool? isProfileComplete,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'mobile': mobile,
      'city': city,
      'brokerage': brokerage,
    };
    if (isProfileComplete != null)
      data['is_profile_complete'] = isProfileComplete;
    if (onboardingStep != null) data['onboarding_step'] = onboardingStep;
    if (instagram != null) data['instagram'] = instagram;
    if (linkedin != null) data['linkedin'] = linkedin;
    if (yearsExperience != null) data['years_experience'] = yearsExperience;
    if (currentMonthlyIncome != null) {
      data['current_monthly_income'] = currentMonthlyIncome;
    }
    if (targetMonthlyIncome != null) {
      data['target_monthly_income'] = targetMonthlyIncome;
    }

    final result = await ApiClient.put(
      ApiEndpoints.profileSetup,
      data,
      requiresAuth: true,
    );

    // Clear cache after setup to ensure fresh data on next fetch
    if (result['success'] == true || result['status'] == 'ok') {
      await ApiClient.clearCache();
    }

    return result;
  }

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await ApiClient.post(ApiEndpoints.changePassword, {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, requiresAuth: true);
  }

  static Future<Map<String, dynamic>> uploadPhoto(File photo) async {
    try {
      final token = await ApiClient.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.uploadPhoto}'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      // Clear cache after photo upload
      if (data['success'] == true) {
        await ApiClient.clearCache();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getGrowthReport(String period) async {
    return await ApiClient.get(
      '${ApiEndpoints.growthReport}?period=$period',
      requiresAuth: true,
      useCache: true,
    );
  }

  static Future<Map<String, dynamic>> getTodayTasks() async {
    return await ApiClient.get(
      ApiEndpoints.todayTasks,
      requiresAuth: true,
      useCache: true,
    );
  }

  static Future<Map<String, dynamic>> completeTask(int id) async {
    return await ApiClient.put(
      ApiEndpoints.completeActivity(id),
      {},
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> getRewards() async {
    return await ApiClient.get(
      ApiEndpoints.userRewards,
      requiresAuth: true,
      useCache: true,
    );
  }

  static Future<Map<String, dynamic>> getPointsHistory({int limit = 100, int offset = 0}) async {
    return await ApiClient.get(
      '${ApiEndpoints.pointsHistory}?limit=$limit&offset=$offset',
      requiresAuth: true,
      useCache: false, // Always fetch fresh history
    );
  }
}
