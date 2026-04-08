// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ريلتور وان';

  @override
  String get settingsScreenTitle => 'الإعدادات';

  @override
  String get settingsSectionAccountSecurity => 'الحساب والأمان';

  @override
  String get settingsSectionAppPreferences => 'تفضيلات التطبيق';

  @override
  String get settingsSectionLegal => 'قانوني';

  @override
  String get settingsEditProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get settingsEditProfileSubtitle => 'حدّث معلوماتك المهنية';

  @override
  String get settingsChangePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get settingsChangePasswordSubtitle => 'حافظ على أمان حسابك';

  @override
  String get settingsLanguageTitle => 'اللغة';

  @override
  String get settingsLanguageSubtitleEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageSubtitleArabic => 'العربية (الإمارات)';

  @override
  String get settingsNewLeadAlertsTitle => 'تنبيهات العملاء الجدد';

  @override
  String get settingsNewLeadAlertsSubtitle =>
      'إشعار فوري للعملاء المحتملين الجدد';

  @override
  String get settingsWeeklyReportsTitle => 'تقارير الأداء الأسبوعية';

  @override
  String get settingsWeeklyReportsSubtitle => 'احصل على رؤى النمو عبر البريد';

  @override
  String get settingsDarkModeTitle => 'الوضع الداكن';

  @override
  String get settingsDarkModeSubtitle => 'واجهة أغمق للعين';

  @override
  String get settingsPrivacyTitle => 'سياسة الخصوصية';

  @override
  String get settingsPrivacySubtitle =>
      'كيف نتعامل مع بياناتك — يُفتح داخل التطبيق';

  @override
  String get settingsTermsTitle => 'الشروط والأحكام';

  @override
  String get settingsTermsSubtitle => 'شروط الخدمة — تُفتح داخل التطبيق';

  @override
  String get settingsDeleteAccount => 'حذف الحساب';

  @override
  String get settingsLogout => 'تسجيل الخروج';

  @override
  String get settingsLoggingOut => 'جاري الخروج...';

  @override
  String get settingsVersion => 'الإصدار 1.2.4';

  @override
  String get languagePickerTitle => 'اختر اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabicUae => 'العربية (الإمارات)';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navTasks => 'المهام';

  @override
  String get navLearn => 'التعلّم';

  @override
  String get navProfile => 'الملف';

  @override
  String get homeWelcomeBack => 'مرحباً بعودتك،';

  @override
  String get homePerformanceReady => 'تقرير أدائك جاهز.';

  @override
  String get homeGuestName => 'وسيط عقاري';

  @override
  String get homeTodayFocus => 'تركيز اليوم';

  @override
  String homeTasksProgress(int done, int total, int pct) {
    return '$done / $total مهام مكتملة · $pct٪';
  }

  @override
  String get homeHotLeads => 'عملاء ساخنون';

  @override
  String get homeAtRisk4x => 'معرّض 4×';

  @override
  String get homeNurture => 'رعاية';

  @override
  String get homeRemaining => 'متبقي';

  @override
  String get homeOpenTasks => 'فتح المهام';

  @override
  String get homeOpenPipeline => 'فتح خط الأنابيب';

  @override
  String get homeNotificationsTooltip => 'الإشعارات';

  @override
  String get activityLogTitle => 'سجل النشاط';

  @override
  String get activityLogSubtitle => 'أحدث إجراءاتك وتقدمك اليوم';

  @override
  String get activityLogOpen => 'فتح';

  @override
  String get activityLogStreak => 'السلسلة';

  @override
  String get activityLogPoints => 'النقاط';

  @override
  String get activityLogEmpty => 'لا يوجد نشاط مسجّل اليوم بعد.';

  @override
  String get growthPotential => 'إمكانات النمو';

  @override
  String get executionRate => 'معدل التنفيذ';

  @override
  String get tourQuickLabel => 'جولة سريعة';

  @override
  String tourStepCounter(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get tourSkipTooltip => 'تخطي الجولة';

  @override
  String get tourBack => '← رجوع';

  @override
  String get tourContinue => 'متابعة';

  @override
  String get tourGetStarted => 'ابدأ الآن';

  @override
  String get tourSkipEntire => 'تخطي الجولة بالكامل';

  @override
  String tourSemantics(int current, int total, String title) {
    return 'جولة سريعة، الخطوة $current من $total: $title';
  }

  @override
  String get tourWelcomeTitle => 'مرحباً في ريلتور وان';

  @override
  String get tourWelcomeBody =>
      'تعرّف بسرعة على الشاشات الأساسية: الزخم، المهام، التعلم، وحسابك.';

  @override
  String get tourSubconsciousTitle => 'المهام — العمل اللاواعي';

  @override
  String get tourSubconsciousBody =>
      'افتح المهام، ثم لسان «اللاواعي» للمهام الذهنية: يوميات، صوت موجّه، تأكيدات، واللعبة الداخلية. التسجيل هنا يحافظ على سلسلة أيامك وانضباطك.';

  @override
  String get tourDealRoomTitle => 'المهام — غرفة الصفقات (عرض العملاء)';

  @override
  String get tourDealRoomBody =>
      'تحت «الواعي»، زر العملاء يبدّل بين غرفة الصفقات (خط الأنابيب والإجراءات) وتتبع الإيرادات. غرفة الصفقات هي مكان المتابعة والزخم مع العملاء.';

  @override
  String get tourLearnTitle => 'مركز التعلّم';

  @override
  String get tourLearnBody =>
      'الدورات والوحدات هنا — استخدم «التعلّم» عندما تنتهي من مهامك وتريد بناء المهارات.';

  @override
  String get tourProfileTitle => 'الملف والإعدادات';

  @override
  String get tourProfileBody =>
      'الاشتراك وتفاصيل الحساب والتفضيلات تحت «الملف».';

  @override
  String get profileSectionSettings => 'إعدادات الملف';

  @override
  String get profileSectionPerformance => 'الأداء';

  @override
  String get profileSectionMyPlan => 'خطتي';

  @override
  String get profileSectionAccount => 'إعدادات الحساب';

  @override
  String get profileEditTitle => 'تعديل الملف';

  @override
  String get profileEditSubtitle => 'إدارة معلوماتك الشخصية';

  @override
  String get profileTopRealtorTitle => 'أفضل وسيط';

  @override
  String get profileTopRealtorSubtitle =>
      'ترتيبك في لوحة المتصدرين وتفصيل النقاط';

  @override
  String get profileConsultantPlan => 'خطة استشاري';

  @override
  String get profilePlanSuffix => ' — خطة';

  @override
  String get profilePremiumSubtitle => 'اضغط لإدارة اشتراكك';

  @override
  String get profileUpgradeSubtitle => 'ترقّ للوصول إلى المزايا المميزة';

  @override
  String get profileAppSettingsTitle => 'إعدادات التطبيق';

  @override
  String get profileAppSettingsSubtitle => 'الأمان والإشعارات والمزيد';

  @override
  String get profileLogout => 'تسجيل الخروج';

  @override
  String get profileDefaultName => 'اسم الوسيط';

  @override
  String get profileVerifiedElite => 'موثّق النخبة';

  @override
  String profilePercentReady(int pct) {
    return '$pct٪ جاهز';
  }

  @override
  String get profileStatPoints => 'نقاط';

  @override
  String get profileStatExecution => 'تنفيذ';

  @override
  String get profileStatPlan => 'الخطة';

  @override
  String get profileFooterBrand => 'ريلتور وان';

  @override
  String get profileVersion => 'الإصدار 1.2.4';

  @override
  String profilePercentComplete(int pct) {
    return '$pct٪ مكتمل';
  }

  @override
  String get profileUpdatePhoto => 'تحديث الصورة';

  @override
  String get profileCamera => 'الكاميرا';

  @override
  String get profileGallery => 'معرض الصور';

  @override
  String get profileLogoutDialogSemantics => 'تأكيد تسجيل الخروج';

  @override
  String get profileLogoutDialogTitle => 'تسجيل الخروج';

  @override
  String get profileLogoutDialogMessage =>
      'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟';

  @override
  String get profileLogoutDialogCancel => 'إلغاء';

  @override
  String get profileLogoutDialogConfirm => 'تسجيل الخروج';

  @override
  String get maintenanceTitle => 'سنعود بعد قليل';

  @override
  String get maintenanceBody =>
      'نقوم حالياً بصيانة سريعة لترقية تطبيق ريلتور وان. لوحة التحكم والعملاء في أمان في الخلفية.';

  @override
  String get maintenanceRetry => 'إعادة المحاولة';

  @override
  String maintenanceVersionLabel(String version) {
    return 'إصدار التطبيق الحالي $version';
  }

  @override
  String get updateTitle => 'مطلوب تحديث';

  @override
  String updateBody(String platform) {
    return 'لضمان الأمان والحصول على أحدث المزايا في تطبيق $platform، يرجى التحديث إلى آخر إصدار.';
  }

  @override
  String updateVersionDetails(String current, String required) {
    return 'الحالي: $current • المطلوب: $required';
  }

  @override
  String get updateButtonLabel => 'الانتقال إلى المتجر';

  @override
  String get updateContinueLabel => 'المتابعة بدون تحديث';
}
