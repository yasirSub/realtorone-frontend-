import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/api_client.dart';
import '../../api/auth_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthApi.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (response['status'] == 'ok' && response['token'] != null) {
        await ApiClient.setToken(response['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', response['user']['name']);
        await prefs.setString('user_email', response['user']['email']);
        await prefs.setBool('hasSeenOnboarding', true);

        // Clear cache to ensure fresh data for the new session
        await ApiClient.clearCache();

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
              'Iconic Leader',
              'diamond@example.com',
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Gold Executive',
              'sarah.chen@example.com',
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Silver Member',
              'james.rodriguez@example.com',
              icon: Icons.stars_rounded,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            _buildDebugBtn(
              'Free User',
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
        _emailController.text = email;
        _passwordController.text = password;
        _handleLogin();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: (color ?? const Color(0xFFF1F5F9)).withValues(
          alpha: 0.1,
        ),
        foregroundColor: color ?? const Color(0xFF1E293B),
        elevation: 0,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: (color ?? const Color(0xFFE2E8F0)).withValues(alpha: 0.2),
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
    return Scaffold(
      body: Stack(
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
                        Icons.rocket_launch_rounded,
                        size: 80,
                        color: Color(0xFF667eea),
                      ).animate().fadeIn(duration: 800.ms).scale(delay: 200.ms),
                      const SizedBox(height: 32),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          letterSpacing: -1,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                      const SizedBox(height: 8),
                      const Text(
                        'Log in to your realtor dashboard',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 500.ms),

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
                        controller: _emailController,
                        label: 'EMAIL ADDRESS',
                        hint: 'agent@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Valid email required'
                            : null,
                      ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.05),

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
                            ? 'Password too short'
                            : null,
                      ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.05),

                      const SizedBox(height: 40),

                      SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'SIGN IN',
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.register,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 1000.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 20,
            bottom: 20,
            child: Opacity(
              opacity: 0.3,
              child: FloatingActionButton.small(
                onPressed: _showDebugLogin,
                backgroundColor: const Color(0xFF1E293B),
                child: const Icon(
                  Icons.bug_report_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
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
    return Opacity(
      opacity: 0.5, // Faded to show it's disabled
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
            onTap: null, // Disabled
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
