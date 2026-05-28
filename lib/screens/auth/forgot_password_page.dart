import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/auth_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

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

  static const List<Map<String, String>> _countryPhoneOptions = [
    {'label': 'AE (+971)', 'code': '+971'},
    {'label': 'IN (+91)', 'code': '+91'},
    {'label': 'US (+1)', 'code': '+1'},
    {'label': 'UK (+44)', 'code': '+44'},
    {'label': 'SA (+966)', 'code': '+966'},
    {'label': 'QA (+974)', 'code': '+974'},
    {'label': 'KW (+965)', 'code': '+965'},
    {'label': 'BH (+973)', 'code': '+973'},
    {'label': 'OM (+968)', 'code': '+968'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedValue) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        if (args.contains('@')) {
          _emailController.text = args;
        } else {
          _phoneController.text = _digitsOnly(args);
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

    debugPrint('----------------------------------------------');
    final identifier = _usePhone
        ? '$_selectedDialCode${_digitsOnly(_phoneController.text)}'
        : _emailController.text.trim();
    debugPrint('[FORGOT PASSWORD] Attempting for: $identifier');
    try {
      final response = await AuthApi.forgotPassword(identifier);
      
      debugPrint('[FORGOT PASSWORD] Server Response: $response');
      debugPrint('----------------------------------------------');

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
      debugPrint('[FORGOT PASSWORD] ERROR: $e');
      debugPrint('----------------------------------------------');
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMailApp() async {
    final email = _emailController.text.trim().toLowerCase();
    final isGmailUser = email.endsWith('@gmail.com');

    if (isGmailUser) {
      final gmailUri = Uri.parse('googlegmail://');
      if (await canLaunchUrl(gmailUri)) {
        await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final mailtoUri = Uri(
      scheme: 'mailto',
      path: _emailController.text.trim(),
    );
    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No email app found on this device.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading) EliteLoader.top(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _isSent ? _buildSuccessState() : _buildRequestState(),
            ),
          ),
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
          const SizedBox(height: 40),
          const Icon(Icons.lock_reset_rounded, size: 80, color: Color(0xFF667eea))
              .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _usePhone
                ? "Choose country code and phone number, we'll start secure phone recovery."
                : "Enter your email address and we'll send you an OTP/Link to reset your password.",
            style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (_errorMessage != null)
            _buildErrorBox(_errorMessage!),

          _buildModeSelector(),
          const SizedBox(height: 16),
          _usePhone ? _buildPhoneField() : _buildEmailField(),
          const SizedBox(height: 32),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'SEND RESET CODE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.green)
            .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        const Text(
          'Request Submitted',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _isPhoneMode
              ? "Use Firebase phone OTP in app, then continue reset with phone verification."
              : "We've sent a 6-digit reset code to ${_emailController.text.trim()}. Please check your inbox.",
          style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _isPhoneMode
                ? () => Navigator.pushReplacementNamed(context, AppRoutes.login)
                : () => Navigator.pushNamed(
                      context,
                      AppRoutes.verifyOtp,
                      arguments: _emailController.text.trim(),
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_isPhoneMode ? 'GO TO LOGIN' : 'ENTER RESET CODE'),
          ),
        ),
        if (!_isPhoneMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openMailApp,
              icon: const Icon(Icons.mail_outline_rounded),
              label: Text(
                _emailController.text.trim().toLowerCase().endsWith('@gmail.com')
                    ? 'OPEN GMAIL'
                    : 'OPEN MAIL APP',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF667eea),
                side: const BorderSide(color: Color(0xFF667eea)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            if (_isPhoneMode) {
              setState(() => _isSent = false);
              return;
            }
            await _handleForgotPassword();
          },
          child: Text(
            _isPhoneMode ? 'Try Again' : 'Resend Email',
            style: const TextStyle(color: Color(0xFF667eea)),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeChip(
              title: 'Email',
              selected: !_usePhone,
              onTap: () => setState(() => _usePhone = false),
            ),
          ),
          Expanded(
            child: _modeChip(
              title: 'Phone',
              selected: _usePhone,
              onTap: () => setState(() => _usePhone = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF667eea) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMAIL ADDRESS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'agent@example.com',
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF667eea)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          validator: (v) =>
              (v == null || !v.trim().contains('@') || !v.trim().contains('.'))
                  ? 'Invalid email'
                  : null,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHONE NUMBER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 128,
              child: DropdownButtonFormField<String>(
                value: _selectedDialCode,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                items: _countryPhoneOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['code'],
                        child: Text(item['label']!, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedDialCode = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  prefixIcon: const Icon(
                    Icons.phone_android_rounded,
                    color: Color(0xFF667eea),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (v) {
                  final digits = _digitsOnly(v ?? '');
                  if (digits.isEmpty) return 'Required';
                  if (digits.length < 7 || digits.length > 15) {
                    return 'Invalid phone';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red[900], fontSize: 13, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
