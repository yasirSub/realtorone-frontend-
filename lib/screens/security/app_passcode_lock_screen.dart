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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RealtorOneBrand.seed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: RealtorOneBrand.seed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter passcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock RealtorOne to continue',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 36),
              PasscodePinInput(
                key: _pinKey,
                hasError: _hasError,
                onCompleted: _verify,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RealtorOneBrand.seed,
                ),
              ],
              const Spacer(),
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
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
