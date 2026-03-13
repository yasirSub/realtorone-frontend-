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
  int _lastSavedProgress = 0;

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
    final List<String> downloadedKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('offline_material_'))
        .toList();

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
    _saveCurrentProgress(); // CRITICAL: Save on exit
    WakelockPlus.disable();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentProgress() async {
    if (_videoPlayerController != null && _playingMaterial != null) {
      final pos = _videoPlayerController!.value.position.inSeconds;
      if (pos > 0) {
        debugPrint('[Integrated Player] PERSISTING EXIT PROGRESS: ${pos}s');
        await LearningApi.updateMaterialProgress(
          materialId: _playingMaterial!.id,
          progressSeconds: pos,
        );
      }
    }
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
        // Sync course completion to backend when all modules are done
        if (mounted && _isCourseCompleted()) {
          try {
            await LearningApi.updateCourseProgress(
              courseId: widget.courseId,
              progressPercent: 100,
              isCompleted: true,
            );
          } catch (_) {}
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
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: EliteLoader())
          : _course == null
          ? _buildErrorState()
          : Column(
              children: [
                if (_playingMaterial != null) ...[
                  SizedBox(
                    height:
                        MediaQuery.of(context).size.width *
                        (9 / 16), // 16:9 ratio
                    width: double.infinity,
                    child: _buildVideoPlayer(),
                  ),
                  _buildPlayerDownloadRow(),
                ],
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(),
                      _buildTakeExamBanner(),
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
    if (_playingMaterial != null)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F172A),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.courseTitle.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.2,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient (always visible; no broken image)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF312E81),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
            // Course thumbnail (only when URL works; never show broken icon)
            if (_course?.thumbnailUrl != null &&
                _course!.thumbnailUrl!.isNotEmpty)
              Image.network(
                _fullThumbnailUrl(_course!.thumbnailUrl!) ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Soft overlay so title stays readable
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Subtle accent when no thumbnail (or image failed)
            Center(
              child: Icon(
                Icons.school_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.08),
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
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white60,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'STREAM CONNECTION FAILED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                final idx = _getModuleIndexForMaterial(_playingMaterial!.id);
                if (idx != null) _openMaterial(_playingMaterial!, idx);
              },
              child: const Text(
                'RETRY',
                style: TextStyle(color: Color(0xFF4ECDC4)),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isPlayerInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4ECDC4),
            strokeWidth: 2,
          ),
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
          left: 10,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top,
          right: 10,
          child: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              _saveCurrentProgress();
              _videoPlayerController?.dispose();
              _chewieController?.dispose();
              _videoPlayerController = null;
              _chewieController = null;
              setState(() {
                _playingMaterial = null;
                _isPlayerInitialized = false;
              });
              // Reload course so lock state updates (e.g. next module unlocks after completing video)
              await _loadCourseDetails();
            },
          ),
        ),
      ],
    );
  }

  /// True if all Video materials in the module are completed.
  bool _isModuleCompleted(int moduleIndex) {
    final modules = _course?.modules ?? [];
    if (moduleIndex < 0 || moduleIndex >= modules.length) return false;
    final module = modules[moduleIndex];
    for (final lesson in module.lessons) {
      for (final material in lesson.materials) {
        final isVideo = material.type.toLowerCase() == 'video';
        if (isVideo && !material.isCompleted) return false;
      }
    }
    return true;
  }

  /// Module is locked until the previous module's videos are all completed.
  bool _isModuleLocked(int moduleIndex) {
    if (moduleIndex <= 0) return false;
    return !_isModuleCompleted(moduleIndex - 1);
  }

  int? _getModuleIndexForMaterial(int materialId) {
    final modules = _course?.modules ?? [];
    for (var i = 0; i < modules.length; i++) {
      for (final lesson in modules[i].lessons) {
        if (lesson.materials.any((m) => m.id == materialId)) return i;
      }
    }
    return null;
  }

  /// True when all modules have all Video materials completed (full course done).
  bool _isCourseCompleted() {
    final modules = _course?.modules ?? [];
    for (var i = 0; i < modules.length; i++) {
      if (!_isModuleCompleted(i)) return false;
    }
    return modules.isNotEmpty;
  }

  static const int _pointsPerModule = 10;

  int _getCourseProgressPercent() {
    final modules = _course?.modules ?? [];
    if (modules.isEmpty) return 0;
    int completed = 0;
    for (var i = 0; i < modules.length; i++) {
      if (_isModuleCompleted(i)) completed++;
    }
    return ((completed / modules.length) * 100).round();
  }

  Widget _buildTakeExamBanner() {
    final isComplete = _isCourseCompleted();
    final progressPercent = _getCourseProgressPercent();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: isComplete
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.08),
                        const Color(0xFF8B5CF6).withOpacity(0.06),
                      ],
                    )
                  : null,
              color: isComplete ? null : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isComplete
                      ? const Color(0xFF6366F1).withOpacity(0.06)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                if (!isComplete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Complete all modules ($progressPercent% done) to unlock your certification exam.',
                      ),
                      backgroundColor: const Color(0xFF6366F1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  AppRoutes.courseExam,
                  arguments: {
                    'courseId': widget.courseId,
                    'courseTitle': widget.courseTitle,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: isComplete
                            ? const Color(0xFF6366F1).withOpacity(0.15)
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isComplete
                            ? Icons.verified_user_rounded
                            : Icons.lock_outline_rounded,
                        color: isComplete
                            ? const Color(0xFF6366F1)
                            : Colors.grey.shade600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isComplete
                                ? 'Ready to certify'
                                : 'Certification exam',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                              color: isComplete
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isComplete
                                ? 'Prove your mastery — take the certification exam.'
                                : '$progressPercent% done — complete all modules to unlock.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isComplete)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Color(0xFF6366F1),
                        ),
                      )
                    else
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumList() {
    final modules = _course?.modules ?? [];
    if (modules.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Curriculum is being updated...')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
    return const SizedBox.shrink();
  }

  Widget _buildModuleItem(ModuleItem module, int index) {
    bool isExpanded = _expandedModules[module.id] ?? false;
    final isLocked = _isModuleLocked(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Complete all videos in Module ${index} to unlock.',
                  ),
                  backgroundColor: const Color(0xFF6366F1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            setState(() {
              _expandedModules[module.id] = !isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isLocked ? const Color(0xFFF1F5F9) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLocked
                    ? const Color(0xFFE2E8F0)
                    : isExpanded
                    ? const Color(0xFF6366F1).withOpacity(0.35)
                    : const Color(0xFFE2E8F0),
                width: isExpanded && !isLocked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isLocked ? 0.02 : 0.04),
                  blurRadius: isExpanded && !isLocked ? 14 : 8,
                  offset: const Offset(0, 2),
                ),
                if (isExpanded && !isLocked)
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFFE2E8F0)
                        : isExpanded
                        ? const Color(0xFF6366F1).withOpacity(0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLocked
                      ? Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: Colors.grey.shade600,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isExpanded
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF64748B),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    module.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.25,
                      color: isLocked
                          ? const Color(0xFF94A3B8)
                          : isExpanded
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Locked',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 24,
                    color: isExpanded
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF94A3B8),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded && !isLocked)
          ...module.lessons
              .map((lesson) => _buildLessonItem(lesson, index))
              .toList(),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }

  Widget _buildLessonItem(LessonItem lesson, int moduleIndex) {
    return Container(
      margin: const EdgeInsets.only(left: 28, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide.none,
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.play_circle_outline_rounded,
            color: Color(0xFF6366F1),
            size: 20,
          ),
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.3,
            color: Color(0xFF334155),
          ),
        ),
        children: lesson.materials
            .map((material) => _buildMaterialItem(material, moduleIndex))
            .toList(),
      ),
    );
  }

  Widget _buildMaterialItem(MaterialItem material, int moduleIndex) {
    Color color;
    String typeLabel;
    switch (material.type.toLowerCase()) {
      case 'video':
        color = const Color(0xFF6366F1);
        typeLabel = 'VIDEO TRAINING';
        break;
      case 'pdf':
        color = const Color(0xFFEF4444);
        typeLabel = 'PDF WORKBOOK';
        break;
      default:
        color = const Color(0xFF64748B);
        typeLabel = 'RESOURCE';
    }

    final isCompleted = material.isCompleted;
    final isDownloaded = _localFiles.containsKey(material.id);
    final isDownloading = _downloadProgress.containsKey(material.id);
    final isLocked = _isModuleLocked(moduleIndex);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFF0FDF4).withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withOpacity(0.2)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMaterial(material, moduleIndex),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail first (visual anchor)
                _buildMaterialThumbnail(material),
                const SizedBox(width: 14),
                // Type badge + title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey.withOpacity(0.1)
                              : color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isLocked ? Colors.grey : color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        material.title ?? 'Untitled Resource',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: isLocked
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF334155),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: const Color(0xFF10B981),
                        ),
                      ),
                      if (isDownloading) ...[
                        const SizedBox(height: 6),
                        _DownloadProgressBar(
                          materialId: material.id,
                          progressMap: _downloadProgress,
                        ),
                      ] else if (isDownloaded) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.offline_pin_rounded,
                              color: const Color(0xFF10B981),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Saved offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Completion: circular checkbox (clear when done)
                GestureDetector(
                  onTap: isLocked ? null : () => _toggleCompletion(material),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.check_rounded,
                      size: 16,
                      color: isCompleted ? Colors.white : Colors.transparent,
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

  /// Builds full URL for a thumbnail path (relative or absolute).
  String? _fullThumbnailUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.contains('://')) return path;

    final trimmed = path.trim();
    final base = ApiEndpoints.baseUrl.replaceAll('/api', '');

    if (trimmed.startsWith('/')) {
      return '$base$trimmed';
    }

    return '$base/storage/$trimmed';
  }

  String _resolveMaterialUrl(String path) {
    final trimmedPath = path.trim();
    if (trimmedPath.contains('://')) return trimmedPath;

    final root = ApiEndpoints.baseUrl.replaceAll('/api', '');
    final normalizedPath = trimmedPath.startsWith('/')
        ? trimmedPath
        : '/$trimmedPath';

    if (normalizedPath.startsWith('/api/stream/')) {
      return '$root$normalizedPath';
    }

    if (normalizedPath.startsWith('/storage/')) {
      return '$root$normalizedPath';
    }

    if (normalizedPath.contains('course-assets/')) {
      final filename = normalizedPath.split('/').last;
      return '$root/api/stream/$filename';
    }

    return '$root/storage${normalizedPath.startsWith('/storage/') ? '' : normalizedPath}';
  }

  /// For video materials without thumbnail_url, try derived URLs (e.g. same name with _thumb.jpg).
  List<String> _videoThumbnailCandidates(MaterialItem material) {
    final candidates = <String>[];
    if (material.thumbnailUrl != null && material.thumbnailUrl!.isNotEmpty) {
      candidates.add(material.thumbnailUrl!);
    }
    if (_course?.thumbnailUrl != null && _course!.thumbnailUrl!.isNotEmpty) {
      candidates.add(_course!.thumbnailUrl!);
    }
    final url = material.url;
    if (material.type.toLowerCase() == 'video' &&
        url != null &&
        url.isNotEmpty) {
      // Try common thumbnail naming: 1080.mp4 -> 1080_thumb.jpg, 1080.jpg, or thumbnails/1080.jpg
      final withoutExt = url.replaceAll(RegExp(r'\.(mp4|webm|mov)$'), '');
      final filename = withoutExt.split('/').last;
      if (filename.isNotEmpty) {
        if (url.contains('course-assets/')) {
          candidates.add('course-assets/${filename}_thumb.jpg');
          candidates.add('course-assets/${filename}.jpg');
          candidates.add('course-assets/thumbnails/$filename.jpg');
        }
      }
    }
    return candidates;
  }

  Widget _buildMaterialThumbnail(MaterialItem material) {
    final isVideo = material.type.toLowerCase() == 'video';
    final rawCandidates = isVideo
        ? _videoThumbnailCandidates(material)
        : [
            if (material.thumbnailUrl != null &&
                material.thumbnailUrl!.isNotEmpty)
              material.thumbnailUrl!,
            if (_course?.thumbnailUrl != null &&
                _course!.thumbnailUrl!.isNotEmpty)
              _course!.thumbnailUrl!,
          ];
    final urls = rawCandidates
        .map((p) => _fullThumbnailUrl(p))
        .whereType<String>()
        .toList();

    if (urls.isEmpty) {
      return _materialThumbnailPlaceholder(material);
    }

    return _TryThumbnailUrls(
      urls: urls,
      placeholder: _materialThumbnailPlaceholder(material),
    );
  }

  /// Placeholder when no thumbnail loads. For video: frame + play icon so it's clearly a video.
  Widget _materialThumbnailPlaceholder(MaterialItem material) {
    final isVideo = material.type.toLowerCase() == 'video';
    if (isVideo) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F46E5),
              const Color(0xFF6366F1),
              const Color(0xFF4338CA),
            ],
          ),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF6366F1),
              size: 22,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
      ),
      child: const Icon(
        Icons.picture_as_pdf_rounded,
        color: Color(0xFFEF4444),
        size: 26,
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

  Future<void> _openMaterial(MaterialItem material, int moduleIndex) async {
    if (material.url == null) return;
    if (_isModuleLocked(moduleIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete all videos in Module $moduleIndex to unlock.',
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (material.type.toLowerCase() == 'video') {
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
        final materialUrl = _resolveMaterialUrl(material.url!);
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
        final videoUrl = _resolveMaterialUrl(material.url!);
        final encodedUrl = Uri.encodeFull(videoUrl);
        debugPrint('[Integrated Player] Target STREAM: $encodedUrl');
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(encodedUrl),
        );
      }
      // Automatic progress tracking & completion
      _videoPlayerController!.addListener(_onPlayerEvent);

      await _videoPlayerController!.initialize();

      // Resume from saved position. Delay + clamped position reduce Android media
      // pipeline log noise (Spurious audio timestamp, CCodecBufferChannel stale buffer /
      // Discard frames) when seeking on emulator or some devices—these are harmless.
      if (material.progressSeconds > 0 && !material.isCompleted) {
        final durationSec = _videoPlayerController!.value.duration.inSeconds;
        final startSec = durationSec > 1
            ? material.progressSeconds.clamp(0, durationSec - 1)
            : (durationSec == 1 ? 0 : material.progressSeconds);
        debugPrint(
          '[Integrated Player] RESUMING FROM: ${startSec}s (saved: ${material.progressSeconds}s)',
        );
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted || _videoPlayerController == null) return;
        await _videoPlayerController!.seekTo(Duration(seconds: startSec));
      }

      // Cinematic Thumbnail Integration
      Widget? placeholder;
      if (material.thumbnailUrl != null) {
        final thumbUrl = _fullThumbnailUrl(material.thumbnailUrl!);
        if (thumbUrl != null && thumbUrl.isNotEmpty) {
          debugPrint('[Integrated Player] Thumbnail: $thumbUrl');
          placeholder = Image.network(
            thumbUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          );
        }
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: true,
        placeholder: placeholder,
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

  void _onPlayerEvent() {
    if (_videoPlayerController == null || _playingMaterial == null) return;

    final currentPos = _videoPlayerController!.value.position.inSeconds;
    final totalDuration = _videoPlayerController!.value.duration.inSeconds;

    // Completion: consider done when at end or within last 2 seconds (player timing can be slightly off)
    final atEnd =
        totalDuration > 0 &&
        (currentPos >= totalDuration || currentPos >= totalDuration - 2);
    if (atEnd && !(_playingMaterial!.isCompleted)) {
      _markAsCompleted(_playingMaterial!);
      _videoPlayerController!.removeListener(_onPlayerEvent);
      return;
    }

    // SAVING PROGRESS (Throttle to every 5 seconds)
    if (currentPos > 0 &&
        currentPos != _lastSavedProgress &&
        currentPos % 5 == 0) {
      _lastSavedProgress = currentPos;
      LearningApi.updateMaterialProgress(
        materialId: _playingMaterial!.id,
        progressSeconds: currentPos,
      );
    }
  }

  Future<void> _downloadMaterial(MaterialItem material) async {
    if (material.url == null) return;

    // NO PERMISSION NEEDED FOR APP-INTERNAL STORAGE (Improved User Experience)

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting high-speed download: ${material.title}...'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );

    String downloadUrl = material.url!;
    downloadUrl = _resolveMaterialUrl(downloadUrl);

    final String extension = material.type.toLowerCase() == 'video'
        ? 'mp4'
        : 'pdf';
    final String fileName =
        'material_${material.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String savePath = '${appDocDir.path}/$fileName';
      final dio = Dio();

      int lastUpdate = 0;
      await dio.download(
        Uri.encodeFull(downloadUrl),
        savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastUpdate > 500 || count == total) {
              lastUpdate = now;
              if (mounted) {
                setState(() => _downloadProgress[material.id] = count / total);
              }
            }
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

  Future<void> _deleteDownloadedMaterial(MaterialItem material) async {
    try {
      final path = _localFiles[material.id];
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('offline_material_${material.id}');

        setState(() {
          _localFiles.remove(material.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline files purged.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Purge error: $e');
    }
  }

  Future<void> _markAsCompleted(
    MaterialItem material, {
    int? moduleIndex,
  }) async {
    final idx = moduleIndex ?? _getModuleIndexForMaterial(material.id);
    final wasModuleAlreadyComplete = idx != null && _isModuleCompleted(idx);
    try {
      await LearningApi.updateMaterialProgress(
        materialId: material.id,
        isCompleted: true,
      );
      await _loadCourseDetails();
      // Show points only when this completion just made the module complete
      if (idx != null &&
          !wasModuleAlreadyComplete &&
          mounted &&
          _isModuleCompleted(idx)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Module ${idx + 1} completed! +$_pointsPerModule points',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Completion tracking failed: $e');
    }
  }
}

/// Tries each thumbnail URL in order; shows placeholder when all fail.
class _TryThumbnailUrls extends StatefulWidget {
  final List<String> urls;
  final Widget placeholder;

  const _TryThumbnailUrls({required this.urls, required this.placeholder});

  @override
  State<_TryThumbnailUrls> createState() => _TryThumbnailUrlsState();
}

class _TryThumbnailUrlsState extends State<_TryThumbnailUrls> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.placeholder;
    final url = widget.urls[_index];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (_index + 1 < widget.urls.length && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _index++);
              });
              return Container(
                width: 56,
                height: 56,
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return widget.placeholder;
          },
        ),
      ),
    );
  }
}

// --- ISOLATED HIGH-PERFORMANCE WIDGETS ---

class _DownloadProgressBar extends StatelessWidget {
  final int materialId;
  final Map<int, double> progressMap;

  const _DownloadProgressBar({
    required this.materialId,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    // This widget listens to the map specifically for its own ID
    final progress = progressMap[materialId] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF1F5F9),
            color: const Color(0xFF6366F1),
            minHeight: 3.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SAVING ${(progress * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgressBadge extends StatelessWidget {
  final int materialId;
  final Map<int, double> progressMap;

  const _DownloadProgressBadge({
    required this.materialId,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = progressMap[materialId] ?? 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SAVING ${(progress * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }
}
