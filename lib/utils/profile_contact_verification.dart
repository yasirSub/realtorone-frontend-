import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/user_api.dart';
import '../theme/realtorone_brand.dart';
import '../utils/firebase_phone_auth_helper.dart';
import '../widgets/otp_pin_input_row.dart';
import '../widgets/realtor_one_dialog_scaffold.dart';

/// Outcome of the post-save contact verification dialog.
enum ProfileContactVerificationResult {
  verified,
  dismissedLater,
  notVerified,
}

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

  Future<ProfileContactVerificationResult> verifyEmail(
    String email, {
    bool sendOtpIfNeeded = true,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return ProfileContactVerificationResult.notVerified;

    if (sendOtpIfNeeded) {
      final send = await UserApi.sendEmailOtp(normalized);
      if (!context.mounted) return ProfileContactVerificationResult.notVerified;
      if (send['status'] != 'ok' &&
          send['success'] != true &&
          send['already_verified'] != true) {
        _snack(
          send['message']?.toString() ?? 'Could not send email verification code.',
          Colors.red,
        );
        return ProfileContactVerificationResult.notVerified;
      }
      if (send['already_verified'] == true) {
        return ProfileContactVerificationResult.verified;
      }
    }

    return _showOtpDialog(
      email: normalized,
      isEmail: true,
      phone: null,
    );
  }

  /// Sends phone OTP via Firebase SMS, then shows verify dialog.
  Future<ProfileContactVerificationResult> verifyPhone({
    required String accountEmail,
    required String phoneE164,
  }) async {
    if (!context.mounted) return ProfileContactVerificationResult.notVerified;
    final email = accountEmail.trim().toLowerCase();
    final phone = phoneE164.trim();
    if (email.isEmpty || phone.isEmpty) {
      return ProfileContactVerificationResult.notVerified;
    }

    final ready = await FirebasePhoneAuthHelper.ensureInitialized();
    if (!ready) {
      _snack(
        'Firebase is not initialized. Rebuild the app and try again.',
        Colors.red,
      );
      return ProfileContactVerificationResult.notVerified;
    }

    final result = await FirebasePhoneAuthHelper.sendOtp(
      auth: firebaseAuth,
      phoneE164: phone,
    );
    if (!context.mounted) return ProfileContactVerificationResult.notVerified;

    if (!result.ok) {
      _snack(result.errorMessage ?? 'Could not send SMS.', Colors.red);
      return ProfileContactVerificationResult.notVerified;
    }

    if (result.autoCredential != null) {
      final response = await _verifyFirebaseCredential(
        credential: result.autoCredential!,
        email: email,
        mobile: phone,
      );
      if (response['status'] == 'ok' || response['success'] == true) {
        return ProfileContactVerificationResult.verified;
      }
      return ProfileContactVerificationResult.notVerified;
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

  Future<ProfileContactVerificationResult> _showOtpDialog({
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
    var outcome = ProfileContactVerificationResult.notVerified;
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
                  outcome = ProfileContactVerificationResult.verified;
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
                    setDialogState(() {
                      isResending = false;
                      errorMessage =
                          (result.errorMessage ?? 'Could not resend code.')
                              .toString();
                    });
                  }
                } else {
                  setDialogState(() {
                    isResending = false;
                    errorMessage =
                        'Phone OTP uses Firebase only. Close and try again.';
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
                  onPressed: isVerifying
                      ? null
                      : () {
                          outcome = ProfileContactVerificationResult.dismissedLater;
                          Navigator.pop(dCtx);
                        },
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

    if (outcome == ProfileContactVerificationResult.verified) {
      _snack(
        isEmail ? 'Email verified successfully!' : 'Phone verified successfully!',
        Colors.green,
      );
    }
    return outcome;
  }
}
