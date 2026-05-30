import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/user_api.dart';

/// Modal to verify email with 6-digit OTP (register, login, profile setup).
class EmailOtpVerificationDialog {
  EmailOtpVerificationDialog._();

  static Future<bool> show(
    BuildContext context,
    String email, {
    bool allowSkip = true,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;

    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    var isSending = false;

    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final otp = controllers.map((c) => c.text).join();
                  return AlertDialog(
                    title: const Text('Verify your email'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Enter the 6-digit code sent to:\n$normalizedEmail\n\n'
                          'Or tap Verify Email in the message we sent — it opens the app and verifies automatically.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 42,
                              height: 52,
                              child: TextFormField(
                                controller: controllers[index],
                                focusNode: focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 1,
                                cursorColor: Colors.black,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  final clean =
                                      value.replaceAll(RegExp(r'\D'), '');
                                  if (clean.isNotEmpty) {
                                    controllers[index].text = clean[0];
                                    if (index < 5) {
                                      focusNodes[index + 1].requestFocus();
                                    } else {
                                      focusNodes[index].unfocus();
                                    }
                                  } else if (index > 0) {
                                    focusNodes[index - 1].requestFocus();
                                  }
                                  setDialogState(() {});
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  setDialogState(() => isSending = true);
                                  final res = await UserApi.sendEmailOtp(
                                    normalizedEmail,
                                  );
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() => isSending = false);
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        res['status'] == 'ok' ||
                                                res['success'] == true
                                            ? 'Verification code resent.'
                                            : (res['message'] ??
                                                'Could not resend code.'),
                                      ),
                                      backgroundColor:
                                          res['status'] == 'ok' ||
                                              res['success'] == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                },
                          child: Text(
                            isSending ? 'Sending…' : 'Resend code',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      if (allowSkip)
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, false),
                          child: const Text('SKIP FOR NOW'),
                        ),
                      FilledButton(
                        onPressed: otp.length < 6
                            ? null
                            : () async {
                                final result = await UserApi.verifyEmailOtp(
                                  normalizedEmail,
                                  otp,
                                );
                                if (result['status'] == 'ok' ||
                                    result['success'] == true) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } else if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['message'] ?? 'Invalid code',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: const Text('VERIFY'),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;
    } finally {
      for (final c in controllers) {
        c.dispose();
      }
      for (final n in focusNodes) {
        n.dispose();
      }
    }
  }
}
