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
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    for (var i = 0; i < widget.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) setState(() {});
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get value => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged?.call('');
    setState(() {});
  }

  void _notify() {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  void _fillFrom(int start, String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    for (var i = 0; i < clean.length && (start + i) < widget.length; i++) {
      _controllers[start + i].text = clean[i];
    }
    final next = (start + clean.length).clamp(0, widget.length - 1);
    if (value.length == widget.length) {
      _focusNodes[next].unfocus();
    } else {
      _focusNodes[next].requestFocus();
    }
    _notify();
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

  @override
  Widget build(BuildContext context) {
    final pinRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final filled = _controllers[index].text.isNotEmpty;
        final focused = _focusNodes[index].hasFocus;

        return Padding(
          padding: EdgeInsets.only(
            right: index == widget.length - 1 ? 0 : 14,
          ),
          child: SizedBox(
            width: 58,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
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
                ),
                AnimatedContainer(
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
                TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  showCursor: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  cursorColor: Colors.transparent,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (v.length > 1) {
                      _fillFrom(index, v);
                      return;
                    }
                    if (v.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    } else if (v.isNotEmpty && index < widget.length - 1) {
                      _focusNodes[index + 1].requestFocus();
                    }
                    _notify();
                  },
                  onTap: () => _controllers[index].selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controllers[index].text.length,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    if (widget.variant == PasscodePinVariant.onDark) {
      return Container(
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
        child: pinRow,
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
      child: pinRow,
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
