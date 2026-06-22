import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Shared iOS/Android audio session for long-form playback (activities, courses).
class MediaPlaybackSession {
  MediaPlaybackSession._();

  static bool _configured = false;

  static Future<void> ensureConfigured() async {
    if (_configured || kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      _configured = true;
    } catch (e) {
      debugPrint('MediaPlaybackSession configure failed: $e');
    }
  }

  /// Apply playback-friendly session before starting a player instance.
  static Future<void> configurePlayer(AudioPlayer player) async {
    await ensureConfigured();
    try {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
      if (!kIsWeb && Platform.isIOS) {
        await player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaPlaybackSession player configure failed: $e');
    }
  }
}
