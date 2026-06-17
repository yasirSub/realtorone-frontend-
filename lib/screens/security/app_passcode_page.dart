import 'package:flutter/material.dart';

import '../../api/user_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../services/app_passcode_service.dart';
import '../../services/app_preferences_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_passcode_disable_sheet.dart';
import '../../widgets/change_password_dialog.dart';
import '../../widgets/otp_pin_input_row.dart';

/// Hub for app passcode, biometrics, forgot passcode, and account password.
class AppPasscodePage extends StatefulWidget {
  const AppPasscodePage({super.key});

  @override
  State<AppPasscodePage> createState() => _AppPasscodePageState();
}

class _AppPasscodePageState extends State<AppPasscodePage> {
  Map<String, dynamic>? _userData;
  bool _loadingProfile = true;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometrics';
  bool _savingBiometric = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppPreferencesService.ensureLoaded();
    final available = await BiometricAuthService.isAvailable();
    final label = await BiometricAuthService.unlockLabel();
    try {
      final response = await UserApi.getProfile(useCache: false);
      if (!mounted) return;
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        AppPasscodeService.instance.configureFromProfile(data);
        setState(() {
          _userData = data;
          _biometricAvailable = available;
          _biometricLabel = label;
          _loadingProfile = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricLabel = label;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _onRefresh() => _load();

  bool get _hasAppPasscode =>
      AppPasscodeService.instance.hasPasscode ||
      _userData?['has_app_passcode'] == true ||
      _userData?['app_passcode_set_at'] != null;

  bool get _emailVerified =>
      isVerifiedTimestamp(_userData?['email_verified_at']);

  Future<void> _onPasscodeSwitchChanged(bool enable) async {
    if (enable) {
      final result = await Navigator.pushNamed(
        context,
        AppRoutes.appPasscodeSetup,
        arguments: const {'hasExistingPasscode': false},
      );
      if (result == true) {
        AppPasscodeService.instance.hasPasscode = true;
        if (_userData != null) {
          _userData!['has_app_passcode'] = true;
          _userData!['app_passcode_set_at'] =
              DateTime.now().toIso8601String();
        }
        setState(() {});
        await _load();
      }
      return;
    }
    final disabled = await AppPasscodeDisableSheet.show(context);
    if (disabled == true) {
      await AppPreferencesService.setBiometricUnlockEnabled(false);
      await _load();
    }
  }

  Future<void> _onBiometricSwitchChanged(bool enable) async {
    if (_savingBiometric) return;
    setState(() => _savingBiometric = true);

    if (enable) {
      final ok = await BiometricAuthService.authenticate(
        reason: 'Confirm $_biometricLabel to enable quick unlock',
      );
      if (!mounted) return;
      if (ok) {
        await AppPreferencesService.setBiometricUnlockEnabled(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not enable $_biometricLabel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await AppPreferencesService.setBiometricUnlockEnabled(false);
    }

    if (mounted) setState(() => _savingBiometric = false);
  }

  Future<void> _openChangePasscode() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.appPasscodeSetup,
      arguments: const {'hasExistingPasscode': true},
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final biometricEnabled =
        AppPreferencesService.biometricUnlockEnabled.value;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Passcode & Security',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: RealtorOneBrand.seed,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ResponsiveHelper.contentPadding(
                      context,
                      top: 20,
                      bottom: 40,
                    ),
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 60,
                        ),
                        child: ResponsiveHelper.constrainWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      _sectionTitle('App lock', isDark),
                      _card(isDark, [
                        _passcodeSwitchTile(isDark),
                        if (_hasAppPasscode && _biometricAvailable) ...[
                          const Divider(height: 1, indent: 60, thickness: 0.5),
                          _biometricSwitchTile(isDark, biometricEnabled),
                        ],
                        if (_hasAppPasscode) ...[
                          const Divider(height: 1, indent: 60, thickness: 0.5),
                          _actionTile(
                            isDark: isDark,
                            icon: Icons.edit_outlined,
                            title: 'Change passcode',
                            subtitle: 'Update your 4-digit app code',
                            onTap: _openChangePasscode,
                          ),
                        ],
                        const Divider(height: 1, indent: 60, thickness: 0.5),
                        _actionTile(
                          isDark: isDark,
                          icon: Icons.help_outline_rounded,
                          title: 'Forgot passcode?',
                          subtitle: 'Reset via email or phone verification',
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.appPasscodeForgot,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _sectionTitle('Account', isDark),
                      _card(isDark, [
                        _actionTile(
                          isDark: isDark,
                          icon: Icons.lock_outline_rounded,
                          title: l10n.settingsChangePasswordTitle,
                          subtitle: l10n.settingsChangePasswordSubtitle,
                          onTap: () => ChangePasswordDialog.show(
                            context,
                            emailVerified: _emailVerified,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _hasAppPasscode
                              ? 'Your app passcode locks RealtorOne when you leave. '
                                  '${_biometricAvailable ? '$_biometricLabel can be used for quick unlock when enabled.' : ''}'
                              : 'Set a 4-digit passcode to lock the app when you switch away or close it.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _card(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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

  Widget _passcodeSwitchTile(bool isDark) {
    final enabled = _hasAppPasscode;
    final statusColor =
        enabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: RealtorOneBrand.seed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
          color: RealtorOneBrand.seed,
          size: 18,
        ),
      ),
      title: Row(
        children: [
          Text(
            'App passcode',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              enabled ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        enabled ? 'Locks app when you leave' : 'Require a code to open the app',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      ),
      trailing: Switch.adaptive(
        value: enabled,
        activeTrackColor: RealtorOneBrand.seed.withValues(alpha: 0.45),
        activeThumbColor: RealtorOneBrand.seed,
        onChanged: _onPasscodeSwitchChanged,
      ),
    );
  }

  Widget _biometricSwitchTile(bool isDark, bool enabled) {
    final icon = _biometricLabel == 'Face ID'
        ? Icons.face_rounded
        : Icons.fingerprint_rounded;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: RealtorOneBrand.seed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: RealtorOneBrand.seed, size: 18),
      ),
      title: Text(
        _biometricLabel,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        'Unlock with $_biometricLabel instead of passcode',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      ),
      trailing: _savingBiometric
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch.adaptive(
              value: enabled,
              activeTrackColor: RealtorOneBrand.seed.withValues(alpha: 0.45),
              activeThumbColor: RealtorOneBrand.seed,
              onChanged: _onBiometricSwitchChanged,
            ),
    );
  }

  Widget _actionTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF667eea), size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 10,
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
}
