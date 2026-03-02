import 'package:flutter/material.dart';
import '../../api/learning_api.dart';
import '../../models/learning_model.dart';
import '../../widgets/elite_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../routes/app_routes.dart';
import '../../api/api_endpoints.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class CourseCurriculumPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseCurriculumPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseCurriculumPage> createState() => _CourseCurriculumPageState();
}

class _CourseCurriculumPageState extends State<CourseCurriculumPage> {
  bool _isLoading = true;
  CourseModel? _course;
  final Map<int, bool> _expandedModules = {};
  
  // YouTube Mode Controllers
  MaterialItem? _playingMaterial;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;
  bool _playerError = false;

  // Offline Download Tracking
  final Map<int, double> _downloadProgress = {};
  final Map<int, String> _localFiles = {}; // materialId -> localPath

  @override
  void initState() {
    super.initState();
    _loadLocalContentInfo();
    _loadCourseDetails();
  }

  Future<void> _loadLocalContentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> downloadedKeys = prefs.getKeys().where((k) => k.startsWith('offline_material_')).toList();
    
    setState(() {
      for (final key in downloadedKeys) {
        final id = int.tryParse(key.replaceFirst('offline_material_', ''));
        if (id != null) {
          _localFiles[id] = prefs.getString(key) ?? '';
        }
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await LearningApi.getCourseDetails(widget.courseId);
      if (res['success'] == true) {
        _course = CourseModel.fromJson(res['data']);
        // Expand first module by default
        if (_course?.modules != null && _course!.modules!.isNotEmpty) {
          _expandedModules[_course!.modules![0].id] = true;
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading course details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: EliteLoader())
          : _course == null
              ? _buildErrorState()
              : Column(
                  children: [
                    if (_playingMaterial != null) ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.width * (9 / 16), // 16:9 ratio
                        width: double.infinity,
                        child: _buildVideoPlayer(),
                      ),
                      _buildPlayerDownloadRow(),
                    ],
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          _buildAppBar(),
                          _buildCurriculumList(),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAppBar() {
    if (_playingMaterial != null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F172A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.courseTitle.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_playingMaterial != null)
              _buildVideoPlayer()
            else if (_course?.thumbnailUrl != null)
              Image.network(
                _course!.thumbnailUrl!,
                fit: BoxFit.cover,
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                ),
              ),
            if (_playingMaterial == null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_playerError) {
      return Container(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white60, size: 40),
            const SizedBox(height: 12),
            const Text(
              'STREAM CONNECTION FAILED',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _openMaterial(_playingMaterial!),
              child: const Text('RETRY', style: TextStyle(color: Color(0xFF4ECDC4))),
            )
          ],
        ),
      );
    }

    if (!_isPlayerInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4), strokeWidth: 2),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: Chewie(controller: _chewieController!),
        ),
        // Overlays
        Positioned(
          top: MediaQuery.of(context).padding.top,
          right: 50,
          child: _localFiles.containsKey(_playingMaterial!.id)
              ? const IconButton(
                  icon: Icon(Icons.offline_pin_rounded, color: Color(0xFF4ECDC4), size: 22),
                  onPressed: null,
                )
              : IconButton(
                  icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 22),
                  onPressed: () => _downloadMaterial(_playingMaterial!),
                ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top,
          right: 10,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: () {
              // Clean up player
              _videoPlayerController?.dispose();
              _chewieController?.dispose();
              _videoPlayerController = null;
              _chewieController = null;
              setState(() {
                _playingMaterial = null;
                _isPlayerInitialized = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurriculumList() {
    final modules = _course?.modules ?? [];
    if (modules.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('Curriculum is being updated...'),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          ...modules.asMap().entries.map((entry) {
            return _buildModuleItem(entry.value, entry.key);
          }).toList(),
        ]),
      ),
    );
  }

  Widget _buildPlayerDownloadRow() {
    if (_playingMaterial == null) return const SizedBox.shrink();
    final material = _playingMaterial!;
    final isDownloaded = _localFiles.containsKey(material.id);
    final isDownloading = _downloadProgress.containsKey(material.id);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title ?? 'Untitled Training',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'READY FOR OFFLINE STUDY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (material.showDownloadLink)
                isDownloaded
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.offline_pin_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'FILES OFFLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    : isDownloading
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    value: _downloadProgress[material.id],
                                    strokeWidth: 2.5,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'SAVING...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _downloadMaterial(material),
                            icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                            label: const Text('DOWNLOAD NOW'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
            ],
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildModuleItem(ModuleItem module, int index) {
    bool isExpanded = _expandedModules[module.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedModules[module.id] = !isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF6366F1).withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                if (isExpanded)
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isExpanded ? const Color(0xFF6366F1) : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    module.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isExpanded
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isExpanded ? const Color(0xFF6366F1) : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...module.lessons.map((lesson) => _buildLessonItem(lesson)).toList(),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }

  Widget _buildLessonItem(LessonItem lesson) {
    return Container(
      margin: const EdgeInsets.only(left: 32, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.play_circle_outline_rounded,
            color: Color(0xFF6366F1), size: 20),
        title: Text(
          lesson.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        children: lesson.materials
            .map((material) => _buildMaterialItem(material))
            .toList(),
      ),
    );
  }

  Widget _buildMaterialItem(MaterialItem material) {
    IconData icon;
    Color color;
    String typeLabel;
    
    switch (material.type) {
      case 'Video':
        icon = Icons.play_lesson_rounded;
        color = const Color(0xFF6366F1);
        typeLabel = 'VIDEO TRAINING';
        break;
      case 'PDF':
        icon = Icons.picture_as_pdf_rounded;
        color = const Color(0xFFEF4444);
        typeLabel = 'PDF WORKBOOK';
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = const Color(0xFF64748B);
        typeLabel = 'RESOURCE';
    }

    final isCompleted = material.isCompleted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? color.withOpacity(0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openMaterial(material),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Tactical Type Indicator
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted ? color.withOpacity(0.1) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              
              // Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.w800, 
                        letterSpacing: 0.8,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      material.title ?? 'Untitled Resource',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? const Color(0xFF1E293B) : const Color(0xFF475569),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tactical Action Group
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (material.showDownloadLink)
                    _localFiles.containsKey(material.id)
                        ? _buildActionButton(
                            icon: Icons.offline_pin_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => _openMaterial(material), // Still opens (uses local)
                          )
                        : _downloadProgress.containsKey(material.id)
                            ? SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  value: _downloadProgress[material.id],
                                  strokeWidth: 2,
                                  color: const Color(0xFF6366F1),
                                ),
                              )
                            : _buildActionButton(
                                icon: Icons.download_for_offline_rounded,
                                color: const Color(0xFF6366F1),
                                onTap: () => _downloadMaterial(material),
                              ),
                  const SizedBox(width: 8),
                  
                  // Progress Control
                  InkWell(
                    onTap: () => _toggleCompletion(material),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: isCompleted ? Colors.white : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Future<void> _toggleCompletion(MaterialItem material) async {
    final newStatus = !material.isCompleted;
    try {
      await LearningApi.updateMaterialProgress(
        materialId: material.id,
        isCompleted: newStatus,
      );
      _loadCourseDetails();
    } catch (e) {
      debugPrint('Error toggling: $e');
    }
  }

  Future<void> _openMaterial(MaterialItem material) async {
    if (material.url == null) return;

    if (material.type == 'Video') {
      _playVideo(material);
    } else {
      String pathToOpen;
      
      if (_localFiles.containsKey(material.id)) {
        pathToOpen = _localFiles[material.id]!;
        debugPrint('[PDF Viewer] Opening LOCAL: $pathToOpen');
        final uri = Uri.file(pathToOpen);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
        }
      } else {
        String materialUrl = material.url!;
        if (!materialUrl.contains('://')) {
          materialUrl = '${ApiEndpoints.baseUrl.replaceAll('/api', '')}/storage/$materialUrl';
        }
        final uri = Uri.parse(Uri.encodeFull(materialUrl));
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      
      if (!material.isCompleted) {
        _markAsCompleted(material);
      }
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load course details'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadCourseDetails,
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(MaterialItem material) async {
    WakelockPlus.enable();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    setState(() {
      _playingMaterial = material;
      _isPlayerInitialized = false;
      _playerError = false;
    });

    try {
      if (_localFiles.containsKey(material.id)) {
        final localPath = _localFiles[material.id]!;
        debugPrint('[Integrated Player] Using LOCAL FILE: $localPath');
        _videoPlayerController = VideoPlayerController.file(File(localPath));
      } else {
        String videoUrl = material.url!;
        if (videoUrl.contains('course-assets/')) {
          final filename = videoUrl.split('/').last;
          videoUrl = '${ApiEndpoints.baseUrl.replaceAll('/api', '')}/api/stream/$filename';
        } else if (!videoUrl.contains('://')) {
          videoUrl = '${ApiEndpoints.baseUrl.replaceAll('/api', '')}/api/stream/$videoUrl';
        }
        final encodedUrl = Uri.encodeFull(videoUrl);
        debugPrint('[Integrated Player] Target STREAM: $encodedUrl');
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(encodedUrl));
      }

      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.position >= _videoPlayerController!.value.duration && 
            _videoPlayerController!.value.isInitialized && !material.isCompleted) {
          _markAsCompleted(material);
        }
      });

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6366F1),
          handleColor: const Color(0xFF6366F1),
          bufferedColor: Colors.white.withOpacity(0.2),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
      );

      setState(() => _isPlayerInitialized = true);
    } catch (e) {
      debugPrint('[Integrated Player] Error: $e');
      setState(() => _playerError = true);
    }
  }

  Future<void> _downloadMaterial(MaterialItem material) async {
    if (material.url == null) return;
    
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission required.')),
          );
        }
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting download: ${material.title}...'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );

    String downloadUrl = material.url!;
    if (!downloadUrl.contains('://')) {
      downloadUrl = '${ApiEndpoints.baseUrl.replaceAll('/api', '')}/storage/$downloadUrl';
    }

    final String extension = material.type == 'Video' ? 'mp4' : 'pdf';
    final String fileName = 'material_${material.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String savePath = '${appDocDir.path}/$fileName';
      final dio = Dio();
      
      await dio.download(
        Uri.encodeFull(downloadUrl), 
        savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            setState(() => _downloadProgress[material.id] = count / total);
          }
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_material_${material.id}', savePath);
      
      setState(() {
        _localFiles[material.id] = savePath;
        _downloadProgress.remove(material.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${material.title}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      setState(() => _downloadProgress.remove(material.id));
    }
  }

  Future<void> _markAsCompleted(MaterialItem material) async {
    try {
      await LearningApi.updateMaterialProgress(
        materialId: material.id,
        isCompleted: true,
      );
      _loadCourseDetails(); 
    } catch (e) {
      debugPrint('Completion tracking failed: $e');
    }
  }
}
