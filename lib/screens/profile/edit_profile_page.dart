import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/user_api.dart';
import '../../utils/phone_utils.dart';
import '../../utils/profile_contact_verification.dart';
import '../../utils/responsive_helper.dart';
import '../../theme/realtorone_brand.dart';
import '../../widgets/elite_loader.dart';
import '../../widgets/otp_pin_input_row.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _brokerageController = TextEditingController();
  final _instagramController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _experienceController = TextEditingController();
  final _currentIncomeController = TextEditingController();
  final _targetIncomeController = TextEditingController();
  String _selectedDialCode = '+971';
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  String _originalEmail = '';
  String _originalPhoneE164 = '';
  bool _originalEmailWasVerified = false;
  bool _originalPhoneWasVerified = false;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _phonesEqual(String a, String b) {
    final na = PhoneUtils.normalizeFreeform(a.trim());
    final nb = PhoneUtils.normalizeFreeform(b.trim());
    if (na.isEmpty && nb.isEmpty) return true;
    return na == nb;
  }

  final List<String> _dubaiCities = [
    'Dubai Marina',
    'Downtown Dubai',
    'Palm Jumeirah',
    'Business Bay',
    'JBR',
    'JLT',
    'DIFC',
    'Arabian Ranches',
    'Dubai Hills',
    'Jumeirah',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final response = await UserApi.getProfile(useCache: false);
      if (mounted &&
          (response['status'] == 'ok' || response['success'] == true)) {
        final userData = response['data'] ?? response['user'] ?? response;

        // Split name
        final fullName = userData['name'] as String? ?? '';
        if (fullName.isNotEmpty) {
          final parts = fullName.trim().split(RegExp(r'\s+'));
          _firstNameController.text = parts[0];
          if (parts.length > 1) {
            _lastNameController.text = parts.sublist(1).join(' ');
          }
        }

        _emailController.text = userData['email'] ?? '';
        _isEmailVerified = isVerifiedTimestamp(userData['email_verified_at']);
        _isPhoneVerified = isVerifiedTimestamp(userData['mobile_verified_at']);
        _originalEmail = _emailController.text.trim().toLowerCase();
        _originalEmailWasVerified = _isEmailVerified;
        _originalPhoneWasVerified = _isPhoneVerified;
        final storedMobile =
            (userData['mobile'] ?? userData['phone_number'] ?? '').toString();
        final parsed = PhoneUtils.parseStored(storedMobile);
        _selectedDialCode = parsed.dialCode;
        _mobileController.text = parsed.localDigits;
        _originalPhoneE164 = PhoneUtils.normalizeFreeform(
          PhoneUtils.composeE164(_selectedDialCode, _mobileController.text),
        );
        _cityController.text = userData['city'] ?? 'Dubai Marina';
        _brokerageController.text = userData['brokerage'] ?? '';
        _instagramController.text = userData['instagram'] ?? '';
        _linkedinController.text = userData['linkedin'] ?? '';

        if (userData['years_experience'] != null) {
          _experienceController.text = userData['years_experience'].toString();
        }
        if (userData['current_monthly_income'] != null) {
          _currentIncomeController.text = userData['current_monthly_income']
              .toString();
        }
        if (userData['target_monthly_income'] != null) {
          _targetIncomeController.text = userData['target_monthly_income']
              .toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _emailController.text.trim().toLowerCase();
    final newPhoneE164 = PhoneUtils.normalizeFreeform(
      PhoneUtils.composeE164(_selectedDialCode, _mobileController.text),
    );
    final emailChanged = newEmail != _originalEmail;
    final phoneChanged = !_phonesEqual(newPhoneE164, _originalPhoneE164);

    setState(() => _isSaving = true);

    try {
      final response = await UserApi.updateProfile(
        name:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                .trim(),
        email: emailChanged ? newEmail : null,
        mobile: phoneChanged ? newPhoneE164 : null,
        city: _cityController.text.trim(),
        brokerage: _brokerageController.text.trim(),
        instagram: _instagramController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        yearsExperience: int.tryParse(_experienceController.text),
        currentMonthlyIncome: double.tryParse(_currentIncomeController.text),
        targetMonthlyIncome: double.tryParse(_targetIncomeController.text),
      );

      if (!mounted) return;

      final ok = response['success'] == true || response['status'] == 'ok';
      if (ok) {
        final apiEmailChanged = response['email_changed'] == true;
        final apiPhoneChanged = response['mobile_changed'] == true;

        void applyVerificationFromResponse(Map<String, dynamic>? payload) {
          if (payload == null) return;
          if (!apiEmailChanged) {
            _isEmailVerified = _originalEmailWasVerified;
          } else {
            _isEmailVerified =
                isVerifiedTimestamp(payload['email_verified_at']);
          }
          if (!apiPhoneChanged) {
            _isPhoneVerified = _originalPhoneWasVerified;
          } else {
            _isPhoneVerified =
                isVerifiedTimestamp(payload['mobile_verified_at']);
          }
        }

        final data = response['data'];
        if (data is Map<String, dynamic>) {
          applyVerificationFromResponse(data);
        } else {
          applyVerificationFromResponse(null);
        }

        final verifier = ProfileContactVerification(
          context: context,
          firebaseAuth: _firebaseAuth,
        );

        var pendingMessage = '';
        var emailReverted = false;
        var phoneReverted = false;

        if (apiEmailChanged) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['otp_send_failed'] == true
                    ? 'Profile saved. Tap resend if you did not get the email code.'
                    : 'Profile saved. Enter the code sent to your new email.',
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
            ),
          );
          final emailResult = await verifier.verifyEmail(
            newEmail,
            sendOtpIfNeeded: response['otp_send_failed'] == true,
          );
          if (emailResult == ProfileContactVerificationResult.verified) {
            _isEmailVerified = true;
            _originalEmail = newEmail;
            _originalEmailWasVerified = true;
          } else if (emailResult ==
              ProfileContactVerificationResult.dismissedLater) {
            emailReverted = true;
            await _revertContactChange(
              revertEmail: true,
              revertPhone: false,
            );
          } else {
            pendingMessage = 'New email is not verified yet.';
          }
        }

        if (apiPhoneChanged && mounted && !phoneReverted) {
          if (!apiEmailChanged) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Profile saved. Enter the code sent to your new phone number.',
                ),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          final accountEmail =
              emailReverted ? _originalEmail : newEmail;
          final phoneResult = await verifier.verifyPhone(
            accountEmail: accountEmail,
            phoneE164: newPhoneE164,
          );
          if (phoneResult == ProfileContactVerificationResult.verified) {
            _isPhoneVerified = true;
            _originalPhoneE164 = newPhoneE164;
            _originalPhoneWasVerified = true;
          } else if (phoneResult ==
              ProfileContactVerificationResult.dismissedLater) {
            phoneReverted = true;
            await _revertContactChange(
              revertEmail: false,
              revertPhone: true,
            );
          } else if (!emailReverted) {
            pendingMessage = pendingMessage.isEmpty
                ? 'New phone number is not verified yet.'
                : '$pendingMessage New phone is not verified yet.';
          }
        }

        if (!mounted) return;

        if (!apiEmailChanged && !apiPhoneChanged) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully!'),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else if (emailReverted || phoneReverted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                emailReverted && phoneReverted
                    ? 'Contact changes discarded. Previous email and phone restored.'
                    : emailReverted
                        ? 'Email change discarded. Your previous email was restored.'
                        : 'Phone change discarded. Your previous number was restored.',
              ),
              backgroundColor: Colors.orange[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (pendingMessage.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(pendingMessage),
              backgroundColor: Colors.orange[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        Navigator.pop(context, true);
      } else {
        _showError(
          response['message']?.toString() ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      if (mounted) _showError('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _revertContactChange({
    required bool revertEmail,
    required bool revertPhone,
  }) async {
    final response = await UserApi.updateProfile(
      email: revertEmail ? _originalEmail : null,
      mobile: revertPhone ? _originalPhoneE164 : null,
      restoreEmailVerification: revertEmail && _originalEmailWasVerified,
      restoreMobileVerification: revertPhone && _originalPhoneWasVerified,
    );
    if (!mounted) return;
    if (response['success'] == true || response['status'] == 'ok') {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        if (revertEmail) {
          _emailController.text = _originalEmail;
          _isEmailVerified =
              isVerifiedTimestamp(data['email_verified_at']) ||
              _originalEmailWasVerified;
        }
        if (revertPhone) {
          final parsed = PhoneUtils.parseStored(_originalPhoneE164);
          _selectedDialCode = parsed.dialCode;
          _mobileController.text = parsed.localDigits;
          _isPhoneVerified =
              isVerifiedTimestamp(data['mobile_verified_at']) ||
              _originalPhoneWasVerified;
        }
      } else {
        if (revertEmail) {
          _emailController.text = _originalEmail;
          _isEmailVerified = _originalEmailWasVerified;
        }
        if (revertPhone) {
          final parsed = PhoneUtils.parseStored(_originalPhoneE164);
          _selectedDialCode = parsed.dialCode;
          _mobileController.text = parsed.localDigits;
          _isPhoneVerified = _originalPhoneWasVerified;
        }
      }
      setState(() {});
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadProfile(silent: true),
            color: RealtorOneBrand.seed,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: ResponsiveHelper.contentPadding(
                    context,
                    top: 16,
                    bottom: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: ResponsiveHelper.constrainWidth(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionCard(
                              isDark: isDark,
                              title: 'Basic information',
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _firstNameController,
                                        label: 'First name',
                                        hint: 'First name',
                                        icon: Icons.person_outline_rounded,
                                        isDark: isDark,
                                        validator: (v) => (v == null ||
                                                v.isEmpty)
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _lastNameController,
                                        label: 'Last name',
                                        hint: 'Last name',
                                        icon: Icons.person_outline_rounded,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  hint: 'agent@example.com',
                                  icon: Icons.alternate_email_rounded,
                                  isDark: isDark,
                                  isVerified: _isEmailVerified,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@'))
                                      ? 'Invalid'
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                _buildPhoneField(isDark),
                                const SizedBox(height: 10),
                                _buildCityDropdown(isDark),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _brokerageController,
                                  label: 'Brokerage',
                                  hint: 'Company name',
                                  icon: Icons.apartment_rounded,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _sectionCard(
                              isDark: isDark,
                              title: 'Professional details',
                              children: [
                                _buildTextField(
                                  controller: _instagramController,
                                  label: 'Instagram',
                                  hint: 'username',
                                  isDark: isDark,
                                  customIcon: Image.asset(
                                    'assets/images/instagram_logo.png',
                                    width: 16,
                                    height: 16,
                                  ),
                                  prefix: '@',
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _linkedinController,
                                  label: 'LinkedIn',
                                  hint: 'linkedin.com/in/username',
                                  isDark: isDark,
                                  customIcon: Image.asset(
                                    'assets/images/linkedin_logo.png',
                                    width: 16,
                                    height: 16,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildTextField(
                                  controller: _experienceController,
                                  label: 'Years of experience',
                                  hint: '5',
                                  icon: Icons.military_tech_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _currentIncomeController,
                                        label: 'Current income',
                                        hint: '50,000',
                                        icon: Icons.account_balance_wallet_outlined,
                                        isDark: isDark,
                                        prefix: 'AED ',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _targetIncomeController,
                                        label: 'Target income',
                                        hint: '150,000',
                                        icon: Icons.auto_graph_rounded,
                                        isDark: isDark,
                                        prefix: 'AED ',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: FilledButton(
                                onPressed: _isSaving ? null : _handleSave,
                                style: FilledButton.styleFrom(
                                  backgroundColor: RealtorOneBrand.seed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Save changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading || _isSaving) EliteLoader.top(),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required bool isDark,
    required String hint,
    String? prefix,
    IconData? icon,
    Widget? customIcon,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefix,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFFCBD5E1),
        fontSize: 13,
      ),
      prefixIcon: icon != null || customIcon != null
          ? Icon(
              icon,
              color: RealtorOneBrand.seed,
              size: 18,
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: RealtorOneBrand.seed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              const Text(
                'Phone',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              if (_isPhoneVerified) ...[
                const SizedBox(width: 8),
                _verifiedBadge(),
              ],
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: DropdownButtonFormField<String>(
                value: _selectedDialCode,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                items: PhoneUtils.countryOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['code'],
                        child: Text(
                          item['label']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedDialCode = v);
                  _formKey.currentState?.validate();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    PhoneUtils.maxInputLengthFor(_selectedDialCode),
                  ),
                ],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: _fieldDecoration(
                  isDark: isDark,
                  hint: 'Phone number',
                  icon: Icons.phone_android_rounded,
                ),
                validator: PhoneUtils.localDigitsValidator(_selectedDialCode),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    IconData? icon,
    Widget? customIcon,
    String? prefix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isVerified = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                _verifiedBadge(),
              ],
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: _fieldDecoration(
            isDark: isDark,
            hint: hint,
            prefix: prefix,
            icon: customIcon == null ? icon : null,
          ).copyWith(
            prefixIcon: customIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 10, right: 4),
                    child: customIcon,
                  )
                : icon != null
                    ? Icon(icon, color: RealtorOneBrand.seed, size: 18)
                    : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF047857)),
          SizedBox(width: 4),
          Text(
            'VERIFIED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFF047857),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 4),
          child: Text(
            'City / area',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value:
              _cityController.text.isNotEmpty &&
                  _dubaiCities.contains(_cityController.text)
              ? _cityController.text
              : 'Dubai Marina',
          items: _dubaiCities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          decoration: _fieldDecoration(
            isDark: isDark,
            hint: 'Select area',
            icon: Icons.location_on_rounded,
          ),
          onChanged: (v) => setState(() => _cityController.text = v!),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}
