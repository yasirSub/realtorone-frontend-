import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final ImagePicker _imagePicker = ImagePicker();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSuccess = false;
  File? _profileImage;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController(text: 'Dubai Marina');
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
    _fetchInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for registration arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['name'] != null && _firstNameController.text.isEmpty) {
        final fullName = args['name'] as String;
        final parts = fullName.trim().split(RegExp(r'\s+'));
        _firstNameController.text = parts[0];
        if (parts.length > 1) {
          _lastNameController.text = parts.sublist(1).join(' ');
        }
      }
      if (args['email'] != null && _emailController.text.isEmpty) {
        _emailController.text = args['email'];
      }
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final response = await UserApi.getProfile();
      if (mounted &&
          (response['status'] == 'ok' || response['success'] == true)) {
        final userData = response['data'] ?? response['user'] ?? response;

        // Split name if exists
        final fullName = userData['name'] as String? ?? '';
        if (fullName.isNotEmpty && _firstNameController.text.isEmpty) {
          final parts = fullName.trim().split(RegExp(r'\s+'));
          _firstNameController.text = parts[0];
          if (parts.length > 1) {
            _lastNameController.text = parts.sublist(1).join(' ');
          }
        }

        if (_emailController.text.isEmpty) {
          _emailController.text = userData['email'] ?? '';
        }
        _mobileController.text = userData['mobile'] ?? '';

        // If they already have a city, set it
        final city = userData['city'] as String?;
        if (city != null && _dubaiCities.contains(city)) {
          _cityController.text = city;
        }

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
      debugPrint('Error fetching initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _cityController.dispose();
    _brokerageController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _experienceController.dispose();
    _currentIncomeController.dispose();
    _targetIncomeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        _showError('Failed to pick image: $e');
      }
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final email = _emailController.text.trim();
      final mobile = _mobileController.text.trim();
      final city = _cityController.text.trim();
      final brokerage = _brokerageController.text.trim();
      final instagram = _instagramController.text.isNotEmpty
          ? _instagramController.text.trim()
          : null;
      final linkedin = _linkedinController.text.isNotEmpty
          ? _linkedinController.text.trim()
          : null;
      final yearsExperience = _experienceController.text.isNotEmpty
          ? int.tryParse(_experienceController.text)
          : null;
      final currentMonthlyIncome = _currentIncomeController.text.isNotEmpty
          ? double.tryParse(_currentIncomeController.text)
          : null;
      final targetMonthlyIncome = _targetIncomeController.text.isNotEmpty
          ? double.tryParse(_targetIncomeController.text)
          : null;

      debugPrint('--- Submitting Profile ---');
      debugPrint('Name: $name');
      debugPrint('Email: $email');
      debugPrint('Mobile: $mobile');
      debugPrint('City: $city');
      debugPrint('Brokerage: $brokerage');

      final response = await UserApi.setupProfile(
        name: name,
        email: email,
        mobile: mobile,
        city: city,
        brokerage: brokerage,
        instagram: instagram,
        linkedin: linkedin,
        yearsExperience: yearsExperience,
        currentMonthlyIncome: currentMonthlyIncome,
        targetMonthlyIncome: targetMonthlyIncome,
      );

      debugPrint('--- Profile Response ---');
      debugPrint('Success: ${response['success']}');
      debugPrint('Status: ${response['status']}');
      debugPrint('Message: ${response['message']}');
      debugPrint('Full Response: $response');

      if (mounted) {
        if (response['success'] == true || response['status'] == 'ok') {
          // Upload profile picture if selected (optional)
          if (_profileImage != null) {
            try {
              debugPrint('--- Uploading Profile Picture ---');
              final photoResponse = await UserApi.uploadPhoto(_profileImage!);
              debugPrint('Photo Upload Response: $photoResponse');

              if (photoResponse['success'] != true) {
                debugPrint(
                  'Warning: Photo upload failed but continuing: ${photoResponse['message']}',
                );
              }
            } catch (photoError) {
              // Log the error but don't block the flow since photo is optional
              debugPrint(
                'Warning: Photo upload error but continuing: $photoError',
              );
            }
          }

          setState(() {
            _isLoading = false;
            _isSuccess = true;
          });

          await Future.delayed(const Duration(milliseconds: 3000));
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
          }
        } else {
          _showError(response['message'] ?? 'Failed to save profile');
        }
      }
    } catch (e) {
      debugPrint('--- Profile Error ---');
      debugPrint(e.toString());
      if (mounted) _showError('Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 1) {
      if (_formKey.currentState!.validate()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    } else {
      _submitProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient blobs for a premium look
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut),

          if (_isLoading) EliteLoader.top(),

          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStepIndicatorBar(),

                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (idx) =>
                          setState(() => _currentStep = idx),
                      children: [_buildBasicStep(), _buildAdditionalStep()],
                    ),
                  ),

                  _buildBottomBar(),
                ],
              ),
            ),
          ),
          if (_isSuccess) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STEP INDICATOR',
                  style: TextStyle(
                    color: Color(0xFF667eea),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (_currentStep > 0)
                IconButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentStep == 0 ? 'Basic Information' : 'Professional Details',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
          const SizedBox(height: 8),
          Text(
            _currentStep == 0
                ? 'Tell us who you are to personalize your workspace.'
                : 'Help us understand your current real estate performance.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          Expanded(child: _buildProgressSegment(0)),
          const SizedBox(width: 8),
          Expanded(child: _buildProgressSegment(1)),
        ],
      ),
    );
  }

  Widget _buildProgressSegment(int step) {
    final isActive = _currentStep >= step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF667eea) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildBasicStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Profile Photo Picker
          GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _profileImage != null
                    ? Colors.transparent
                    : const Color(0xFF667eea).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF667eea).withValues(alpha: 0.3),
                  width: 2,
                ),
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _profileImage == null
                  ? const Icon(
                      Icons.add_a_photo_rounded,
                      color: Color(0xFF667eea),
                      size: 40,
                    )
                  : null,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 8),
          Text(
            _profileImage != null ? 'TAP TO CHANGE' : 'UPLOAD PHOTO (OPTIONAL)',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),
          _buildTextField(
            controller: _firstNameController,
            label: 'FIRST NAME',
            hint: 'Alexander',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _lastNameController,
            label: 'LAST NAME',
            hint: 'Sterling',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'EMAIL ADDRESS',
            hint: 'agent@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Invalid email' : null,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _mobileController,
            label: 'PHONE NUMBER',
            hint: '+971 50 123 4567',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildCityDropdown()
              .animate()
              .fadeIn(delay: 500.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _brokerageController,
            label: 'BROKERAGE NAME',
            hint: 'E.g. Blue Chip Real Estate',
            icon: Icons.apartment_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAdditionalStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTextField(
            controller: _instagramController,
            label: 'INSTAGRAM',
            hint: '@username',
            icon: Icons.camera_alt_outlined,
            prefix: '@',
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _linkedinController,
            label: 'LINKEDIN URL',
            hint: 'linkedin.com/in/username',
            icon: Icons.link_rounded,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _experienceController,
            label: 'YEARS OF EXPERIENCE',
            hint: '5',
            icon: Icons.military_tech_outlined,
            keyboardType: TextInputType.number,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _currentIncomeController,
            label: 'CURRENT MONTHLY INCOME',
            hint: '50,000',
            icon: Icons.account_balance_wallet_outlined,
            prefix: 'AED ',
            keyboardType: TextInputType.number,
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _targetIncomeController,
            label: 'TARGET MONTHLY INCOME',
            hint: '150,000',
            icon: Icons.auto_graph_rounded,
            prefix: 'AED ',
            keyboardType: TextInputType.number,
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
          const SizedBox(height: 48),

          TextButton(
            onPressed: _isLoading ? null : _submitProfile,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SKIP & FINISH SETUP',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 700.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
              child: Icon(icon, color: const Color(0xFF667eea), size: 18),
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
            floatingLabelBehavior: FloatingLabelBehavior.never,
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
          value: _cityController.text,
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 40,
            offset: Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
                ),
                child: _isLoading
                    ? const SizedBox(width: 120, child: EliteLoader())
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 1 ? 'SAVE PROFILE' : 'CONTINUE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(
          0xFF020617,
        ).withValues(alpha: 0.98), // Deep Elite Background
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Pulsing Effect
            Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.5, 1.5),
                  duration: 2.seconds,
                ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glassmorphic Icon Container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1), // Indigo
                            Color(0xFF8B5CF6), // Violet
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 48),

                // Tactical Welcome Text
                Text(
                  'WELCOME AGENT ${_firstNameController.text.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'CLEARANCE GRANTED: LEVEL 1',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 60),

                // Loading Bar
                SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      const LinearProgressIndicator(
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                        minHeight: 2,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'INITIALIZING STRATEGY PROTOCOLS...',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ).animate().fadeIn(delay: 800.ms),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}
