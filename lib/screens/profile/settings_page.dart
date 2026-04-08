import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_client.dart';
import '../../api/user_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../legal/legal_document_webview_page.dart';
import '../../widgets/realtor_one_dialog_scaffold.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  bool _pushNotifications = true;
  bool _emailUpdates = true;

  void _openLegalInApp(String slug) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LegalDocumentWebViewPage(slug: slug),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isDialogLoading = false;
    final pageContext = context;

    RealtorOneDialogScaffold.show<void>(
      context: context,
      semanticsLabel: 'Change password form',
      builder: (d) => StatefulBuilder(
        builder: (_, setDialogState) {
          final isDark = Theme.of(d).brightness == Brightness.dark;
          return RealtorOneDialogScaffold(
            title: 'Change password',
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(d),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isDialogLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton(
                  onPressed: () async {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        const SnackBar(
                          content: Text('New passwords do not match'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(
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
                      final ok = response['success'] == true ||
                          response['status'] == 'ok';
                      if (d.mounted && ok) {
                        Navigator.pop(d);
                      }
                      if (!pageContext.mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          SnackBar(
                            content: Text(response['message'] ?? 'Error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!pageContext.mounted) return;
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      if (d.mounted) {
                        setDialogState(() => isDialogLoading = false);
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update'),
                ),
            ],
            child: SingleChildScrollView(
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
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog() {
    RealtorOneDialogScaffold.show<void>(
      context: context,
      barrierDismissible: false,
      semanticsLabel: 'Confirm account deletion request',
      builder: (d) {
        final isDark = Theme.of(d).brightness == Brightness.dark;
        return RealtorOneDialogScaffold(
          title: 'Delete account',
          titleColor: const Color(0xFFDC2626),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(
                'Keep account',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(d);
                setState(() => _isLoading = true);
                try {
                  final response = await UserApi.requestAccountDeletion();
                  if (mounted) {
                    if (response['success'] == true ||
                        response['status'] == 'ok') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Account deletion requested. Pending admin review.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      _logout();
                    } else {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response['message'] ?? 'Failed to submit request.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connection error. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Request deletion'),
            ),
          ],
          child: Text(
            'This requests permanent deletion of your realtor data, leads, and performance history. Continue?',
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

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLanguagePicker(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.languagePickerTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              RadioListTile<Locale>(
                contentPadding: EdgeInsets.zero,
                value: const Locale('en'),
                groupValue: localeProvider.locale,
                activeColor: const Color(0xFF667eea),
                title: Text(
                  l10n.languageEnglish,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onChanged: (v) async {
                  if (v == null) return;
                  await localeProvider.setLocale(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              RadioListTile<Locale>(
                contentPadding: EdgeInsets.zero,
                value: const Locale('ar'),
                groupValue: localeProvider.locale,
                activeColor: const Color(0xFF667eea),
                title: Text(
                  l10n.languageArabicUae,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onChanged: (v) async {
                  if (v == null) return;
                  await localeProvider.setLocale(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          l10n.settingsScreenTitle,
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
              _buildSection(l10n.settingsSectionAccountSecurity),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.person_outline_rounded,
                  title: l10n.settingsEditProfileTitle,
                  subtitle: l10n.settingsEditProfileSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
                _buildSettingsItem(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.settingsChangePasswordTitle,
                  subtitle: l10n.settingsChangePasswordSubtitle,
                  onTap: _showChangePasswordDialog,
                ),
              ], isDark),
              const SizedBox(height: 24),
              _buildSection(l10n.settingsSectionAppPreferences),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.language_rounded,
                  title: l10n.settingsLanguageTitle,
                  subtitle: localeProvider.isArabic
                      ? l10n.settingsLanguageSubtitleArabic
                      : l10n.settingsLanguageSubtitleEnglish,
                  onTap: () => _showLanguagePicker(isDark),
                ),
                _buildSwitchItem(
                  icon: Icons.notifications_active_outlined,
                  title: l10n.settingsNewLeadAlertsTitle,
                  subtitle: l10n.settingsNewLeadAlertsSubtitle,
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                  isDark: isDark,
                ),
                _buildSwitchItem(
                  icon: Icons.mail_outline_rounded,
                  title: l10n.settingsWeeklyReportsTitle,
                  subtitle: l10n.settingsWeeklyReportsSubtitle,
                  value: _emailUpdates,
                  onChanged: (v) => setState(() => _emailUpdates = v),
                  isDark: isDark,
                ),
                _buildSwitchItem(
                  icon: Icons.dark_mode_outlined,
                  title: l10n.settingsDarkModeTitle,
                  subtitle: l10n.settingsDarkModeSubtitle,
                  value: isDark,
                  onChanged: (v) => themeProvider.toggleTheme(v),
                  isDark: isDark,
                ),
              ], isDark),
              const SizedBox(height: 24),
              _buildSection(l10n.settingsSectionLegal),
              _buildSettingsCard([
                _buildSettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: l10n.settingsPrivacyTitle,
                  subtitle: l10n.settingsPrivacySubtitle,
                  onTap: () => _openLegalInApp('privacy'),
                ),
                _buildSettingsItem(
                  icon: Icons.gavel_outlined,
                  title: l10n.settingsTermsTitle,
                  subtitle: l10n.settingsTermsSubtitle,
                  onTap: () => _openLegalInApp('terms'),
                ),
              ], isDark),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _showDeleteAccountDialog,
                child: Text(
                  l10n.settingsDeleteAccount,
                  style: const TextStyle(
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
                    _isLoading
                        ? l10n.settingsLoggingOut
                        : l10n.settingsLogout,
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
                  l10n.settingsVersion,
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
        title,
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
