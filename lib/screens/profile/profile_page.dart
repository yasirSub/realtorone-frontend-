import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../api/chat_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/realtor_one_dialog_scaffold.dart';
import '../../widgets/otp_pin_input_row.dart';
import '../../utils/responsive_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../utils/phone_utils.dart';
import '../../utils/firebase_phone_auth_helper.dart';
import '../../utils/phone_otp_debug_log.dart';
import '../../utils/phone_otp_user_message.dart';
import '../../widgets/app_version_details_sheet.dart';
import '../../theme/realtorone_brand.dart';
import '../chatbot/reven_feedback_sheet.dart';
import '../../services/app_passcode_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _aiQuota;
  bool _isLoading = true;
  bool _showCompletenessLabel = true;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  String _verificationDialCode = '+971';
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppVersionLabel();
  }

  Future<void> _loadAppVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'v${info.version}';
      });
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    try {
      final results = await Future.wait([
        UserApi.getProfile(useCache: false),
        ChatApi.getAiQuota().catchError(
          (_) => <String, dynamic>{'success': false},
        ),
      ]);
      final response = results[0];
      final quotaRes = results[1];
      debugPrint('PROFILE_DEBUG: Raw Response: $response');
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
            AppPasscodeService.instance.configureFromProfile(
              _userData is Map<String, dynamic> ? _userData : null,
            );
            debugPrint('PROFILE_DEBUG: User Email: ${_userData?['email']}');
            debugPrint(
              'PROFILE_DEBUG: Membership Tier: ${_userData?['membership_tier']} (Type: ${_userData?['membership_tier']?.runtimeType})',
            );
            debugPrint(
              'PROFILE_DEBUG: Is Premium: ${_userData?['is_premium']} (Type: ${_userData?['is_premium']?.runtimeType})',
            );
          }
          if (quotaRes['success'] == true &&
              quotaRes['visible'] != false &&
              quotaRes['data'] is Map) {
            _aiQuota = Map<String, dynamic>.from(quotaRes['data'] as Map);
          } else {
            _aiQuota = null;
          }
          _isLoading = false;
        });
        // Auto-hide the detail pill after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showCompletenessLabel = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateCompleteness() {
    if (_userData == null) return 0;
    int count = 0;
    const total = 7;

    if (_userData!['name']?.toString().isNotEmpty == true) count++;
    if (_userData!['mobile']?.toString().isNotEmpty == true) count++;
    if (_userData!['brokerage']?.toString().isNotEmpty == true) count++;
    if (_userData!['years_experience'] != null) count++;
    if (_userData!['current_monthly_income'] != null) count++;
    if (isVerifiedTimestamp(_userData!['email_verified_at'])) count++;
    if (isVerifiedTimestamp(_userData!['mobile_verified_at'])) count++;

    return count / total;
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.profileUpdatePhoto,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(loc.profileCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(loc.profileGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (image != null) {
        setState(() => _isLoading = true);
        try {
          final response = await UserApi.uploadPhoto(File(image.path));
          if (response['success'] == true) {
            _loadUserData();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response['message'] ?? 'Upload failed'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isLoading = false);
            }
          }
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      // Small artificial delay for premium feel
      await Future.delayed(const Duration(milliseconds: 1500));

      // Try to notify backend about logout (but don't block if it fails)
      try {
        await ApiClient.post('/auth/logout', {}, requiresAuth: true);
      } catch (e) {
        debugPrint('Backend logout call failed: $e');
      }

      // Clear ALL local data
      await ApiClient.clearToken();
      await ApiClient.clearLocalSessionData();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      await ApiClient.clearToken();
      await ApiClient.clearLocalSessionData();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadUserData,
            color: const Color(0xFF667eea),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  stretch: true,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E293B), Color(0xFF334155)],
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Completeness Circle
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: CircularProgressIndicator(
                                      value: _calculateCompleteness(),
                                      strokeWidth: 4,
                                      backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation(
                                        _calculateCompleteness() >= 1.0
                                            ? const Color(0xFF10B981) // Green
                                            : const Color(0xFFEF4444), // Red
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white10,
                                      backgroundImage:
                                          _userData?['profile_photo'] != null
                                          ? NetworkImage(
                                              _userData!['profile_photo'],
                                            )
                                          : const AssetImage(
                                                  'assets/images/welcome.png',
                                                )
                                                as ImageProvider,
                                    ),
                                  ),
                                  // Detail Pill (Hides after 5s)
                                  if (_showCompletenessLabel &&
                                      _calculateCompleteness() < 1.0)
                                    Positioned(
                                      top: -20,
                                      child:
                                          Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEF4444,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  l10n.profilePercentComplete(
                                                    (_calculateCompleteness() *
                                                            100)
                                                        .toInt(),
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              )
                                              .animate()
                                              .fadeIn()
                                              .shake()
                                              .then(delay: 4.seconds)
                                              .fadeOut(),
                                    ),
                                  // Edit Icon
                                  Positioned(
                                    bottom: 5,
                                    right: 5,
                                    child: InkWell(
                                      onTap: _pickAndUploadPhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF667eea),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ).animate().scale(
                                duration: 600.ms,
                                curve: Curves.easeOutBack,
                              ),
                              const SizedBox(height: 20),
                              // Debug text removed for production
                              Text(
                                    _userData?['name']?.toString() ??
                                        l10n.profileDefaultName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 200.ms)
                                  .slideY(begin: 0.2),
                              const SizedBox(height: 4),
                              Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _userData?['email'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        isVerifiedTimestamp(
                                              _userData?['email_verified_at'],
                                            )
                                            ? Icons.verified_user_rounded
                                            : Icons.warning_amber_rounded,
                                        color:
                                            isVerifiedTimestamp(
                                              _userData?['email_verified_at'],
                                            )
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        size: 14,
                                      ),
                                    ],
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms)
                                  .slideY(begin: 0.2),
                              if (_userData?['mobile']?.toString().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 4),
                                Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _userData!['mobile'].toString(),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          isVerifiedTimestamp(
                                                _userData?['mobile_verified_at'],
                                              )
                                              ? Icons.verified_user_rounded
                                              : Icons.warning_amber_rounded,
                                          color:
                                              isVerifiedTimestamp(
                                                _userData?['mobile_verified_at'],
                                              )
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                          size: 14,
                                        ),
                                      ],
                                    )
                                    .animate()
                                    .fadeIn(delay: 350.ms)
                                    .slideY(begin: 0.2),
                              ],
                              const SizedBox(height: 20),
                              _buildStatusBadge(l10n),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: ResponsiveHelper.contentPadding(
                    context,
                    top: 24,
                    bottom: 140,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ResponsiveHelper.constrainWidth(
                        child: Column(
                          children: [
                            _buildProfileMetrics(isDark, l10n),
                            const SizedBox(height: 16),
                            _buildVerificationCard(isDark, l10n),
                            const SizedBox(height: 32),
                            _buildMenuSection(l10n.profileSectionSettings, [
                              _MenuItem(
                                icon: Icons.person_outline,
                                title: l10n.profileEditTitle,
                                subtitle: l10n.profileEditSubtitle,
                                onTap: () async {
                                  final result = await Navigator.pushNamed(
                                    context,
                                    AppRoutes.editProfile,
                                  );
                                  if (result == true) {
                                    _loadUserData();
                                  }
                                },
                              ),
                            ], isDark),
                            const SizedBox(height: 24),
                            _buildMenuSection(l10n.profileSectionPerformance, [
                              _MenuItem(
                                icon: Icons.emoji_events_outlined,
                                title: l10n.profileTopRealtorTitle,
                                subtitle: l10n.profileTopRealtorSubtitle,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.leaderboard,
                                ),
                              ),
                            ], isDark),
                            const SizedBox(height: 24),

                            if (_aiQuota != null) ...[
                              _buildAiUsageCard(isDark),
                              const SizedBox(height: 24),
                            ],

                            // My Plan Section
                            _buildMenuSection(l10n.profileSectionMyPlan, [
                              _MenuItem(
                                icon: Icons.workspace_premium_rounded,
                                title: _userData?['is_premium'] == true
                                    ? '${(_userData?['membership_tier'] ?? 'Premium').toString().replaceAll(' - GOLD', '').replaceAll('- GOLD', '').replaceAll(' GOLD', '').replaceAll('GOLD', '').trim()}${l10n.profilePlanSuffix}'
                                    : l10n.profileConsultantPlan,
                                subtitle: _userData?['is_premium'] == true
                                    ? l10n.profilePremiumSubtitle
                                    : l10n.profileUpgradeSubtitle,
                                onTap: () async {
                                  final result = await Navigator.pushNamed(
                                    context,
                                    AppRoutes.subscriptionPlans,
                                  );
                                  if (result == true) {
                                    _loadUserData();
                                  }
                                },
                              ),
                            ], isDark),
                            const SizedBox(height: 24),

                            _buildMenuSection(l10n.profileSectionAccount, [
                              _MenuItem(
                                icon: Icons.feedback_outlined,
                                title: 'Send Feedback',
                                subtitle: 'Share ideas or report issues',
                                onTap: () => RevenFeedbackSheet.show(context),
                              ),
                              _MenuItem(
                                icon: Icons.settings_outlined,
                                title: l10n.profileAppSettingsTitle,
                                subtitle: l10n.profileAppSettingsSubtitle,
                                onTap: () =>
                                    Navigator.pushNamed(context, AppRoutes.settings),
                              ),
                              if (_userData?['is_admin'] == true)
                                _MenuItem(
                                  icon: Icons.admin_panel_settings_outlined,
                                  title: 'Manage user subscriptions',
                                  subtitle:
                                      'Change tier manually (recorded as admin)',
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.adminManageSubscription,
                                  ),
                                ),
                            ], isDark),
                            const SizedBox(height: 48),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: TextButton.icon(
                                onPressed: () => _showLogoutDialog(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red[700],
                                  backgroundColor: Colors.red[50],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.logout_rounded),
                                label: Text(
                                  l10n.profileLogout,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildFooter(l10n),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Full Screen Loading Overlay
          if (_isLoading)
            EliteLoader.top(
              color: _getTierColor(_userData?['membership_tier']),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    final completeness = _calculateCompleteness();
    final isComplete = completeness >= 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isComplete ? const Color(0xFF10B981) : const Color(0xFFEF4444))
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete
                ? Icons.verified_user_rounded
                : Icons.warning_amber_rounded,
            color: isComplete
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isComplete
                ? l10n.profileVerifiedElite
                : l10n.profilePercentReady((completeness * 100).toInt()),
            style: TextStyle(
              color: isComplete
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiUsageCard(bool isDark) {
    final q = _aiQuota!;
    int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    final todayUsed = _int(q['tokens_today']);
    final monthUsed = _int(q['tokens_month']);
    final dailyLimit = _int(q['daily_limit']);
    final monthlyLimit = _int(q['monthly_limit']);
    final remainDay = q['remaining_daily'];
    final remainMonth = q['remaining_monthly'];
    String fmtLimit(int n) => n <= 0 ? 'Unlimited' : n.toString();
    double barFrac(int used, int limit) {
      if (limit <= 0) return used > 0 ? 0.12 : 0;
      return (used / limit).clamp(0.0, 1.0);
    }

    final sessions = q['recent_sessions'];
    final List<Map<String, dynamic>> recent = sessions is List
        ? sessions
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: RealtorOneBrand.accentIndigo,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Coach usage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${q['tier'] ?? _userData?['membership_tier'] ?? 'Consultant'} plan limits',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (q['exceeded'] != null && '$q[exceeded]'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Limit reached — resets ${q['exceeded'] == 'monthly' ? 'next month' : 'tomorrow'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _aiUsageMeter(
            label: 'Today',
            used: todayUsed,
            limitLabel: fmtLimit(dailyLimit),
            remaining: remainDay is int
                ? remainDay
                : int.tryParse('$remainDay'),
            fraction: barFrac(todayUsed, dailyLimit),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _aiUsageMeter(
            label: 'This month',
            used: monthUsed,
            limitLabel: fmtLimit(monthlyLimit),
            remaining: remainMonth is int
                ? remainMonth
                : int.tryParse('$remainMonth'),
            fraction: barFrac(monthUsed, monthlyLimit),
            isDark: isDark,
            accent: Colors.amber,
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Recent chats',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 8),
            ...recent.take(5).map((s) {
              final title = (s['title'] ?? 'Chat').toString();
              final tokens = _int(s['tokens']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$tokens TK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: RealtorOneBrand.accentIndigo,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _aiUsageMeter({
    required String label,
    required int used,
    required String limitLabel,
    required int? remaining,
    required double fraction,
    required bool isDark,
    Color accent = const Color(0xFF6366F1),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              '$used / $limitLabel TK${remaining != null ? ' · $remaining left' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction > 0 ? fraction : null,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            color: accent,
          ),
        ),
      ],
    );
  }

  String _displayTierName() {
    return (_userData?['membership_tier'] ?? 'Consultant')
        .toString()
        .replaceAll(' - GOLD', '')
        .replaceAll('- GOLD', '')
        .replaceAll(' GOLD', '')
        .replaceAll('GOLD', '')
        .trim();
  }

  double _executionRateValue() {
    final raw = _userData?['execution_rate']?.toString() ?? '0';
    return (double.tryParse(raw.replaceAll('%', '').trim()) ?? 0)
        .clamp(0, 100);
  }

  List<Color> _getTierGradient(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'titan':
      case 'titan - gold':
      case 'titan-gold':
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case 'rainmaker':
        return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
      default:
        return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
  }

  Future<void> _openSubscriptionPlans() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.subscriptionPlans,
    );
    if (result == true) {
      _loadUserData();
    }
  }

  Widget _buildProfileMetrics(bool isDark, AppLocalizations l10n) {
    final execution = _executionRateValue();
    final points = '${_userData?['total_rewards'] ?? '0'}';
    final isPremium = _userData?['is_premium'] == true;
    final tierName = _displayTierName();
    final tierColor = _getTierColor(_userData?['membership_tier']);
    final tierGradient = _getTierGradient(_userData?['membership_tier']);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openSubscriptionPlans,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tierGradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tierName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          isPremium
                              ? l10n.profilePremiumSubtitle
                              : l10n.profileUpgradeSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPremium ? 'Manage' : 'Upgrade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCompactMetricTile(
                isDark: isDark,
                label: l10n.profileStatExecution,
                value: '${execution.toInt()}%',
                accent: const Color(0xFF667eea),
                trailing: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    value: execution / 100,
                    strokeWidth: 3,
                    backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF667eea)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.rewards),
                child: _buildCompactMetricTile(
                  isDark: isDark,
                  label: l10n.profileStatPoints,
                  value: points,
                  accent: const Color(0xFFF59E0B),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: tierColor.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _buildCompactMetricTile({
    required bool isDark,
    required String label,
    required String value,
    required Color accent,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Color _getTierColor(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'titan':
      case 'titan - gold':
      case 'titan-gold':
        return const Color(0xFFF59E0B); // Gold color
      case 'rainmaker':
        return const Color(0xFF6366F1);
      case 'consultant':
        return const Color(0xFF64748B); // Default gray
      // Legacy support (will be migrated)
      case 'diamond':
        return const Color(0xFF7C3AED);
      case 'platinum':
        return const Color(0xFFD946EF);
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'silver':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items
                .asMap()
                .entries
                .map(
                  (e) => _buildMenuItem(
                    e.value,
                    e.key != items.length - 1,
                    isDark,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item, bool showDivider, bool isDark) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Icon(
            item.icon,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            size: 22,
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          subtitle: Text(
            item.subtitle ?? '',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Color(0xFFCBD5E1),
            size: 12,
          ),
          onTap: item.onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 60, thickness: 0.5),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Center(
      child: Column(
        children: [
          Text(
            l10n.profileFooterBrand,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          AppVersionTapLabel(
            label: _appVersionLabel.isNotEmpty
                ? _appVersionLabel
                : l10n.profileVersion.replaceAll('Version ', 'v'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    RealtorOneDialogScaffold.show<void>(
      context: context,
      semanticsLabel: l10n.profileLogoutDialogSemantics,
      builder: (d) {
        final isDark = Theme.of(d).brightness == Brightness.dark;
        final dlg = AppLocalizations.of(d)!;
        return RealtorOneDialogScaffold(
          title: dlg.profileLogoutDialogTitle,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(
                dlg.profileLogoutDialogCancel,
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(d);
                _logout();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text(dlg.profileLogoutDialogConfirm),
            ),
          ],
          child: Text(
            dlg.profileLogoutDialogMessage,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startEmailVerification() async {
    final email = _userData?['email'];
    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await UserApi.sendEmailOtp(email);
      setState(() => _isLoading = false);

      if (response['status'] == 'ok' ||
          response['success'] == true ||
          response['already_verified'] == true) {
        if (response['already_verified'] == true) {
          _showSnackBar('Email is already verified.', Colors.green);
          await _loadUserData();
          return;
        }
        _showSnackBar(
          'Verification email sent. Check your inbox and spam folder.',
          Colors.green,
        );
        _showOtpVerifyDialog(email: email, isEmail: true);
      } else {
        final message = response['mail_configured'] == false
            ? 'Email delivery is not configured on the server yet. Please try again later or contact support.'
            : (response['message'] ?? 'Failed to send verification code');
        _showSnackBar(message, Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Connection error. Please try again.', Colors.red);
    }
  }

  Future<void> _startPhoneVerification() async {
    final email = _userData?['email'];
    if (email == null || email.isEmpty) return;

    final existingPhone = (_userData?['mobile']?.toString() ?? '').trim();
    final initialPhone = PhoneUtils.parseStored(existingPhone).localDigits;
    final phoneController = TextEditingController(text: initialPhone);
    final parsed = PhoneUtils.parseStored(existingPhone);
    _verificationDialCode = parsed.dialCode;

    final newPhone = await RealtorOneDialogScaffold.show<String>(
      context: context,
      builder: (dCtx) {
        final isDark = Theme.of(dCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return RealtorOneDialogScaffold(
              title: 'Enter Phone Number',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final e164 = PhoneUtils.composeE164(
                      _verificationDialCode,
                      phoneController.text,
                    );
                    final phoneError = PhoneUtils.validateLocalDigits(
                      phoneController.text,
                      dialCode: _verificationDialCode,
                    );
                    if (phoneError != null) {
                      _showSnackBar(phoneError, Colors.red);
                      return;
                    }
                    Navigator.pop(dCtx, e164);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.seed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('SUBMIT'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select country code and enter your phone number. A verification code will be sent via Firebase SMS.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: DropdownButtonFormField<String>(
                          value: _verificationDialCode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          selectedItemBuilder: (context) =>
                              PhoneUtils.countryOptions
                                  .map(
                                    (item) => Text(
                                      item['code']!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          items: PhoneUtils.countryOptions
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['code'],
                                  child: Text(
                                    item['label']!,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => _verificationDialCode = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              PhoneUtils.maxInputLengthFor(
                                _verificationDialCode,
                              ),
                            ),
                          ],
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (newPhone == null || newPhone.isEmpty) return;
    setState(() {
      if (_userData != null) {
        _userData!['mobile'] = newPhone;
      }
    });

    final phone = newPhone;

    if (!PhoneUtils.isValidE164(phone)) {
      _showSnackBar(
        'Invalid number. For India choose +91 and enter 8271819813 (10 digits).',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);
    PhoneOtpDebugLog.start('profile phone verification');
    PhoneOtpDebugLog.log('user', 'email=$email phone=${PhoneOtpDebugLog.maskPhone(phone)}');
    _showSnackBar(PhoneOtpUserMessage.sending, const Color(0xFF667eea));
    try {
      await _sendFirebasePhoneOtp(email: email, phone: phone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(
        'Could not start phone verification. Please try again.',
        Colors.red,
      );
    }
  }

  Future<void> _sendFirebasePhoneOtp({
    required String email,
    required String phone,
  }) async {
    PhoneOtpDebugLog.log('step', 'ensureInitialized');
    final ready = await FirebasePhoneAuthHelper.ensureInitialized();
    if (!ready) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      const technical =
          'Firebase is not initialized. Rebuild the app and ensure google-services.json matches project realtor-one.';
      PhoneOtpDebugLog.error('ensureInitialized', technical);
      _showSnackBar(
        PhoneOtpUserMessage.forInitFailure(technical: technical),
        Colors.red,
      );
      return;
    }

    PhoneOtpDebugLog.log('step', 'sendOtp (Firebase only — no Brevo)');
    final result = await FirebasePhoneAuthHelper.sendOtp(
      auth: _firebaseAuth,
      phoneE164: phone,
    );

    if (!mounted) return;

    if (!result.ok) {
      final msg = result.errorMessage ?? '';
      PhoneOtpDebugLog.log(
        'Firebase result',
        'ok=false billing=${result.billingBlocked} '
            'notForwarded=${result.notificationNotForwarded}',
      );
      final upper = msg.toUpperCase();

      // Firebase device/number temporary block (too-many-requests / unusual activity).
      final firebaseBlocked =
          upper.contains('TOO MANY REQUESTS') ||
          upper.contains('TOO-MANY-REQUESTS') ||
          upper.contains('TOO_MANY_REQUESTS') ||
          upper.contains('UNUSUAL ACTIVITY') ||
          upper.contains('17010');

      if (firebaseBlocked) {
        setState(() => _isLoading = false);
        await RealtorOneDialogScaffold.show<void>(
          context: context,
          barrierDismissible: false,
          builder: (dCtx) {
            return RealtorOneDialogScaffold(
              title: 'Try again later',
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx),
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.seed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  PhoneOtpUserMessage.forSendFailure(technical: msg),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ),
            );
          },
        );
        return;
      }

      setState(() => _isLoading = false);
      final failMsg = msg.isNotEmpty ? msg : 'Firebase could not send SMS.';
      PhoneOtpDebugLog.error('Firebase failed', failMsg);
      _showSnackBar(
        PhoneOtpUserMessage.forSendFailure(technical: failMsg),
        Colors.red,
      );
      return;
    }

    if (result.autoCredential != null) {
      PhoneOtpDebugLog.log('success', 'auto-verified via silent push');
      await _verifyPhoneWithFirebaseCredential(
        credential: result.autoCredential!,
        email: email,
        mobile: phone,
      );
      return;
    }

    setState(() => _isLoading = false);
    PhoneOtpDebugLog.log('success', 'codeSent — SMS dispatched');
    _showSnackBar(PhoneOtpUserMessage.codeSent, Colors.green);
    _showOtpVerifyDialog(
      email: email,
      isEmail: false,
      phone: phone,
      firebaseVerificationId: result.verificationId,
      usesFirebasePhone: true,
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void _showOtpVerifyDialog({
    required String email,
    required bool isEmail,
    String? phone,
    String? firebaseVerificationId,
    bool usesFirebasePhone = false,
  }) {
    final otpInputKey = GlobalKey<OtpPinInputRowState>();
    var currentOtp = '';
    var visualState = OtpPinVisualState.idle;
    var errorMessage = '';
    var isVerifying = false;
    var isResending = false;
    var currentFirebaseVerificationId = firebaseVerificationId ?? '';
    var currentUsesFirebase = usesFirebasePhone;

    RealtorOneDialogScaffold.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleVerify() async {
              final otp = currentOtp.replaceAll(RegExp(r'\D'), '');
              if (otp.length < 6 || isVerifying) return;

              setDialogState(() {
                isVerifying = true;
                errorMessage = '';
                visualState = OtpPinVisualState.idle;
              });

              try {
                Map<String, dynamic> response;
                if (isEmail) {
                  response = await UserApi.verifyEmailOtp(email, otp);
                } else if (currentUsesFirebase &&
                    currentFirebaseVerificationId.isNotEmpty) {
                  final credential = PhoneAuthProvider.credential(
                    verificationId: currentFirebaseVerificationId,
                    smsCode: otp,
                  );
                  response = await _verifyPhoneWithFirebaseCredential(
                    credential: credential,
                    email: email,
                    mobile: phone ?? '',
                    showSnackBarFeedback: false,
                  );
                } else {
                  response = await UserApi.verifyPhoneOtp(
                    email,
                    otp,
                    mobile: phone,
                  );
                }

                if (response['status'] == 'ok' || response['success'] == true) {
                  setDialogState(() {
                    visualState = OtpPinVisualState.success;
                    isVerifying = false;
                  });
                  if (mounted) {
                    setState(() {
                      _userData ??= {};
                      if (isEmail) {
                        _userData!['email_verified_at'] =
                            response['email_verified_at'] ??
                            DateTime.now().toIso8601String();
                      } else {
                        _userData!['mobile_verified_at'] =
                            response['mobile_verified_at'] ??
                            DateTime.now().toIso8601String();
                        if (phone != null && phone.isNotEmpty) {
                          _userData!['mobile'] = phone;
                        }
                      }
                    });
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  _showSnackBar(
                    isEmail
                        ? 'Email verified successfully!'
                        : 'Phone number verified successfully!',
                    Colors.green,
                  );
                  await _loadUserData();
                } else {
                  setDialogState(() {
                    isVerifying = false;
                    visualState = OtpPinVisualState.error;
                    errorMessage = PhoneOtpUserMessage.forDialogError(
                      response['message']?.toString(),
                    );
                  });
                  otpInputKey.currentState?.clear();
                }
              } catch (e) {
                setDialogState(() {
                  isVerifying = false;
                  visualState = OtpPinVisualState.error;
                  errorMessage = PhoneOtpUserMessage.connectionError;
                });
                otpInputKey.currentState?.clear();
              }
            }

            Future<void> handleResend() async {
              if (isResending) return;
              setDialogState(() {
                isResending = true;
                errorMessage = '';
                visualState = OtpPinVisualState.idle;
              });
              otpInputKey.currentState?.clear();
              currentOtp = '';

              try {
                if (isEmail) {
                  final response = await UserApi.sendEmailOtp(email);
                  if (!dCtx.mounted) return;
                  if (response['status'] == 'ok' ||
                      response['success'] == true) {
                    setDialogState(() {
                      isResending = false;
                      errorMessage = '';
                    });
                    _showSnackBar('Verification code resent.', Colors.green);
                  } else {
                    setDialogState(() {
                      isResending = false;
                      errorMessage = PhoneOtpUserMessage.forDialogError(
                        response['message']?.toString(),
                      );
                    });
                  }
                  return;
                }

                if (phone == null || phone.isEmpty) {
                  setDialogState(() {
                    isResending = false;
                    errorMessage = 'Phone number missing. Close and try again.';
                  });
                  return;
                }

                if (currentUsesFirebase) {
                  final ready =
                      await FirebasePhoneAuthHelper.ensureInitialized();
                  if (!ready) {
                    setDialogState(() {
                      isResending = false;
                      errorMessage = PhoneOtpUserMessage.somethingWentWrong;
                    });
                    return;
                  }
                  final result = await FirebasePhoneAuthHelper.sendOtp(
                    auth: _firebaseAuth,
                    phoneE164: phone,
                  );
                  if (!dCtx.mounted) return;
                  if (result.ok && result.verificationId != null) {
                    currentFirebaseVerificationId = result.verificationId!;
                    setDialogState(() {
                      isResending = false;
                      errorMessage = '';
                    });
                    _showSnackBar('New code sent via SMS.', Colors.green);
                  } else {
                    setDialogState(() {
                      isResending = false;
                      errorMessage = PhoneOtpUserMessage.forResendFailure(
                        technical: result.errorMessage,
                      );
                    });
                  }
                } else {
                  setDialogState(() {
                    isResending = false;
                    errorMessage = PhoneOtpUserMessage.couldNotResend;
                  });
                }
              } catch (_) {
                if (!dCtx.mounted) return;
                setDialogState(() {
                  isResending = false;
                  errorMessage = PhoneOtpUserMessage.couldNotResend;
                });
              }
            }

            final canVerify =
                currentOtp.length == 6 &&
                !isVerifying &&
                visualState != OtpPinVisualState.success;

            return RealtorOneDialogScaffold(
              title: isEmail ? 'Verify Email' : 'Verify Phone Number',
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dCtx),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: canVerify ? handleVerify : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.seed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('VERIFY'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEmail
                        ? 'Enter the 6-digit verification code sent to your email:\n$email'
                        : 'Enter the 6-digit verification code sent to your phone:\n$phone',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OtpPinInputRow(
                    key: otpInputKey,
                    visualState: visualState,
                    onChanged: (otp) {
                      setDialogState(() => currentOtp = otp);
                    },
                    onCompleted: handleVerify,
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (visualState == OtpPinVisualState.success) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Verified!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: (isResending || isVerifying)
                            ? null
                            : handleResend,
                        child: Text(
                          isResending ? 'Sending…' : 'Resend code',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (visualState == OtpPinVisualState.error) ...[
                        const Text(
                          '·',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        TextButton(
                          onPressed: isVerifying
                              ? null
                              : () {
                                  otpInputKey.currentState?.clear();
                                  setDialogState(() {
                                    currentOtp = '';
                                    errorMessage = '';
                                    visualState = OtpPinVisualState.idle;
                                  });
                                },
                          child: const Text(
                            'Enter again',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _verifyPhoneWithFirebaseCredential({
    required PhoneAuthCredential credential,
    required String email,
    required String mobile,
    bool showSnackBarFeedback = true,
  }) async {
    try {
      final authResult = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await authResult.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        const technical = 'Missing Firebase id token';
        PhoneOtpDebugLog.error('verify credential', technical);
        if (mounted) {
          setState(() => _isLoading = false);
          if (showSnackBarFeedback) {
            _showSnackBar(
              PhoneOtpUserMessage.forVerifyFailure(technical: technical),
              Colors.red,
            );
          }
        }
        return {
          'status': 'error',
          'message': PhoneOtpUserMessage.forVerifyFailure(technical: technical),
        };
      }

      final response = await UserApi.verifyPhoneOtpWithIdToken(
        email: email,
        mobile: mobile,
        idToken: idToken,
      );

      if (response['status'] == 'ok' || response['success'] == true) {
        if (mounted) {
          setState(() {
            _userData ??= {};
            _userData!['mobile_verified_at'] =
                response['mobile_verified_at'] ??
                DateTime.now().toIso8601String();
            if (mobile.isNotEmpty) {
              _userData!['mobile'] = mobile;
            }
          });
        }
        if (showSnackBarFeedback) {
          _showSnackBar('Phone number verified successfully!', Colors.green);
        }
        _loadUserData();
      } else if (mounted) {
        setState(() => _isLoading = false);
        if (showSnackBarFeedback) {
          final technical = (response['message'] ?? response['error'] ?? '')
              .toString()
              .trim();
          _showSnackBar(
            PhoneOtpUserMessage.forVerifyFailure(technical: technical),
            Colors.red,
          );
        }
      }

      await _firebaseAuth.signOut();
      return response;
    } on FirebaseAuthException catch (e) {
      PhoneOtpDebugLog.error(
        'verify credential',
        FirebasePhoneAuthHelper.technicalMessage(e),
      );
      final friendly = PhoneOtpUserMessage.forVerifyFailure(exception: e);
      if (mounted) {
        setState(() => _isLoading = false);
        if (showSnackBarFeedback) {
          _showSnackBar(friendly, Colors.red);
        }
      }
      return {'status': 'error', 'message': friendly};
    } catch (e) {
      PhoneOtpDebugLog.error('verify credential', e);
      final friendly = PhoneOtpUserMessage.forVerifyFailure(technical: e.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        if (showSnackBarFeedback) {
          _showSnackBar(friendly, Colors.red);
        }
      }
      return {'status': 'error', 'message': friendly};
    }
  }

  Widget _buildVerificationCard(bool isDark, AppLocalizations l10n) {
    final emailVerified = isVerifiedTimestamp(_userData?['email_verified_at']);
    final phoneVerified = isVerifiedTimestamp(_userData?['mobile_verified_at']);
    final hasEmail = (_userData?['email']?.toString() ?? '').trim().isNotEmpty;
    final showEmailVerify = hasEmail && !emailVerified;
    final showPhoneVerify = !phoneVerified;

    // Hide the verification panel when everything is already verified.
    if (!showEmailVerify && !showPhoneVerify) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF667eea),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Account Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showEmailVerify)
            _buildVerificationRow(
              icon: Icons.email_rounded,
              title: 'Email Verification',
              subtitle: _userData?['email'] ?? 'Not set',
              isVerified: false,
              onVerify: () => _startEmailVerification(),
            ),
          if (showEmailVerify && showPhoneVerify)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFF334155), height: 1),
            ),
          if (showPhoneVerify)
            _buildVerificationRow(
              icon: Icons.phone_android_rounded,
              title: 'Phone Verification',
              subtitle: _userData?['mobile']?.toString().isNotEmpty == true
                  ? _userData!['mobile']
                  : 'Add phone number to verify',
              isVerified: false,
              onVerify: () => _startPhoneVerification(),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildVerificationRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
    required VoidCallback onVerify,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        isVerified
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            : FilledButton(
                onPressed: onVerify,
                style: FilledButton.styleFrom(
                  backgroundColor: RealtorOneBrand.seed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                ),
                child: const Text(
                  'VERIFY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
