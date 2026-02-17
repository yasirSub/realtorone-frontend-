class ApiEndpoints {
  // Base URL
  static const String baseUrl = 'http://192.168.31.129:8000/api';

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
  static const String userRewards = '/user/rewards';

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
  static const String momentumDashboard = '/dashboard/momentum';
  static const String momentumLeaders = '/admin/momentum-leaders';

  // Activity Logging
  static const String logActivity = '/activities/log';
  static const String activityTypes = '/activity-types';

  // Tasks
  static const String todayTasks = '/tasks/today';

  // Courses (End-user)
  static const String courses = '/courses';

  // Subscription endpoints
  static const String packages = '/packages';
  static const String mySubscription = '/user/subscription';
  static const String validateCoupon = '/subscriptions/validate-coupon';
  static const String purchaseSubscription = '/subscriptions/purchase';

  // ============== PHASE 2: RESULTS TRACKER ==============
  static const String results = '/results';
  static const String resultsMonthlyGraph = '/results/monthly-graph';

  // ============== PHASE 2: FOLLOW-UP GUARD ==============
  static const String followUps = '/follow-ups';
  static String completeFollowUp(int id) => '/follow-ups/$id/complete';

  // ============== PHASE 4: LEADERBOARD ==============
  static const String leaderboard = '/leaderboard';
  static const String leaderboardCategories = '/leaderboard/categories';
  static const String leaderboardRefresh = '/leaderboard/refresh';

  // ============== PHASE 4: BADGES ==============
  static const String badges = '/badges';
  static const String badgesRecent = '/badges/recent';

  // ============== PHASE 6: WEEKLY REVIEW ==============
  static const String weeklyReview = '/weekly-review';
}
