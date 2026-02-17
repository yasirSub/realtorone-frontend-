import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _showCompletenessLabel = true;

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
    if (_userData!['city']?.toString().isNotEmpty == true) count++;
    if (_userData!['brokerage']?.toString().isNotEmpty == true) count++;
    if (_userData!['years_experience'] != null) count++;
    if (_userData!['current_monthly_income'] != null) count++;
    if (_userData!['target_monthly_income'] != null) count++;

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
      builder: (context) => SafeArea(
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
            const Text(
              'UPDATE PHOTO',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

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
                                                  '${(_calculateCompleteness() * 100).toInt()}% COMPLETE',
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
                                        'Realtor Name',
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
                              Text(
                                    _userData?['email'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms)
                                  .slideY(begin: 0.2),
                              const SizedBox(height: 20),
                              _buildStatusBadge(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatsRow(isDark),
                      const SizedBox(height: 32),
                      _buildMenuSection('Profile Settings', [
                        _MenuItem(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          subtitle: 'Manage your personal info',
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
                        _MenuItem(
                          icon: Icons.location_on_outlined,
                          title: 'City',
                          subtitle: _userData?['city'] ?? 'Dubai Marina',
                          onTap: () {},
                        ),
                      ], isDark),
                      const SizedBox(height: 24),
                      _buildMenuSection('Performance', [
                        _MenuItem(
                          icon: Icons.monetization_on_outlined,
                          title: 'Target Income',
                          subtitle:
                              'AED ${_userData?['target_monthly_income'] ?? '---'}',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.psychology_outlined,
                          title: 'My Challenges',
                          subtitle:
                              _userData?['diagnosis_blocker'] ??
                              'Lead Generation',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.diagnosis),
                        ),
                      ], isDark),
                      const SizedBox(height: 24),

                      // My Plan Section
                      _buildMenuSection('My Plan', [
                        _MenuItem(
                          icon: Icons.workspace_premium_rounded,
                          title: _userData?['is_premium'] == true
                              ? '${(_userData?['membership_tier'] ?? 'Premium').toString().replaceAll(' - GOLD', '').replaceAll('- GOLD', '').replaceAll(' GOLD', '').replaceAll('GOLD', '').trim()} Plan'
                              : 'Consultant Plan',
                          subtitle: _userData?['is_premium'] == true
                              ? 'Tap to manage your subscription'
                              : 'Upgrade to unlock premium features',
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

                      _buildMenuSection('Account Settings', [
                        _MenuItem(
                          icon: Icons.notifications_none,
                          title: 'Notifications',
                          subtitle: 'Turn alerts on/off',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.settings_outlined,
                          title: 'App Settings',
                          subtitle: 'Security, Notifications, and more',
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
                          label: const Text(
                            'LOGOUT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildFooter(),
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

  Widget _buildStatusBadge() {
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
                ? 'VERIFIED ELITE'
                : '${(completeness * 100).toInt()}% READY',
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

  Widget _buildStatsRow(bool isDark) {
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
            'POINTS',
            Colors.amber,
            onTap: () => Navigator.pushNamed(context, AppRoutes.rewards),
          ),
          _buildStatItem(
            '${_userData?['execution_rate'] ?? '85'}%',
            'EXECUTION',
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
            'PLAN',
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

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            'REALTOR ONE',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Version 1.2.4',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text(
              'LOGOUT',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
