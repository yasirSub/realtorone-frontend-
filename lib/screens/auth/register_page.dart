import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/auth_api.dart';
import '../../api/api_client.dart';
import '../../services/google_auth_service.dart';
import '../../services/meta_app_events_service.dart';
import '../../services/push_notification_service.dart';
import '../../routes/app_routes.dart';
import '../../services/app_version_gate_service.dart';
import '../../widgets/auth/auth_form_ui.dart';
import '../../utils/phone_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _usePhone = false;
  String _selectedDialCode = '+971';
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _composePhoneE164() =>
      PhoneUtils.composeE164(_selectedDialCode, _phoneController.text);

  Future<void> _navigateAfterAuth(Map<String, dynamic>? userData) async {
    if (!mounted) return;
    if (await AppVersionGate.blockEntryIfRequired()) return;
    if (!mounted) return;

    if (userData != null) {
      if (userData['is_profile_complete'] != true) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      } else if (userData['has_completed_diagnosis'] != true) {
        Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.main);
  }

  Future<void> _enterProfileSetup({
    required String name,
    String? email,
    String? mobile,
  }) async {
    if (!mounted) return;
    if (await AppVersionGate.blockEntryIfRequired()) return;
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.profileSetup,
      arguments: {
        'name': name,
        'email': email,
        'mobile': mobile,
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _usePhone ? null : _emailController.text.trim().toLowerCase();
      final mobile = _usePhone ? _composePhoneE164() : null;

      final response = await AuthApi.register(
        name: _nameController.text.trim(),
        password: _passwordController.text,
        email: email,
        mobile: mobile,
      );

      if (!mounted) return;

      final otpSendFailed = response['otp_send_failed'] == true;

      if (response['status'] == 'ok' || otpSendFailed) {
        await MetaAppEventsService.instance.trackRegistration(
          method: _usePhone ? 'phone' : 'email',
        );
        if (otpSendFailed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ??
                    'Account created, but verification email could not be sent. You can resend from Profile after login.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Ensure we have a token (handle cases where register doesn't return one)
        final token = await ApiClient.getToken();
        if (token == null) {
          final loginResponse = await AuthApi.login(
            _usePhone ? mobile! : email!,
            _passwordController.text,
          );
          if (loginResponse['status'] != 'ok' ||
              loginResponse['token'] == null) {
            setState(
              () => _errorMessage = otpSendFailed
                  ? (response['message'] ??
                      'Account created, but login failed. Try signing in manually.')
                  : 'Registration successful, but failed to log in automatically.',
            );
            return;
          }
        }

        if (mounted && !_usePhone && email != null) {
          final needsVerify = response['email_verification_required'] == true;
          if (needsVerify) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Verify your email anytime from Profile after you finish setup.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }

        if (mounted) {
          await _enterProfileSetup(
            name: _nameController.text.trim(),
            email: _usePhone ? null : email,
            mobile: _usePhone ? mobile : null,
          );
        }
      } else {
        final field = response['field']?.toString();
        setState(() {
          _errorMessage = response['message'] ?? 'Registration failed.';
          if (field == 'email') {
            _usePhone = false;
          } else if (field == 'mobile') {
            _usePhone = true;
          }
        });
      }
    } catch (e) {
      setState(
        () =>
            _errorMessage = 'An error occurred. Please check your connection.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final google = await GoogleAuthService.instance.signIn();
      final response = await AuthApi.loginWithGoogle(
        idToken: google.idToken,
        email: google.account.email,
        name: google.account.displayName,
        photoUrl: google.account.photoUrl,
      );
      debugPrint('[GOOGLE SIGNUP] Backend response: $response');

      if (!mounted) return;
      if (response['status'] == 'ok' && response['token'] != null) {
        await ApiClient.setToken(response['token']);
        await PushNotificationService.syncTokenWithBackend();
        await MetaAppEventsService.instance.trackRegistration(method: 'google');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name'] ?? '');
        await prefs.setString('user_email', response['user']['email'] ?? '');
        await prefs.setBool('hasSeenOnboarding', true);
        await ApiClient.clearCache();

        final profile = await ApiClient.get('/user/profile', requiresAuth: true);
        if (!mounted) return;
        if (profile['success'] == true) {
          await _navigateAfterAuth(
            Map<String, dynamic>.from(profile['data'] as Map),
          );
        } else {
          await _navigateAfterAuth(null);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Google signup failed.';
        });
        debugPrint('[GOOGLE SIGNUP] Failed at backend: $_errorMessage');
      }
    } on GoogleSignInCancelledException {
      if (mounted) setState(() => _isLoading = false);
      return;
    } on PlatformException catch (e) {
      debugPrint(
        '[GOOGLE SIGNUP] PlatformException code=${e.code} message=${e.message}',
      );
      if (mounted) {
        setState(() {
          _errorMessage = GoogleAuthService.instance.platformErrorMessage(e);
        });
      }
    } catch (e) {
      debugPrint('[GOOGLE SIGNUP] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Google signup failed. $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final response = await AuthApi.loginWithApple(
        identityToken: credential.identityToken!,
        email: credential.email,
        firstName: credential.givenName,
        lastName: credential.familyName,
        userIdentifier: credential.userIdentifier,
      );

      if (!mounted) return;
      if (response['status'] == 'ok' && response['token'] != null) {
        await ApiClient.setToken(response['token']);
        await PushNotificationService.syncTokenWithBackend();
        await MetaAppEventsService.instance.trackRegistration(method: 'apple');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name'] ?? '');
        await prefs.setString('user_email', response['user']['email'] ?? '');
        await prefs.setBool('hasSeenOnboarding', true);
        await ApiClient.clearCache();

        final profile = await ApiClient.get('/user/profile', requiresAuth: true);
        if (!mounted) return;
        if (profile['success'] == true) {
          await _navigateAfterAuth(
            Map<String, dynamic>.from(profile['data'] as Map),
          );
        } else {
          await _navigateAfterAuth(null);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Apple signup failed.';
        });
      }
    } catch (e) {
      debugPrint('[APPLE SIGNUP] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Apple signup failed. Check your network or cancel.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
      child: AuthFormUi.scaffold(
        context: context,
        isLoading: _isLoading,
        child: _registerForm(),
      ),
    );
  }

  Widget _registerForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFormUi.header(
            title: 'Create account',
            subtitle: 'Join RealtorOne and grow your real estate business',
            leading: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AuthFormUi.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                size: 28,
                color: AuthFormUi.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) AuthFormUi.errorBanner(_errorMessage!),
          AuthFormUi.textField(
            controller: _nameController,
            label: 'Full name',
            hint: 'Your name',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          AuthFormUi.modeToggle(
            usePhone: _usePhone,
            onEmail: () => setState(() {
              _usePhone = false;
              _errorMessage = null;
            }),
            onPhone: () => setState(() {
              _usePhone = true;
              _errorMessage = null;
            }),
          ),
          const SizedBox(height: 14),
          if (_usePhone)
            AuthFormUi.phoneField(
              dialCode: _selectedDialCode,
              controller: _phoneController,
              onDialCodeChanged: (v) => setState(() => _selectedDialCode = v),
              validator: PhoneUtils.localDigitsValidator(_selectedDialCode),
            )
          else
            AuthFormUi.textField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Required';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          const SizedBox(height: 14),
          AuthFormUi.textField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Min 6 characters',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 16),
          AuthFormUi.primaryButton(
            label: 'Sign up',
            onPressed: _isLoading ? null : _handleRegister,
          ),
          const SizedBox(height: 20),
          AuthFormUi.orDivider(),
          const SizedBox(height: 16),
          AuthFormUi.socialRow(
            enabled: !_isLoading,
            onGoogle: _handleGoogleLogin,
            onApple: _handleAppleLogin,
          ),
          const SizedBox(height: 20),
          AuthFormUi.footerLink(
            prompt: 'Already have an account?',
            action: 'Sign in',
            onTap: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
