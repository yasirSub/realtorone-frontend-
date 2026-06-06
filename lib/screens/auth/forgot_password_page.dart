import 'package:flutter/material.dart';
import '../../api/auth_api.dart';
import '../../utils/phone_utils.dart';
import '../../routes/app_routes.dart';
import '../../widgets/auth/auth_form_ui.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSent = false;
  bool _isPhoneMode = false;
  bool _initializedValue = false;
  bool _usePhone = false;
  String _selectedDialCode = '+971';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedValue) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        if (args.contains('@')) {
          _emailController.text = args;
        } else {
          final parsed = PhoneUtils.parseStored(args);
          _selectedDialCode = parsed.dialCode;
          _phoneController.text = parsed.localDigits;
          _usePhone = true;
        }
      }
      _initializedValue = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final identifier = _usePhone
        ? PhoneUtils.composeE164(_selectedDialCode, _phoneController.text)
        : _emailController.text.trim();

    try {
      final response = await AuthApi.forgotPassword(identifier);

      if (response['status'] == 'ok') {
        setState(() {
          _isSent = true;
          _isPhoneMode = _usePhone;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send reset code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormUi.scaffold(
      context: context,
      isLoading: _isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AuthFormUi.titleColor,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(height: 8),
          _isSent ? _buildSuccessState() : _buildRequestState(),
        ],
      ),
    );
  }

  Widget _buildRequestState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFormUi.header(
            title: 'Forgot password?',
            subtitle: _usePhone
                ? "Enter your phone number and we'll start secure recovery."
                : "Enter your email and we'll send a reset code.",
            leading: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AuthFormUi.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 28,
                color: AuthFormUi.primary,
              ),
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
          const SizedBox(height: 16),
          AuthFormUi.primaryButton(
            label: 'Send reset code',
            onPressed: _isLoading ? null : _handleForgotPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFormUi.header(
          title: 'Request submitted',
          subtitle: _isPhoneMode
              ? 'Use Firebase phone OTP in app, then continue reset with phone verification.'
              : "We've sent a 6-digit reset code to ${_emailController.text.trim()}.",
          leading: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 28,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthFormUi.primaryButton(
          label: _isPhoneMode ? 'Go to login' : 'Enter reset code',
          onPressed: _isPhoneMode
              ? () => Navigator.pushReplacementNamed(context, AppRoutes.login)
              : () => Navigator.pushNamed(
                    context,
                    AppRoutes.verifyOtp,
                    arguments: _emailController.text.trim(),
                  ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () async {
              if (_isPhoneMode) {
                setState(() => _isSent = false);
                return;
              }
              await _handleForgotPassword();
            },
            child: Text(
              _isPhoneMode ? 'Try again' : 'Resend email',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AuthFormUi.primary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
