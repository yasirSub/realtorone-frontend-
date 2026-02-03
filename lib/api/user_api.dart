import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_client.dart';
import 'api_endpoints.dart';

class UserApi {
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiClient.get(ApiEndpoints.userProfile, requiresAuth: true);
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

    return await ApiClient.put(
      ApiEndpoints.updateProfile,
      data,
      requiresAuth: true,
    );
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
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'mobile': mobile,
      'city': city,
      'brokerage': brokerage,
      'is_profile_complete': true,
    };
    if (instagram != null) data['instagram'] = instagram;
    if (linkedin != null) data['linkedin'] = linkedin;
    if (yearsExperience != null) data['years_experience'] = yearsExperience;
    if (currentMonthlyIncome != null) {
      data['current_monthly_income'] = currentMonthlyIncome;
    }
    if (targetMonthlyIncome != null) {
      data['target_monthly_income'] = targetMonthlyIncome;
    }

    return await ApiClient.put(
      ApiEndpoints.profileSetup,
      data,
      requiresAuth: true,
    );
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

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getGrowthReport(String period) async {
    return await ApiClient.get(
      '${ApiEndpoints.growthReport}?period=$period',
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> getTodayTasks() async {
    return await ApiClient.get('/tasks/today', requiresAuth: true);
  }
}
