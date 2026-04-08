import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key, required this.message});

  final String message;

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Animated Illustration or Icon
                  Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6366F1),
                              const Color(0xFF6366F1).withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.settings_suggest_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fade(duration: const Duration(milliseconds: 800))
                      .scale(
                        duration: const Duration(milliseconds: 800),
                        begin: const Offset(0.8, 0.8),
                      )
                      .shimmer(
                        duration: const Duration(seconds: 3),
                        color: Colors.white24,
                      ),
                  const SizedBox(height: 48),
                  const Text(
                    'SYSTEM OPTIMIZATION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.maintenanceTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      message.isNotEmpty ? message : l10n.maintenanceBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5F1),
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.initial,
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(60),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(
                            Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                    child: Text(
                      l10n.maintenanceRetry.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (version.isNotEmpty)
                    Opacity(
                      opacity: 0.6,
                      child: Text(
                        l10n.maintenanceVersionLabel(version),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
