import 'package:flutter/material.dart';

import '../../api/app_passcode_api.dart';
import '../../routes/app_routes.dart';
import '../../services/app_passcode_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../widgets/passcode_pin_input.dart';

class AppPasscodeLockScreen extends StatefulWidget {
  const AppPasscodeLockScreen({super.key, this.popOnSuccess = false});

  final bool popOnSuccess;

  @override
  State<AppPasscodeLockScreen> createState() => _AppPasscodeLockScreenState();
}

class _AppPasscodeLockScreenState extends State<AppPasscodeLockScreen> {
  final _pinKey = GlobalKey<PasscodePinInputState>();
  bool _loading = false;
  bool _hasError = false;
  String? _error;

  Future<void> _verify(String code) async {
    if (_loading || code.length < 4) return;
    setState(() {
      _loading = true;
      _hasError = false;
      _error = null;
    });

    try {
      final res = await AppPasscodeApi.verifyPasscode(code);
      if (!mounted) return;
      if (res['success'] == true) {
        AppPasscodeService.instance.unlock();
        if (widget.popOnSuccess) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.main);
        }
        return;
      }
      setState(() {
        _hasError = true;
        _error = res['message']?.toString() ?? 'Incorrect passcode';
        _loading = false;
      });
      _pinKey.currentState?.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _error = 'Could not verify. Try again.';
        _loading = false;
      });
      _pinKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A),
                RealtorOneBrand.seed.withValues(alpha: 0.12),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const Spacer(flex: 2),
                PasscodeEntryCard(
                  onDarkBackground: true,
                  title: 'Enter passcode',
                  subtitle: 'Unlock RealtorOne to continue',
                  loading: _loading,
                  error: _error,
                  pinInput: PasscodePinInput(
                    key: _pinKey,
                    hasError: _hasError,
                    variant: PasscodePinVariant.onDark,
                    onCompleted: _verify,
                  ),
                ),
                const Spacer(flex: 3),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.appPasscodeForgot,
                  ),
                  child: const Text(
                    'Forgot passcode?',
                    style: TextStyle(
                      color: RealtorOneBrand.seed,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
