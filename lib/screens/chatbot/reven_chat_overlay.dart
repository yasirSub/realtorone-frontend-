import 'package:flutter/material.dart';

import 'reven_chat_page.dart';

/// Global Reven chat shell: floating panel or minimized bubble while user uses the app.
class RevenChatOverlay {
  RevenChatOverlay._();

  static final ValueNotifier<RevenOverlayUiState> ui = ValueNotifier(
    const RevenOverlayUiState.hidden(),
  );

  static bool _pendingStartVoice = false;
  static final ValueNotifier<bool> panelExpanded = ValueNotifier(false);

  static bool get isVisible => ui.value.visible;
  static bool get isMinimized => ui.value.minimized;

  static void setPanelExpanded(bool expanded) {
    if (panelExpanded.value == expanded) {
      return;
    }
    panelExpanded.value = expanded;
  }

  /// System back while full-screen chat → shrink panel first (chat page listens).
  static bool consumePanelExpandedBack() {
    if (!panelExpanded.value) {
      return false;
    }
    panelExpanded.value = false;
    return true;
  }

  static bool consumeStartVoice() {
    final v = _pendingStartVoice;
    _pendingStartVoice = false;
    return v;
  }

  static Future<void> show(
    BuildContext context, {
    bool startVoice = false,
    bool startMinimized = false,
  }) {
    _pendingStartVoice = startVoice;
    ui.value = RevenOverlayUiState(
      visible: true,
      minimized: startMinimized,
      startVoice: startVoice,
      callStatus: RevenOverlayCallStatus.idle,
    );
    return Future.value();
  }

  static void minimizeIfExpanded() {
    if (isVisible && !isMinimized) {
      minimize();
    }
  }

  static void expand() {
    final s = ui.value;
    if (!s.visible) return;
    ui.value = s.copyWith(minimized: false);
  }

  static void hide() {
    panelExpanded.value = false;
    ui.value = const RevenOverlayUiState.hidden();
  }

  static void minimize() {
    final s = ui.value;
    if (!s.visible) return;
    panelExpanded.value = false;
    ui.value = s.copyWith(minimized: true);
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

/// Floating chat host — no fullscreen scrim; app stays usable underneath.
class RevenChatOverlayHost extends StatefulWidget {
  const RevenChatOverlayHost({super.key});

  @override
  State<RevenChatOverlayHost> createState() => _RevenChatOverlayHostState();
}

class _RevenChatOverlayHostState extends State<RevenChatOverlayHost> {
  Offset? _bubbleDragOffset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RevenOverlayUiState>(
      valueListenable: RevenChatOverlay.ui,
      builder: (context, state, _) {
        if (!state.visible) return const SizedBox.shrink();

        final media = MediaQuery.of(context);
        final bottomInset = media.padding.bottom + 76;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Keep chat alive while minimized (voice session continues).
            Offstage(
              offstage: state.minimized,
              child: Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 8,
                      bottom: bottomInset,
                      top: media.padding.top + 8,
                    ),
                    child: const RevenChatPage(
                      key: ValueKey('reven-chat-panel'),
                      embedded: true,
                    ),
                  ),
                ),
              ),
            ),
            if (state.minimized)
              _DraggableRevenBubble(
                dragOffset: _bubbleDragOffset,
                onMoved: (offset) => setState(() => _bubbleDragOffset = offset),
                state: state,
              ),
          ],
        );
      },
    );
  }
}

class _DraggableRevenBubble extends StatelessWidget {
  const _DraggableRevenBubble({
    required this.state,
    required this.dragOffset,
    required this.onMoved,
  });

  final RevenOverlayUiState state;
  final Offset? dragOffset;
  final ValueChanged<Offset> onMoved;

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
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final defaultPos = Offset(size.width - 80, size.height - padding.bottom - 120);
    final origin = dragOffset ?? defaultPos;
    final clamped = Offset(
      origin.dx.clamp(8.0, size.width - 72),
      origin.dy.clamp(padding.top + 8, size.height - padding.bottom - 100),
    );

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          onMoved(
            Offset(
              (clamped.dx + d.delta.dx).clamp(8.0, size.width - 72),
              (clamped.dy + d.delta.dy).clamp(
                padding.top + 8,
                size.height - padding.bottom - 100,
              ),
            ),
          );
        },
        onTap: RevenChatOverlay.expand,
        child: _bubbleCore(),
      ),
    );
  }

  Widget _bubbleCore({double ringWidth = 3}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: _ringColor, width: ringWidth),
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
