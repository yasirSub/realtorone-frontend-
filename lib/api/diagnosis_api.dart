import 'api_client.dart';
import 'api_endpoints.dart';

class DiagnosisApi {
  static Future<Map<String, dynamic>> submitDiagnosis({
    required String primaryBlocker,
    required Map<String, int> scores,
  }) async {
    return await ApiClient.post(ApiEndpoints.diagnosisSubmit, {
      'primary_blocker': primaryBlocker,
      'scores': scores,
    }, requiresAuth: true);
  }
}
