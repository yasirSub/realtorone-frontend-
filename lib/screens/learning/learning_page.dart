// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/learning_model.dart';
import '../../routes/app_routes.dart';
import '../../api/learning_api.dart';
import '../../widgets/skill_skeleton.dart';
import '../../widgets/elite_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_endpoints.dart';
import '../../api/app_config.dart';
import 'pdf_viewer_page.dart';
import '../../utils/authenticated_media_url.dart';
import '../../utils/responsive_helper.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _userTier = 'Consultant';
  List<ModuleModel> _modules = [];
  List<EbookModel> _ebooks = [];
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch modules with courses
      final courseRes = await LearningApi.getCourses();
      if (courseRes['success'] == true) {
        final List<dynamic> data = courseRes['data'] ?? [];
        _modules = data.map((json) => ModuleModel.fromJson(json)).toList();
        _userTier = courseRes['user_tier'] ?? 'Consultant';
      }

      // Fetch ebooks
      final ebookRes = await LearningApi.getEbooks();
      if (ebookRes['success'] == true) {
        final List<dynamic> data = ebookRes['data'] ?? [];
        _ebooks = data.map((json) => EbookModel.fromJson(json)).toList();
      }

      final certRes = await LearningApi.getMyCertificates();
      if (certRes['success'] == true && certRes['data'] is List) {
        _certificates = (certRes['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _certificates = [];
      }

      // Simulate real API latency
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading learning data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isPremium => _userTier.toLowerCase() != 'free';

  int _getTierWeight(String tier) {
    switch (tier.toLowerCase()) {
      case 'titan':
        return 3;
      case 'rainmaker':
        return 2;
      case 'consultant':
        return 1;
      case 'free':
        return 0;
      default:
        return 1; // Default to consultant for safety
    }
  }

  bool _isTierUnlocked(String requiredTier) {
    return _getTierWeight(_userTier) >= _getTierWeight(requiredTier);
  }

  String _resolveAssetUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Use AppConfig.apiOrigin so we only strip the trailing `/api` from the
    // base URL — `baseUrl.replaceAll('/api', '')` mangles the host because the
    // production API lives at `https://api.aanantbishthealing.com/api`.
    final host = AppConfig.apiOrigin;
    if (trimmed.startsWith('/')) {
      return '$host$trimmed';
    }

    return '$host/storage/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: const Color(0xFF1E293B),
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: _openCertificatesSheet,
                  tooltip: 'My certificates',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      if (_certificates.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF1E293B),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text(
                  'LEARNING HUB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
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
                          colors: [
                            Color(0xFF1E293B),
                            Color(0xFF2D2348),
                            Color(0xFF764ba2),
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -24,
                      top: -20,
                      child: Opacity(
                        opacity: 0.18,
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 200,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    // HUD Overlay – stats row
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildMiniBadge(
                              'RANK',
                              _userTier.toUpperCase(),
                              const Color(0xFF4ECDC4),
                              Icons.verified_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicatorColor: const Color(0xFF667eea),
                  indicatorWeight: 4,
                  labelColor: const Color(0xFF1E293B),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                  tabs: const [
                    Tab(text: 'COURSES'),
                    Tab(text: 'E-BOOKS'),
                  ],
                ),
              ),
            ),
          ],
          body: Container(
            color: const Color(0xFFF8FAFC),
            child: TabBarView(
              children: [
                // COURSES TAB
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF6366F1),
                  child: _isLoading
                      ? const Center(child: EliteLoader())
                      : _buildTieredList(),
                ),
                // E-BOOKS TAB
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF6366F1),
                  child: _isLoading
                      ? const Center(child: EliteLoader())
                      : _buildEbookList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO BLUEPRINTS UNLOCKED',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to the next tier for new content.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTieredList() {
    final List<String> tiers = ['Consultant', 'Rainmaker', 'Titan'];

    // Gather all courses from all modules
    final allCourses = <CourseModel>[];
    for (var module in _modules) {
      allCourses.addAll(module.courses);
    }

    return ListView.builder(
      padding: ResponsiveHelper.contentPadding(context, top: 24, bottom: 140),
      itemCount: tiers.length,
      itemBuilder: (context, index) {
        final tier = tiers[index];

        // Filter courses by their OWN minTier property
        final tierCourses = allCourses
            .where((c) => c.minTier.toLowerCase() == tier.toLowerCase())
            .toList();

        if (tierCourses.isEmpty) return const SizedBox.shrink();

        return ResponsiveHelper.constrainWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // TIER HEADER (The User wants Tiers as the separation)
            _buildTierSectionHeader(tier),
            const SizedBox(height: 12),
            // Courses under this Tier
            ...tierCourses.map((course) {
              return _buildCourseCard(course, _getTierColor(tier));
            }),
            const SizedBox(height: 12),
          ],
        ),);
      },
    );
  }

  Widget _buildEbookList() {
    final List<String> tiers = ['Consultant', 'Rainmaker', 'Titan'];

    return ListView.builder(
      padding: ResponsiveHelper.contentPadding(context, top: 24, bottom: 140),
      itemCount: tiers.length,
      itemBuilder: (context, index) {
        final tier = tiers[index];

        final tierEbooks = _ebooks
            .where((e) => e.minTier.toLowerCase() == tier.toLowerCase())
            .toList();

        if (tierEbooks.isEmpty) return const SizedBox.shrink();

        return ResponsiveHelper.constrainWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildTierSectionHeader(tier),
            const SizedBox(height: 12),
            ...tierEbooks.map((ebook) {
              return _buildEbookCard(ebook, _getTierColor(tier));
            }),
            const SizedBox(height: 12),
          ],
        ),);
      },
    );
  }
  Widget _buildEbookCard(EbookModel ebook, Color tierColor) {
    final bool isOffline = !ebook.isPublished;
    final bool isLocked = !isOffline && !_isTierUnlocked(ebook.minTier);

    return Opacity(
      opacity: isOffline ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isOffline) {
                // Do nothing
                return;
              }
              if (isLocked) {
                _showUpgradePrompt(ebook.minTier);
              } else {
                _openEbook(ebook);
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Ebook Thumbnail
                      Container(
                        width: 80,
                        height: 110,
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          image: ebook.thumbnailUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                    _resolveAssetUrl(ebook.thumbnailUrl!),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: ebook.thumbnailUrl == null
                            ? Center(
                                child: Icon(
                                  Icons.book_rounded,
                                  color: tierColor,
                                  size: 32,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ebook.title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isOffline)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'OFFLINE',
                                      style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else if (isLocked)
                                  Icon(
                                    Icons.lock_rounded,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ebook.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tierColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'PDF ASSET',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: tierColor,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  isOffline ? 'COMING SOON' : (isLocked ? 'LOCKED - GET ACCESS' : 'READ NOW'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isOffline
                                        ? Colors.grey
                                        : (isLocked
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF6366F1)),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (!isOffline && isLocked)
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Color(0xFF6366F1),
                                    size: 10,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEbook(EbookModel ebook) async {
    if (ebook.fileUrl == null) return;
    final base = _resolveAssetUrl(ebook.fileUrl!);
    final url = await AuthenticatedMediaUrl.resolve(base);
    final headers = await AuthenticatedMediaUrl.streamHeaders();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(
          title: ebook.title,
          url: url,
          headers: headers,
        ),
      ),
    );
  }

  void _showUpgradeDialog(String tier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'ASSET ENCRYPTED',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'This elite strategy asset is reserved for $tier members. Upgrade your subscription to gain access.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'DISMISS',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              // Navigate to subscription
            },
            child: const Text(
              'VIEW TIERS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'titan':
        return const Color(0xFFF59E0B);
      case 'rainmaker':
        return const Color(0xFF6366F1);
      case 'consultant':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366f1);
    }
  }

  Widget _buildTierSectionHeader(String tier) {
    final color = _getTierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            '${tier.toUpperCase()} LEVEL ASSETS',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradePrompt(String tierName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.lock_person_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'LOCKED ASSET • UPGRADE TO ${tierName.toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'UNLOCK NOW',
          textColor: const Color(0xFF4ECDC4),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.subscriptionPlans),
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course, Color moduleColor) {
    final bool isOffline = !course.isPublished;
    final bool isLocked = !isOffline && (course.isLocked && !_isTierUnlocked(course.minTier));

    return Opacity(
      opacity: isOffline ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 90, // Fixed height for absolute rendering stability
        decoration: BoxDecoration(
          color: (isLocked || isOffline) ? Colors.white.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: moduleColor.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            if (isOffline) {
              // Do nothing
              return;
            }
            _openCourse(course);
          },
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                // Fixed Size Side Thumbnail
                Container(
                  width: 100,
                  height: 90,
                  color: moduleColor.withOpacity(0.1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (course.thumbnailUrl != null &&
                          course.thumbnailUrl!.isNotEmpty)
                        Image.network(
                          _resolveAssetUrl(course.thumbnailUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.grey,
                              ),
                        )
                      else
                        Center(
                          child: Icon(
                            (isLocked || isOffline)
                                ? Icons.lock_outline_rounded
                                : Icons.play_circle_fill_rounded,
                            color: moduleColor.withOpacity(0.4),
                            size: 32,
                          ),
                        ),
                      if (isOffline)
                        Container(
                          color: Colors.black.withOpacity(0.1),
                          child: const Center(
                            child: Text(
                              'OFFLINE',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else if (isLocked)
                        Container(
                          color: Colors.white.withOpacity(0.3),
                          child: const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF64748B),
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
  
                // Course Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: (isLocked || isOffline)
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF1E293B),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTierPill(course.minTier, isLocked: (isLocked || isOffline)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.description,
                          style: TextStyle(
                            color: (isLocked || isOffline) ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 10,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isLocked && !isOffline && course.progressPercent > 0) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: course.progressPercent / 100,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                moduleColor,
                              ),
                              minHeight: 2,
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

  Widget _buildTierPill(String tier, {bool isLocked = false}) {
    Color color;
    switch (tier.toLowerCase()) {
      case 'titan':
        color = const Color(0xFFF59E0B); // Amber
        break;
      case 'rainmaker':
        color = const Color(0xFF6366F1); // Indigo
        break;
      case 'consultant':
        color = const Color(0xFF10B981); // Emerald
        break;
      default:
        color = const Color(0xFF64748B); // Slate
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLocked
              ? Colors.grey.withOpacity(0.2)
              : color.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: isLocked ? Colors.grey : color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMiniBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Future<void> _openCertificateUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCertificatesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: _certificates.isEmpty ? 0.45 : 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFF6366F1),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'My Certificates',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildCertificatesList(
                      scrollController: scrollController,
                      onGoToCourses: () {
                        Navigator.pop(sheetContext);
                        DefaultTabController.of(context).animateTo(0);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCertificatesList({
    ScrollController? scrollController,
    VoidCallback? onGoToCourses,
  }) {
    if (_certificates.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO CERTIFICATES YET',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Complete a course and pass the test to earn your certificate. You can also download it from the course page.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onGoToCourses ?? () => DefaultTabController.of(context).animateTo(0),
            child: const Text(
              'Go to Courses',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final c = _certificates[index];
        final title = c['course_title']?.toString() ?? 'Course';
        final courseId = c['course_id'] as int?;
        final pdfUrl = c['pdf_url'] as String?;
        final htmlUrl = c['html_url'] as String?;
        final certNo = c['certificate_number']?.toString() ?? '';
        final score = c['score_percent'];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFF6366F1),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (certNo.isNotEmpty)
                          Text(
                            certNo,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        if (score != null)
                          Text(
                            'Score: $score%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (pdfUrl != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openCertificateUrl(pdfUrl),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (pdfUrl != null && htmlUrl != null) const SizedBox(width: 8),
                  if (htmlUrl != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openCertificateUrl(htmlUrl),
                        child: const Text('View'),
                      ),
                    ),
                ],
              ),
              if (courseId != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.courseCurriculum,
                      arguments: {
                        'courseId': courseId,
                        'courseTitle': title,
                      },
                    );
                  },
                  child: const Text('Open course'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCourse(CourseModel course) async {
    final bool isLocked = course.isLocked && !_isTierUnlocked(course.minTier);
    if (isLocked) {
      _showUpgradePrompt(course.minTier);
      return;
    }

    // Navigate to course curriculum
    Navigator.pushNamed(
      context,
      AppRoutes.courseCurriculum,
      arguments: {'courseId': course.id, 'courseTitle': course.title},
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
