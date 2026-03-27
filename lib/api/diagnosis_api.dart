import 'api_client.dart';
import 'api_endpoints.dart';

class DiagnosisQuestionOption {
  final String text;
  final String blockerType;
  final int score;

  DiagnosisQuestionOption({
    required this.text,
    required this.blockerType,
    required this.score,
  });

  factory DiagnosisQuestionOption.fromJson(Map<String, dynamic> json) {
    return DiagnosisQuestionOption(
      text: (json['text'] ?? '').toString(),
      blockerType: (json['blocker_type'] ?? 'leadGeneration').toString(),
      score: int.tryParse('${json['score'] ?? 0}') ?? 0,
    );
  }
}

class DiagnosisQuestion {
  final int id;
  final String question;
  final int displayOrder;
  final List<DiagnosisQuestionOption> options;

  DiagnosisQuestion({
    required this.id,
    required this.question,
    required this.displayOrder,
    required this.options,
  });

  factory DiagnosisQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List?) ?? const [];
    return DiagnosisQuestion(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      question: (json['question'] ?? '').toString(),
      displayOrder: int.tryParse('${json['display_order'] ?? 0}') ?? 0,
      options: rawOptions
          .whereType<Map>()
          .map((e) => DiagnosisQuestionOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class DiagnosisApi {
  static Future<List<DiagnosisQuestion>> getQuestions() async {
    final res = await ApiClient.get(
      ApiEndpoints.diagnosisQuestions,
      requiresAuth: true,
    );
    if (res['success'] != true) return <DiagnosisQuestion>[];
    final data = (res['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((e) => DiagnosisQuestion.fromJson(Map<String, dynamic>.from(e)))
        .where((q) => q.question.isNotEmpty && q.options.isNotEmpty)
        .toList();
  }

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
