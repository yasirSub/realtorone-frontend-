import 'package:flutter/material.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/register_page.dart';
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
import 'app_routes.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      AppRoutes.initial: (context) => const SplashScreen(),
      AppRoutes.onboarding: (context) => const OnboardingPage(),
      AppRoutes.login: (context) => const LoginPage(),
      AppRoutes.register: (context) => const RegisterPage(),
      AppRoutes.profileSetup: (context) => const ProfileSetupPage(),
      AppRoutes.editProfile: (context) => const EditProfilePage(),
      AppRoutes.diagnosis: (context) => const DiagnosisQuestionsPage(),
      AppRoutes.diagnosisResult: (context) => const DiagnosisResultPage(),
      AppRoutes.main: (context) => const MainNavigation(),
      AppRoutes.beliefRewiring: (context) => const BeliefRewiringPage(),
      AppRoutes.reports: (context) => const ReportsPage(),
      AppRoutes.settings: (context) => const SettingsPage(),
      AppRoutes.dashboard: (context) => const DashboardPage(), // Legacy
    };
  }
}
