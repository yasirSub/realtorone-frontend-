import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/app_preferences_service.dart';
import '../../services/app_runtime_config_service.dart';
import '../../theme/realtorone_brand.dart';
import 'chatbot_floating_button.dart';
import 'reven_chat_page.dart';
import 'reven_route_tracker.dart';

/// Global Reven chat shell: floating panel or minimized bubble while user uses the app.
class RevenChatOverlay {
  RevenChatOverlay._();

  static final ValueNotifier<RevenOverlayUiState> ui = ValueNotifier(
    const RevenOverlayUiState.hidden(),
  );

  static bool _pendingStartVoice = false;
  static int? _pendingSessionId;
  static final ValueNotifier<bool> panelExpanded = ValueNotifier(false);

  /// Bumped when the minimized bubble toggles voice on/off (embedded chat listens).
  static final ValueNotifier<int> voiceToggleSignal = ValueNotifier(0);

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

  static int? consumeSessionId() {
    final v = _pendingSessionId;
    _pendingSessionId = null;
    return v;
  }

  static Future<void> show(
    BuildContext context, {
    bool startVoice = false,
    int? sessionId,
    bool startMinimized = false,
  }) {
    if (!AppPreferencesService.chatbotEnabled.value) {
      return Future.value();
    }
    _pendingStartVoice = startVoice;
    _pendingSessionId = sessionId;
    unawaited(AppRuntimeConfigService.refresh(force: true));
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

  /// Restore floating chat panel (not full screen).
  static void expand() {
    final s = ui.value;
    if (!s.visible) return;
    unawaited(AppRuntimeConfigService.refresh(force: true));
    panelExpanded.value = false;
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

  /// Double-tap minimized Reven icon — toggle voice while staying minimized.
  static void toggleVoiceFromMinimizedBubble() {
    if (!isVisible || !isMinimized) return;
    voiceToggleSignal.value++;
  }

  static void updateCallStatus(RevenOverlayCallStatus status) {
    updatePresentation(callStatus: status);
  }

  static void updatePresentation({
    RevenOverlayCallStatus? callStatus,
    String? caption,
    RevenOverlayCaptionRole? captionRole,
  }) {
    final s = ui.value;
    if (!s.visible) return;
    ui.value = s.copyWith(
      callStatus: callStatus,
      caption: caption,
      captionRole: captionRole,
    );
  }
}

enum RevenOverlayCallStatus { idle, listening, speaking, processing }

/// Who the minimized caption represents (drives bubble colors).
enum RevenOverlayCaptionRole { none, user, assistant, thinking }

class RevenOverlayUiState {
  const RevenOverlayUiState({
    required this.visible,
    required this.minimized,
    required this.startVoice,
    required this.callStatus,
    this.caption = '',
    this.captionRole = RevenOverlayCaptionRole.none,
  });

  const RevenOverlayUiState.hidden()
      : visible = false,
        minimized = false,
        startVoice = false,
        callStatus = RevenOverlayCallStatus.idle,
        caption = '',
        captionRole = RevenOverlayCaptionRole.none;

  final bool visible;
  final bool minimized;
  final bool startVoice;
  final RevenOverlayCallStatus callStatus;
  final String caption;
  final RevenOverlayCaptionRole captionRole;

  bool get isVoiceActive =>
      callStatus != RevenOverlayCallStatus.idle ||
      captionRole != RevenOverlayCaptionRole.none;

  RevenOverlayUiState copyWith({
    bool? visible,
    bool? minimized,
    bool? startVoice,
    RevenOverlayCallStatus? callStatus,
    String? caption,
    RevenOverlayCaptionRole? captionRole,
  }) {
    return RevenOverlayUiState(
      visible: visible ?? this.visible,
      minimized: minimized ?? this.minimized,
      startVoice: startVoice ?? this.startVoice,
      callStatus: callStatus ?? this.callStatus,
      caption: caption ?? this.caption,
      captionRole: captionRole ?? this.captionRole,
    );
  }
}

/// Floating chat host — panel layout is handled inside [RevenChatPage].
class RevenChatOverlayHost extends StatelessWidget {
  const RevenChatOverlayHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RevenOverlayUiState>(
      valueListenable: RevenChatOverlay.ui,
      builder: (context, state, _) {
        if (!state.visible) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Keep chat alive while minimized (voice session continues).
            Positioned.fill(
              child: Offstage(
                offstage: state.minimized,
                child: const RevenChatPage(
                  key: ValueKey('reven-chat-panel'),
                  embedded: true,
                ),
              ),
            ),
            if (state.minimized) _StickyRevenLauncher(state: state),
          ],
        );
      },
    );
  }
}

/// Minimized Reven — same spot as [RevenGlobalFloatingButton]; tap to reopen.
class _StickyRevenLauncher extends StatelessWidget {
  const _StickyRevenLauncher({required this.state});

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
    final routeName = RevenRouteTracker.instance.routeName;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final onMainTabs = routeName == AppRoutes.main;
    final caption = state.caption.trim();
    final showCaption = state.captionRole != RevenOverlayCaptionRole.none;
    final showRing = state.isVoiceActive;

    return Positioned(
      right: 16,
      bottom: onMainTabs ? 140 : bottom + 88,
      child: GestureDetector(
        onTap: RevenChatOverlay.expand,
        onDoubleTap: RevenChatOverlay.toggleVoiceFromMinimizedBubble,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showCaption)
              _MinimizedVoiceCaption(
                text: caption,
                role: state.captionRole,
              ),
            Semantics(
              button: true,
              label: showCaption
                  ? caption
                  : 'Open Reven chat. Double-tap to toggle voice.',
              child: Material(
                color: Colors.transparent,
                elevation: showRing ? 10 : 8,
                shadowColor: showRing
                    ? _ringColor.withValues(alpha: 0.45)
                    : Colors.black26,
                shape: const CircleBorder(),
                child: Container(
                  decoration: showRing
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _ringColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _ringColor.withValues(alpha: 0.38),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        )
                      : null,
                  child: const ChatbotFloatingButton(
                    delegateGesturesToParent: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimizedVoiceCaption extends StatefulWidget {
  const _MinimizedVoiceCaption({
    required this.text,
    required this.role,
  });

  final String text;
  final RevenOverlayCaptionRole role;

  @override
  State<_MinimizedVoiceCaption> createState() => _MinimizedVoiceCaptionState();
}

class _MinimizedVoiceCaptionState extends State<_MinimizedVoiceCaption>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.role == RevenOverlayCaptionRole.thinking) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MinimizedVoiceCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.role == RevenOverlayCaptionRole.thinking && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    } else if (widget.role != RevenOverlayCaptionRole.thinking) {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  _CaptionChrome _chrome(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.role) {
      case RevenOverlayCaptionRole.user:
        return _CaptionChrome(
          accent: const Color(0xFF3B82F6),
          label: 'You',
          icon: Icons.mic_none_rounded,
          surface: isDark ? const Color(0xE61E293B) : const Color(0xF5FFFFFF),
          titleColor: isDark ? Colors.white : const Color(0xFF0F172A),
          subtitleColor: isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B),
        );
      case RevenOverlayCaptionRole.assistant:
        return _CaptionChrome(
          accent: RealtorOneBrand.accentIndigo,
          label: 'Reven',
          icon: Icons.auto_awesome_rounded,
          surface: isDark ? const Color(0xE61E293B) : const Color(0xF5FFFFFF),
          titleColor: isDark ? Colors.white : const Color(0xFF0F172A),
          subtitleColor: isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B),
        );
      case RevenOverlayCaptionRole.thinking:
        return _CaptionChrome(
          accent: const Color(0xFFF59E0B),
          label: 'Thinking',
          icon: Icons.psychology_alt_outlined,
          surface: isDark ? const Color(0xE61E293B) : const Color(0xF5FFFFFF),
          titleColor: isDark ? Colors.white : const Color(0xFF0F172A),
          subtitleColor: isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B),
          showPulse: true,
        );
      case RevenOverlayCaptionRole.none:
        return _CaptionChrome(
          accent: const Color(0xFF4F7CFF),
          label: '',
          icon: Icons.chat_bubble_outline_rounded,
          surface: Colors.transparent,
          titleColor: Colors.black,
          subtitleColor: Colors.grey,
        );
    }
  }

  String get _bodyText {
    final raw = widget.text.trim();
    switch (widget.role) {
      case RevenOverlayCaptionRole.user:
        return raw.isEmpty ? 'Listening…' : raw;
      case RevenOverlayCaptionRole.assistant:
        return raw.isEmpty ? 'Speaking…' : raw;
      case RevenOverlayCaptionRole.thinking:
        return raw.isEmpty || raw == 'Thinking…'
            ? 'Working on your answer…'
            : raw;
      case RevenOverlayCaptionRole.none:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == RevenOverlayCaptionRole.none) {
      return const SizedBox.shrink();
    }

    final chrome = _chrome(context);
    final body = _bodyText;
    final showBody = body.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: chrome.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: chrome.accent.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        chrome.accent,
                        chrome.accent.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              chrome.icon,
                              size: 14,
                              color: chrome.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              chrome.label,
                              style: TextStyle(
                                color: chrome.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (chrome.showPulse && _pulse != null) ...[
                              const SizedBox(width: 6),
                              _ThinkingDots(animation: _pulse!),
                            ],
                          ],
                        ),
                        if (showBody) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: chrome.titleColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _CaptionChrome {
  const _CaptionChrome({
    required this.accent,
    required this.label,
    required this.icon,
    required this.surface,
    required this.titleColor,
    required this.subtitleColor,
    this.showPulse = false,
  });

  final Color accent;
  final String label;
  final IconData icon;
  final Color surface;
  final Color titleColor;
  final Color subtitleColor;
  final bool showPulse;
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        Widget dot(double phase) {
          final t = (animation.value + phase) % 1.0;
          final scale = 0.55 + 0.45 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Container(
            width: 5 * scale,
            height: 5 * scale,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot(0), dot(0.33), dot(0.66)],
        );
      },
    );
  }
}
