import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import 'chatbot_floating_button.dart';
import 'reven_chat_overlay.dart';
import 'reven_route_tracker.dart';

/// Wraps the whole app so Reven floats above any route (tabs, settings, courses, etc.).
class RevenGlobalShell extends StatelessWidget {
  const RevenGlobalShell({super.key, required this.child});

  final Widget? child;

  static bool routeAllowsGlobalFab(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return false;
    }
    const hidden = {
      AppRoutes.initial,
      AppRoutes.onboarding,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.verifyOtp,
      AppRoutes.resetPassword,
      AppRoutes.profileSetup,
      AppRoutes.diagnosis,
      AppRoutes.diagnosisResult,
      AppRoutes.maintenance,
      AppRoutes.updateRequired,
    };
    return !hidden.contains(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final routeName =
        RevenRouteTracker.routeName ?? ModalRoute.of(context)?.settings.name;

    return Stack(
      fit: StackFit.expand,
      children: [
        child ?? const SizedBox.shrink(),
        const RevenChatOverlayHost(),
        if (routeAllowsGlobalFab(routeName)) const RevenGlobalFloatingButton(),
      ],
    );
  }
}

/// Reven launcher on every in-app screen (hidden while chat panel or bubble is open).
class RevenGlobalFloatingButton extends StatelessWidget {
  const RevenGlobalFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RevenOverlayUiState>(
      valueListenable: RevenChatOverlay.ui,
      builder: (context, state, _) {
        if (state.visible) return const SizedBox.shrink();

        final routeName =
            RevenRouteTracker.routeName ?? ModalRoute.of(context)?.settings.name;
        if (!RevenGlobalShell.routeAllowsGlobalFab(routeName)) {
          return const SizedBox.shrink();
        }

        final bottom = MediaQuery.paddingOf(context).bottom;

        // Match original Home placement (above bottom nav).
        final onMainTabs = routeName == AppRoutes.main;
        return Positioned(
          right: 16,
          bottom: onMainTabs ? 140 : bottom + 88,
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Talk to Reven',
              child: ChatbotFloatingButton(
                onOpen: () => RevenChatOverlay.show(context),
                onOpenVoice: () =>
                    RevenChatOverlay.show(context, startVoice: true),
              ),
            ),
          ),
        );
      },
    );
  }
}
