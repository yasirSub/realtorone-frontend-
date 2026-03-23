/// Web / non-IO: no local file for native waveform decode.
Future<String?> downloadActivityAudioForWaveform(String url) async => null;

String activityWaveformCacheExtension(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final lower = path.toLowerCase();
  for (final ext in ['.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus']) {
    if (lower.endsWith(ext)) return ext;
  }
  return '.mp3';
}
