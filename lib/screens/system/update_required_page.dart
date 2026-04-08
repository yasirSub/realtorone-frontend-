import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';

class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({
    super.key,
    required this.minVersion,
    required this.storeUrl,
    required this.platformLabel,
  });

  final String minVersion;
  final String storeUrl;
  final String platformLabel;

  Future<void> _openStore() async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final currentVersion = snapshot.data?.version ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFF020617),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
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
                    l10n.updateBody(platformLabel),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFCBD5F5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (currentVersion.isNotEmpty || minVersion.isNotEmpty)
                    Text(
                      l10n.updateVersionDetails(
                        currentVersion.isEmpty ? '-' : currentVersion,
                        minVersion.isEmpty ? '-' : minVersion,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 32),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _openStore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l10n.updateButtonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.initial,
                          );
                        },
                        child: Text(
                          l10n.updateContinueLabel,
                          style: const TextStyle(
                            color: Color(0xFFCBD5F5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

