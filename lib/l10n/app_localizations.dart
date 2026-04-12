import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RealtorOne'**
  String get appTitle;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsScreenTitle;

  /// No description provided for @settingsSectionAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & SECURITY'**
  String get settingsSectionAccountSecurity;

  /// No description provided for @settingsSectionAppPreferences.
  ///
  /// In en, this message translates to:
  /// **'APP PREFERENCES'**
  String get settingsSectionAppPreferences;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get settingsSectionLegal;

  /// No description provided for @settingsEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsEditProfileTitle;

  /// No description provided for @settingsEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your professional info'**
  String get settingsEditProfileSubtitle;

  /// No description provided for @settingsChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePasswordTitle;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your account secure'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitleEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageSubtitleEnglish;

  /// No description provided for @settingsLanguageSubtitleArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic (UAE)'**
  String get settingsLanguageSubtitleArabic;

  /// No description provided for @settingsNewLeadAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'New Lead Alerts'**
  String get settingsNewLeadAlertsTitle;

  /// No description provided for @settingsNewLeadAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instant notification for new leads'**
  String get settingsNewLeadAlertsSubtitle;

  /// No description provided for @settingsWeeklyReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Performance Reports'**
  String get settingsWeeklyReportsTitle;

  /// No description provided for @settingsWeeklyReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get growth insights via email'**
  String get settingsWeeklyReportsSubtitle;

  /// No description provided for @settingsDarkModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkModeTitle;

  /// No description provided for @settingsDarkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a darker interface'**
  String get settingsDarkModeSubtitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data — opens in app (admin-editable)'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get settingsTermsTitle;

  /// No description provided for @settingsTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of service — opens in app (admin-editable)'**
  String get settingsTermsSubtitle;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'DELETE ACCOUNT'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get settingsLogout;

  /// No description provided for @settingsLoggingOut.
  ///
  /// In en, this message translates to:
  /// **'LOGGING OUT...'**
  String get settingsLoggingOut;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.2.4'**
  String get settingsVersion;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languagePickerTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabicUae.
  ///
  /// In en, this message translates to:
  /// **'العربية (الإمارات)'**
  String get languageArabicUae;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get navHome;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'TASKS'**
  String get navTasks;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'LEARN'**
  String get navLearn;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get navProfile;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get homeWelcomeBack;

  /// No description provided for @homePerformanceReady.
  ///
  /// In en, this message translates to:
  /// **'Your performance report is ready.'**
  String get homePerformanceReady;

  /// No description provided for @homeGuestName.
  ///
  /// In en, this message translates to:
  /// **'REALTOR ALPHA'**
  String get homeGuestName;

  /// No description provided for @homeTodayFocus.
  ///
  /// In en, this message translates to:
  /// **'Today Focus'**
  String get homeTodayFocus;

  /// No description provided for @homeTasksProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} tasks done · {pct}%'**
  String homeTasksProgress(int done, int total, int pct);

  /// No description provided for @homeHotLeads.
  ///
  /// In en, this message translates to:
  /// **'Hot leads'**
  String get homeHotLeads;

  /// No description provided for @homeAtRisk4x.
  ///
  /// In en, this message translates to:
  /// **'At risk 4x'**
  String get homeAtRisk4x;

  /// No description provided for @homeNurture.
  ///
  /// In en, this message translates to:
  /// **'Nurture'**
  String get homeNurture;

  /// No description provided for @homeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get homeRemaining;

  /// No description provided for @homeOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'Open Tasks'**
  String get homeOpenTasks;

  /// No description provided for @homeOpenPipeline.
  ///
  /// In en, this message translates to:
  /// **'Open Pipeline'**
  String get homeOpenPipeline;

  /// No description provided for @homeNotificationsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotificationsTooltip;

  /// No description provided for @activityLogTitle.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY LOG'**
  String get activityLogTitle;

  /// No description provided for @activityLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s recent actions and progress'**
  String get activityLogSubtitle;

  /// No description provided for @activityLogOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get activityLogOpen;

  /// No description provided for @activityLogStreak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get activityLogStreak;

  /// No description provided for @activityLogPoints.
  ///
  /// In en, this message translates to:
  /// **'POINTS'**
  String get activityLogPoints;

  /// No description provided for @activityLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity logged today yet.'**
  String get activityLogEmpty;

  /// No description provided for @growthPotential.
  ///
  /// In en, this message translates to:
  /// **'Growth Potential'**
  String get growthPotential;

  /// No description provided for @executionRate.
  ///
  /// In en, this message translates to:
  /// **'Execution Rate'**
  String get executionRate;

  /// No description provided for @tourQuickLabel.
  ///
  /// In en, this message translates to:
  /// **'QUICK TOUR'**
  String get tourQuickLabel;

  /// No description provided for @tourStepCounter.
  ///
  /// In en, this message translates to:
  /// **'STEP {current} OF {total}'**
  String tourStepCounter(int current, int total);

  /// No description provided for @tourSkipTooltip.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get tourSkipTooltip;

  /// No description provided for @tourBack.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get tourBack;

  /// No description provided for @tourContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get tourContinue;

  /// No description provided for @tourGetStarted.
  ///
  /// In en, this message translates to:
  /// **'GET STARTED'**
  String get tourGetStarted;

  /// No description provided for @tourSkipEntire.
  ///
  /// In en, this message translates to:
  /// **'Skip entire tour'**
  String get tourSkipEntire;

  /// No description provided for @tourSemantics.
  ///
  /// In en, this message translates to:
  /// **'Quick tour, step {current} of {total}: {title}'**
  String tourSemantics(int current, int total, String title);

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to RealtorOne'**
  String get tourWelcomeTitle;

  /// No description provided for @tourWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'This short walkthrough highlights where to execute daily work—momentum, Tasks, learning, and your account.'**
  String get tourWelcomeBody;

  /// No description provided for @tourSubconsciousTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks — Belief workspace'**
  String get tourSubconsciousTitle;

  /// No description provided for @tourSubconsciousBody.
  ///
  /// In en, this message translates to:
  /// **'Open Tasks, then use Belief for identity conditioning: journaling, guided audio, affirmations, and inner-game work. Logging here keeps your streak and discipline signal accurate.'**
  String get tourSubconsciousBody;

  /// No description provided for @tourDealRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks — Deal Room (Clients)'**
  String get tourDealRoomTitle;

  /// No description provided for @tourDealRoomBody.
  ///
  /// In en, this message translates to:
  /// **'Under Focus, this Clients control switches between Deal Room (pipeline and client actions) and Revenue tracking. Deal Room is where you run lead follow-up and client momentum.'**
  String get tourDealRoomBody;

  /// No description provided for @tourLearnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning hub'**
  String get tourLearnTitle;

  /// No description provided for @tourLearnBody.
  ///
  /// In en, this message translates to:
  /// **'Courses and modules live here — use Learn when you’re ready to stack skills after your tasks.'**
  String get tourLearnBody;

  /// No description provided for @tourProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & settings'**
  String get tourProfileTitle;

  /// No description provided for @tourProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Subscription, account details, and preferences are under Profile.'**
  String get tourProfileBody;

  /// No description provided for @profileSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSectionSettings;

  /// No description provided for @profileSectionPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get profileSectionPerformance;

  /// No description provided for @profileSectionMyPlan.
  ///
  /// In en, this message translates to:
  /// **'My Plan'**
  String get profileSectionMyPlan;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get profileSectionAccount;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your personal info'**
  String get profileEditSubtitle;

  /// No description provided for @profileTopRealtorTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Realtor'**
  String get profileTopRealtorTitle;

  /// No description provided for @profileTopRealtorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your leaderboard rank and score breakdown'**
  String get profileTopRealtorSubtitle;

  /// No description provided for @profileConsultantPlan.
  ///
  /// In en, this message translates to:
  /// **'Consultant Plan'**
  String get profileConsultantPlan;

  /// No description provided for @profilePlanSuffix.
  ///
  /// In en, this message translates to:
  /// **' Plan'**
  String get profilePlanSuffix;

  /// No description provided for @profilePremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to manage your subscription'**
  String get profilePremiumSubtitle;

  /// No description provided for @profileUpgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to unlock premium features'**
  String get profileUpgradeSubtitle;

  /// No description provided for @profileAppSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get profileAppSettingsTitle;

  /// No description provided for @profileAppSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Security, notifications, and more'**
  String get profileAppSettingsSubtitle;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get profileLogout;

  /// No description provided for @profileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Realtor Name'**
  String get profileDefaultName;

  /// No description provided for @profileVerifiedElite.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED ELITE'**
  String get profileVerifiedElite;

  /// No description provided for @profilePercentReady.
  ///
  /// In en, this message translates to:
  /// **'{pct}% READY'**
  String profilePercentReady(int pct);

  /// No description provided for @profileStatPoints.
  ///
  /// In en, this message translates to:
  /// **'POINTS'**
  String get profileStatPoints;

  /// No description provided for @profileStatExecution.
  ///
  /// In en, this message translates to:
  /// **'EXECUTION'**
  String get profileStatExecution;

  /// No description provided for @profileStatPlan.
  ///
  /// In en, this message translates to:
  /// **'PLAN'**
  String get profileStatPlan;

  /// No description provided for @profileFooterBrand.
  ///
  /// In en, this message translates to:
  /// **'REALTOR ONE'**
  String get profileFooterBrand;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.2.4'**
  String get profileVersion;

  /// No description provided for @profilePercentComplete.
  ///
  /// In en, this message translates to:
  /// **'{pct}% COMPLETE'**
  String profilePercentComplete(int pct);

  /// No description provided for @profileUpdatePhoto.
  ///
  /// In en, this message translates to:
  /// **'UPDATE PHOTO'**
  String get profileUpdatePhoto;

  /// No description provided for @profileCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get profileCamera;

  /// No description provided for @profileGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get profileGallery;

  /// No description provided for @profileLogoutDialogSemantics.
  ///
  /// In en, this message translates to:
  /// **'Confirm log out'**
  String get profileLogoutDialogSemantics;

  /// No description provided for @profileLogoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogoutDialogTitle;

  /// No description provided for @profileLogoutDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get profileLogoutDialogMessage;

  /// No description provided for @profileLogoutDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileLogoutDialogCancel;

  /// No description provided for @profileLogoutDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogoutDialogConfirm;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'We’ll be right back'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'We’re performing a short maintenance window to upgrade RealtorOne. Your dashboard and clients are safe in the background.'**
  String get maintenanceBody;

  /// No description provided for @maintenanceRetry.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get maintenanceRetry;

  /// No description provided for @maintenanceVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Running app version {version}'**
  String maintenanceVersionLabel(String version);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'To keep your {platform} app secure and in sync with the latest features, please update to the latest version.'**
  String updateBody(String platform);

  /// No description provided for @updateVersionDetails.
  ///
  /// In en, this message translates to:
  /// **'Current: {current} • Required: {required}'**
  String updateVersionDetails(String current, String required);

  /// No description provided for @updateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'GO TO STORE'**
  String get updateButtonLabel;

  /// No description provided for @updateContinueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue without updating'**
  String get updateContinueLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
