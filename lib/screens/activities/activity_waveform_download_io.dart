import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/api_client.dart';

Future<String?> downloadActivityAudioForWaveform(String url) async {
  final dir = await getTemporaryDirectory();
  final ext = activityWaveformCacheExtension(url);
  final file = File('${dir.path}/wf_${url.hashCode}$ext');
  if (await file.exists() && await file.length() > 0) return file.path;

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );
  final headers = <String, String>{};
  final token = await ApiClient.getToken();
  if (token != null) headers['Authorization'] = 'Bearer $token';

  await dio.download(
    url,
    file.path,
    options: Options(headers: headers.isEmpty ? null : headers),
  );
  return file.path;
}

String activityWaveformCacheExtension(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final lower = path.toLowerCase();
  for (final ext in ['.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus']) {
    if (lower.endsWith(ext)) return ext;
  }
  return '.mp3';
}
