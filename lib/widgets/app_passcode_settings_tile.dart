import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/realtorone_brand.dart';
import 'app_passcode_disable_sheet.dart';

/// App passcode enable/disable row for Settings.
class AppPasscodeSettingsTile extends StatelessWidget {
  const AppPasscodeSettingsTile({
    super.key,
    required this.hasPasscode,
    required this.onUpdated,
    this.showDivider = true,
  });

  final bool hasPasscode;
  final VoidCallback onUpdated;
  final bool showDivider;

  Future<void> _onSwitchChanged(BuildContext context, bool enable) async {
    if (enable) {
      final result = await Navigator.pushNamed(
        context,
        AppRoutes.appPasscodeSetup,
        arguments: const {'hasExistingPasscode': false},
      );
      if (result == true) onUpdated();
      return;
    }
    final disabled = await AppPasscodeDisableSheet.show(context);
    if (disabled == true) onUpdated();
  }

  Future<void> _openChangePasscode(BuildContext context) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.appPasscodeSetup,
      arguments: const {'hasExistingPasscode': true},
    );
    if (result == true) onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = hasPasscode;
    final statusColor =
        enabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RealtorOneBrand.seed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: RealtorOneBrand.seed,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Text(
                'App Passcode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
            enabled
                ? 'Locks app when you leave'
                : 'Require a code to open the app',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          trailing: Switch.adaptive(
            value: enabled,
            activeTrackColor: RealtorOneBrand.seed.withValues(alpha: 0.45),
            activeThumbColor: RealtorOneBrand.seed,
            onChanged: (v) => _onSwitchChanged(context, v),
          ),
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _openChangePasscode(context),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Change passcode'),
                  style: TextButton.styleFrom(
                    foregroundColor: RealtorOneBrand.seed,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _onSwitchChanged(context, false),
                  child: Text(
                    'Turn off',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (showDivider) const Divider(height: 1, indent: 60, thickness: 0.5),
      ],
    );
  }
}
