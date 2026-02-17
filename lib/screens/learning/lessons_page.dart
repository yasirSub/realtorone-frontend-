import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/learning_api.dart';
import '../../models/learning_model.dart';
import '../../widgets/skill_skeleton.dart';

class LessonsPage extends StatefulWidget {
  final String categoryName;
  final String categoryTitle;

  const LessonsPage({
    super.key,
    required this.categoryName,
    required this.categoryTitle,
  });

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  bool _isLoading = true;
  List<LearningContent> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final response = await LearningApi.getContent(
        category: widget.categoryName,
      );
      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        _lessons = data.map((json) => LearningContent.fromJson(json)).toList();
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: SkillSkeleton(itemCount: 5)),
            )
          else if (_lessons.isEmpty)
            _buildEmptyState()
          else
            _buildLessonsList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F172A),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.categoryTitle.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                Icons.school_rounded,
                size: 200,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'NO LESSONS YET',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Training content is being deployed.',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsList() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final lesson = _lessons[index];
          return _buildLessonCard(lesson, index);
        }, childCount: _lessons.length),
      ),
    );
  }

  Widget _buildLessonCard(LearningContent lesson, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openLesson(lesson),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildTypeIcon(lesson.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lesson.durationMinutes} MIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (lesson.isCompleted) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 32,
                color: const Color(0xFF6366F1).withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
  }

  Widget _buildTypeIcon(ContentType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case ContentType.video:
        iconData = Icons.play_lesson_rounded;
        color = const Color(0xFF6366F1);
        break;
      case ContentType.audio:
        iconData = Icons.headphones_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case ContentType.article:
        iconData = Icons.article_rounded;
        color = const Color(0xFF10B981);
        break;
      case ContentType.quiz:
        iconData = Icons.quiz_rounded;
        color = const Color(0xFFEC4899);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 22),
    );
  }

  void _openLesson(LearningContent lesson) {
    // For now, show a snackbar or simple detail view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: ${lesson.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
