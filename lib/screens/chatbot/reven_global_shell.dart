import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/app_preferences_service.dart';
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

  static void handleSystemBack() {
    if (!RevenChatOverlay.isVisible) {
      return;
    }
    if (RevenChatOverlay.consumePanelExpandedBack()) {
      return;
    }
    if (!RevenChatOverlay.isMinimized) {
      RevenChatOverlay.minimize();
    }
  }

  static bool get canSystemPop {
    if (!RevenChatOverlay.isVisible) {
      return true;
    }
    if (RevenChatOverlay.isMinimized) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        RevenRouteTracker.instance,
        RevenChatOverlay.ui,
        AppPreferencesService.chatbotEnabled,
      ]),
      builder: (context, _) {
        final routeName = RevenRouteTracker.instance.routeName;
        final chatbotOn = AppPreferencesService.chatbotEnabled.value;

        return PopScope(
          canPop: canSystemPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            handleSystemBack();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              if (chatbotOn) const RevenChatOverlayHost(),
              if (chatbotOn &&
                  routeAllowsGlobalFab(routeName) &&
                  !RevenChatOverlay.isVisible)
                const RevenGlobalFloatingButton(),
            ],
          ),
        );
      },
    );
  }
}

/// Reven launcher on in-app screens (hidden while chat panel or bubble is open).
class RevenGlobalFloatingButton extends StatelessWidget {
  const RevenGlobalFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    final routeName = RevenRouteTracker.instance.routeName;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final onMainTabs = routeName == AppRoutes.main;

    return Positioned(
      right: 16,
      bottom: onMainTabs ? 140 : bottom + 88,
      child: Semantics(
        button: true,
        label: 'Talk to Reven. Double-tap for voice.',
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: const CircleBorder(),
          child: ChatbotFloatingButton(
            onOpen: () => RevenChatOverlay.show(context),
            onOpenVoice: () =>
                RevenChatOverlay.show(context, startVoice: true),
          ),
        ),
      ),
    );
  }
}
