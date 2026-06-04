import 'package:flutter/material.dart';

import 'reven_chat_page.dart';

/// Global Reven chat shell: full panel or minimized bubble while user uses other tabs.
class RevenChatOverlay {
  RevenChatOverlay._();

  static final ValueNotifier<RevenOverlayUiState> ui = ValueNotifier(
    const RevenOverlayUiState.hidden(),
  );

  static bool _pendingStartVoice = false;

  static bool get isVisible => ui.value.visible;
  static bool get isMinimized => ui.value.minimized;

  static bool consumeStartVoice() {
    final v = _pendingStartVoice;
    _pendingStartVoice = false;
    return v;
  }

  static Future<void> show(
    BuildContext context, {
    bool startVoice = false,
  }) {
    _pendingStartVoice = startVoice;
    ui.value = RevenOverlayUiState(
      visible: true,
      minimized: false,
      startVoice: startVoice,
      callStatus: RevenOverlayCallStatus.idle,
    );
    return Future.value();
  }

  static void minimize() {
    final s = ui.value;
    if (!s.visible) return;
    ui.value = s.copyWith(minimized: true);
  }

  static void expand() {
    final s = ui.value;
    if (!s.visible) return;
    ui.value = s.copyWith(minimized: false);
  }

  static void hide() {
    ui.value = const RevenOverlayUiState.hidden();
  }

  static void updateCallStatus(RevenOverlayCallStatus status) {
    final s = ui.value;
    if (!s.visible) return;
    ui.value = s.copyWith(callStatus: status);
  }
}

enum RevenOverlayCallStatus { idle, listening, speaking, processing }

class RevenOverlayUiState {
  const RevenOverlayUiState({
    required this.visible,
    required this.minimized,
    required this.startVoice,
    required this.callStatus,
  });

  const RevenOverlayUiState.hidden()
      : visible = false,
        minimized = false,
        startVoice = false,
        callStatus = RevenOverlayCallStatus.idle;

  final bool visible;
  final bool minimized;
  final bool startVoice;
  final RevenOverlayCallStatus callStatus;

  RevenOverlayUiState copyWith({
    bool? visible,
    bool? minimized,
    bool? startVoice,
    RevenOverlayCallStatus? callStatus,
  }) {
    return RevenOverlayUiState(
      visible: visible ?? this.visible,
      minimized: minimized ?? this.minimized,
      startVoice: startVoice ?? this.startVoice,
      callStatus: callStatus ?? this.callStatus,
    );
  }
}

/// Place once above the nav bar (e.g. in [MainNavigation]).
class RevenChatOverlayHost extends StatelessWidget {
  const RevenChatOverlayHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RevenOverlayUiState>(
      valueListenable: RevenChatOverlay.ui,
      builder: (context, state, _) {
        if (!state.visible) return const SizedBox.shrink();

        return Stack(
          children: [
            if (!state.minimized)
              Positioned.fill(
                child: GestureDetector(
                  onTap: RevenChatOverlay.minimize,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
              ),
            Offstage(
              offstage: state.minimized,
              child: const Align(
                alignment: Alignment.bottomRight,
                child: RevenChatPage(
                  key: ValueKey('reven-chat-panel'),
                  embedded: true,
                ),
              ),
            ),
            if (state.minimized) _MinimizedRevenBubble(state: state),
          ],
        );
      },
    );
  }
}

class _MinimizedRevenBubble extends StatelessWidget {
  const _MinimizedRevenBubble({required this.state});

  final RevenOverlayUiState state;

  Color get _ringColor {
    switch (state.callStatus) {
      case RevenOverlayCallStatus.listening:
        return const Color(0xFF22C55E);
      case RevenOverlayCallStatus.speaking:
        return const Color(0xFF6366F1);
      case RevenOverlayCallStatus.processing:
        return const Color(0xFFF59E0B);
      case RevenOverlayCallStatus.idle:
        return const Color(0xFF4F7CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: RevenChatOverlay.expand,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: _ringColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _ringColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/chat-bot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniChip(
                  icon: Icons.open_in_full_rounded,
                  label: 'Open',
                  onTap: RevenChatOverlay.expand,
                ),
                const SizedBox(width: 6),
                _MiniChip(
                  icon: Icons.close_rounded,
                  label: 'End',
                  onTap: RevenChatOverlay.hide,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A).withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
