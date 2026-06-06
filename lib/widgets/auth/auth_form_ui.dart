import 'package:flutter/material.dart';

import '../../utils/phone_utils.dart';
import '../../utils/responsive_helper.dart';
import '../elite_loader.dart';
import '../phone_number_input_row.dart';

/// Compact, professional auth form styling (iOS-friendly).
class AuthFormUi {
  AuthFormUi._();

  static const Color primary = Color(0xFF667EEA);
  static const Color titleColor = Color(0xFF0F172A);
  static const Color mutedColor = Color(0xFF64748B);
  static const double fieldRadius = 12;
  static const double buttonHeight = 48;
  static const double maxFormWidth = 400;

  static InputDecoration inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  static Widget fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: mutedColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static Widget scaffold({
    required BuildContext context,
    required Widget child,
    bool isLoading = false,
  }) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primary.withValues(alpha: 0.08),
                      const Color(0xFFF8FAFC),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isLoading) EliteLoader.top(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.horizontalPadding(context)
                      .clamp(20, 28),
                  vertical: 16,
                ),
                child: ResponsiveHelper.constrainWidth(
                  maxWidth: maxFormWidth,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget header({
    required String title,
    required String subtitle,
    Widget? leading,
  }) {
    return Column(
      children: [
        leading ??
            Image.asset(
              'assets/images/logo.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: mutedColor,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  static Widget modeToggle({
    required bool usePhone,
    required VoidCallback onEmail,
    required VoidCallback onPhone,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeChip(
              title: 'Email',
              selected: !usePhone,
              onTap: onEmail,
            ),
          ),
          Expanded(
            child: _modeChip(
              title: 'Phone',
              selected: usePhone,
              onTap: onPhone,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _modeChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : mutedColor,
          ),
        ),
      ),
    );
  }

  static Widget textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fieldLabel(label),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
          decoration: inputDecoration(
            hint: hint,
            prefixIcon: icon,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  static Widget phoneField({
    required String dialCode,
    required ValueChanged<String> onDialCodeChanged,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fieldLabel('Phone number'),
        FormField<String>(
          validator: (_) => validator?.call(controller.text),
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhoneNumberInputRow(
                  dialCode: dialCode,
                  controller: controller,
                  isDark: false,
                  onDialCodeChanged: onDialCodeChanged,
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      state.errorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: buttonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  static Widget orDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
      ],
    );
  }

  static Widget socialRow({
    required VoidCallback? onGoogle,
    required VoidCallback? onApple,
    bool enabled = true,
  }) {
    final opacity = enabled ? 1.0 : 0.5;
    return Opacity(
      opacity: opacity,
      child: Row(
        children: [
          Expanded(
            child: _socialButton(
              label: 'Google',
              child: Image.asset(
                'assets/images/google_logo.png',
                width: 18,
                height: 18,
              ),
              onTap: enabled ? onGoogle : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _socialButton(
              label: 'Apple',
              child: const Icon(Icons.apple, size: 20, color: Colors.black),
              onTap: enabled ? onApple : null,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _socialButton({
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: titleColor,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(fieldRadius),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget footerLink({
    required String prompt,
    required String action,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(color: mutedColor, fontSize: 13),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
