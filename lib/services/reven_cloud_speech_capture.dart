import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records short WAV clips for cloud Whisper transcription.
class RevenCloudSpeechCapture {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ampTimer;
  String? _activePath;
  bool _recording = false;

  bool get isActive => _recording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> start({void Function(double db)? onAmplitude}) async {
    if (_recording) return true;
    if (!await _recorder.hasPermission()) return false;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/reven_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );

    _activePath = path;
    _recording = true;

    if (onAmplitude != null) {
      _ampTimer?.cancel();
      _ampTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        if (!_recording) return;
        try {
          final amp = await _recorder.getAmplitude();
          onAmplitude(amp.current);
        } catch (_) {}
      });
    }

    return true;
  }

  Future<String?> stop() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    if (!_recording) return null;
    _recording = false;
    try {
      final path = await _recorder.stop();
      return path ?? _activePath;
    } catch (_) {
      return _activePath;
    } finally {
      _activePath = null;
    }
  }

  Future<void> cancel() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    if (_recording) {
      _recording = false;
      try {
        final path = await _recorder.stop();
        await _deleteIfExists(path ?? _activePath);
      } catch (_) {}
    }
    _activePath = null;
  }

  Future<void> deleteFile(String? path) => _deleteIfExists(path);

  Future<void> _deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _ampTimer?.cancel();
    _recorder.dispose();
  }
}
