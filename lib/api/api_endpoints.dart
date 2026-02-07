class ApiEndpoints {
  // Base URL
  static const String baseUrl = 'https://realtorone-backend.onrender.com/api';

  // Auth endpoints
  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String health = '/health';

  // Password endpoints
  static const String forgotPassword = '/password/forgot';
  static const String resetPassword = '/password/reset';

  // Email verification
  static const String verifyEmail = '/email/verify';

  // User endpoints
  static const String userProfile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String profileSetup = '/user/profile/setup';
  static const String changePassword = '/user/change-password';
  static const String uploadPhoto = '/user/photo';

  // Diagnosis endpoints
  static const String diagnosisSubmit = '/diagnosis/submit';

  // Activities endpoints
  static const String activities = '/activities';
  static const String activitiesProgress = '/activities/progress';
  static String completeActivity(int id) => '/activities/$id/complete';

  // Learning endpoints
  static const String learningCategories = '/learning/categories';
  static const String learningContent = '/learning/content';
  static const String learningProgress = '/learning/progress';

  // Dashboard endpoints
  static const String dashboardStats = '/dashboard/stats';
  static const String growthReport = '/reports/growth';
}
