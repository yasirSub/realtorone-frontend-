import 'dart:async';
import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../api/api_client.dart';
import '../../theme/realtorone_brand.dart';
import '../../api/api_endpoints.dart';
import '../../api/chat_api.dart';
import '../../api/user_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/realtor_one_dialog_scaffold.dart';
import 'data/reven_quick_prompts.dart';
import 'reven_chat_overlay.dart';

// ignore_for_file: unused_element

enum _RevenInteractionMode { text, voice }

enum _VoiceCallStatus { idle, listening, processing, speaking }

class RevenChatPage extends StatefulWidget {
  const RevenChatPage({
    super.key,
    this.embedded = false,
    this.startVoiceOnOpen = false,
  });

  /// When true, chat is hosted by [RevenChatOverlay] (minimize / multitask).
  final bool embedded;
  final bool startVoiceOnOpen;

  /// Opens Reven overlay. [startVoice] enters voice mode and starts the mic.
  static Future<void> show(
    BuildContext context, {
    bool startVoice = false,
  }) {
    return RevenChatOverlay.show(context, startVoice: startVoice);
  }

  @override
  State<RevenChatPage> createState() => _RevenChatPageState();
}

class _RevenChatPageState extends State<RevenChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;
  bool _isLoading = false;
  Timer? _waitElapsedTimer;
  bool _humanHandoffActive = false;
  bool _voiceInAiChatEnabled = true;
  bool _voiceAutoSend = true;
  bool _voiceReadAloud = true;
  bool _voiceCloudEnabled = true;
  Map<String, bool> _voiceCloudTierAllow = const {
    'Consultant': false,
    'Rainmaker': true,
    'Titan': true,
  };
  String _membershipTier = 'Consultant';
  bool _preferAiVoiceOnly = false;
  bool _voiceAllowUserPick = true;
  String _defaultVoiceId = 'nova';
  String? _preferredVoiceId;
  List<Map<String, String>> _voiceOptions = const [
    {'id': 'nova', 'label': 'Nova'},
  ];
  bool _speechInitialized = false;
  bool _ttsReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _lastTurnWasVoice = false;
  _RevenInteractionMode _interactionMode = _RevenInteractionMode.text;
  String _voiceModelLabel = 'MAI-Voice-2';
  String _voiceSpeakerFamily = 'Speakers';
  int? _sessionId;
  List<Map<String, dynamic>> _sessions = [];

  final List<_RevenMessage> _messages = [];
  Timer? _handoffPollTimer;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  static const _prefVoiceKey = 'reven_preferred_voice_id';
  String _voiceTranscript = '';
  String _lastVoiceCaption = '';
  /// Shown on the voice orb while cloud audio loads (text not in transcript yet).
  String _pendingAssistantReply = '';
  /// User tapped mic to mute; blocks hands-free auto re-listen until they tap again.
  bool _voiceMicPausedByUser = false;
  bool _wasExpandedBeforeVoice = false;
  Timer? _voiceUtteranceTimer;
  Timer? _voiceSilenceFinalizeTimer;
  late final AnimationController _micPulseController;
  /// Mic dB level from speech_to_text; orb/mic glow when above [_voiceSoundActiveDb].
  double _voiceSoundLevel = 0;
  bool _voiceUserSpeaking = false;
  static const double _voiceSoundActiveDb = -40;
  /// How long after mic goes quiet before we send (voice hands-free).
  static const Duration _voiceSilenceSendDelay =
      Duration(milliseconds: 450);
  bool _voiceFinalizeInProgress = false;

  _VoiceCallStatus get _voiceCallStatus {
    if (_isListening && _voiceUserSpeaking) {
      return _VoiceCallStatus.listening;
    }
    if (_isListening && _isVoiceInteractionMode) {
      return _VoiceCallStatus.idle;
    }
    if (_isListening) return _VoiceCallStatus.listening;
    if (_isSpeaking) return _VoiceCallStatus.speaking;
    if (_isLoading && _isVoiceInteractionMode) {
      return _VoiceCallStatus.processing;
    }
    return _VoiceCallStatus.idle;
  }

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadVoiceSettings();
    _loadMembershipTier();
    _loadPreferredVoice();
    _initSpeech();
    _initTts();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartVoiceOnOpen());
  }

  Future<void> _maybeStartVoiceOnOpen() async {
    final shouldStart =
        widget.startVoiceOnOpen || RevenChatOverlay.consumeStartVoice();
    if (!shouldStart || !_voiceInAiChatEnabled || _humanHandoffActive) return;
    await _enterVoiceMode();
    if (mounted) await _startVoiceInput();
  }

  void _syncOverlayCallStatus() {
    if (!widget.embedded) return;
    RevenOverlayCallStatus mapped;
    switch (_voiceCallStatus) {
      case _VoiceCallStatus.listening:
        mapped = RevenOverlayCallStatus.listening;
        break;
      case _VoiceCallStatus.speaking:
        mapped = RevenOverlayCallStatus.speaking;
        break;
      case _VoiceCallStatus.processing:
        mapped = RevenOverlayCallStatus.processing;
        break;
      case _VoiceCallStatus.idle:
        mapped = RevenOverlayCallStatus.idle;
        break;
    }
    RevenChatOverlay.updateCallStatus(mapped);
  }

  void _closeChat() {
    if (widget.embedded) {
      RevenChatOverlay.hide();
      return;
    }
    Navigator.of(context).pop();
  }

  void _minimizeChat() {
    if (widget.embedded) {
      RevenChatOverlay.minimize();
      return;
    }
    Navigator.of(context).pop();
  }

  void _syncHandoffPolling() {
    _handoffPollTimer?.cancel();
    if (!_humanHandoffActive || _sessionId == null) return;
    _handoffPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollHistoryForHumanReplies(),
    );
  }

  Future<void> _pollHistoryForHumanReplies() async {
    final sid = _sessionId;
    if (sid == null || !_humanHandoffActive || !mounted) return;
    try {
      final res = await ChatApi.getHistory(sid);
      if (res['success'] != true || res['messages'] is! List) return;
      final msgs = res['messages'] as List;
      final parsed = <_RevenMessage>[];
      for (final m in msgs) {
        if (m is Map<String, dynamic>) {
          parsed.add(_messageFromApiRow(m));
        }
      }
      if (!mounted) return;
      final hadNew = parsed.length > _messages.length ||
          (parsed.isNotEmpty &&
              _messages.isNotEmpty &&
              parsed.last.text != _messages.last.text);
      setState(() {
        _humanHandoffActive = res['human_handoff_active'] == true;
        _messages
          ..clear()
          ..addAll(parsed);
      });
      if (hadNew) _scrollToBottom();
      if (!_humanHandoffActive) {
        _handoffPollTimer?.cancel();
      }
    } catch (_) {}
  }

  static bool _configFlag(dynamic v, {bool defaultValue = true}) {
    if (v == null) return defaultValue;
    if (v == false || v == 0) return false;
    return v.toString().toLowerCase() != 'false';
  }

  Future<void> _loadPreferredVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefVoiceKey)?.trim();
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _preferredVoiceId = saved);
      }
    } catch (_) {}
  }

  Future<void> _savePreferredVoice(String voiceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefVoiceKey, voiceId);
    } catch (_) {}
  }

  Future<void> _loadVoiceSettings() async {
    try {
      final res = await ApiClient.getPublic('/app-config');
      final data = (res['data'] as Map?) ?? <String, dynamic>{};
      if (!mounted) return;
      final optsRaw = data['voice_options'];
      final opts = <Map<String, String>>[];
      if (optsRaw is List) {
        for (final item in optsRaw) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              opts.add({
                'id': id,
                'label': item['label']?.toString() ?? id,
                'hint': item['hint']?.toString() ?? '',
              });
            }
          }
        }
      }
      setState(() {
        _voiceInAiChatEnabled = _configFlag(data['voice_in_ai_chat']);
        _voiceAutoSend = _configFlag(data['voice_auto_send']);
        _voiceReadAloud = _configFlag(data['voice_read_aloud']);
        final cloudFlag = data['voice_cloud_enabled'];
        _voiceCloudEnabled = cloudFlag == null
            ? true
            : _configFlag(cloudFlag, defaultValue: true);
        final tierRaw = data['voice_cloud_tier_allow'];
        if (tierRaw is Map) {
          _voiceCloudTierAllow = {
            'Consultant': _configFlag(tierRaw['Consultant'], defaultValue: false),
            'Rainmaker': _configFlag(tierRaw['Rainmaker'], defaultValue: true),
            'Titan': _configFlag(tierRaw['Titan'], defaultValue: true),
          };
        }
        _preferAiVoiceOnly = _effectiveVoiceCloudEnabled;
        _voiceAllowUserPick = _configFlag(data['voice_allow_user_pick']);
        _defaultVoiceId = data['voice_id']?.toString() ?? 'nova';
        if (opts.isNotEmpty) _voiceOptions = opts;
        _voiceModelLabel = data['voice_model_label']?.toString() ?? 'Voice AI';
        _voiceSpeakerFamily =
            data['voice_speaker_family']?.toString() ?? 'Speakers';
      });
    } catch (_) {}
  }

  Future<void> _enterVoiceMode() async {
    if (!_voiceInAiChatEnabled || _humanHandoffActive) return;
    if (_isVoiceInteractionMode) return;
    await _stopTts();
    if (!mounted) return;
    setState(() {
      _wasExpandedBeforeVoice = _isExpanded;
      _isExpanded = true; // full-screen call experience
      _interactionMode = _RevenInteractionMode.voice;
      _voiceMicPausedByUser = false;
    });
    await _loadVoiceSettings();
  }

  Future<void> _exitVoiceMode() async {
    if (!_isVoiceInteractionMode) return;
    await _cancelVoiceInput();
    await _stopTts();
    if (!mounted) return;
    setState(() {
      _interactionMode = _RevenInteractionMode.text;
      _isExpanded = _wasExpandedBeforeVoice;
      _lastVoiceCaption = '';
      _voiceTranscript = '';
      _voiceMicPausedByUser = false;
    });
  }

  Future<void> _scheduleVoiceListenAfterReply() async {
    if (!_isVoiceInteractionMode ||
        _humanHandoffActive ||
        !_voiceInAiChatEnabled ||
        _voiceMicPausedByUser) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted ||
        !_isVoiceInteractionMode ||
        _isListening ||
        _isSpeaking ||
        _isLoading) {
      return;
    }
    await _startVoiceInput();
  }

  bool get _isVoiceInteractionMode =>
      _interactionMode == _RevenInteractionMode.voice;

  String? get _activeVoiceIdForApi {
    final id = _voiceAllowUserPick
        ? (_preferredVoiceId?.trim().isNotEmpty == true
            ? _preferredVoiceId!.trim()
            : _defaultVoiceId)
        : _defaultVoiceId;
    if (_voiceOptions.any((v) => _voiceIdsEqual(v['id'] ?? '', id))) {
      for (final v in _voiceOptions) {
        if (_voiceIdsEqual(v['id'] ?? '', id)) return v['id'];
      }
    }
    return _defaultVoiceId.isNotEmpty ? _defaultVoiceId : null;
  }

  String get _normalizedMembershipTier {
    final raw = _membershipTier.trim();
    if (raw.isEmpty) return 'Consultant';
    for (final key in _voiceCloudTierAllow.keys) {
      if (key.toLowerCase() == raw.toLowerCase()) return key;
    }
    return raw;
  }

  bool get _effectiveVoiceCloudEnabled {
    if (!_voiceCloudEnabled) return false;
    return _voiceCloudTierAllow[_normalizedMembershipTier] == true;
  }

  String get _voicePlaybackLabel {
    if (!_effectiveVoiceCloudEnabled) {
      return 'Device voice (cloud off)';
    }
    return '$_voiceSpeakerFamily · $_voiceModelLabel';
  }

  bool _voiceIdsEqual(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Future<void> _loadMembershipTier() async {
    try {
      final res = await UserApi.getProfile(useCache: true);
      final tier = res['membership_tier']?.toString().trim();
      if (!mounted || tier == null || tier.isEmpty) return;
      setState(() => _membershipTier = tier);
      await _loadVoiceSettings();
    } catch (_) {}
  }

  String get _activeVoiceLabel {
    final id = _activeVoiceIdForApi ?? _defaultVoiceId;
    for (final v in _voiceOptions) {
      if (_voiceIdsEqual(v['id'] ?? '', id)) return v['label'] ?? id;
    }
    return id;
  }

  Future<void> _showVoicePicker() async {
    if (!_voiceAllowUserPick || !_effectiveVoiceCloudEnabled) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI voice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_voiceSpeakerFamily — pick a speaker for cloud voice.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ..._voiceOptions.map((v) {
                  final id = v['id'] ?? '';
                  final active = _activeVoiceIdForApi ?? _defaultVoiceId;
                  final selected = _voiceIdsEqual(active, id);
                  final hint = v['hint']?.trim() ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(
                      v['label'] ?? id,
                      style: TextStyle(
                        color: selected ? const Color(0xFF4F7CFF) : Colors.white,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    subtitle: hint.isNotEmpty
                        ? Text(
                            hint,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: Color(0xFF4F7CFF))
                        : null,
                    onTap: () => Navigator.pop(ctx, id),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _preferredVoiceId = picked);
    await _savePreferredVoice(picked);
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
        if (_isVoiceInteractionMode) {
          unawaited(_scheduleVoiceListenAfterReply());
        }
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {}
  }

  Future<void> _stopTts() async {
    try {
      await _cloudPlayer.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isSpeaking = false);
  }

  bool _bytesLookLikeMp3(List<int> bytes) {
    if (bytes.length < 3) return false;
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return true;
    return false;
  }

  bool _bytesLookLikeWav(List<int> bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
  }

  Future<bool> _speakCloudAudio(String base64, String mime) async {
    final bytes = base64Decode(base64);
    if (bytes.isEmpty) return false;
    await _cloudPlayer.stop();
    if (!mounted) return false;
    setState(() => _isSpeaking = true);

    String playMime = mime;
    if (_bytesLookLikeMp3(bytes)) {
      playMime = 'audio/mpeg';
    } else if (_bytesLookLikeWav(bytes) || mime.contains('wav')) {
      playMime = 'audio/wav';
    } else if (!mime.contains('mpeg') && !mime.contains('mp3')) {
      playMime = 'audio/mpeg';
    }

    try {
      await _cloudPlayer.play(BytesSource(bytes, mimeType: playMime));
      await _cloudPlayer.onPlayerComplete.first;
      return true;
    } catch (_) {
      if (playMime != 'audio/mpeg') {
        try {
          await _cloudPlayer.play(
            BytesSource(bytes, mimeType: 'audio/mpeg'),
          );
          await _cloudPlayer.onPlayerComplete.first;
          return true;
        } catch (_) {}
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<bool> _speakDeviceTts(String text) async {
    final spoken = text.trim();
    if (spoken.isEmpty || !_ttsReady) return false;
    await _stopTts();
    if (!mounted) return false;
    setState(() => _isSpeaking = true);
    try {
      await _tts.speak(spoken);
      return true;
    } catch (_) {
      if (mounted) setState(() => _isSpeaking = false);
      return false;
    }
  }

  Future<void> _speakReply(String text, {Map<String, dynamic>? apiRes}) async {
    if (!_voiceReadAloud || _humanHandoffActive) return;

    // Cloud AI voice disabled → built-in phone TTS only (no OpenRouter audio).
    if (!_effectiveVoiceCloudEnabled) {
      final spoke = await _speakDeviceTts(text);
      if (spoke && _isVoiceInteractionMode) {
        await _scheduleVoiceListenAfterReply();
      }
      return;
    }

    Map<String, dynamic>? voiceRes = apiRes;
    var audioB64 = apiRes?['reply_audio_base64']?.toString() ?? '';

    // Fallback TTS if /chat did not return inline audio.
    if (audioB64.isEmpty) {
      if (mounted) setState(() => _isSpeaking = true);
      voiceRes = await ChatApi.synthesizeVoice(
        text,
        voiceId: _activeVoiceIdForApi,
      );
      if (!mounted) return;
      if (voiceRes['success'] == true &&
          voiceRes['reply_audio_engine']?.toString() == 'device') {
        final spoke = await _speakDeviceTts(text);
        if (spoke && _isVoiceInteractionMode) {
          await _scheduleVoiceListenAfterReply();
        } else if (mounted) {
          setState(() => _isSpeaking = false);
        }
        return;
      }
      audioB64 = voiceRes['reply_audio_base64']?.toString() ?? '';
      if (audioB64.isEmpty && voiceRes['success'] != true) {
        final err = voiceRes['message']?.toString().trim() ?? '';
        final spoke = await _speakDeviceTts(text);
        if (mounted) setState(() => _isSpeaking = false);
        if (spoke) {
          if (err.isNotEmpty) {
            _showVoiceSnack('$err — using device voice.');
          }
          if (_isVoiceInteractionMode) {
            await _scheduleVoiceListenAfterReply();
          }
          return;
        }
        if (mounted) setState(() => _isSpeaking = false);
      }
    }

    final audioMime =
        voiceRes?['reply_audio_mime']?.toString() ?? 'audio/mpeg';
    final engine = voiceRes?['reply_audio_engine']?.toString() ?? '';

    if (audioB64.isNotEmpty) {
      await _stopTts();
      final spoke = await _speakCloudAudio(audioB64, audioMime);
      if (spoke) {
        if (_isVoiceInteractionMode) {
          await _scheduleVoiceListenAfterReply();
        }
        return;
      }
      _showVoiceSnack(
        'Could not play cloud voice ($_voiceSpeakerFamily). Pick a matching speaker in your profile or admin.',
      );
      if (_isVoiceInteractionMode) {
        await _scheduleVoiceListenAfterReply();
      }
      return;
    }

    if (engine == 'failed' || _preferAiVoiceOnly) {
      final err = voiceRes?['reply_audio_error']?.toString() ??
          voiceRes?['message']?.toString();
      _showVoiceSnack(
        err != null && err.isNotEmpty
            ? err
            : 'Cloud voice ($_voiceModelLabel) unavailable. Enable cloud voice in admin and choose a speaker for this model.',
      );
      if (_isVoiceInteractionMode) {
        await _scheduleVoiceListenAfterReply();
      }
    } else if (_isVoiceInteractionMode && audioB64.isEmpty) {
      if (mounted) setState(() => _isSpeaking = false);
      final err = voiceRes?['message']?.toString().trim() ?? '';
      final spoke = await _speakDeviceTts(text);
      if (spoke) {
        if (err.isNotEmpty) {
          _showVoiceSnack('$err — using device voice.');
        }
        await _scheduleVoiceListenAfterReply();
      } else if (err.isNotEmpty) {
        _showVoiceSnack(err);
        await _scheduleVoiceListenAfterReply();
      }
    }
  }

  void _showVoiceSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String get _voiceSpeakingCaption {
    if (!_isSpeaking) return '';
    if (_pendingAssistantReply.trim().isNotEmpty) {
      return _pendingAssistantReply.trim();
    }
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (!m.isUser && !m.isLoading && m.text.trim().isNotEmpty) {
        return m.text.trim();
      }
    }
    return '';
  }

  void _scheduleVoiceUtteranceFinalize() {
    if (_isVoiceInteractionMode && _voiceUserSpeaking) return;
    _voiceUtteranceTimer?.cancel();
    final delay = _isVoiceInteractionMode
        ? const Duration(milliseconds: 2200)
        : const Duration(milliseconds: 1400);
    _voiceUtteranceTimer = Timer(delay, () {
      if (!_isListening) return;
      if (_voiceTranscript.trim().isNotEmpty) {
        unawaited(_finishVoiceSession());
      }
    });
  }

  void _onVoiceSoundLevel(double level) {
    if (!_isListening || !mounted) return;

    final speaking = level > _voiceSoundActiveDb;
    final changedSpeaking = speaking != _voiceUserSpeaking;

    if (changedSpeaking || (speaking && (_voiceSoundLevel - level).abs() > 2)) {
      setState(() {
        _voiceSoundLevel = level;
        _voiceUserSpeaking = speaking;
      });
      _syncOverlayCallStatus();
      if (speaking) {
        if (!_micPulseController.isAnimating) {
          _micPulseController.repeat(reverse: true);
        }
      } else {
        _micPulseController.stop();
      }
    }

    _voiceSilenceFinalizeTimer?.cancel();
    if (speaking) {
      _voiceUtteranceTimer?.cancel();
      _voiceSilenceFinalizeTimer?.cancel();
      if (_isVoiceInteractionMode) {
        try {
          _speech.changePauseFor(const Duration(seconds: 2));
        } catch (_) {}
      }
      return;
    }

    if (!_isVoiceInteractionMode) return;

    final hasText = _voiceTranscript.trim().isNotEmpty;
    if (hasText) {
      _voiceSilenceFinalizeTimer = Timer(_voiceSilenceSendDelay, () {
        if (!mounted || !_isListening || _voiceUserSpeaking) return;
        unawaited(_finishVoiceSession());
      });
    }
  }

  void _resetVoiceSoundActivity() {
    _voiceSilenceFinalizeTimer?.cancel();
    _voiceSoundLevel = 0;
    _voiceUserSpeaking = false;
  }

  Future<void> _restartVoiceListenIfNeeded() async {
    if (!_isVoiceInteractionMode ||
        _humanHandoffActive ||
        !_voiceInAiChatEnabled ||
        _voiceMicPausedByUser ||
        _isListening ||
        _isSpeaking ||
        _isLoading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _startVoiceInput();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (status != 'done' && status != 'notListening') return;
          if (!_isListening) return;
          if (_isVoiceInteractionMode) {
            if (_voiceTranscript.trim().isEmpty) {
              unawaited(_restartVoiceListenIfNeeded());
            } else {
              unawaited(_finishVoiceSession());
            }
            return;
          }
          unawaited(_finishVoiceSession());
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _micPulseController.stop();
          if (_isVoiceInteractionMode) {
            unawaited(_restartVoiceListenIfNeeded());
          }
        },
      );
      if (mounted) setState(() => _speechInitialized = ok);
    } catch (_) {}
  }

  Future<void> _toggleVoiceInput() async {
    if (!_voiceInAiChatEnabled || _humanHandoffActive) return;
    if (_isLoading && _isVoiceInteractionMode && !_isSpeaking) return;
    if (!_isVoiceInteractionMode) {
      await _enterVoiceMode();
      if (!mounted) return;
      await _startVoiceInput();
      return;
    }
    if (_isListening) {
      await _pauseVoiceInput();
      return;
    }
    _voiceMicPausedByUser = false;
    await _stopTts();
    await _startVoiceInput();
  }

  /// Mic tap while listening: stop mic without sending (tap again to resume).
  Future<void> _pauseVoiceInput() async {
    _voiceUtteranceTimer?.cancel();
    _resetVoiceSoundActivity();
    if (_isListening) {
      await _speech.stop();
    } else {
      await _speech.cancel();
    }
    _micPulseController.stop();
    final partial = _voiceTranscript.trim();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _voiceMicPausedByUser = true;
      _voiceTranscript = '';
      if (partial.isNotEmpty) _lastVoiceCaption = partial;
    });
  }

  Future<void> _cancelVoiceInput() async {
    if (!_isListening) return;
    _resetVoiceSoundActivity();
    await _speech.cancel();
    _voiceTranscript = '';
    if (!mounted) return;
    setState(() => _isListening = false);
    _micPulseController.stop();
  }

  Future<void> _startVoiceInput() async {
    if (_isListening || !_voiceInAiChatEnabled || _isLoading) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input.'),
        ),
      );
      return;
    }

    if (!_speechInitialized) {
      await _initSpeech();
      if (!_speechInitialized) return;
    }

    _voiceTranscript = '';
    if (mounted) {
      setState(() {
        _lastVoiceCaption = '';
      });
    }

    final locales = await _speech.locales();
    final localeId = locales.isNotEmpty ? locales.first.localeId : null;

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _voiceMicPausedByUser = false;
      _voiceUserSpeaking = false;
      _voiceSoundLevel = 0;
    });
    _micPulseController.stop();
    _syncOverlayCallStatus();

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          setState(() => _voiceTranscript = words);
        }
        if (_isVoiceInteractionMode) {
          if (result.finalResult && words.isNotEmpty) {
            _voiceSilenceFinalizeTimer?.cancel();
            _voiceUtteranceTimer?.cancel();
            unawaited(_finishVoiceSession());
          }
          return;
        }
        if (words.isNotEmpty || result.finalResult) {
          _scheduleVoiceUtteranceFinalize();
        }
      },
      onSoundLevelChange: _onVoiceSoundLevel,
      localeId: localeId,
      listenMode: _isVoiceInteractionMode
          ? stt.ListenMode.dictation
          : stt.ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
      pauseFor: Duration(seconds: _isVoiceInteractionMode ? 2 : 2),
      listenFor: Duration(seconds: _isVoiceInteractionMode ? 300 : 45),
    );
  }

  Future<void> _finishVoiceSession() async {
    if (!_isListening || _voiceFinalizeInProgress) return;
    _voiceFinalizeInProgress = true;
    _voiceUtteranceTimer?.cancel();
    _voiceSilenceFinalizeTimer?.cancel();
    _resetVoiceSoundActivity();
    try {
      await _speech.stop();
      _micPulseController.stop();
      final text = _voiceTranscript.trim();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _voiceTranscript = '';
        if (text.isNotEmpty) _lastVoiceCaption = text;
      });
      if (text.isEmpty) {
        if (!_voiceMicPausedByUser) {
          await _restartVoiceListenIfNeeded();
        }
        return;
      }
      if (_voiceAutoSend) {
        await _sendToApi(text, fromVoice: true);
      } else {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    } finally {
      _voiceFinalizeInProgress = false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    try {
      final res = await ChatApi.listSessions();
      if (res['success'] == true && res['sessions'] is List) {
        final list = (res['sessions'] as List)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (mounted) setState(() => _sessions = list);
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadHistory() async {
    final sessions = await _fetchSessions();
    try {
      if (sessions.isNotEmpty) {
        final first = sessions.first;
        final rawId = first['id'];
        final sid = rawId is int ? rawId : int.tryParse(rawId.toString());
        if (sid != null) {
          final historyRes = await ChatApi.getHistory(sid);
          if (historyRes['success'] == true && historyRes['messages'] is List) {
            final msgs = historyRes['messages'] as List;
            if (!mounted) return;
            setState(() {
              _sessionId = sid;
              _humanHandoffActive = historyRes['human_handoff_active'] == true;
              _messages.clear();
              for (final m in msgs) {
                if (m is Map<String, dynamic>) {
                  _messages.add(_messageFromApiRow(m));
                }
              }
            });
            _syncHandoffPolling();
            _scrollToBottom();
            return;
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(
          const _RevenMessage(
            text:
                'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _startNewChat() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(
        const _RevenMessage(
          text:
              'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
          isUser: false,
        ),
      );
    });
    Navigator.of(context).pop();
    _scrollToBottom();
  }

  Future<void> _deleteSession(int sid) async {
    final confirm = await RealtorOneDialogScaffold.show<bool>(
      context: context,
      semanticsLabel: 'Confirm delete chat',
      builder: (d) {
        final isDark = Theme.of(d).brightness == Brightness.dark;
        return RealtorOneDialogScaffold(
          title: 'Delete chat?',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
          child: Text(
            'This chat will be permanently deleted. You can\'t undo this.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        );
      },
    );
    if (confirm != true || !mounted) return;
    try {
      final res = await ChatApi.deleteSession(sid);
      if (res['success'] == true && mounted) {
        final wasCurrent = _sessionId == sid;
        if (wasCurrent) {
          Navigator.of(context).pop();
          setState(() {
            _sessionId = null;
            _messages.clear();
            _messages.add(
              const _RevenMessage(
                text:
                    'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
                isUser: false,
              ),
            );
          });
        } else {
          await _fetchSessions();
        }
      }
    } catch (_) {}
  }

  Future<void> _switchToSession(int sid) async {
    Navigator.of(context).pop();
    try {
      final res = await ChatApi.getHistory(sid);
      if (res['success'] == true && res['messages'] is List && mounted) {
        final msgs = res['messages'] as List;
        setState(() {
          _sessionId = sid;
          _humanHandoffActive = res['human_handoff_active'] == true;
          _messages.clear();
          for (final m in msgs) {
            if (m is Map<String, dynamic>) {
              _messages.add(_messageFromApiRow(m));
            }
          }
        });
        _syncHandoffPolling();
        _scrollToBottom();
      }
    } catch (_) {}
  }

  _RevenMessage _messageFromApiRow(Map<String, dynamic> m) {
    final role = (m['role'] as String?) ?? 'assistant';
    final content = (m['content'] as String?) ?? '';
    final parsed = _parseMessageContent(content);
    final createdAt = _parseDateTime(m['created_at']);
    return _RevenMessage(
      text: parsed.$1,
      isUser: role == 'user',
      isHuman: role == 'human',
      courses: parsed.$2,
      commands: parsed.$3,
      clients: parsed.$4,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  void _showChatList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subtitleColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Chat history',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _startNewChat,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: const Color(0xFF4F7CFF),
                      ),
                      label: Text(
                        'New chat',
                        style: TextStyle(
                          color: const Color(0xFF4F7CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: subtitleColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No past chats yet',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sessions.length,
                        itemBuilder: (_, i) {
                          final s = _sessions[i];
                          final rawId = s['id'];
                          final sid = rawId is int
                              ? rawId
                              : int.tryParse(rawId.toString());
                          final title =
                              (s['title'] as String?)?.trim().isNotEmpty == true
                              ? (s['title'] as String)
                              : 'Chat ${i + 1}';
                          final updated = s['updated_at'] ?? s['created_at'];
                          final dateStr = updated != null
                              ? _formatDate(updated.toString())
                              : '';
                          final isActive = _sessionId == sid;

                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(
                                        0xFF4F7CFF,
                                      ).withValues(alpha: 0.15)
                                    : borderColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.chat_bubble_rounded,
                                color: isActive
                                    ? const Color(0xFF4F7CFF)
                                    : subtitleColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 15,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: dateStr.isNotEmpty
                                ? Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: subtitleColor,
                                size: 20,
                              ),
                              onPressed: sid != null
                                  ? () => _deleteSession(sid)
                                  : null,
                            ),
                            onTap: sid != null
                                ? () => _switchToSession(sid)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) async {
      await _fetchSessions();
    });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _startWaitElapsedTicker() {
    _waitElapsedTimer?.cancel();
    _waitElapsedTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      if (_isLoading) {
        setState(() {});
      } else {
        _waitElapsedTimer?.cancel();
      }
    });
  }

  void _stopWaitElapsedTicker() {
    _waitElapsedTimer?.cancel();
    _waitElapsedTimer = null;
  }

  @override
  void dispose() {
    _stopWaitElapsedTicker();
    _voiceUtteranceTimer?.cancel();
    _voiceSilenceFinalizeTimer?.cancel();
    if (widget.embedded) {
      RevenChatOverlay.updateCallStatus(RevenOverlayCallStatus.idle);
    }
    _handoffPollTimer?.cancel();
    _micPulseController.dispose();
    if (_isListening) {
      _speech.stop();
    }
    _speech.cancel();
    _tts.stop();
    _cloudPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static (
    String,
    List<Map<String, dynamic>>?,
    List<Map<String, dynamic>>?,
    List<Map<String, dynamic>>?,
  )
  _parseMessageContent(String content) {
    if (content.isEmpty) return ('', null, null, null);

    String text = content;
    List<Map<String, dynamic>>? courses;
    List<Map<String, dynamic>>? commands;
    List<Map<String, dynamic>>? clients;

    if (content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>?;
        if (decoded != null) {
          text = decoded['text'] as String? ?? '';
          final c = decoded['courses'];
          if (c is List && c.isNotEmpty) {
            courses = c
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
          final cmd = decoded['commands'];
          if (cmd is List && cmd.isNotEmpty) {
            commands = cmd
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
          final cl = decoded['clients'];
          if (cl is List && cl.isNotEmpty) {
            clients = cl
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
        }
      } catch (_) {}
    }

    // --- NEW: Parse bracketed commands from text [View X] ---
    final List<Map<String, dynamic>> extracted = commands ?? [];
    // More inclusive regex to capture common navigation requests
    final reg = RegExp(
      r'\[View\s+(Dashboard|Profile|Tasks|Learning|Courses|Deal Room|Active Clients|Clients|Home|Settings)\]',
      caseSensitive: false,
    );
    final matches = reg.allMatches(text).toList();

    if (matches.isNotEmpty) {
      for (final m in matches) {
        final fullMatch = m.group(0)!;
        final target = m.group(1)!.toLowerCase();

        // Prevent duplicates
        if (!extracted.any((e) => e['label'] == fullMatch)) {
          extracted.add({
            'label': fullMatch,
            'keyword': fullMatch,
            'target': target.replaceAll(' ', '-'),
          });
        }
      }
      commands = extracted;
    }

    return (text, courses, commands, clients);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendToApi(String text, {bool fromVoice = false}) async {
    if (_isLoading) return;
    await _stopTts();
    if (fromVoice) {
      _lastTurnWasVoice = true;
    } else {
      _lastTurnWasVoice = false;
    }
    final now = DateTime.now();
    setState(() {
      _messages.add(_RevenMessage(text: text, isUser: true, createdAt: now));
      _messages.add(
        _RevenMessage(
          text: '…',
          isUser: false,
          isLoading: true,
          createdAt: now,
        ),
      );
      _isLoading = true;
    });
    _startWaitElapsedTicker();
    _scrollToBottom();

    final voiceTurn = _isVoiceInteractionMode;
    final inlineCloudVoice = voiceTurn &&
        _voiceReadAloud &&
        _effectiveVoiceCloudEnabled;
    final res = await ChatApi.sendMessage(
      text,
      sessionId: _sessionId,
      voiceReply: inlineCloudVoice,
      voiceMode: voiceTurn,
      voiceId: _activeVoiceIdForApi,
    );

    if (!mounted) return;
    String? ttsReply;
    Map<String, dynamic>? ttsRes;
    String? deferredVoiceReply;
    final shouldSpeak = _voiceReadAloud &&
        (voiceTurn || _lastTurnWasVoice);
    _stopWaitElapsedTicker();
    setState(() {
      _messages.removeLast();
      _isLoading = false;
      if (res['success'] == true && res['awaiting_human'] == true) {
        _humanHandoffActive = res['human_handoff_active'] == true;
        final sid = res['session_id'];
        if (sid is int) _sessionId = sid;
        else if (sid != null) _sessionId = int.tryParse(sid.toString());
        final handoffReply = (res['reply'] as String?)?.trim() ?? '';
        if (handoffReply.isNotEmpty) {
          _messages.add(
            _RevenMessage(
              text: handoffReply,
              isUser: false,
              createdAt: DateTime.now(),
            ),
          );
        }
        _syncHandoffPolling();
        return;
      }
      if (res['success'] == true) {
        _humanHandoffActive = res['human_handoff_active'] == true;
        if (_humanHandoffActive) _syncHandoffPolling();
        List<Map<String, dynamic>>? courses = res['courses'] is List
            ? (res['courses'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;
        List<Map<String, dynamic>>? commands = res['commands'] is List
            ? (res['commands'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;
        List<Map<String, dynamic>>? clients = res['clients'] is List
            ? (res['clients'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;

        // --- Parse bracketed commands from text if commands is empty ---
        String replyText = res['reply'] as String? ?? '';
        if (commands == null || commands.isEmpty) {
          final regex = RegExp(r'\[(.*?)\]');
          final matches = regex.allMatches(replyText);
          if (matches.isNotEmpty) {
            commands = matches.map((m) {
              final label = m.group(1)!;
              return {
                'label': label,
                'target': label.toLowerCase().replaceAll(' ', '-'),
              };
            }).toList();
            // Optional: Remove the bracketed parts from the text to avoid duplication
            replyText = replyText
                .replaceAll(RegExp(r'\s*\[.*?\]\s*'), '')
                .trim();
          }
        }

        if (voiceTurn) {
          replyText = replyText.replaceAll(RegExp(r'\s*\[.*?\]\s*'), '').trim();
        }

        final holdTextForVoice = voiceTurn &&
            shouldSpeak &&
            inlineCloudVoice &&
            replyText.isNotEmpty;

        if (holdTextForVoice) {
          deferredVoiceReply = replyText;
          _pendingAssistantReply = replyText;
          _isSpeaking = true;
        } else {
          _messages.add(
            _RevenMessage(
              text: replyText,
              isUser: false,
              courses: voiceTurn ? null : courses,
              commands: voiceTurn ? null : commands,
              clients: voiceTurn ? null : clients,
              createdAt: DateTime.now(),
            ),
          );
        }

        // --- Auto-fetch clients/courses if promised but not sent ---
        if (voiceTurn) {
          final sid = res['session_id'];
          if (sid != null) {
            _sessionId = sid is int ? sid : int.tryParse(sid.toString());
            _fetchSessions();
          }
          _lastTurnWasVoice = false;
        }

        if (!holdTextForVoice) {
        final lastMsg = _messages.last;
        final replyLower = lastMsg.text.toLowerCase();

        final needsClients =
            (lastMsg.clients == null || lastMsg.clients!.isEmpty) &&
            (replyLower.contains('client') ||
                replyLower.contains('lead') ||
                replyLower.contains('deal room') ||
                replyLower.contains('active clients') ||
                replyLower.contains('your clients'));

        final needsCourses =
            (lastMsg.courses == null || lastMsg.courses!.isEmpty) &&
            (replyLower.contains('course') ||
                replyLower.contains('learn') ||
                replyLower.contains('curriculum') ||
                replyLower.contains('available courses') ||
                replyLower.contains('your courses'));

        final needsRevenue =
            lastMsg.revenueSummary == null &&
            (replyLower.contains('revenue') ||
                replyLower.contains('commission') ||
                replyLower.contains('performance') ||
                replyLower.contains('earned') ||
                replyLower.contains('income'));

        if (needsClients) {
          _autoFetchClientsForLastMessage();
        }
        if (needsCourses) {
          _autoFetchCoursesForLastMessage();
        }
        if (needsRevenue) {
          _autoFetchRevenueForLastMessage();
        }

        final sid = res['session_id'];
        if (sid != null) {
          _sessionId = sid is int ? sid : int.tryParse(sid.toString());
          _fetchSessions();
        }

        if (!voiceTurn) {
          _lastTurnWasVoice = false;
        }
        }
      } else {
        final unavailable = res['service_unavailable'] == true;
        final errMsg = (res['message'] as String?)?.trim();
        _messages.add(
          _RevenMessage(
            text: unavailable
                ? 'Reven is temporarily unreachable (server busy or updating). Please try again in a minute.'
                : (errMsg != null && errMsg.isNotEmpty
                    ? errMsg
                    : 'Something went wrong. Please try again.'),
            isUser: false,
          ),
        );
      }
    });
    if (res['success'] == true) {
      var speakText = deferredVoiceReply ??
          (res['reply'] as String? ?? '').trim();
      if (voiceTurn && deferredVoiceReply == null) {
        speakText = speakText.replaceAll(RegExp(r'\s*\[.*?\]\s*'), '').trim();
      }
      if (speakText.isEmpty) {
        speakText = _messages.reversed
            .where((m) => !m.isUser && !m.isLoading)
            .map((m) => m.text.trim())
            .firstWhere((t) => t.isNotEmpty, orElse: () => '');
      }
      if (shouldSpeak && speakText.isNotEmpty) {
        ttsReply = speakText;
        ttsRes = res;
      }
    }
    _scrollToBottom();
    if (ttsReply != null) {
      await _speakReply(ttsReply, apiRes: ttsRes);
      if (deferredVoiceReply != null && mounted) {
        final reply = deferredVoiceReply!;
        setState(() {
          _pendingAssistantReply = '';
          _isSpeaking = false;
          final exists = _messages.any(
            (m) => !m.isUser && !m.isLoading && m.text == reply,
          );
          if (!exists) {
            _messages.add(
              _RevenMessage(
                text: reply,
                isUser: false,
                createdAt: DateTime.now(),
              ),
            );
          }
        });
        _scrollToBottom();
      }
    }
    // Hands-free: re-open mic after reply unless the user muted it with the mic button.
    if (_isVoiceInteractionMode &&
        !_voiceMicPausedByUser &&
        !_isSpeaking &&
        !_isListening) {
      await _scheduleVoiceListenAfterReply();
    }
  }

  Future<void> _autoFetchClientsForLastMessage() async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.results}?type=hot_lead',
        requiresAuth: true,
      );
      if (res['success'] == true && res['data'] is List && mounted) {
        final list = (res['data'] as List)
            .take(5)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (list.isNotEmpty) {
          setState(() {
            final idx = _messages.lastIndexWhere(
              (m) => !m.isUser && m.clients == null,
            );
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = _RevenMessage(
                text: old.text,
                isUser: old.isUser,
                courses: old.courses,
                commands: old.commands,
                clients: list,
                createdAt: old.createdAt,
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _autoFetchCoursesForLastMessage() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.courses, requiresAuth: true);
      if (res['success'] == true && res['data'] is List && mounted) {
        final list = (res['data'] as List)
            .take(3)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (list.isNotEmpty) {
          setState(() {
            final idx = _messages.lastIndexWhere(
              (m) => !m.isUser && m.courses == null,
            );
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = _RevenMessage(
                text: old.text,
                isUser: old.isUser,
                courses: list,
                commands: old.commands,
                clients: old.clients,
                createdAt: old.createdAt,
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _autoFetchRevenueForLastMessage() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.results, requiresAuth: true);
      if (res['success'] == true && res['summary'] != null && mounted) {
        setState(() {
          final idx = _messages.lastIndexWhere(
            (m) => !m.isUser && m.revenueSummary == null,
          );
          if (idx != -1) {
            final old = _messages[idx];
            _messages[idx] = _RevenMessage(
              text: old.text,
              isUser: old.isUser,
              courses: old.courses,
              commands: old.commands,
              clients: old.clients,
              revenueSummary: res['summary'],
              createdAt: old.createdAt,
            );
          }
        });
      }
    } catch (_) {}
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _sendToApi(text);
  }

  void _sendQuickPrompt(RevenQuickPrompt prompt) {
    _sendToApi(prompt.message);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncOverlayCallStatus();
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactWidth = constraints.maxWidth > 460
                ? 420.0
                : constraints.maxWidth - 28;
            final compactHeight = constraints.maxHeight > 760
                ? 560.0
                : constraints.maxHeight * 0.55;
            final windowWidth = _isExpanded
                ? constraints.maxWidth
                : compactWidth.clamp(300.0, constraints.maxWidth);
            final windowHeight = _isExpanded
                ? constraints.maxHeight
                : compactHeight.clamp(420.0, constraints.maxHeight);
            final bubbleMaxWidth = _isExpanded
                ? 400.0
                : (windowWidth - 80).clamp(180.0, 310.0);

            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                _isExpanded ? 0 : 20,
                _isExpanded ? 0 : 14,
                _isExpanded ? 0 : 24,
                keyboardInset + (_isExpanded ? 0 : 185),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: windowWidth,
                  height: windowHeight,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(_isExpanded ? 0 : 24),
                    border: Border.all(color: borderColor, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: const Color(
                          0xFF4F7CFF,
                        ).withValues(alpha: isDark ? 0.08 : 0.04),
                        blurRadius: 60,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // ── Header ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          border: Border(
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4F7CFF,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Image.asset(
                                'assets/images/chat-bot.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reven',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    _humanHandoffActive
                                        ? 'Human support is chatting'
                                        : _interactionMode == _RevenInteractionMode.voice
                                            ? 'Voice · $_voicePlaybackLabel'
                                            : (_isExpanded ? 'Full view' : 'AI assistant'),
                                    style: TextStyle(
                                      color: _humanHandoffActive
                                          ? const Color(0xFFF59E0B)
                                          : _interactionMode == _RevenInteractionMode.voice
                                              ? const Color(0xFF22C55E)
                                              : subtitleColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Online pulse dot
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4ADE80,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chat history',
                              onPressed: _showChatList,
                              icon: Icon(
                                Icons.history_rounded,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: _isExpanded
                                  ? 'Exit full screen'
                                  : 'Full screen',
                              onPressed: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              icon: Icon(
                                _isExpanded
                                    ? Icons.close_fullscreen_rounded
                                    : Icons.open_in_full_rounded,
                                color: subtitleColor,
                                size: 18,
                              ),
                            ),
                            if (widget.embedded)
                              IconButton(
                                tooltip: 'Minimize',
                                onPressed: _minimizeChat,
                                icon: Icon(
                                  Icons.minimize_rounded,
                                  color: subtitleColor,
                                  size: 20,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: _closeChat,
                              icon: Icon(
                                Icons.close_rounded,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_humanHandoffActive)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          child: Text(
                            'A team member is helping you. AI replies are paused for now.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                      // ── Messages or voice conversation transcript ───
                      Expanded(
                        child: _isVoiceInteractionMode
                            ? _VoiceConversationView(
                                messages: _messages,
                                scrollController: _scrollController,
                                titleColor: titleColor,
                                subtitleColor: subtitleColor,
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                                itemCount:
                                    _messages.length +
                                    (_messages.length == 1 ? 1 : 0),
                                separatorBuilder: (_, index) {
                                  if (_messages.length == 1 && index == 0) {
                                    return const SizedBox(height: 16);
                                  }
                                  return const SizedBox(height: 8);
                                },
                                itemBuilder: (context, index) {
                                  if (_messages.length == 1 && index == 1) {
                                    return _QuickPromptsPanel(
                                      onPromptTapped: _sendQuickPrompt,
                                    );
                                  }
                                  final msg = _messages[index];
                                  DateTime? prevAt;
                                  for (var i = index - 1; i >= 0; i--) {
                                    final t = _messages[i].createdAt;
                                    if (t != null) {
                                      prevAt = t;
                                      break;
                                    }
                                  }
                                  return _ChatBubble(
                                    message: msg,
                                    previousCreatedAt: prevAt,
                                    bubbleMaxWidth: bubbleMaxWidth,
                                    surfaceColor: surfaceColor,
                                    borderColor: borderColor,
                                    titleColor: titleColor,
                                    subtitleColor: subtitleColor,
                                    onCommandTapped: _sendToApi,
                                  );
                                },
                              ),
                      ),

                      // ── Composer: voice (ChatGPT-style) or text ────
                      if (_isVoiceInteractionMode &&
                          _voiceInAiChatEnabled &&
                          !_humanHandoffActive)
                        _RevenVoiceComposer(
                          status: _voiceCallStatus,
                          processingSince: () {
                            if (!_isLoading) return null;
                            for (var i = _messages.length - 1; i >= 0; i--) {
                              final m = _messages[i];
                              if (m.isLoading && m.createdAt != null) {
                                return m.createdAt;
                              }
                            }
                            return null;
                          }(),
                          micPaused: _voiceMicPausedByUser,
                          micSessionOpen: _isListening,
                          userSpeaking: _voiceUserSpeaking,
                          voiceModelLabel: _voicePlaybackLabel,
                          activeVoiceLabel: _activeVoiceLabel,
                          showVoicePicker:
                              _effectiveVoiceCloudEnabled && _voiceAllowUserPick,
                          liveCaption: _isListening
                              ? _voiceTranscript
                              : (_isSpeaking
                                  ? _voiceSpeakingCaption
                                  : _lastVoiceCaption),
                          speakingCaption: _voiceSpeakingCaption,
                          pulse: _micPulseController,
                          isDark: isDark,
                          backgroundColor: backgroundColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          messageController: _messageController,
                          onMicTap: _toggleVoiceInput,
                          onVoicePick: _showVoicePicker,
                          onExitVoice: _exitVoiceMode,
                          onSendText: _sendMessage,
                        )
                      else
                        _RevenTextComposer(
                          messageController: _messageController,
                          backgroundColor: backgroundColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          showMic: _voiceInAiChatEnabled && !_humanHandoffActive,
                          isListening: _isListening,
                          isSpeaking: _isSpeaking,
                          micPulse: _micPulseController,
                          onMicTap: _toggleVoiceInput,
                          onSend: _sendMessage,
                          onFieldTap: _scrollToBottom,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Composers ─────────────────────────────────────────────────────────────

const double _kComposerBtnSize = 40;
const double _kComposerBarMinHeight = 50;

/// Text-mode input: one pill bar with text + mic + send (iMessage-style).
class _RevenTextComposer extends StatelessWidget {
  const _RevenTextComposer({
    required this.messageController,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.showMic,
    required this.isListening,
    required this.isSpeaking,
    required this.micPulse,
    required this.onMicTap,
    required this.onSend,
    this.onFieldTap,
  });

  final TextEditingController messageController;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;
  final bool showMic;
  final bool isListening;
  final bool isSpeaking;
  final AnimationController micPulse;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final VoidCallback? onFieldTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kComposerBarMinHeight),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  textAlignVertical: TextAlignVertical.center,
                  onTap: () {
                    onFieldTap?.call();
                    Future<void>.delayed(const Duration(milliseconds: 280), () {
                      onFieldTap?.call();
                    });
                  },
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Message Reven...',
                    hintStyle: TextStyle(
                      color: subtitleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  ),
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              if (showMic) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _VoiceMicButton(
                    isListening: isListening,
                    isSpeaking: isSpeaking,
                    voiceModeActive: false,
                    pulse: micPulse,
                    backgroundColor: surfaceColor,
                    borderColor: borderColor,
                    subtitleColor: subtitleColor,
                    onTap: onMicTap,
                    compact: true,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 5, 5),
                child: _RevenComposerCircleButton(
                  icon: Icons.send_rounded,
                  backgroundColor: const Color(0xFF4F7CFF),
                  iconColor: Colors.white,
                  onTap: onSend,
                  shadowColor: const Color(0xFF4F7CFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenComposerCircleButton extends StatelessWidget {
  const _RevenComposerCircleButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.borderColor,
    this.shadowColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kComposerBtnSize,
        height: _kComposerBtnSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null ? Border.all(color: borderColor!) : null,
          boxShadow: shadowColor != null
              ? [
                  BoxShadow(
                    color: shadowColor!.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

// ── Voice UI ─────────────────────────────────────────────────────────────

/// ChatGPT-style voice composer: small floating orb + status above a pill
/// row with a Type field, a mic, and a white End button. Chat stays visible.
class _RevenVoiceComposer extends StatelessWidget {
  const _RevenVoiceComposer({
    required this.status,
    this.processingSince,
    this.micPaused = false,
    this.micSessionOpen = false,
    this.userSpeaking = false,
    required this.voiceModelLabel,
    required this.activeVoiceLabel,
    required this.showVoicePicker,
    required this.liveCaption,
    this.speakingCaption = '',
    required this.pulse,
    required this.isDark,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.messageController,
    required this.onMicTap,
    required this.onVoicePick,
    required this.onExitVoice,
    required this.onSendText,
  });

  final _VoiceCallStatus status;
  final DateTime? processingSince;
  final bool micPaused;
  final bool micSessionOpen;
  final bool userSpeaking;
  final String voiceModelLabel;
  final String activeVoiceLabel;
  final bool showVoicePicker;
  final String liveCaption;
  final String speakingCaption;
  final AnimationController pulse;
  final bool isDark;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;
  final TextEditingController messageController;
  final VoidCallback onMicTap;
  final VoidCallback onVoicePick;
  final VoidCallback onExitVoice;
  final VoidCallback onSendText;

  Color get _accent {
    switch (status) {
      case _VoiceCallStatus.listening:
        return const Color(0xFF22C55E);
      case _VoiceCallStatus.processing:
        return const Color(0xFFF59E0B);
      case _VoiceCallStatus.speaking:
        return RealtorOneBrand.accentIndigo;
      case _VoiceCallStatus.idle:
        return const Color(0xFF4F7CFF);
    }
  }

  String get _statusText {
    switch (status) {
      case _VoiceCallStatus.listening:
        return liveCaption.trim().isNotEmpty
            ? liveCaption.trim()
            : 'Listening to you…';
      case _VoiceCallStatus.processing:
        if (processingSince != null) {
          return 'Thinking… ${_RevenChatTimestamps.waiting(processingSince!)}';
        }
        return 'Thinking…';
      case _VoiceCallStatus.speaking:
        final cap = speakingCaption.trim().isNotEmpty
            ? speakingCaption.trim()
            : liveCaption.trim();
        if (cap.isNotEmpty) {
          return cap.length > 140 ? '${cap.substring(0, 137)}…' : cap;
        }
        return 'Speaking… · tap mic to interrupt';
      case _VoiceCallStatus.idle:
        if (micPaused) {
          return 'Tap the mic to resume';
        }
        if (micSessionOpen) {
          return 'Speak now — sends when you pause (~½ sec)';
        }
        return 'Tap the mic and talk — like ChatGPT voice';
    }
  }

  bool get _micIsListening => userSpeaking;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Floating orb + live status ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VoiceCallOrb(
                  accent: _accent,
                  active: userSpeaking,
                  pulse: pulse,
                  isListening: userSpeaking,
                  size: 72,
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _micIsListening ? titleColor : subtitleColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Pill: tune · Type · mic · End ───────────────────────
          Material(
            color: surfaceColor,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Container(
                constraints: const BoxConstraints(minHeight: _kComposerBarMinHeight),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showVoicePicker)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 5),
                        child: _RoundIconButton(
                          icon: Icons.tune_rounded,
                          bg: surfaceColor,
                          fg: subtitleColor,
                          tooltip: 'Change voice ($activeVoiceLabel)',
                          onTap: onVoicePick,
                          size: _kComposerBtnSize,
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 3,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSendText(),
                        decoration: InputDecoration(
                          hintText: 'Type',
                          hintStyle: TextStyle(
                            color: subtitleColor,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(8, 12, 4, 12),
                        ),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: GestureDetector(
                        onTap: onMicTap,
                        child: AnimatedBuilder(
                          animation: pulse,
                          builder: (_, child) {
                            final scale = _micIsListening
                                ? 1.0 + (pulse.value * 0.1)
                                : 1.0;
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            width: _kComposerBtnSize,
                            height: _kComposerBtnSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: userSpeaking
                                  ? const Color(0xFF22C55E)
                                  : micSessionOpen
                                      ? const Color(0xFF4F7CFF).withValues(alpha: 0.2)
                                      : surfaceColor,
                              border: Border.all(
                                color: userSpeaking
                                    ? const Color(0xFF22C55E)
                                    : micSessionOpen
                                        ? const Color(0xFF4F7CFF)
                                        : borderColor,
                              ),
                            ),
                            child: Icon(
                              userSpeaking
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: userSpeaking
                                  ? Colors.white
                                  : micSessionOpen
                                      ? const Color(0xFF4F7CFF)
                                      : subtitleColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 5, 5, 5),
                      child: _RevenComposerCircleButton(
                        icon: Icons.close_rounded,
                        backgroundColor: Colors.white,
                        iconColor: const Color(0xFF0F172A),
                        onTap: onExitVoice,
                        borderColor: borderColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

class _VoiceCallOrb extends StatelessWidget {
  const _VoiceCallOrb({
    required this.accent,
    required this.active,
    required this.pulse,
    required this.isListening,
    this.size = 88,
  });

  final Color accent;
  final bool active;
  final AnimationController pulse;
  final bool isListening;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * 0.72;
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final ring = isListening ? 0.12 + pulse.value * 0.18 : 0.08;
        return SizedBox(
          width: size + ring * 60,
          height: size + ring * 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active) ...[
                Container(
                  width: size + ring * 60,
                  height: size + ring * 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.06),
                  ),
                ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                ),
              ],
              Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.92),
                      const Color(0xFF6366F1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(core * 0.18),
                  child: Image.asset(
                    'assets/images/chat-bot.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceWaveBars extends StatefulWidget {
  const _VoiceWaveBars({required this.active});

  final bool active;

  @override
  State<_VoiceWaveBars> createState() => _VoiceWaveBarsState();
}

class _VoiceWaveBarsState extends State<_VoiceWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _VoiceWaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.25) % 1.0;
            final h = 8.0 + (phase * 10.0);
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: RealtorOneBrand.accentIndigo,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _VoiceMicButton extends StatelessWidget {
  const _VoiceMicButton({
    required this.isListening,
    required this.isSpeaking,
    required this.voiceModeActive,
    required this.pulse,
    required this.backgroundColor,
    required this.borderColor,
    required this.subtitleColor,
    required this.onTap,
    this.compact = false,
  });

  final bool isListening;
  final bool isSpeaking;
  final bool voiceModeActive;
  final AnimationController pulse;
  final Color backgroundColor;
  final Color borderColor;
  final Color subtitleColor;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = isListening || isSpeaking;
    final fill = isListening
        ? const Color(0xFFEF4444)
        : isSpeaking
            ? RealtorOneBrand.accentIndigo
            : voiceModeActive
                ? const Color(0xFF22C55E).withValues(alpha: 0.14)
                : backgroundColor;
    final border = active
        ? (isListening ? const Color(0xFFEF4444) : RealtorOneBrand.accentIndigo)
        : voiceModeActive
            ? const Color(0xFF22C55E)
            : borderColor;
    final size = compact ? _kComposerBtnSize : 48.0;
    final iconSize = compact ? 20.0 : 22.0;
    final shape = compact
        ? const BoxDecoration(shape: BoxShape.circle)
        : BoxDecoration(borderRadius: BorderRadius.circular(14));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) {
          final scale = isListening ? 1.0 + (pulse.value * 0.08) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: size,
          height: size,
          decoration: shape.copyWith(
            color: fill,
            border: Border.all(color: border, width: active ? 1.6 : 1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: (isListening
                              ? const Color(0xFFEF4444)
                              : RealtorOneBrand.accentIndigo)
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            active ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: active
                ? Colors.white
                : voiceModeActive
                    ? const Color(0xFF22C55E)
                    : subtitleColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ─────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: _animation.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Voice conversation transcript (ChatGPT / Gemini style) ───────────────

class _VoiceConversationView extends StatelessWidget {
  const _VoiceConversationView({
    required this.messages,
    required this.scrollController,
    required this.titleColor,
    required this.subtitleColor,
  });

  final List<_RevenMessage> messages;
  final ScrollController scrollController;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final turns = messages.where((m) => !m.isLoading && m.text.trim().isNotEmpty).toList();
    final visible = turns.length > 10 ? turns.sublist(turns.length - 10) : turns;
    _RevenMessage? pending;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isLoading) {
        pending = messages[i];
        break;
      }
    }

    if (visible.isEmpty && pending == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Start talking — Reven will reply out loud and keep the conversation going.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    final itemCount = visible.length + (pending != null ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (pending != null && index == itemCount - 1) {
          DateTime? prevAt;
          for (var i = messages.length - 1; i >= 0; i--) {
            final m = messages[i];
            if (!m.isLoading && m.createdAt != null) {
              prevAt = m.createdAt;
              break;
            }
          }
          final started = pending.createdAt ?? DateTime.now();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reven',
                  style: TextStyle(
                    color: const Color(0xFF22C55E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _RevenChatTimestamps.waiting(started, after: prevAt),
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        final msg = visible[index];
        DateTime? prevAt;
        final globalIndex = turns.length - visible.length + index;
        if (globalIndex > 0) {
          prevAt = turns[globalIndex - 1].createdAt;
        }
        return _VoiceTurnLine(
          message: msg,
          previousCreatedAt: prevAt,
          titleColor: titleColor,
          subtitleColor: subtitleColor,
        );
      },
    );
  }
}

class _VoiceTurnLine extends StatelessWidget {
  const _VoiceTurnLine({
    required this.message,
    this.previousCreatedAt,
    required this.titleColor,
    required this.subtitleColor,
  });

  final _RevenMessage message;
  final DateTime? previousCreatedAt;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final label = isUser ? 'You' : (message.isHuman ? 'Support' : 'Reven');
    final accent = isUser
        ? const Color(0xFF4F7CFF)
        : message.isHuman
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (message.createdAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _RevenChatTimestamps.label(
                    message.createdAt!,
                    after: previousCreatedAt,
                  ),
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.text.trim(),
            textAlign: isUser ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble widget ────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.previousCreatedAt,
    required this.bubbleMaxWidth,
    required this.surfaceColor,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
    this.onCommandTapped,
  });

  final _RevenMessage message;
  final DateTime? previousCreatedAt;
  final double bubbleMaxWidth;
  final Color surfaceColor;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;
  final void Function(String)? onCommandTapped;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isHuman = message.isHuman;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4F7CFF)
              : isHuman
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                  : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isHuman ? const Color(0xFFF59E0B).withValues(alpha: 0.45) : borderColor,
                ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: message.isLoading
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TypingDot(delay: 0),
                        _TypingDot(delay: 1),
                        _TypingDot(delay: 2),
                      ],
                    ),
                  ),
                  if (message.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _RevenChatTimestamps.waiting(
                        message.createdAt!,
                        after: previousCreatedAt,
                      ),
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHuman) ...[
                    Text(
                      'Human support',
                      style: TextStyle(
                        color: const Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 4),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  if (message.courses != null &&
                      message.courses!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty) const SizedBox(height: 12),
                    _CourseList(
                      courses: message.courses!,
                      titleColor: titleColor,
                    ),
                  ],
                  if (message.clients != null &&
                      message.clients!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty))
                      const SizedBox(height: 12),
                    _ClientList(
                      clients: message.clients!,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ],
                  if (message.revenueSummary != null && !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty) ||
                        (message.clients != null &&
                            message.clients!.isNotEmpty))
                      const SizedBox(height: 12),
                    _RevenueSummary(
                      summary: message.revenueSummary!,
                      titleColor: titleColor,
                    ),
                  ],
                  if (message.commands != null &&
                      message.commands!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty))
                      const SizedBox(height: 12),
                    _CommandChips(
                      commands: message.commands!,
                      titleColor: titleColor,
                      onCommandTapped: onCommandTapped,
                    ),
                  ],
                  if (message.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _RevenChatTimestamps.label(
                        message.createdAt!,
                        after: previousCreatedAt,
                      ),
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.8)
                            : subtitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ── Course list inside chat bubble ────────────────────────────────────────

class _CourseList extends StatelessWidget {
  const _CourseList({required this.courses, required this.titleColor});

  final List<Map<String, dynamic>> courses;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Courses',
              style: TextStyle(
                color: titleColor.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            _ListNavigateButton(
              context: context,
              label: 'Open Hub',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.main,
                  (route) => false,
                  arguments: const {'initialIndex': 2},
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...courses.map((c) {
          final title = (c['title'] as String?) ?? 'Course';
          final desc = (c['description'] as String?)?.toString();
          final isPublished =
              (c['is_published'] == true ||
              c['is_published'] == 1 ||
              c['is_published'] == "1");
          final isOffline = !isPublished;

          return Opacity(
            opacity: isOffline ? 0.5 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4F7CFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4F7CFF).withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: isOffline
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.courseCurriculum,
                          arguments: {
                            'courseId': c['id'],
                            'courseTitle': title,
                          },
                        );
                      },
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOffline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OFFLINE',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (desc != null && desc.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              desc,
                              style: TextStyle(
                                color: titleColor.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 20,
                      color: const Color(0xFF667EEA).withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Command chips inside chat bubble ────────────────────────────────────

class _CommandChips extends StatelessWidget {
  const _CommandChips({
    required this.commands,
    required this.titleColor,
    this.onCommandTapped,
  });

  final List<Map<String, dynamic>> commands;
  final Color titleColor;
  final void Function(String)? onCommandTapped;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: commands.map((c) {
        final keyword = (c['keyword'] as String?) ?? '';
        final label = (c['label'] as String?) ?? keyword;
        final target = (c['target'] as String?) ?? '';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark
            ? const Color(0xFF263148)
            : const Color(0xFFDDE5F0);
        final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;

        void openTarget() {
          // IMPORTANT: Close the chat dialog before navigating
          Navigator.of(context).pop();

          switch (target) {
            case 'dashboard':
            case 'home':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 0},
              );
              return;
            case 'tasks':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 1},
              );
              return;
            case 'courses':
            case 'learning':
            case 'learn':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 2},
              );
              return;
            case 'badges':
              Navigator.of(context).pushNamed(AppRoutes.badges);
              return;
            case 'profile':
            case 'settings':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 3},
              );
              return;
            case 'deal-room':
            case 'client-list':
            case 'clients':
            case 'active-clients':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {
                  'initialIndex': 1,
                  'activitiesTabIndex': 1,
                  'revenueSubTab': 0,
                },
              );
              return;
          }
        }

        return GestureDetector(
          onTap: () {
            if (target.isNotEmpty) {
              openTarget();
              return;
            }
            if (onCommandTapped != null && keyword.isNotEmpty) {
              onCommandTapped!(keyword);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: titleColor, fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Quick prompts panel ─────────────────────────────────────────────────

class _QuickPromptsPanel extends StatelessWidget {
  const _QuickPromptsPanel({required this.onPromptTapped});

  final void Function(RevenQuickPrompt) onPromptTapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'QUICK TOPICS',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ...revenPromptCategories.map(
          (category) => _CategoryRow(
            category: category,
            onPromptTapped: onPromptTapped,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onPromptTapped,
    required this.subtitleColor,
  });

  final RevenPromptCategory category;
  final void Function(RevenQuickPrompt) onPromptTapped;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.title,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: category.prompts
                .map((p) => _PromptChip(prompt: p, onTapped: onPromptTapped))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.onTapped});

  final RevenQuickPrompt prompt;
  final void Function(RevenQuickPrompt) onTapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: () => onTapped(prompt),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prompt.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              prompt.label,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Timestamps (clock + step duration for latency debugging) ───────────────

class _RevenChatTimestamps {
  static String clock(DateTime dt) {
    final h = dt.hour;
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$hour12:$m:$s $ampm';
  }

  static String deltaSeconds(DateTime dt, DateTime after) {
    final sec = dt.difference(after).inMilliseconds / 1000.0;
    if (sec < 0.05) return '';
    return ' · +${sec.toStringAsFixed(1)}s';
  }

  /// e.g. `3:42:08 PM · +12.4s` (time since previous message in chat).
  static String label(DateTime dt, {DateTime? after}) {
    final base = clock(dt);
    if (after == null) return base;
    return '$base${deltaSeconds(dt, after)}';
  }

  /// Live timer while Reven is thinking (updates via parent setState).
  static String waiting(DateTime started, {DateTime? after}) {
    final now = DateTime.now();
    final waitSec = now.difference(started).inMilliseconds / 1000.0;
    if (after != null) {
      final totalSec = now.difference(after).inMilliseconds / 1000.0;
      return 'Waiting ${waitSec.toStringAsFixed(1)}s (${totalSec.toStringAsFixed(1)}s since you)';
    }
    return 'Waiting ${waitSec.toStringAsFixed(1)}s…';
  }
}

// ── Data model ───────────────────────────────────────────────────────────

class _RevenMessage {
  final String text;
  final bool isUser;
  final bool isHuman;
  final bool isLoading;
  final List<Map<String, dynamic>>? courses;
  final List<Map<String, dynamic>>? commands;
  final List<Map<String, dynamic>>? clients;
  final Map<String, dynamic>? revenueSummary;
  final DateTime? createdAt;

  const _RevenMessage({
    required this.text,
    required this.isUser,
    this.isHuman = false,
    this.isLoading = false,
    this.courses,
    this.commands,
    this.clients,
    this.revenueSummary,
    this.createdAt,
  });
}

class _ClientList extends StatelessWidget {
  const _ClientList({
    required this.clients,
    required this.titleColor,
    required this.subtitleColor,
  });

  final List<Map<String, dynamic>> clients;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Active Clients',
              style: TextStyle(
                color: titleColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            _ListNavigateButton(
              context: context,
              label: 'View All',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.main,
                  (route) => false,
                  arguments: const {
                    'initialIndex': 1,
                    'activitiesTabIndex': 1,
                    'revenueSubTab': 0,
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...clients.map((c) {
          final name = (c['client_name'] as String?) ?? 'Client';
          final status = (c['status'] as String?) ?? '-';
          final source = (c['source'] as String?) ?? '-';
          final value = c['value']?.toString() ?? '-';
          final date = (c['date'] as String?) ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 16,
                            color: const Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: $status · Source: $source · Value: $value${date.isNotEmpty ? ' · Date: $date' : ''}',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: subtitleColor.withOpacity(0.3),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Shared navigation button for lists ────────────────────────────────────

class _ListNavigateButton extends StatelessWidget {
  const _ListNavigateButton({
    required this.context,
    required this.label,
    required this.onTap,
  });

  final BuildContext context;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667EEA),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              size: 10,
              color: Color(0xFF667EEA),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  const _RevenueSummary({required this.summary, required this.titleColor});

  final Map<String, dynamic> summary;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final commission = (summary['total_commission'] ?? 0).toStringAsFixed(0);
    final deals = summary['deals_closed'] ?? 0;
    final conversion = summary['conversion_rate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REVENUE PERFORMANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              _ListNavigateButton(
                context: context,
                label: 'Tracker',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.main,
                    (route) => false,
                    arguments: const {
                      'initialIndex': 1,
                      'activitiesTabIndex': 1,
                      'revenueSubTab': 1, // REVENUE tab
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'COMMISSION',
                  value: '$commission AED',
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryStat(
                  label: 'DEALS',
                  value: '$deals',
                  icon: Icons.handshake_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryStat(
            label: 'CONVERSION RATE',
            value: '$conversion%',
            icon: Icons.trending_up_rounded,
            horizontal: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.horizontal = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
