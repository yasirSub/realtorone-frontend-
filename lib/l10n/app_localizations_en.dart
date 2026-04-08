// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RealtorOne';

  @override
  String get settingsScreenTitle => 'SETTINGS';

  @override
  String get settingsSectionAccountSecurity => 'ACCOUNT & SECURITY';

  @override
  String get settingsSectionAppPreferences => 'APP PREFERENCES';

  @override
  String get settingsSectionLegal => 'LEGAL';

  @override
  String get settingsEditProfileTitle => 'Edit Profile';

  @override
  String get settingsEditProfileSubtitle => 'Update your professional info';

  @override
  String get settingsChangePasswordTitle => 'Change Password';

  @override
  String get settingsChangePasswordSubtitle => 'Keep your account secure';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitleEnglish => 'English';

  @override
  String get settingsLanguageSubtitleArabic => 'Arabic (UAE)';

  @override
  String get settingsNewLeadAlertsTitle => 'New Lead Alerts';

  @override
  String get settingsNewLeadAlertsSubtitle =>
      'Instant notification for new leads';

  @override
  String get settingsWeeklyReportsTitle => 'Weekly Performance Reports';

  @override
  String get settingsWeeklyReportsSubtitle => 'Get growth insights via email';

  @override
  String get settingsDarkModeTitle => 'Dark Mode';

  @override
  String get settingsDarkModeSubtitle => 'Switch to a darker interface';

  @override
  String get settingsPrivacyTitle => 'Privacy Policy';

  @override
  String get settingsPrivacySubtitle =>
      'How we handle your data — opens in app (admin-editable)';

  @override
  String get settingsTermsTitle => 'Terms & Conditions';

  @override
  String get settingsTermsSubtitle =>
      'Terms of service — opens in app (admin-editable)';

  @override
  String get settingsDeleteAccount => 'DELETE ACCOUNT';

  @override
  String get settingsLogout => 'LOGOUT';

  @override
  String get settingsLoggingOut => 'LOGGING OUT...';

  @override
  String get settingsVersion => 'Version 1.2.4';

  @override
  String get languagePickerTitle => 'Choose language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabicUae => 'العربية (الإمارات)';

  @override
  String get navHome => 'HOME';

  @override
  String get navTasks => 'TASKS';

  @override
  String get navLearn => 'LEARN';

  @override
  String get navProfile => 'PROFILE';

  @override
  String get homeWelcomeBack => 'Welcome back,';

  @override
  String get homePerformanceReady => 'Your performance report is ready.';

  @override
  String get homeGuestName => 'REALTOR ALPHA';

  @override
  String get homeTodayFocus => 'Today Focus';

  @override
  String homeTasksProgress(int done, int total, int pct) {
    return '$done / $total tasks done · $pct%';
  }

  @override
  String get homeHotLeads => 'Hot leads';

  @override
  String get homeAtRisk4x => 'At risk 4x';

  @override
  String get homeNurture => 'Nurture';

  @override
  String get homeRemaining => 'Remaining';

  @override
  String get homeOpenTasks => 'Open Tasks';

  @override
  String get homeOpenPipeline => 'Open Pipeline';

  @override
  String get homeNotificationsTooltip => 'Notifications';

  @override
  String get activityLogTitle => 'ACTIVITY LOG';

  @override
  String get activityLogSubtitle => 'Today\'s recent actions and progress';

  @override
  String get activityLogOpen => 'Open';

  @override
  String get activityLogStreak => 'STREAK';

  @override
  String get activityLogPoints => 'POINTS';

  @override
  String get activityLogEmpty => 'No activity logged today yet.';

  @override
  String get growthPotential => 'Growth Potential';

  @override
  String get executionRate => 'Execution Rate';

  @override
  String get tourQuickLabel => 'QUICK TOUR';

  @override
  String tourStepCounter(int current, int total) {
    return 'STEP $current OF $total';
  }

  @override
  String get tourSkipTooltip => 'Skip tour';

  @override
  String get tourBack => '← Back';

  @override
  String get tourContinue => 'CONTINUE';

  @override
  String get tourGetStarted => 'GET STARTED';

  @override
  String get tourSkipEntire => 'Skip entire tour';

  @override
  String tourSemantics(int current, int total, String title) {
    return 'Quick tour, step $current of $total: $title';
  }

  @override
  String get tourWelcomeTitle => 'Welcome to RealtorOne';

  @override
  String get tourWelcomeBody =>
      'This short walkthrough highlights where to execute daily work—momentum, Tasks, learning, and your account.';

  @override
  String get tourSubconsciousTitle => 'Tasks — Subconscious workspace';

  @override
  String get tourSubconsciousBody =>
      'Open Tasks, then use Subconscious for identity conditioning: journaling, guided audio, affirmations, and inner-game work. Logging here keeps your streak and discipline signal accurate.';

  @override
  String get tourDealRoomTitle => 'Tasks — Deal Room (Clients)';

  @override
  String get tourDealRoomBody =>
      'Under Conscious, this Clients control switches between Deal Room (pipeline and client actions) and Revenue tracking. Deal Room is where you run lead follow-up and client momentum.';

  @override
  String get tourLearnTitle => 'Learning hub';

  @override
  String get tourLearnBody =>
      'Courses and modules live here — use Learn when you’re ready to stack skills after your tasks.';

  @override
  String get tourProfileTitle => 'Profile & settings';

  @override
  String get tourProfileBody =>
      'Subscription, account details, and preferences are under Profile.';

  @override
  String get profileSectionSettings => 'Profile Settings';

  @override
  String get profileSectionPerformance => 'Performance';

  @override
  String get profileSectionMyPlan => 'My Plan';

  @override
  String get profileSectionAccount => 'Account Settings';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditSubtitle => 'Manage your personal info';

  @override
  String get profileTopRealtorTitle => 'Top Realtor';

  @override
  String get profileTopRealtorSubtitle =>
      'View your leaderboard rank and score breakdown';

  @override
  String get profileConsultantPlan => 'Consultant Plan';

  @override
  String get profilePlanSuffix => ' Plan';

  @override
  String get profilePremiumSubtitle => 'Tap to manage your subscription';

  @override
  String get profileUpgradeSubtitle => 'Upgrade to unlock premium features';

  @override
  String get profileAppSettingsTitle => 'App Settings';

  @override
  String get profileAppSettingsSubtitle => 'Security, notifications, and more';

  @override
  String get profileLogout => 'LOGOUT';

  @override
  String get profileDefaultName => 'Realtor Name';

  @override
  String get profileVerifiedElite => 'VERIFIED ELITE';

  @override
  String profilePercentReady(int pct) {
    return '$pct% READY';
  }

  @override
  String get profileStatPoints => 'POINTS';

  @override
  String get profileStatExecution => 'EXECUTION';

  @override
  String get profileStatPlan => 'PLAN';

  @override
  String get profileFooterBrand => 'REALTOR ONE';

  @override
  String get profileVersion => 'Version 1.2.4';

  @override
  String profilePercentComplete(int pct) {
    return '$pct% COMPLETE';
  }

  @override
  String get profileUpdatePhoto => 'UPDATE PHOTO';

  @override
  String get profileCamera => 'Camera';

  @override
  String get profileGallery => 'Gallery';

  @override
  String get profileLogoutDialogSemantics => 'Confirm log out';

  @override
  String get profileLogoutDialogTitle => 'Log out';

  @override
  String get profileLogoutDialogMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get profileLogoutDialogCancel => 'Cancel';

  @override
  String get profileLogoutDialogConfirm => 'Log out';

  @override
  String get maintenanceTitle => 'We’ll be right back';

  @override
  String get maintenanceBody =>
      'We’re performing a short maintenance window to upgrade RealtorOne. Your dashboard and clients are safe in the background.';

  @override
  String get maintenanceRetry => 'TRY AGAIN';

  @override
  String maintenanceVersionLabel(String version) {
    return 'Running app version $version';
  }

  @override
  String get updateTitle => 'Update required';

  @override
  String updateBody(String platform) {
    return 'To keep your $platform app secure and in sync with the latest features, please update to the latest version.';
  }

  @override
  String updateVersionDetails(String current, String required) {
    return 'Current: $current • Required: $required';
  }

  @override
  String get updateButtonLabel => 'GO TO STORE';

  @override
  String get updateContinueLabel => 'Continue without updating';
}
