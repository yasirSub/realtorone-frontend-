/// The 4 main performance blockers identified by diagnosis
enum BlockerType { leadGeneration, confidence, closing, discipline }

extension BlockerTypeExtension on BlockerType {
  String get title {
    switch (this) {
      case BlockerType.leadGeneration:
        return 'Lead Generation Block';
      case BlockerType.confidence:
        return 'Confidence Block';
      case BlockerType.closing:
        return 'Closing Block';
      case BlockerType.discipline:
        return 'Discipline Block';
    }
  }

  String get description {
    switch (this) {
      case BlockerType.leadGeneration:
        return 'You have skills but lack a system to consistently generate leads';
      case BlockerType.confidence:
        return 'You hesitate in client conversations due to knowledge or experience gaps';
      case BlockerType.closing:
        return 'You generate interest but struggle to convert it into deals';
      case BlockerType.discipline:
        return 'You know what to do but lack consistent execution habits';
    }
  }

  String get icon {
    switch (this) {
      case BlockerType.leadGeneration:
        return '🎯';
      case BlockerType.confidence:
        return '💪';
      case BlockerType.closing:
        return '🤝';
      case BlockerType.discipline:
        return '⏰';
    }
  }

  String get color {
    switch (this) {
      case BlockerType.leadGeneration:
        return '#FF6B6B';
      case BlockerType.confidence:
        return '#4ECDC4';
      case BlockerType.closing:
        return '#45B7D1';
      case BlockerType.discipline:
        return '#96CEB4';
    }
  }
}

class DiagnosisQuestion {
  final int id;
  final String question;
  final List<DiagnosisOption> options;
  final String category; // leadGeneration, confidence, closing, discipline

  DiagnosisQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.category,
  });

  factory DiagnosisQuestion.fromJson(Map<String, dynamic> json) {
    return DiagnosisQuestion(
      id: json['id'],
      question: json['question'],
      options: (json['options'] as List)
          .map((o) => DiagnosisOption.fromJson(o))
          .toList(),
      category: json['category'],
    );
  }
}

class DiagnosisOption {
  final int id;
  final String text;
  final int score;
  final String blockerType;

  DiagnosisOption({
    required this.id,
    required this.text,
    required this.score,
    required this.blockerType,
  });

  factory DiagnosisOption.fromJson(Map<String, dynamic> json) {
    return DiagnosisOption(
      id: json['id'],
      text: json['text'],
      score: json['score'],
      blockerType: json['blocker_type'],
    );
  }
}

class DiagnosisResult {
  final BlockerType primaryBlocker;
  final Map<BlockerType, int> scores;
  final List<String> strengths;
  final List<String> limitations;
  final int riskIndex; // 1-10
  final String growthForecast;
  final List<String> recommendedPath;

  DiagnosisResult({
    required this.primaryBlocker,
    required this.scores,
    required this.strengths,
    required this.limitations,
    required this.riskIndex,
    required this.growthForecast,
    required this.recommendedPath,
  });

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) {
    return DiagnosisResult(
      primaryBlocker: BlockerType.values.firstWhere(
        (e) => e.name == json['primary_blocker'],
        orElse: () => BlockerType.leadGeneration,
      ),
      scores: {
        BlockerType.leadGeneration: json['scores']['lead_generation'] ?? 0,
        BlockerType.confidence: json['scores']['confidence'] ?? 0,
        BlockerType.closing: json['scores']['closing'] ?? 0,
        BlockerType.discipline: json['scores']['discipline'] ?? 0,
      },
      strengths: List<String>.from(json['strengths'] ?? []),
      limitations: List<String>.from(json['limitations'] ?? []),
      riskIndex: json['risk_index'] ?? 5,
      growthForecast: json['growth_forecast'] ?? '',
      recommendedPath: List<String>.from(json['recommended_path'] ?? []),
    );
  }
}
