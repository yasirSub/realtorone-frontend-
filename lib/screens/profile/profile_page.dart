import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/realtor_one_dialog_scaffold.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/phone_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _showCompletenessLabel = true;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  String _verificationDialCode = '+971';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await UserApi.getProfile(useCache: false);
      debugPrint('PROFILE_DEBUG: Raw Response: $response');
      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            _userData = response['data'];
            debugPrint('PROFILE_DEBUG: User Email: ${_userData?['email']}');
            debugPrint(
              'PROFILE_DEBUG: Membership Tier: ${_userData?['membership_tier']} (Type: ${_userData?['membership_tier']?.runtimeType})',
            );
            debugPrint(
              'PROFILE_DEBUG: Is Premium: ${_userData?['is_premium']} (Type: ${_userData?['is_premium']?.runtimeType})',
            );
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
    if (_userData!['email_verified_at'] != null) count++;
    if (_userData!['mobile_verified_at'] != null) count++;

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
                                    _userData?['email_verified_at'] != null
                                        ? Icons.verified_user_rounded
                                        : Icons.warning_amber_rounded,
                                    color: _userData?['email_verified_at'] != null
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    size: 14,
                                  ),
                                ],
                              )
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.2),
                              if (_userData?['mobile']?.toString().isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                      _userData?['mobile_verified_at'] != null
                                          ? Icons.verified_user_rounded
                                          : Icons.warning_amber_rounded,
                                      color: _userData?['mobile_verified_at'] != null
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
                  padding: ResponsiveHelper.contentPadding(context, top: 24, bottom: 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ResponsiveHelper.constrainWidth(
                        child: Column(
                          children: [
                      _buildStatsRow(isDark, l10n),
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
                          icon: Icons.settings_outlined,
                          title: l10n.profileAppSettingsTitle,
                          subtitle: l10n.profileAppSettingsSubtitle,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.settings),
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

  Widget _buildStatsRow(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${_userData?['total_rewards'] ?? '0'}',
            l10n.profileStatPoints,
            Colors.amber,
            onTap: () => Navigator.pushNamed(context, AppRoutes.rewards),
          ),
          _buildStatItem(
            '${_userData?['execution_rate'] ?? '85'}%',
            l10n.profileStatExecution,
            const Color(0xFF4ECDC4),
          ),
          _buildStatItem(
            (_userData?['membership_tier'] ?? 'Consultant')
                .toString()
                .replaceAll(' - GOLD', '')
                .replaceAll('- GOLD', '')
                .replaceAll(' GOLD', '')
                .replaceAll('GOLD', '')
                .trim()
                .toUpperCase(),
            l10n.profileStatPlan,
            _getTierColor(_userData?['membership_tier']),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.subscriptionPlans),
          ),
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
        return const Color(0xFF94A3B8); // Silver/Gray color
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

  Widget _buildStatItem(
    String value,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
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
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
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
          Text(
            l10n.profileVersion,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
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
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SUBMIT'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select country code and enter your phone number to receive OTP.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 128,
                        child: DropdownButtonFormField<String>(
                          value: _verificationDialCode,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                            labelText: 'PHONE NUMBER',
                            labelStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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

    setState(() => _isLoading = true);
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _verifyPhoneWithFirebaseCredential(
            credential: credential,
            email: email,
            mobile: phone,
          );
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showSnackBar(
            e.message ?? 'Failed to send Firebase OTP. Please try again.',
            Colors.red,
          );
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showOtpVerifyDialog(
            email: email,
            isEmail: false,
            phone: phone,
            firebaseVerificationId: verificationId,
            usesFirebasePhone: true,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // User can still verify manually with OTP.
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(
        'Could not start phone verification. Please try again.',
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showOtpVerifyDialog({
    required String email,
    required bool isEmail,
    String? phone,
    String? firebaseVerificationId,
    bool usesFirebasePhone = false,
  }) {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    RealtorOneDialogScaffold.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final otp = controllers.map((c) => c.text).join();
            return RealtorOneDialogScaffold(
              title: isEmail ? 'Verify Email' : 'Verify Phone Number',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: otp.length < 6
                      ? null
                      : () async {
                          Navigator.pop(dCtx); // Close dialog first
                          setState(() => _isLoading = true);

                          try {
                            Map<String, dynamic> response;
                            if (isEmail) {
                              response = await UserApi.verifyEmailOtp(email, otp);
                            } else if (usesFirebasePhone &&
                                firebaseVerificationId != null &&
                                firebaseVerificationId.isNotEmpty) {
                              final credential = PhoneAuthProvider.credential(
                                verificationId: firebaseVerificationId,
                                smsCode: otp,
                              );
                              response = await _verifyPhoneWithFirebaseCredential(
                                credential: credential,
                                email: email,
                                mobile: phone ?? '',
                                showSuccessSnackBar: false,
                              );
                            } else {
                              response = await UserApi.verifyPhoneOtp(email, otp);
                            }

                            if (response['status'] == 'ok' ||
                                response['success'] == true) {
                              _showSnackBar(
                                isEmail
                                    ? 'Email verified successfully!'
                                    : 'Phone number verified successfully!',
                                Colors.green,
                              );
                              _loadUserData();
                            } else {
                              setState(() => _isLoading = false);
                              _showSnackBar(
                                response['message'] ?? 'Invalid code',
                                Colors.red,
                              );
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showSnackBar(
                              'Connection error. Please try again.',
                              Colors.red,
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                  ),
                  child: const Text('VERIFY'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 42,
                        height: 52,
                        child: TextFormField(
                          controller: controllers[index],
                          focusNode: focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 1,
                          cursorColor: Colors.black,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF667eea),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            final clean = value.replaceAll(RegExp(r'\D'), '');
                            if (clean.isNotEmpty) {
                              controllers[index].text = clean[0];
                              if (index < 5) {
                                focusNodes[index + 1].requestFocus();
                              } else {
                                focusNodes[index].unfocus();
                              }
                            } else if (index > 0) {
                              focusNodes[index - 1].requestFocus();
                            }
                            setDialogState(() {});
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in controllers) {
        c.dispose();
      }
      for (final n in focusNodes) {
        n.dispose();
      }
    });
  }

  Future<Map<String, dynamic>> _verifyPhoneWithFirebaseCredential({
    required PhoneAuthCredential credential,
    required String email,
    required String mobile,
    bool showSuccessSnackBar = true,
  }) async {
    try {
      final authResult = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await authResult.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Failed to verify phone with Firebase.', Colors.red);
        }
        return {'status': 'error', 'message': 'Missing Firebase id token'};
      }

      final response = await UserApi.verifyPhoneOtpWithIdToken(
        email: email,
        mobile: mobile,
        idToken: idToken,
      );

      if (response['status'] == 'ok' || response['success'] == true) {
        if (showSuccessSnackBar) {
          _showSnackBar('Phone number verified successfully!', Colors.green);
        }
        _loadUserData();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }

      await _firebaseAuth.signOut();
      return response;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Invalid OTP or Firebase verification failed.', Colors.red);
      }
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Widget _buildVerificationCard(bool isDark, AppLocalizations l10n) {
    final emailVerified = _userData?['email_verified_at'] != null;
    final phoneVerified = _userData?['mobile_verified_at'] != null;
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
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        isVerified
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            : ElevatedButton(
                onPressed: onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
