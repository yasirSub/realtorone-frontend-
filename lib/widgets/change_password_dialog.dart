import 'package:flutter/material.dart';

import '../api/user_api.dart';
import '../routes/app_routes.dart';
import '../theme/realtorone_brand.dart';
import '../widgets/realtor_one_dialog_scaffold.dart';

/// Change account login password (distinct from app passcode).
class ChangePasswordDialog {
  ChangePasswordDialog._();

  static void show(
    BuildContext context, {
    required bool emailVerified,
  }) {
    if (!emailVerified) {
      RealtorOneDialogScaffold.show<void>(
        context: context,
        builder: (d) => RealtorOneDialogScaffold(
          title: 'Verification Required',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(d);
                Navigator.pushNamed(context, AppRoutes.forgotPassword);
              },
              style: FilledButton.styleFrom(
                backgroundColor: RealtorOneBrand.seed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Verify Now'),
            ),
          ],
          child: const Text(
            'You need to verify your email first to enable password management.',
          ),
        ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isDialogLoading = false;
    final pageContext = context;

    RealtorOneDialogScaffold.show<void>(
      context: context,
      semanticsLabel: 'Change password form',
      builder: (d) => StatefulBuilder(
        builder: (_, setDialogState) {
          final isDark = Theme.of(d).brightness == Brightness.dark;
          return RealtorOneDialogScaffold(
            title: 'Change password',
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(d),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isDialogLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton(
                  onPressed: () async {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        const SnackBar(
                          content: Text('New passwords do not match'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        const SnackBar(
                          content: Text('Password must be 6+ chars'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isDialogLoading = true);
                    try {
                      final response = await UserApi.changePassword(
                        currentPasswordController.text,
                        newPasswordController.text,
                      );
                      final ok = response['success'] == true ||
                          response['status'] == 'ok';
                      if (d.mounted && ok) {
                        Navigator.pop(d);
                      }
                      if (!pageContext.mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          SnackBar(
                            content: Text(response['message'] ?? 'Error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!pageContext.mounted) return;
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      if (d.mounted) {
                        setDialogState(() => isDialogLoading = false);
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: RealtorOneBrand.seed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Update'),
                ),
            ],
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      hintText: 'Enter your old password',
                      suffixIcon: TextButton(
                        onPressed: () {
                          Navigator.pop(d);
                          Navigator.pushNamed(
                            pageContext,
                            AppRoutes.forgotPassword,
                          );
                        },
                        child: const Text(
                          'Forgot?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
