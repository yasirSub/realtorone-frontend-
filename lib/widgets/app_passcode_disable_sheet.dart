import 'package:flutter/material.dart';

import '../api/app_passcode_api.dart';
import '../services/app_passcode_service.dart';
import '../theme/realtorone_brand.dart';
import 'passcode_pin_input.dart';

/// Bottom sheet to turn off app passcode after entering the current PIN.
class AppPasscodeDisableSheet extends StatefulWidget {
  const AppPasscodeDisableSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const AppPasscodeDisableSheet(),
      ),
    );
  }

  @override
  State<AppPasscodeDisableSheet> createState() =>
      _AppPasscodeDisableSheetState();
}

class _AppPasscodeDisableSheetState extends State<AppPasscodeDisableSheet> {
  final _pinKey = GlobalKey<PasscodePinInputState>();
  bool _loading = false;
  String? _error;

  Future<void> _disable(String code) async {
    if (_loading || code.length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AppPasscodeApi.disablePasscode(passcode: code);
      if (!mounted) return;
      if (res['success'] == true) {
        AppPasscodeService.instance.clear();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Incorrect passcode';
        _loading = false;
      });
      _pinKey.currentState?.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not turn off passcode. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          PasscodeEntryCard(
            onDarkBackground: isDark,
            icon: Icons.lock_open_rounded,
            title: 'Turn off passcode?',
            subtitle: 'Enter your current code to disable app lock',
            loading: _loading,
            error: _error,
            pinInput: PasscodePinInput(
              key: _pinKey,
              hasError: _error != null,
              onCompleted: _disable,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
