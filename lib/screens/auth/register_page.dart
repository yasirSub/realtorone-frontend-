import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/auth_api.dart';
import '../../api/api_client.dart';
import '../../services/push_notification_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthApi.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (response['status'] == 'ok') {
        // Ensure we have a token (handle cases where register doesn't return one)
        final token = await ApiClient.getToken();
        if (token == null) {
          final loginResponse = await AuthApi.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
          if (loginResponse['status'] != 'ok' ||
              loginResponse['token'] == null) {
            setState(
              () => _errorMessage =
                  'Registration successful, but failed to log in automatically.',
            );
            return;
          }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.profileSetup,
            arguments: {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
            },
          );
        }
      } else {
        setState(
          () => _errorMessage = response['message'] ?? 'Registration failed.',
        );
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

  Future<void> _handleGoogleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[GOOGLE SIGNUP] Started');
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GOOGLE SIGNUP] User cancelled account picker');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      debugPrint('[GOOGLE SIGNUP] Selected account: ${account.email}');

      final auth = await account.authentication;
      final idToken = auth.idToken;
      debugPrint(
        '[GOOGLE SIGNUP] idToken present: ${idToken != null && idToken.isNotEmpty}',
      );
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          _googleWebClientId.isEmpty
              ? 'Google id token missing. Pass --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com'
              : 'Google id token missing. Check Firebase OAuth config and SHA fingerprints.',
        );
      }

      final response = await AuthApi.loginWithGoogle(
        idToken: idToken,
        email: account.email,
        name: account.displayName,
        photoUrl: account.photoUrl,
      );
      debugPrint('[GOOGLE SIGNUP] Backend response: $response');

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
          _errorMessage = response['message'] ?? 'Google signup failed.';
        });
        debugPrint('[GOOGLE SIGNUP] Failed at backend: $_errorMessage');
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[GOOGLE SIGNUP] PlatformException code=${e.code} message=${e.message}',
      );
      if (mounted) {
        setState(() {
          _errorMessage =
              'Google signup failed (${e.code}). ${e.message ?? ''}'.trim();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF667eea).withValues(alpha: 0.15),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading) EliteLoader.top(),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                              Icons.person_add_outlined,
                              size: 70,
                              color: Color(0xFF667eea),
                            )
                            .animate()
                            .fadeIn(duration: 800.ms)
                            .scale(delay: 100.ms),
                        const SizedBox(height: 32),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                        const SizedBox(height: 8),
                        const Text(
                          'Join our community of elite realtors',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 48),

                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().shake(),

                        _buildTextField(
                          controller: _nameController,
                          label: 'FULL NAME',
                          hint: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.05),

                        const SizedBox(height: 20),

                        _buildTextField(
                          controller: _emailController,
                          label: 'EMAIL ADDRESS',
                          hint: 'agent@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Invalid'
                              : null,
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.05),

                        const SizedBox(height: 20),

                        _buildTextField(
                          controller: _passwordController,
                          label: 'PASSWORD',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Min 6 characters'
                              : null,
                        ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.05),

                        const SizedBox(height: 40),

                        SizedBox(
                          height: 60,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 900.ms).scale(),

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: const Color(0xFFE2E8F0),
                                thickness: 1.5,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: const Color(0xFFE2E8F0),
                                thickness: 1.5,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 1000.ms),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialBtn(
                              customIcon: Image.asset(
                                'assets/images/google_logo.png',
                                width: 24,
                                height: 24,
                              ),
                              label: 'Google',
                              color: const Color(0xFF4285F4),
                            ),
                            const SizedBox(width: 16),
                            _buildSocialBtn(
                              icon: Icons.apple_rounded,
                              label: 'Apple',
                              color: Colors.black,
                            ),
                          ],
                        ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.2),

                        const SizedBox(height: 40),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 1200.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF667eea), size: 18),
            ),
            suffixIcon: isPassword
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSocialBtn({
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Color color,
  }) {
    final isGoogle = label.toLowerCase() == 'google';
    final isApple = label.toLowerCase() == 'apple';
    final enabled = isGoogle && !_isLoading;
    return Opacity(
      opacity: enabled || isApple ? 1 : 0.5,
      child: Container(
        height: 60,
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled
                ? _handleGoogleRegister
                : (isApple
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Apple signup will be enabled soon.',
                              ),
                            ),
                          );
                        }
                      : null),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                customIcon ?? Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
