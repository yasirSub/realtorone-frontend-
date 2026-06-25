import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_version_gate_service.dart';
import '../../services/support_contact_service.dart';
import '../../theme/realtorone_brand.dart';

class UpdateRequiredPage extends StatefulWidget {
  const UpdateRequiredPage({
    super.key,
    required this.minVersion,
    required this.maxVersion,
    required this.storeUrl,
    required this.apkUrl,
    required this.platformLabel,
  });

  final String minVersion;
  final String maxVersion;
  final String storeUrl;
  final String apkUrl;
  final String platformLabel;

  @override
  State<UpdateRequiredPage> createState() => _UpdateRequiredPageState();
}

class _UpdateRequiredPageState extends State<UpdateRequiredPage>
    with WidgetsBindingObserver {
  bool _isRetrying = false;
  String? _retryHint;
  late String _minVersion;
  late String _maxVersion;
  SupportContact _contact = SupportContact.defaults;

  @override
  void initState() {
    super.initState();
    _minVersion = widget.minVersion;
    _maxVersion = widget.maxVersion;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadContact());
  }

  Future<void> _loadContact() async {
    final contact = await SupportContactService.loadCached();
    if (!mounted) return;
    setState(() => _contact = contact);
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheckVersion());
    }
  }

  Future<void> _recheckVersion({bool fromManualRetry = false}) async {
    if (_isRetrying) return;
    if (fromManualRetry) {
      setState(() {
        _isRetrying = true;
        _retryHint = null;
      });
    }

    try {
      final result = await AppVersionGate.retryFromUpdateScreen();
      if (!mounted) return;

      switch (result.outcome) {
        case VersionRetryOutcome.unblocked:
          return;
        case VersionRetryOutcome.stillBlocked:
          final latest = result.latest;
          setState(() {
            if (latest != null) {
              _minVersion = latest.minVersion;
              _maxVersion = latest.maxVersion;
            }
            if (fromManualRetry) {
              _retryHint = AppLocalizations.of(context)!.updateStillRequired;
            }
          });
          await _loadContact();
          break;
        case VersionRetryOutcome.configUnavailable:
          if (fromManualRetry) {
            setState(() {
              _retryHint = AppLocalizations.of(context)!.updateRetryFailed;
            });
          }
          break;
      }
    } finally {
      if (mounted && fromManualRetry) {
        setState(() => _isRetrying = false);
      }
    }
  }

  Future<void> _openStore(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _versionRangeLabel({
    required String currentVersion,
    required String minVersion,
    required String maxVersion,
    required AppLocalizations l10n,
  }) {
    final current = currentVersion.isEmpty ? '-' : currentVersion;
    if (minVersion.isNotEmpty && maxVersion.isNotEmpty) {
      return 'Your version: $current · Allowed: $minVersion – $maxVersion';
    }
    if (minVersion.isNotEmpty) {
      return l10n.updateVersionDetails(current, minVersion);
    }
    if (maxVersion.isNotEmpty) {
      return 'Your version: $current · Maximum allowed: $maxVersion';
    }
    return 'Your version: $current';
  }

  static String _storeSubtitle(String platformLabel) {
    if (platformLabel.toLowerCase().contains('ios')) {
      return 'Opens Apple App Store';
    }
    if (platformLabel.toLowerCase().contains('android')) {
      return 'Opens Google Play Store';
    }
    return 'Opens app store';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final currentVersion = snapshot.data?.version ?? '';

          return Scaffold(
            backgroundColor: const Color(0xFF020617),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    _UpdateHeroIcon(),
                    const SizedBox(height: 28),
                    Text(
                      l10n.updateTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.updateBody(widget.platformLabel),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5F5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (currentVersion.isNotEmpty ||
                        _minVersion.isNotEmpty ||
                        _maxVersion.isNotEmpty)
                      Text(
                        _versionRangeLabel(
                          currentVersion: currentVersion,
                          minVersion: _minVersion,
                          maxVersion: _maxVersion,
                          l10n: l10n,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    if (_contact.hasAny) ...[
                      const SizedBox(height: 24),
                      _SupportContactCard(
                        contact: _contact,
                        onLaunch: _launch,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (widget.storeUrl.isNotEmpty)
                            _PrimaryStoreButton(
                              label: l10n.updateButtonLabel,
                              subtitle: _storeSubtitle(widget.platformLabel),
                              onPressed: () => _openStore(widget.storeUrl),
                            ),
                          if (!kIsWeb &&
                              Platform.isAndroid &&
                              widget.apkUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _SecondaryActionButton(
                              icon: Icons.download_rounded,
                              label: 'Download APK (beta)',
                              onPressed: () => _openStore(widget.apkUrl),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _SecondaryActionButton(
                            icon: Icons.refresh_rounded,
                            label: l10n.updateRetryLabel,
                            isLoading: _isRetrying,
                            onPressed: _isRetrying
                                ? null
                                : () => _recheckVersion(fromManualRetry: true),
                          ),
                          if (_retryHint != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _retryHint!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SupportContactCard extends StatelessWidget {
  const _SupportContactCard({
    required this.contact,
    required this.onLaunch,
  });

  final SupportContact contact;
  final Future<void> Function(Uri uri) onLaunch;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              onTap: () => onLaunch(Uri(scheme: 'mailto', path: contact.email)),
            ),
          if (contact.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: contact.phone,
              onTap: () {
                final digits = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
                onLaunch(Uri(scheme: 'tel', path: digits));
              },
            ),
          ],
          if (contact.contactUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.language_rounded,
              label: 'Visit support page',
              onTap: () => onLaunch(Uri.parse(contact.contactUrl)),
            ),
          ],
        ],
      ),
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

class _PrimaryStoreButton extends StatelessWidget {
  const _PrimaryStoreButton({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: RealtorOneBrand.accentTeal.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: RealtorOneBrand.splashGradient,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: enabled ? 0.05 : 0.03),
            border: Border.all(
              color: RealtorOneBrand.seed.withValues(alpha: enabled ? 0.35 : 0.18),
            ),
          ),
          child: Container(
            width: double.infinity,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 20,
                    color: enabled
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white38,
                  ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? Colors.white.withValues(alpha: 0.92)
                        : Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateHeroIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.35),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: RealtorOneBrand.accentTeal.withValues(alpha: 0.22),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RealtorOneBrand.splashGradient,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F172A),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RealtorOneBrand.splashGradient,
                border: Border.all(
                  color: const Color(0xFF020617),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_circle_down_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          duration: const Duration(milliseconds: 2400),
          begin: const Offset(0.97, 0.97),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeInOut,
        );
  }
}
