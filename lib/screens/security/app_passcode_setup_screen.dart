import 'package:flutter/material.dart';

import '../../api/app_passcode_api.dart';
import '../../services/app_passcode_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../widgets/passcode_pin_input.dart';

class AppPasscodeSetupScreen extends StatefulWidget {
  const AppPasscodeSetupScreen({super.key, this.hasExistingPasscode = false});

  final bool hasExistingPasscode;

  @override
  State<AppPasscodeSetupScreen> createState() => _AppPasscodeSetupScreenState();
}

class _AppPasscodeSetupScreenState extends State<AppPasscodeSetupScreen> {
  final _currentKey = GlobalKey<PasscodePinInputState>();
  final _newKey = GlobalKey<PasscodePinInputState>();
  final _confirmKey = GlobalKey<PasscodePinInputState>();

  int _step = 0;
  String _current = '';
  String _newPasscode = '';
  bool _loading = false;
  String? _error;

  Future<void> _save(String confirm) async {
    if (_newPasscode != confirm) {
      setState(() => _error = 'Passcodes do not match');
      _confirmKey.currentState?.clear();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await AppPasscodeApi.setPasscode(
        passcode: _newPasscode,
        currentPasscode: widget.hasExistingPasscode ? _current : null,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppPasscodeService.instance
          ..hasPasscode = true
          ..unlock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App passcode saved')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Could not save passcode';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _disable() async {
    final current = _currentKey.currentState?.value ?? '';
    if (current.length < 4) {
      setState(() => _error = 'Enter your current passcode');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AppPasscodeApi.disablePasscode(passcode: current);
      if (!mounted) return;
      if (res['success'] == true) {
        AppPasscodeService.instance.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App passcode removed')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Could not remove passcode';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.hasExistingPasscode ? 'App Passcode' : 'Set App Passcode',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hasExistingPasscode && _step == 0) ...[
              Text(
                'Enter current passcode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              PasscodePinInput(
                key: _currentKey,
                onCompleted: (v) => setState(() {
                  _current = v;
                  _step = 1;
                  _error = null;
                }),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _loading ? null : _disable,
                child: const Text('Remove passcode'),
              ),
            ] else if (_step <= 1) ...[
              Text(
                _step == 0 && !widget.hasExistingPasscode
                    ? 'Choose a 4-digit passcode'
                    : 'Enter new passcode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              PasscodePinInput(
                key: _newKey,
                onCompleted: (v) => setState(() {
                  _newPasscode = v;
                  _step = 2;
                  _error = null;
                }),
              ),
            ] else ...[
              const Text(
                'Confirm passcode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              PasscodePinInput(
                key: _confirmKey,
                onCompleted: _save,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Your passcode locks the app when you leave. Reset with your phone number if you forget it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
