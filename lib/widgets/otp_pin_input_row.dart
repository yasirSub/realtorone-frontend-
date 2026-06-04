import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum OtpPinVisualState { idle, error, success }

/// Six single-digit OTP boxes with multi-digit paste and visual success/error states.
class OtpPinInputRow extends StatefulWidget {
  const OtpPinInputRow({
    super.key,
    required this.visualState,
    this.onChanged,
    this.onCompleted,
  });

  final OtpPinVisualState visualState;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;

  @override
  OtpPinInputRowState createState() => OtpPinInputRowState();
}

class OtpPinInputRowState extends State<OtpPinInputRow> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String get otp => _controllers.map((c) => c.text).join();

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

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged?.call('');
    setState(() {});
  }

  void _notifyChanged() {
    widget.onChanged?.call(otp);
    if (otp.length == 6) {
      widget.onCompleted?.call();
    }
  }

  void _fillFromIndex(int startIndex, String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    for (var i = 0; i < clean.length && (startIndex + i) < 6; i++) {
      _controllers[startIndex + i].text = clean[i];
    }
    final nextIndex = (startIndex + clean.length).clamp(0, 5);
    if (otp.length == 6) {
      _focusNodes[nextIndex].unfocus();
    } else {
      _focusNodes[nextIndex].requestFocus();
    }
    setState(_notifyChanged);
  }

  Color _borderColor({required bool focused}) {
    switch (widget.visualState) {
      case OtpPinVisualState.success:
        return const Color(0xFF10B981);
      case OtpPinVisualState.error:
        return const Color(0xFFEF4444);
      case OtpPinVisualState.idle:
        return focused ? const Color(0xFF667eea) : const Color(0xFFE2E8F0);
    }
  }

  Color _fillColor() {
    switch (widget.visualState) {
      case OtpPinVisualState.success:
        return const Color(0xFFECFDF5);
      case OtpPinVisualState.error:
        return const Color(0xFFFEF2F2);
      case OtpPinVisualState.idle:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 42,
          height: 52,
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            enabled: widget.visualState != OtpPinVisualState.success,
            cursorColor: Colors.black,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: widget.visualState == OtpPinVisualState.success
                  ? const Color(0xFF047857)
                  : Colors.black,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _fillColor(),
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _borderColor(focused: false),
                  width: widget.visualState == OtpPinVisualState.success ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _borderColor(focused: true),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              final clean = value.replaceAll(RegExp(r'\D'), '');
              if (clean.length > 1) {
                _fillFromIndex(index, clean);
                return;
              }
              if (clean.isNotEmpty) {
                _controllers[index].text = clean;
                if (index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                }
              } else if (index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
              _notifyChanged();
            },
          ),
        );
      }),
    );
  }
}

bool isVerifiedTimestamp(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  final text = value.toString().trim();
  return text.isNotEmpty && text.toLowerCase() != 'null';
}
