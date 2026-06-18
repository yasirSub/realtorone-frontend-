import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/api_client.dart';
import '../../api/auth_api.dart';
import '../../services/google_auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/auth/auth_form_ui.dart';
import '../../utils/phone_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
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
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _loginIdentifier() => _usePhone
      ? PhoneUtils.composeE164(_selectedDialCode, _phoneController.text)
      : _emailController.text.trim().toLowerCase();

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthApi.login(
        _loginIdentifier(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (response['status'] == 'ok' && response['token'] != null) {
        await ApiClient.setToken(response['token']);
        await PushNotificationService.syncTokenWithBackend();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name']);
        await prefs.setString('user_email', response['user']['email'] ?? '');
        await prefs.setBool('hasSeenOnboarding', true);

        // Clear cache to ensure fresh data for the new session
        await ApiClient.clearCache();

        if (response['email_verification_required'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please verify your email from Profile when you are ready.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }

        final profile = await ApiClient.get(
          '/user/profile',
          requiresAuth: true,
        );

        if (mounted) {
          if (profile['success'] == true) {
            final userData = profile['data'];
            if (userData['is_profile_complete'] != true) {
              Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
            } else if (userData['has_completed_diagnosis'] != true) {
              Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.main);
            }
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.main);
          }
        }
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Check your network.';
      });
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
      debugPrint('[GOOGLE LOGIN] Backend response: $response');

      if (!mounted) return;
      if (response['status'] == 'ok' && response['token'] != null) {
        await ApiClient.setToken(response['token']);
        await PushNotificationService.syncTokenWithBackend();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name'] ?? '');
        await prefs.setString('user_email', response['user']['email'] ?? '');
        await prefs.setBool('hasSeenOnboarding', true);
        await ApiClient.clearCache();

        final profile = await ApiClient.get('/user/profile', requiresAuth: true);
        if (!mounted) return;
        if (profile['success'] == true) {
          final userData = profile['data'];
          if (userData['is_profile_complete'] != true) {
            Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
          } else if (userData['has_completed_diagnosis'] != true) {
            Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.main);
          }
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Google login failed.';
        });
        debugPrint('[GOOGLE LOGIN] Failed at backend: $_errorMessage');
      }
    } on GoogleSignInCancelledException {
      if (mounted) setState(() => _isLoading = false);
      return;
    } on PlatformException catch (e) {
      debugPrint(
        '[GOOGLE LOGIN] PlatformException code=${e.code} message=${e.message}',
      );
      if (mounted) {
        setState(() {
          _errorMessage = GoogleAuthService.instance.platformErrorMessage(e);
        });
      }
    } catch (e) {
      debugPrint('[GOOGLE LOGIN] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Google login failed. $e';
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name'] ?? '');
        await prefs.setString('user_email', response['user']['email'] ?? '');
        await prefs.setBool('hasSeenOnboarding', true);
        await ApiClient.clearCache();

        final profile = await ApiClient.get('/user/profile', requiresAuth: true);
        if (!mounted) return;
        if (profile['success'] == true) {
          final userData = profile['data'];
          if (userData['is_profile_complete'] != true) {
            Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
          } else if (userData['has_completed_diagnosis'] != true) {
            Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.main);
          }
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Apple login failed.';
        });
      }
    } catch (e) {
      debugPrint('[APPLE LOGIN] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Apple login failed. Check your network or cancel.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDebugLogin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DEBUG ACCESS HUB',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildDebugBtn(
              'Demo Account',
              'demo11@gmail.com',
              password: '123456789',
              icon: Icons.rocket_launch_rounded,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Titan',
              'diamond@example.com',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Rainmaker',
              'sarah.chen@example.com',
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Consultant',
              'sophia.kim@example.com',
              icon: Icons.person_outline_rounded,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(height: 24),
            Divider(color: Colors.grey[100]),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'My Account',
              'myname@gmail.com',
              password: '123456789',
              icon: Icons.account_circle_rounded,
              color: const Color(0xFF667eea),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Yasir',
              'yasir.subhani123@gmail.com',
              password: 'password123',
              icon: Icons.person_rounded,
              color: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugBtn(
    String name,
    String email, {
    String password = 'password123',
    IconData? icon,
    Color? color,
  }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _usePhone = false;
        _emailController.text = email;
        _passwordController.text = password;
        _handleLogin();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: (color ?? const Color(0xFFF1F5F9)).withOpacity(0.1),
        foregroundColor: color ?? const Color(0xFF1E293B),
        elevation: 0,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: (color ?? const Color(0xFFE2E8F0)).withOpacity(0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              'LOG IN AS $name',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormUi.scaffold(
      context: context,
      isLoading: _isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onDoubleTap: _showDebugLogin,
              child: AuthFormUi.header(
                title: 'Welcome back',
                subtitle: 'Sign in to your RealtorOne account',
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) AuthFormUi.errorBanner(_errorMessage!),
            AuthFormUi.modeToggle(
              usePhone: _usePhone,
              onEmail: () => setState(() => _usePhone = false),
              onPhone: () => setState(() => _usePhone = true),
            ),
            const SizedBox(height: 14),
            if (_usePhone)
              AuthFormUi.phoneField(
                dialCode: _selectedDialCode,
                controller: _phoneController,
                onDialCodeChanged: (v) =>
                    setState(() => _selectedDialCode = v),
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
              hint: 'Enter password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscurePassword,
              onTogglePassword: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.forgotPassword,
                  arguments: _loginIdentifier(),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AuthFormUi.mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthFormUi.primaryButton(
              label: 'Sign in',
              onPressed: _isLoading ? null : _handleLogin,
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
              prompt: "Don't have an account?",
              action: 'Sign up',
              onTap: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.register),
            ),
          ],
        ),
      ),
    );
  }
}
