import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../api/app_passcode_api.dart';
import '../../routes/app_routes.dart';
import '../../services/app_passcode_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../utils/firebase_phone_auth_helper.dart';
import '../../utils/phone_otp_debug_log.dart';
import '../../utils/phone_otp_user_message.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/auth/auth_form_ui.dart';
import '../../widgets/otp_pin_input_row.dart';
import '../../widgets/passcode_pin_input.dart';

class AppPasscodeForgotScreen extends StatefulWidget {
  const AppPasscodeForgotScreen({super.key});

  @override
  State<AppPasscodeForgotScreen> createState() =>
      _AppPasscodeForgotScreenState();
}

class _AppPasscodeForgotScreenState extends State<AppPasscodeForgotScreen> {
  final _phoneController = TextEditingController();
  String _dialCode = '+971';
  bool _loading = false;
  String? _error;
  String? _verificationId;
  bool _otpSent = false;
  String _otp = '';
  final _newPinKey = GlobalKey<PasscodePinInputState>();
  final _confirmPinKey = GlobalKey<PasscodePinInputState>();
  String _newPasscode = '';
  int _step = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final mobile = PhoneUtils.composeE164(_dialCode, _phoneController.text);
    if (!PhoneUtils.isValidE164(mobile)) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      PhoneOtpDebugLog.start('app passcode forgot — phone OTP');
      final check = await AppPasscodeApi.forgotPasscodePhone(mobile);
      if (check['success'] != true) {
        setState(() {
          _error = check['message']?.toString() ?? 'Phone not found';
          _loading = false;
        });
        return;
      }

      await FirebasePhoneAuthHelper.ensureInitialized();
      final result = await FirebasePhoneAuthHelper.sendOtp(
        auth: FirebaseAuth.instance,
        phoneE164: mobile,
      );
      if (!mounted) return;
      if (!result.ok) {
        PhoneOtpDebugLog.dumpReport();
        setState(() {
          _error = PhoneOtpUserMessage.forSendFailure(
            technical: result.errorMessage,
          );
          _loading = false;
        });
        return;
      }

      if (result.autoCredential != null) {
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          result.autoCredential!,
        );
        _pendingIdToken = await userCredential.user?.getIdToken();
        await FirebaseAuth.instance.signOut();
        setState(() {
          _step = 1;
          _loading = false;
        });
        return;
      }

      setState(() {
        _verificationId = result.verificationId;
        _otpSent = true;
        _loading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      PhoneOtpDebugLog.dumpReport();
      setState(() {
        _error = PhoneOtpUserMessage.forSendFailure(
          technical: FirebasePhoneAuthHelper.technicalMessage(e),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = PhoneOtpUserMessage.forSendFailure();
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_otp.length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_verificationId == null) {
        setState(() {
          _error = PhoneOtpUserMessage.somethingWentWrong;
          _loading = false;
        });
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otp,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      await FirebaseAuth.instance.signOut();
      if (idToken == null) throw Exception('No token');
      if (!mounted) return;
      setState(() {
        _step = 1;
        _loading = false;
      });
      _pendingIdToken = idToken;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = PhoneOtpUserMessage.forVerifyFailure();
        _loading = false;
      });
    }
  }

  String? _pendingIdToken;

  Future<void> _resetPasscode(String confirm) async {
    if (_newPasscode != confirm) {
      setState(() => _error = 'Passcodes do not match');
      _confirmPinKey.currentState?.clear();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = _pendingIdToken;
      if (token == null) {
        setState(() {
          _error = PhoneOtpUserMessage.somethingWentWrong;
          _loading = false;
        });
        return;
      }
      final res = await AppPasscodeApi.resetPasscodePhone(
        idToken: token,
        passcode: _newPasscode,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        AppPasscodeService.instance
          ..hasPasscode = true
          ..unlock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passcode reset successfully')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.main,
          (_) => false,
        );
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Reset failed';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = PhoneOtpUserMessage.connectionError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset passcode')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 0 && !_otpSent) ...[
              AuthFormUi.phoneField(
                dialCode: _dialCode,
                onDialCodeChanged: (v) => setState(() => _dialCode = v),
                controller: _phoneController,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _sendOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: RealtorOneBrand.seed,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_loading ? 'Sending…' : 'Send OTP'),
              ),
            ] else if (_step == 0 && _otpSent) ...[
              const Text(
                'Enter the code sent to your phone',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OtpPinInputRow(
                visualState: OtpPinVisualState.idle,
                onChanged: (v) => _otp = v,
                onCompleted: _verifyOtpAndContinue,
              ),
            ] else if (_step == 1) ...[
              PasscodeEntryCard(
                title: 'New passcode',
                subtitle: 'Choose a new 4-digit code',
                loading: _loading,
                error: _error,
                pinInput: PasscodePinInput(
                  key: _newPinKey,
                  hasError: _error != null,
                  onCompleted: (v) => setState(() {
                    _newPasscode = v;
                    _step = 2;
                    _error = null;
                  }),
                ),
              ),
            ] else if (_step == 2) ...[
              PasscodeEntryCard(
                title: 'Confirm passcode',
                subtitle: 'Enter the same code again',
                loading: _loading,
                error: _error,
                pinInput: PasscodePinInput(
                  key: _confirmPinKey,
                  hasError: _error != null,
                  onCompleted: _resetPasscode,
                ),
              ),
            ],
            if (_step < 1 && _error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
            if (_step < 1 && _loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}
