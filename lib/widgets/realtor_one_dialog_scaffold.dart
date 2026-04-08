import 'package:flutter/material.dart';

/// Branded dialog shell aligned with Deal Room / app tour surfaces (not raw [AlertDialog]).
class RealtorOneDialogScaffold extends StatelessWidget {
  const RealtorOneDialogScaffold({
    super.key,
    required this.title,
    this.titleColor,
    this.child,
    this.actions = const [],
    this.semanticsLabel,
  });

  final String title;
  final Color? titleColor;
  final Widget? child;
  final List<Widget> actions;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 16, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: titleColor ??
                      (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              if (child != null) ...[
                const SizedBox(height: 14),
                child!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, child: dialog);
    }
    return dialog;
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext dialogContext) builder,
    bool barrierDismissible = true,
    String? semanticsLabel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) {
        final w = builder(dialogContext);
        return semanticsLabel != null
            ? Semantics(label: semanticsLabel, child: w)
            : w;
      },
    );
  }
}
