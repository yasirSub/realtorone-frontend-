import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/phone_utils.dart';

/// Compact country code + local phone number row (avoids wide dropdown overflow).
class PhoneNumberInputRow extends StatelessWidget {
  const PhoneNumberInputRow({
    super.key,
    required this.dialCode,
    required this.controller,
    required this.onDialCodeChanged,
    this.isDark = false,
  });

  final String dialCode;
  final TextEditingController controller;
  final ValueChanged<String> onDialCodeChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = const Color(0xFFE2E8F0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: DropdownButtonFormField<String>(
            value: dialCode,
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF667EEA),
                  width: 1.5,
                ),
              ),
            ),
            selectedItemBuilder: (context) => PhoneUtils.countryOptions
                .map(
                  (item) => Text(
                    item['code']!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
            items: PhoneUtils.countryOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['code'],
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onDialCodeChanged(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                PhoneUtils.maxInputLengthFor(dialCode),
              ),
            ],
            decoration: InputDecoration(
              hintText: 'Phone number',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: fillColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(
                  color: Color(0xFF667EEA),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
