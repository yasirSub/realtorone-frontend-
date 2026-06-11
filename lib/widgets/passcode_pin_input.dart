import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/realtorone_brand.dart';

/// Visual style for passcode boxes — ensures contrast on any screen background.
enum PasscodePinVariant {
  /// White card on dark backgrounds (lock screen).
  onDark,

  /// Elevated card on light/dark app surfaces (setup, profile).
  onSurface,
}

class PasscodePinInput extends StatefulWidget {
  const PasscodePinInput({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.variant = PasscodePinVariant.onSurface,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final PasscodePinVariant variant;

  @override
  PasscodePinInputState createState() => PasscodePinInputState();
}

class PasscodePinInputState extends State<PasscodePinInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get value => _controller.text;

  void clear() {
    _controller.clear();
    _focusNode.requestFocus();
    widget.onChanged?.call('');
    setState(() {});
  }

  void _onTextChanged() {
    setState(() {});
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(text);
    }
  }

  Color get _emptyRingColor => widget.hasError
      ? const Color(0xFFFCA5A5)
      : const Color(0xFF94A3B8);

  Color get _filledDotColor => widget.hasError
      ? const Color(0xFFEF4444)
      : RealtorOneBrand.seed;

  Color get _boxFill => widget.hasError
      ? const Color(0xFFFEF2F2)
      : Colors.white;

  Color _borderColor({required bool focused, required bool filled}) {
    if (widget.hasError) return const Color(0xFFEF4444);
    if (focused) return RealtorOneBrand.seed;
    if (filled) return RealtorOneBrand.seed.withValues(alpha: 0.35);
    return const Color(0xFFCBD5E1);
  }

  Widget _buildDot(int index, String code) {
    final filled = index < code.length;
    final focused = _focusNode.hasFocus && index == code.length;

    return Padding(
      padding: EdgeInsets.only(
        right: index == widget.length - 1 ? 0 : 14,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 58,
        height: 62,
        decoration: BoxDecoration(
          color: _boxFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor(focused: focused, filled: filled),
            width: focused ? 2.5 : 1.5,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: RealtorOneBrand.seed.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: filled ? 16 : 12,
          height: filled ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? _filledDotColor : Colors.transparent,
            border: Border.all(
              color: filled ? _filledDotColor : _emptyRingColor,
              width: filled ? 0 : 2,
            ),
          ),
        ),
      ),
    );
  }

  static const _inputDecoration = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    filled: true,
    fillColor: Colors.transparent,
    isCollapsed: true,
    counterText: '',
    contentPadding: EdgeInsets.zero,
  );

  Widget _buildHiddenField() {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofocus: true,
        enableSuggestions: false,
        autocorrect: false,
        showCursor: false,
        style: const TextStyle(
          color: Colors.transparent,
          fontSize: 1,
          height: 1,
        ),
        cursorColor: Colors.transparent,
        decoration: _inputDecoration,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.length),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;

    final inputWidth = widget.length * 58.0 + (widget.length - 1) * 14.0;

    final content = GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
      width: inputWidth,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Invisible field behind dots — receives keyboard + backspace.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: _buildHiddenField(),
            ),
          ),
          // Visual dots only; taps pass through to the field.
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.length,
                (index) => _buildDot(index, code),
              ),
            ),
          ),
        ],
      ),
      ),
    );

    if (widget.variant == PasscodePinVariant.onDark) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: content,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: widget.hasError
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.hasError
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: content,
    );
  }
}

/// Shared header + card layout for passcode flows.
class PasscodeEntryCard extends StatelessWidget {
  const PasscodeEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pinInput,
    this.error,
    this.loading = false,
    this.icon = Icons.lock_rounded,
    this.onDarkBackground = false,
  });

  final String title;
  final String subtitle;
  final Widget pinInput;
  final String? error;
  final bool loading;
  final IconData icon;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        onDarkBackground ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = onDarkBackground
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: onDarkBackground
                ? RealtorOneBrand.seed.withValues(alpha: 0.18)
                : RealtorOneBrand.seed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: RealtorOneBrand.seed, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: titleColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        pinInput,
        if (error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (loading) ...[
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: RealtorOneBrand.seed,
            ),
          ),
        ],
      ],
    );
  }
}
