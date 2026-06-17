import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../api/app_passcode_api.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import '../../services/app_passcode_service.dart';
import '../../theme/realtorone_brand.dart';
import '../../utils/api_user_message.dart';
import '../../utils/firebase_phone_auth_helper.dart';
import '../../utils/phone_otp_debug_log.dart';
import '../../utils/phone_otp_user_message.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/auth/auth_form_ui.dart';
import '../../widgets/otp_pin_input_row.dart';
import '../../widgets/passcode_pin_input.dart';

enum _ResetMethod { email, phone }

class AppPasscodeForgotScreen extends StatefulWidget {
  const AppPasscodeForgotScreen({super.key});

  @override
  State<AppPasscodeForgotScreen> createState() =>
      _AppPasscodeForgotScreenState();
}

class _AppPasscodeForgotScreenState extends State<AppPasscodeForgotScreen> {
  final _phoneController = TextEditingController();

  _ResetMethod? _method;
  String _dialCode = '+971';
  String? _accountEmail;
  String? _accountMobile;
  bool _loadingProfile = true;
  bool _loading = false;
  String? _error;
  String? _verificationId;
  bool _otpSent = false;
  String _otp = '';
  final _newPinKey = GlobalKey<PasscodePinInputState>();
  final _confirmPinKey = GlobalKey<PasscodePinInputState>();
  String _newPasscode = '';
  int _step = 0;
  String? _pendingIdToken;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final response = await UserApi.getProfile(useCache: false);
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final mobile = data['mobile']?.toString().trim() ?? '';
        setState(() {
          _accountEmail = data['email']?.toString().trim();
          _accountMobile = mobile.isNotEmpty ? mobile : null;
          if (mobile.isNotEmpty) {
            final parsed = PhoneUtils.parseStored(mobile);
            _dialCode = parsed.dialCode;
            _phoneController.text = parsed.localDigits;
          }
          _loadingProfile = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfile = false);
  }

  bool get _canUseEmail =>
      _accountEmail != null && _accountEmail!.isNotEmpty;

  bool get _canUsePhone =>
      _accountMobile != null && _accountMobile!.isNotEmpty;

  Future<void> _finishResetSuccess() async {
    ApiClient.invalidateEndpointCache(ApiEndpoints.userProfile);
    AppPasscodeService.instance
      ..hasPasscode = true
      ..unlock();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Passcode reset successfully')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.main,
      (_) => false,
    );
  }

  Future<void> _sendEmailOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final check = await AppPasscodeApi.forgotPasscodeEmail();
      if (!mounted) return;
      if (check['success'] != true) {
        setState(() {
          _error = ApiUserMessage.fromResponse(
            check,
            fallback: 'Could not send email verification code',
          );
          _loading = false;
        });
        return;
      }

      setState(() {
        _otpSent = true;
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

  Future<void> _sendPhoneOtp() async {
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
          _error = ApiUserMessage.fromResponse(
            check,
            fallback: 'Phone not found',
          );
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

  Future<void> _verifyPhoneOtpAndContinue() async {
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
      Map<String, dynamic> res;
      if (_method == _ResetMethod.email) {
        res = await AppPasscodeApi.resetPasscodeEmail(
          token: _otp,
          passcode: _newPasscode,
        );
      } else {
        final token = _pendingIdToken;
        if (token == null) {
          setState(() {
            _error = PhoneOtpUserMessage.somethingWentWrong;
            _loading = false;
          });
          return;
        }
        res = await AppPasscodeApi.resetPasscodePhone(
          idToken: token,
          passcode: _newPasscode,
        );
      }

      if (!mounted) return;
      if (res['success'] == true) {
        await _finishResetSuccess();
        return;
      }
      setState(() {
        _error = ApiUserMessage.fromResponse(
          res,
          fallback: 'Reset failed',
        );
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

  void _selectMethod(_ResetMethod method) {
    setState(() {
      _method = method;
      _error = null;
      _otpSent = false;
      _otp = '';
      _step = 0;
    });
    if (method == _ResetMethod.email) {
      _sendEmailOtp();
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return '${local[0]}***@${parts[1]}';
    return '${local.substring(0, 2)}***@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset passcode'),
        leading: (_method != null && _step == 0)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() {
                  if (_otpSent) {
                    _otpSent = false;
                    _otp = '';
                  } else {
                    _method = null;
                  }
                  _error = null;
                }),
              )
            : null,
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_method == null) ...[
                    Text(
                      'Choose how to verify your identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will send a one-time code, then you can set a new passcode.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _methodCard(
                      isDark: isDark,
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: _canUseEmail
                          ? 'Code to ${_maskEmail(_accountEmail!)}'
                          : 'No email on your account',
                      enabled: _canUseEmail,
                      onTap: () => _selectMethod(_ResetMethod.email),
                    ),
                    const SizedBox(height: 12),
                    _methodCard(
                      isDark: isDark,
                      icon: Icons.phone_android_rounded,
                      title: 'Phone',
                      subtitle: _canUsePhone
                          ? 'SMS to your registered number'
                          : 'Add a phone number in your profile first',
                      enabled: _canUsePhone,
                      onTap: () => _selectMethod(_ResetMethod.phone),
                    ),
                  ] else if (_step == 0 && !_otpSent && _method == _ResetMethod.phone) ...[
                    AuthFormUi.phoneField(
                      dialCode: _dialCode,
                      onDialCodeChanged: (v) => setState(() => _dialCode = v),
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _sendPhoneOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: RealtorOneBrand.seed,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_loading ? 'Sending…' : 'Send SMS code'),
                    ),
                  ] else if (_step == 0 && _otpSent) ...[
                    Text(
                      _method == _ResetMethod.email
                          ? 'Enter the 6-digit code sent to\n${_maskEmail(_accountEmail ?? '')}'
                          : 'Enter the code sent to your phone',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OtpPinInputRow(
                      visualState: OtpPinVisualState.idle,
                      onChanged: (v) => _otp = v,
                      onCompleted: () {
                        if (_method == _ResetMethod.email) {
                          setState(() {
                            _step = 1;
                            _error = null;
                          });
                        } else {
                          _verifyPhoneOtpAndContinue();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (_method == _ResetMethod.email) {
                                _sendEmailOtp();
                              } else {
                                _sendPhoneOtp();
                              }
                            },
                      child: const Text('Resend code'),
                    ),
                  ] else if (_step == 0 &&
                      _method == _ResetMethod.email &&
                      _loading) ...[
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(height: 12),
                    const Text(
                      'Sending verification code to your email…',
                      textAlign: TextAlign.center,
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
                  if (_step < 1 && _loading && _method == _ResetMethod.phone && !_otpSent) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _methodCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? RealtorOneBrand.seed.withValues(alpha: 0.35)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RealtorOneBrand.seed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? RealtorOneBrand.seed : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: enabled
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? RealtorOneBrand.seed : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
