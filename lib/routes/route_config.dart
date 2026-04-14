import 'package:flutter/material.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/register_page.dart';
import '../screens/auth/forgot_password_page.dart';
import '../screens/auth/otp_verification_page.dart';
import '../screens/auth/reset_password_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/onboarding/onboarding_page.dart';
import '../screens/onboarding/profile_setup_page.dart';
import '../screens/diagnosis/diagnosis_questions_page.dart';
import '../screens/diagnosis/diagnosis_result_page.dart';
import '../screens/main_navigation.dart';
import '../screens/belief_rewiring/belief_rewiring_page.dart';
import '../screens/profile/edit_profile_page.dart';
import '../screens/profile/settings_page.dart';
import '../screens/reports/reports_page.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/subscription/subscription_plans_page.dart';
import 'app_routes.dart';

import '../screens/rewards/rewards_page.dart';
import '../screens/results/results_tracker_page.dart';
import '../screens/activities/activities_page.dart';
import '../screens/leaderboard/leaderboard_page.dart';
import '../screens/badges/badges_page.dart';
import '../screens/chatbot/reven_chat_page.dart';

import '../screens/learning/course_curriculum_page.dart';
import '../screens/learning/video_player_page.dart';
import '../screens/learning/course_exam_page.dart';
import '../screens/system/maintenance_page.dart';
import '../screens/system/update_required_page.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      AppRoutes.initial: (context) => const SplashScreen(),
      AppRoutes.onboarding: (context) => const OnboardingPage(),
      AppRoutes.login: (context) => const LoginPage(),
      AppRoutes.register: (context) => const RegisterPage(),
      AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
      AppRoutes.verifyOtp: (context) {
        final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
        return OtpVerificationPage(email: email);
      },
      AppRoutes.resetPassword: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
        return ResetPasswordPage(
          email: args['email'] as String?,
          token: args['token'] as String?,
        );
      },
      AppRoutes.profileSetup: (context) => const ProfileSetupPage(),
      AppRoutes.editProfile: (context) => const EditProfilePage(),
      AppRoutes.diagnosis: (context) => const DiagnosisQuestionsPage(),
      AppRoutes.diagnosisResult: (context) => const DiagnosisResultPage(),
      AppRoutes.main: (context) => const MainNavigation(),
      AppRoutes.beliefRewiring: (context) => const BeliefRewiringPage(),
      AppRoutes.reports: (context) => const ReportsPage(),
      AppRoutes.settings: (context) => const SettingsPage(),
      AppRoutes.dashboard: (context) => const DashboardPage(), // Legacy
      AppRoutes.subscriptionPlans: (context) => const SubscriptionPlansPage(),
      AppRoutes.rewards: (context) => const RewardsPage(),
      AppRoutes.resultsTracker: (context) => const ResultsTrackerPage(),
      AppRoutes.activities: (context) => const ActivitiesPage(),
      AppRoutes.leaderboard: (context) => const LeaderboardPage(),
      AppRoutes.badges: (context) => const BadgesPage(),
      AppRoutes.revenChat: (context) => const RevenChatPage(),
      AppRoutes.maintenance: (context) {
        final args = ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>? ?? <String, dynamic>{};
        return MaintenancePage(
          message: (args['message'] as String?) ?? '',
        );
      },
      AppRoutes.updateRequired: (context) {
        final args = ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>? ?? <String, dynamic>{};
        return UpdateRequiredPage(
          minVersion: (args['minVersion'] as String?) ?? '',
          storeUrl: (args['storeUrl'] as String?) ?? '',
          platformLabel: (args['platformLabel'] as String?) ?? 'mobile',
        );
      },
      AppRoutes.courseCurriculum: (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return CourseCurriculumPage(
          courseId: args['courseId'],
          courseTitle: args['courseTitle'],
        );
      },
      AppRoutes.videoPlayer: (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return VideoPlayerPage(
          videoUrl: args['videoUrl'],
          title: args['title'],
          materialId: args['materialId'],
        );
      },
      AppRoutes.courseExam: (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return CourseExamPage(
          courseId: args['courseId'],
          courseTitle: args['courseTitle'] ?? 'Exam',
        );
      },
    };
  }
}
