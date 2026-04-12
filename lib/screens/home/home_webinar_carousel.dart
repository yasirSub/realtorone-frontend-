import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../models/webinar.dart';

class HomeWebinarCarousel extends StatefulWidget {
  const HomeWebinarCarousel({super.key});

  @override
  State<HomeWebinarCarousel> createState() => _HomeWebinarCarouselState();
}

class _HomeWebinarCarouselState extends State<HomeWebinarCarousel> {
  List<Webinar> _webinars = [];
  bool _isLoading = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadWebinars();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWebinars() async {
    try {
      final res = await ApiClient.getWebinars();
      if (mounted && res['success'] == true) {
        final data = res['data'];
        if (data is List) {
          setState(() {
            _webinars = data
                .whereType<Map>()
                .map((e) => Webinar.fromJson(Map<String, dynamic>.from(e)))
                .where((w) => w.isActive)
                .toList();
          });
          // Refresh countdown every minute
          _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
            if (mounted) setState(() {});
          });
        }
      }
    } catch (_) {
      // Silently fail — section is hidden when empty
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCountdown(DateTime scheduledAt) {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now);

    if (diff.isNegative) {
      final elapsed = now.difference(scheduledAt);
      if (elapsed.inHours < 24) return 'Live / Just started';
      return 'Session ended';
    }
    if (diff.inDays > 0) return 'In ${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) return 'In ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    return 'Starting in ${diff.inMinutes}m';
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _webinars.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'UPCOMING WEBINARS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _webinars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final w = _webinars[index];
              return _WebinarCard(
                webinar: w,
                isDark: isDark,
                countdownText: w.scheduledAt != null ? _formatCountdown(w.scheduledAt!) : null,
                onJoin: () => _openLink(w.zoomLink),
              ).animate().fadeIn(delay: Duration(milliseconds: 300 + index * 80)).slideX(begin: 0.2);
            },
          ),
        ),
      ],
    );
  }
}

class _WebinarCard extends StatelessWidget {
  final Webinar webinar;
  final bool isDark;
  final String? countdownText;
  final VoidCallback onJoin;

  const _WebinarCard({
    required this.webinar,
    required this.isDark,
    required this.countdownText,
    required this.onJoin,
  });

  Color _tierColor() {
    switch (webinar.targetTier) {
      case 'Titan': return const Color(0xFF8B5CF6);
      case 'Rainmaker': return const Color(0xFF3B82F6);
      default: return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = webinar.isPromotional ? const Color(0xFFF59E0B) : _tierColor();

    return GestureDetector(
      onTap: webinar.zoomLink != null ? onJoin : null,
      child: Container(
        width: 290,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.85),
              accent.withValues(alpha: 0.6),
              const Color(0xFF0F172A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background thumbnail if provided
            if (webinar.imageUrl != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    webinar.imageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.55),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (webinar.isPromotional)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PROMO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (countdownText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                countdownText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    webinar.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  if (webinar.description != null && webinar.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      webinar.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: webinar.zoomLink != null ? onJoin : null,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        webinar.zoomLink != null ? 'JOIN NOW' : 'DETAILS',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
