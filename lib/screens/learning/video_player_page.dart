import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import '../../api/learning_api.dart';
import '../../api/api_client.dart';


class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int materialId;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.materialId,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final token = await ApiClient.getToken();
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      
      _videoPlayerController.addListener(() {
        if (_videoPlayerController.value.position >= _videoPlayerController.value.duration && 
            !_completed && _videoPlayerController.value.isInitialized) {
          _markAsCompleted();
        }
      });

      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF4ECDC4),
          handleColor: const Color(0xFF4ECDC4),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
      );
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _markAsCompleted() async {
    _completed = true;
    try {
      await LearningApi.updateMaterialProgress(
        materialId: widget.materialId,
        isCompleted: true,
      );
      debugPrint('Video marked as completed: ${widget.materialId}');
    } catch (e) {
      debugPrint('Error marking video completed: $e');
      _completed = false; // Allow retry
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Center(
        child: _hasError
            ? _buildErrorWidget()
            : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                      SizedBox(height: 20),
                      Text(
                        'INITIALIZING SECURE STREAM...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        const Text(
          'STREAM CONNECTION FAILED',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your connection or try again later.',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _hasError = false;
              _chewieController = null;
            });
            _initializePlayer();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
          ),
          child: const Text('RETRY STREAM'),
        ),
      ],
    );
  }
}
