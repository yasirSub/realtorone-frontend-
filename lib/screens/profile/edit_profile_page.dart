import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/user_api.dart';
import '../../widgets/elite_loader.dart';

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

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await UserApi.getProfile();
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
        _mobileController.text = userData['mobile'] ?? '';
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
    setState(() => _isSaving = true);

    try {
      final response = await UserApi.updateProfile(
        name:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                .trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        city: _cityController.text.trim(),
        brokerage: _brokerageController.text.trim(),
        instagram: _instagramController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        yearsExperience: int.tryParse(_experienceController.text),
        currentMonthlyIncome: double.tryParse(_currentIncomeController.text),
        targetMonthlyIncome: double.tryParse(_targetIncomeController.text),
      );

      if (mounted) {
        if (response['success'] == true || response['status'] == 'ok') {
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
          Navigator.pop(context, true);
        } else {
          _showError(response['message'] ?? 'Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) _showError('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('BASIC INFORMATION'),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'FIRST NAME',
                    hint: 'Alexander',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'LAST NAME',
                    hint: 'Last Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'EMAIL ADDRESS',
                    hint: 'agent@example.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Invalid' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _mobileController,
                    label: 'PHONE NUMBER',
                    hint: '+971 50 123 4567',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildCityDropdown(),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerageController,
                    label: 'BROKERAGE NAME',
                    hint: 'E.g. Blue Chip Real Estate',
                    icon: Icons.apartment_rounded,
                  ),

                  const SizedBox(height: 48),
                  _buildSectionHeader('PROFESSIONAL DETAILS'),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _instagramController,
                    label: 'INSTAGRAM',
                    hint: '@username',
                    customIcon: Image.asset(
                      'assets/images/instagram_logo.png',
                      width: 20,
                      height: 20,
                    ),
                    prefix: '@',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _linkedinController,
                    label: 'LINKEDIN URL',
                    hint: 'linkedin.com/in/username',
                    customIcon: Image.asset(
                      'assets/images/linkedin_logo.png',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _experienceController,
                    label: 'YEARS OF EXPERIENCE',
                    hint: '5',
                    icon: Icons.military_tech_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _currentIncomeController,
                    label: 'CURRENT MONTHLY INCOME',
                    hint: '50,000',
                    icon: Icons.account_balance_wallet_outlined,
                    prefix: 'AED ',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _targetIncomeController,
                    label: 'TARGET MONTHLY INCOME',
                    hint: '150,000',
                    icon: Icons.auto_graph_rounded,
                    prefix: 'AED ',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading || _isSaving) EliteLoader.top(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF667eea),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Widget? customIcon,
    String? prefix,
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
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
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
              child:
                  customIcon ??
                  Icon(icon, color: const Color(0xFF667eea), size: 18),
            ),
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

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PRIMARY OPERATIONAL SECTOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
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
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF667eea),
                size: 18,
              ),
            ),
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
          ),
          onChanged: (v) => setState(() => _cityController.text = v!),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }
}
