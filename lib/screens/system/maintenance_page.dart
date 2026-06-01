import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../services/support_contact_service.dart';

/// Why the user landed on this screen (from route `kind`).
enum MaintenancePageKind {
  maintenance,
  unavailable,
}

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({
    super.key,
    required this.message,
    this.contact = SupportContact.defaults,
    this.kind = MaintenancePageKind.maintenance,
  });

  final String message;
  final SupportContact contact;
  final MaintenancePageKind kind;

  static MaintenancePageKind kindFromRoute(Object? raw) {
    final value = (raw is String ? raw : raw?.toString() ?? '').toLowerCase();
    if (value == 'unavailable' ||
        value == 'error' ||
        value == 'offline' ||
        value == 'service') {
      return MaintenancePageKind.unavailable;
    }
    return MaintenancePageKind.maintenance;
  }

  bool get _isMaintenance => kind == MaintenancePageKind.maintenance;

  Color get _accent =>
      _isMaintenance ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

  String get _statusLabel =>
      _isMaintenance ? 'MAINTENANCE MODE' : 'SERVICE UNAVAILABLE';

  String get _statusSub =>
      _isMaintenance ? 'System upgrade in progress' : 'Please wait and retry';

  IconData get _statusIcon =>
      _isMaintenance ? Icons.engineering_rounded : Icons.cloud_off_rounded;

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFF020617),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        duration: const Duration(milliseconds: 2200),
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1.0, 1.0),
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _accent.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, size: 16, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusSub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isMaintenance) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _accent.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    l10n.maintenanceTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      message.isNotEmpty ? message : l10n.maintenanceBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5F1),
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (contact.hasAny) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact support',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (contact.email.isNotEmpty)
                            _ContactRow(
                              icon: Icons.mail_outline_rounded,
                              label: contact.email,
                              onTap: () => _launch(
                                Uri(scheme: 'mailto', path: contact.email),
                              ),
                            ),
                          if (contact.phone.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _ContactRow(
                              icon: Icons.phone_outlined,
                              label: contact.phone,
                              onTap: () {
                                final digits = contact.phone.replaceAll(
                                  RegExp(r'[^\d+]'),
                                  '',
                                );
                                _launch(Uri(scheme: 'tel', path: digits));
                              },
                            ),
                          ],
                          if (contact.contactUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _ContactRow(
                              icon: Icons.language_rounded,
                              label: 'Visit support page',
                              onTap: () =>
                                  _launch(Uri.parse(contact.contactUrl)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.initial,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMaintenance
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.maintenanceRetry.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Text(
                    'RealtorOne',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  if (version.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: 0.5,
                      child: Text(
                        l10n.maintenanceVersionLabel(version),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF818CF8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFCBD5F1),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
