import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasscodePinInput extends StatefulWidget {
  const PasscodePinInput({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
    this.obscure = true,
    this.hasError = false,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool obscure;
  final bool hasError;

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
    setState(_notify);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 10),
          child: SizedBox(
            width: 48,
            height: 52,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              obscureText: widget.obscure,
              maxLength: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF667eea),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (v) {
                if (v.length > 1) {
                  _fillFrom(index, v);
                  return;
                }
                if (v.isNotEmpty && index < widget.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
                _notify();
              },
              onTap: () => _controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[index].text.length,
              ),
            ),
          ),
        );
      }),
    );
  }
}
