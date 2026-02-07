import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import '../../providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  bool _pushNotifications = true;
  bool _emailUpdates = true;

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Change Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      hintText: 'Enter your old password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading
                    ? null
                    : () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (isDialogLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: () async {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('New passwords do not match'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password must be 6+ chars'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isDialogLoading = true);
                    try {
                      final response = await UserApi.changePassword(
                        currentPasswordController.text,
                        newPasswordController.text,
                      );
                      if (mounted) {
                        if (response['success'] == true ||
                            response['status'] == 'ok') {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(response['message'] ?? 'Error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      if (mounted)
                        setDialogState(() => isDialogLoading = false);
                    }
                  },
                  child: const Text(
                    'UPDATE',
                    style: TextStyle(
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure? This action is permanent and will delete all your realtor data, leads, and performance history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('KEEP ACCOUNT'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSection('Account & Security'),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your professional info',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
                _buildSettingsItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle: 'Keep your account secure',
                  onTap: _showChangePasswordDialog,
                ),
              ], isDark),
              const SizedBox(height: 24),
              _buildSection('App Preferences'),
              _buildSettingsCard([
                _buildSwitchItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'New Lead Alerts',
                  subtitle: 'Instant notification for new leads',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                  isDark: isDark,
                ),
                _buildSwitchItem(
                  icon: Icons.mail_outline_rounded,
                  title: 'Weekly Performance Reports',
                  subtitle: 'Get growth insights via email',
                  value: _emailUpdates,
                  onChanged: (v) => setState(() => _emailUpdates = v),
                  isDark: isDark,
                ),
                _buildSwitchItem(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  subtitle: 'Switch to a darker interface',
                  value: isDark,
                  onChanged: (v) => themeProvider.toggleTheme(v),
                  isDark: isDark,
                ),
              ], isDark),
              const SizedBox(height: 24),
              _buildSection('Support & Help'),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  subtitle: 'Tutorials and FAQs',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Contact Support',
                  subtitle: 'Chat with our elite team',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  icon: Icons.star_outline_rounded,
                  title: 'Rate App',
                  subtitle: 'Help us improve your experience',
                  onTap: () {},
                ),
              ], isDark),
              const SizedBox(height: 24),
              _buildSection('Legal'),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () {},
                ),
                _buildSettingsItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'App usage guidelines',
                  onTap: () {},
                ),
              ], isDark),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _showDeleteAccountDialog,
                child: const Text(
                  'DELETE ACCOUNT',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _logout,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    backgroundColor: Colors.red[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    _isLoading ? 'LOGGING OUT...' : 'LOGOUT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Version 1.2.4',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667eea), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: Color(0xFFCBD5E1),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667eea), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF667eea),
    );
  }
}
