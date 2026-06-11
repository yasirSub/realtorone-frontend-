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

  int get _totalSteps => widget.hasExistingPasscode ? 3 : 2;

  int get _displayStep {
    if (widget.hasExistingPasscode) return _step + 1;
    return _step == 0 ? 1 : 2;
  }

  String get _title {
    if (widget.hasExistingPasscode && _step == 0) {
      return 'Current passcode';
    }
    if (_step <= 1 && (!widget.hasExistingPasscode || _step == 1)) {
      return widget.hasExistingPasscode ? 'New passcode' : 'Create passcode';
    }
    return 'Confirm passcode';
  }

  String get _subtitle {
    if (widget.hasExistingPasscode && _step == 0) {
      return 'Enter your existing 4-digit code';
    }
    if (_step <= 1 && (!widget.hasExistingPasscode || _step == 1)) {
      return 'Choose a 4-digit code to lock the app';
    }
    return 'Enter the same code again to confirm';
  }

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

  Widget _buildPinStep() {
    if (widget.hasExistingPasscode && _step == 0) {
      return PasscodePinInput(
        key: _currentKey,
        hasError: _error != null,
        onCompleted: (v) => setState(() {
          _current = v;
          _step = 1;
          _error = null;
        }),
      );
    }
    if (_step <= 1 && (!widget.hasExistingPasscode || _step == 1)) {
      return PasscodePinInput(
        key: _newKey,
        hasError: _error != null,
        onCompleted: (v) => setState(() {
          _newPasscode = v;
          _step = 2;
          _error = null;
        }),
      );
    }
    return PasscodePinInput(
      key: _confirmKey,
      hasError: _error != null,
      onCompleted: _save,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.hasExistingPasscode ? 'App Passcode' : 'Set App Passcode',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalSteps, (i) {
                  final active = i < _displayStep;
                  return Container(
                    width: active ? 28 : 10,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? RealtorOneBrand.seed
                          : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(flex: 2),
              PasscodeEntryCard(
                onDarkBackground: isDark,
                title: _title,
                subtitle: _subtitle,
                loading: _loading,
                error: _error,
                pinInput: _buildPinStep(),
              ),
              const Spacer(flex: 3),
              if (widget.hasExistingPasscode && _step == 0)
                OutlinedButton(
                  onPressed: _loading ? null : _disable,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Remove passcode',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Your passcode locks the app when you leave. Reset with your phone number if you forget it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
