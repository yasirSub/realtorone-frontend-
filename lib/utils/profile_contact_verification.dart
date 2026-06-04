import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/user_api.dart';
import '../theme/realtorone_brand.dart';
import '../utils/firebase_phone_auth_helper.dart';
import '../widgets/otp_pin_input_row.dart';
import '../widgets/realtor_one_dialog_scaffold.dart';

/// Sends OTP and shows verify dialog after email/phone change (e.g. Edit Profile save).
class ProfileContactVerification {
  ProfileContactVerification({
    required this.context,
    required this.firebaseAuth,
  });

  final BuildContext context;
  final FirebaseAuth firebaseAuth;

  void _snack(String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  /// Returns true when verified (or dialog completed successfully).
  Future<bool> verifyEmail(String email, {bool sendOtpIfNeeded = true}) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (sendOtpIfNeeded) {
      final send = await UserApi.sendEmailOtp(normalized);
      if (!context.mounted) return false;
      if (send['status'] != 'ok' &&
          send['success'] != true &&
          send['already_verified'] != true) {
        _snack(
          send['message']?.toString() ?? 'Could not send email verification code.',
          Colors.red,
        );
        return false;
      }
      if (send['already_verified'] == true) return true;
    }

    return _showOtpDialog(
      email: normalized,
      isEmail: true,
      phone: null,
    );
  }

  /// Sends phone OTP (Firebase or server SMS) then shows verify dialog.
  Future<bool> verifyPhone({
    required String accountEmail,
    required String phoneE164,
  }) async {
    if (!context.mounted) return false;
    final email = accountEmail.trim().toLowerCase();
    final phone = phoneE164.trim();
    if (email.isEmpty || phone.isEmpty) return false;

    final ready = await FirebasePhoneAuthHelper.ensureInitialized();
    if (!ready) {
      _snack(
        'Firebase is not initialized. Rebuild the app and try again.',
        Colors.red,
      );
      return await _sendBrevoAndShowDialog(email: email, phone: phone);
    }

    final result = await FirebasePhoneAuthHelper.sendOtp(
      auth: firebaseAuth,
      phoneE164: phone,
    );
    if (!context.mounted) return false;

    if (!result.ok) {
      if (result.billingBlocked) {
        return await _sendBrevoAndShowDialog(email: email, phone: phone);
      }
      final msg = result.errorMessage ?? 'Could not send SMS.';
      _snack(msg, Colors.red);
      return await _sendBrevoAndShowDialog(email: email, phone: phone);
    }

    if (result.autoCredential != null) {
      final response = await _verifyFirebaseCredential(
        credential: result.autoCredential!,
        email: email,
        mobile: phone,
      );
      return response['status'] == 'ok' || response['success'] == true;
    }

    _snack('Verification code sent to your phone.', Colors.green);
    return _showOtpDialog(
      email: email,
      isEmail: false,
      phone: phone,
      firebaseVerificationId: result.verificationId,
      usesFirebasePhone: true,
    );
  }

  Future<bool> _sendBrevoAndShowDialog({
    required String email,
    required String phone,
  }) async {
    final smsResponse = await UserApi.sendPhoneOtp(email, phone);
    if (!context.mounted) return false;
    if (smsResponse['status'] == 'ok' || smsResponse['success'] == true) {
      _snack('Verification code sent via SMS.', Colors.green);
      return _showOtpDialog(
        email: email,
        isEmail: false,
        phone: phone,
        usesFirebasePhone: false,
      );
    }
    _snack(
      smsResponse['message']?.toString() ?? 'Could not send SMS verification code.',
      Colors.red,
    );
    return false;
  }

  Future<Map<String, dynamic>> _verifyFirebaseCredential({
    required PhoneAuthCredential credential,
    required String email,
    required String mobile,
  }) async {
    try {
      final authResult = await firebaseAuth.signInWithCredential(credential);
      final idToken = await authResult.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return {'status': 'error', 'message': 'Missing Firebase id token'};
      }
      final response = await UserApi.verifyPhoneOtpWithIdToken(
        email: email,
        mobile: mobile,
        idToken: idToken,
      );
      await firebaseAuth.signOut();
      return response;
    } on FirebaseAuthException catch (e) {
      await firebaseAuth.signOut();
      return {
        'status': 'error',
        'message': FirebasePhoneAuthHelper.userMessage(e),
      };
    } catch (e) {
      await firebaseAuth.signOut();
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> _showOtpDialog({
    required String email,
    required bool isEmail,
    String? phone,
    String? firebaseVerificationId,
    bool usesFirebasePhone = false,
  }) async {
    final otpInputKey = GlobalKey<OtpPinInputRowState>();
    var currentOtp = '';
    var visualState = OtpPinVisualState.idle;
    var errorMessage = '';
    var isVerifying = false;
    var isResending = false;
    var verified = false;
    var currentFirebaseVerificationId = firebaseVerificationId ?? '';
    var currentUsesFirebase = usesFirebasePhone;

    await RealtorOneDialogScaffold.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleVerify() async {
              final otp = currentOtp.replaceAll(RegExp(r'\D'), '');
              if (otp.length < 6 || isVerifying) return;

              setDialogState(() {
                isVerifying = true;
                errorMessage = '';
                visualState = OtpPinVisualState.idle;
              });

              try {
                Map<String, dynamic> response;
                if (isEmail) {
                  response = await UserApi.verifyEmailOtp(email, otp);
                } else if (currentUsesFirebase &&
                    currentFirebaseVerificationId.isNotEmpty) {
                  final credential = PhoneAuthProvider.credential(
                    verificationId: currentFirebaseVerificationId,
                    smsCode: otp,
                  );
                  response = await _verifyFirebaseCredential(
                    credential: credential,
                    email: email,
                    mobile: phone ?? '',
                  );
                } else {
                  response = await UserApi.verifyPhoneOtp(
                    email,
                    otp,
                    mobile: phone,
                  );
                }

                if (response['status'] == 'ok' || response['success'] == true) {
                  verified = true;
                  setDialogState(() {
                    visualState = OtpPinVisualState.success;
                    isVerifying = false;
                  });
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                  if (dCtx.mounted) Navigator.pop(dCtx);
                } else {
                  setDialogState(() {
                    isVerifying = false;
                    visualState = OtpPinVisualState.error;
                    errorMessage =
                        (response['message'] ?? 'Invalid code. Try again.')
                            .toString();
                  });
                  otpInputKey.currentState?.clear();
                }
              } catch (_) {
                setDialogState(() {
                  isVerifying = false;
                  visualState = OtpPinVisualState.error;
                  errorMessage = 'Connection error. Please try again.';
                });
                otpInputKey.currentState?.clear();
              }
            }

            Future<void> handleResend() async {
              if (isResending) return;
              setDialogState(() {
                isResending = true;
                errorMessage = '';
                visualState = OtpPinVisualState.idle;
              });
              otpInputKey.currentState?.clear();
              currentOtp = '';

              try {
                if (isEmail) {
                  final response = await UserApi.sendEmailOtp(email);
                  if (!dCtx.mounted) return;
                  setDialogState(() {
                    isResending = false;
                    errorMessage = response['status'] == 'ok' ||
                            response['success'] == true
                        ? ''
                        : (response['message'] ?? 'Could not resend code.')
                            .toString();
                  });
                  return;
                }

                if (phone == null || phone.isEmpty) {
                  setDialogState(() {
                    isResending = false;
                    errorMessage = 'Phone number missing.';
                  });
                  return;
                }

                if (currentUsesFirebase) {
                  final result = await FirebasePhoneAuthHelper.sendOtp(
                    auth: firebaseAuth,
                    phoneE164: phone,
                  );
                  if (!dCtx.mounted) return;
                  if (result.ok && result.verificationId != null) {
                    currentFirebaseVerificationId = result.verificationId!;
                    setDialogState(() {
                      isResending = false;
                      errorMessage = '';
                    });
                  } else {
                    final smsResponse = await UserApi.sendPhoneOtp(email, phone);
                    if (!dCtx.mounted) return;
                    if (smsResponse['status'] == 'ok') {
                      currentUsesFirebase = false;
                      setDialogState(() {
                        isResending = false;
                        errorMessage = '';
                      });
                    } else {
                      setDialogState(() {
                        isResending = false;
                        errorMessage =
                            (result.errorMessage ??
                                    smsResponse['message'] ??
                                    'Could not resend code.')
                                .toString();
                      });
                    }
                  }
                } else {
                  final smsResponse = await UserApi.sendPhoneOtp(email, phone);
                  if (!dCtx.mounted) return;
                  setDialogState(() {
                    isResending = false;
                    errorMessage = smsResponse['status'] == 'ok' ||
                            smsResponse['success'] == true
                        ? ''
                        : (smsResponse['message'] ?? 'Could not resend code.')
                            .toString();
                  });
                }
              } catch (_) {
                if (!dCtx.mounted) return;
                setDialogState(() {
                  isResending = false;
                  errorMessage = 'Could not resend code. Try again.';
                });
              }
            }

            final canVerify =
                currentOtp.length == 6 &&
                !isVerifying &&
                visualState != OtpPinVisualState.success;

            return RealtorOneDialogScaffold(
              title: isEmail ? 'Verify new email' : 'Verify new phone',
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(dCtx),
                  child: const Text(
                    'LATER',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: canVerify ? handleVerify : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.seed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('VERIFY'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEmail
                        ? 'Enter the 6-digit code sent to:\n$email'
                        : 'Enter the 6-digit code sent to:\n$phone',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OtpPinInputRow(
                    key: otpInputKey,
                    visualState: visualState,
                    onChanged: (otp) => setDialogState(() => currentOtp = otp),
                    onCompleted: handleVerify,
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            (isResending || isVerifying) ? null : handleResend,
                        child: Text(
                          isResending ? 'Sending…' : 'Resend code',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (verified) {
      _snack(
        isEmail ? 'Email verified successfully!' : 'Phone verified successfully!',
        Colors.green,
      );
    }
    return verified;
  }
}
