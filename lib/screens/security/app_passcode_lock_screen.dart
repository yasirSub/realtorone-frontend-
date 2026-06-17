import 'package:flutter/material.dart';

import '../../api/app_passcode_api.dart';
import '../../routes/app_routes.dart';
import '../../services/app_passcode_service.dart';
import '../../services/app_preferences_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../utils/api_user_message.dart';
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
  bool _autoBiometricAttempted = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _bioBusy = false;
  String _biometricLabel = 'Biometrics';
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareBiometric();
  }

  Future<void> _prepareBiometric() async {
    try {
      await AppPreferencesService.ensureLoaded();
      final enabled = AppPreferencesService.biometricUnlockEnabled.value;
      final available = await BiometricAuthService.isAvailable();
      final label = await BiometricAuthService.unlockLabel();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = enabled;
        _biometricAvailable = available && enabled;
        _biometricLabel = label;
      });
      if (_biometricAvailable) {
        await _tryBiometricAuth(isAuto: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _tryBiometricAuth({bool isAuto = false}) async {
    if (_bioBusy || _loading || !_biometricAvailable) {
      return;
    }
    if (isAuto && _autoBiometricAttempted) return;
    if (isAuto) _autoBiometricAttempted = true;
    setState(() {
      _bioBusy = true;
      _hasError = false;
      _error = null;
    });
    try {
      final didAuthenticate = await BiometricAuthService.authenticate(
        reason: 'Use $_biometricLabel to unlock RealtorOne',
      );
      if (!mounted) return;
      if (didAuthenticate) {
        AppPasscodeService.instance.unlock();
        if (widget.popOnSuccess) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.main);
        }
        return;
      }
      setState(() {
        _error = '$_biometricLabel canceled. Enter your passcode.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '$_biometricLabel unavailable. Enter your passcode.';
      });
    } finally {
      if (mounted) {
        setState(() => _bioBusy = false);
      }
    }
  }

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
      final msg = ApiUserMessage.fromResponse(
        res,
        fallback: 'Incorrect passcode',
      );
      final statusCode = res['statusCode'];
      if (statusCode == 401 ||
          msg.toLowerCase().contains('session expired')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
        return;
      }
      setState(() {
        _hasError = true;
        _error = msg;
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
                if (_biometricAvailable && _biometricEnabled) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: (_loading || _bioBusy)
                        ? null
                        : () => _tryBiometricAuth(),
                    icon: Icon(
                      _biometricLabel == 'Face ID'
                          ? Icons.face_rounded
                          : Icons.fingerprint_rounded,
                    ),
                    label: Text(
                      _bioBusy
                          ? 'Checking $_biometricLabel...'
                          : 'Use $_biometricLabel',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: RealtorOneBrand.seed,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
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
