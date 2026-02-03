class UserModel {
  final int? id;
  final String name;
  final String email;
  final String? mobile;
  final String? city;
  final String? brokerage;
  final String? instagram;
  final String? linkedin;
  final int? yearsExperience;
  final double? currentMonthlyIncome;
  final double? targetMonthlyIncome;
  final String? profilePhoto;
  final bool isProfileComplete;
  final bool hasCompletedDiagnosis;
  final String? diagnosisBlocker;
  final int growthScore;
  final int executionRate;
  final int mindsetIndex;
  final String? rank;
  final bool isPremium;
  final DateTime? createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.city,
    this.brokerage,
    this.instagram,
    this.linkedin,
    this.yearsExperience,
    this.currentMonthlyIncome,
    this.targetMonthlyIncome,
    this.profilePhoto,
    this.isProfileComplete = false,
    this.hasCompletedDiagnosis = false,
    this.diagnosisBlocker,
    this.growthScore = 0,
    this.executionRate = 0,
    this.mindsetIndex = 0,
    this.rank,
    this.isPremium = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'],
      city: json['city'],
      brokerage: json['brokerage'],
      instagram: json['instagram'],
      linkedin: json['linkedin'],
      yearsExperience: json['years_experience'],
      currentMonthlyIncome: json['current_monthly_income']?.toDouble(),
      targetMonthlyIncome: json['target_monthly_income']?.toDouble(),
      profilePhoto: json['profile_photo'],
      isProfileComplete: json['is_profile_complete'] ?? false,
      hasCompletedDiagnosis: json['has_completed_diagnosis'] ?? false,
      diagnosisBlocker: json['diagnosis_blocker'],
      growthScore: json['growth_score'] ?? 0,
      executionRate: json['execution_rate'] ?? 0,
      mindsetIndex: json['mindset_index'] ?? 0,
      rank: json['rank'],
      isPremium: json['is_premium'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'city': city,
      'brokerage': brokerage,
      'instagram': instagram,
      'linkedin': linkedin,
      'years_experience': yearsExperience,
      'current_monthly_income': currentMonthlyIncome,
      'target_monthly_income': targetMonthlyIncome,
      'profile_photo': profilePhoto,
      'is_profile_complete': isProfileComplete,
      'has_completed_diagnosis': hasCompletedDiagnosis,
      'diagnosis_blocker': diagnosisBlocker,
      'growth_score': growthScore,
      'execution_rate': executionRate,
      'mindset_index': mindsetIndex,
      'rank': rank,
      'is_premium': isPremium,
    };
  }

  UserModel copyWith({
    int? id,
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
    String? profilePhoto,
    bool? isProfileComplete,
    bool? hasCompletedDiagnosis,
    String? diagnosisBlocker,
    int? growthScore,
    int? executionRate,
    int? mindsetIndex,
    String? rank,
    bool? isPremium,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      city: city ?? this.city,
      brokerage: brokerage ?? this.brokerage,
      instagram: instagram ?? this.instagram,
      linkedin: linkedin ?? this.linkedin,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      currentMonthlyIncome: currentMonthlyIncome ?? this.currentMonthlyIncome,
      targetMonthlyIncome: targetMonthlyIncome ?? this.targetMonthlyIncome,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      hasCompletedDiagnosis:
          hasCompletedDiagnosis ?? this.hasCompletedDiagnosis,
      diagnosisBlocker: diagnosisBlocker ?? this.diagnosisBlocker,
      growthScore: growthScore ?? this.growthScore,
      executionRate: executionRate ?? this.executionRate,
      mindsetIndex: mindsetIndex ?? this.mindsetIndex,
      rank: rank ?? this.rank,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
