// ignore_for_file: unnecessary_underscores

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
          _countdownTimer?.cancel();
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

  String _formatCountdown(DateTime scheduledAtUtc) {
    final scheduled = scheduledAtUtc.toLocal();
    final now = DateTime.now();
    final diff = scheduled.difference(now);

    if (diff.isNegative) {
      final elapsed = now.difference(scheduled);
      if (elapsed.inHours < 24) return 'Live now';
      return 'Session ended';
    }
    if (diff.inDays > 0) {
      return 'Starts in ${diff.inDays}d ${diff.inHours.remainder(24)}h';
    }
    if (diff.inHours > 0) {
      return 'Starts in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return 'Starts in ${diff.inMinutes}m';
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final singleWebinar = _webinars.length == 1;
    final carouselCardWidth = (screenWidth * 0.86).clamp(300.0, 420.0);

    final Widget webinarBody = singleWebinar
        ? _WebinarCard(
            webinar: _webinars.first,
            isDark: isDark,
            fullWidth: true,
            countdownText: _webinars.first.scheduledAt != null
                ? _formatCountdown(_webinars.first.scheduledAt!)
                : null,
            localTimeLabel: _webinars.first.localScheduleLabel(),
            onJoin: () => _openLink(_webinars.first.zoomLink),
          )
        : SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: _webinars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final w = _webinars[index];
                return SizedBox(
                  width: carouselCardWidth,
                  child: _WebinarCard(
                    webinar: w,
                    isDark: isDark,
                    fullWidth: false,
                    countdownText: w.scheduledAt != null
                        ? _formatCountdown(w.scheduledAt!)
                        : null,
                    localTimeLabel: w.localScheduleLabel(),
                    onJoin: () => _openLink(w.zoomLink),
                  ),
                );
              },
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              const SizedBox(width: 8),
              Text(
                singleWebinar ? 'Upcoming webinar' : 'Upcoming webinars',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
        webinarBody.animate().fadeIn(delay: 260.ms).slideY(begin: 0.06),
      ],
    );
  }
}

class _WebinarCard extends StatelessWidget {
  final Webinar webinar;
  final bool isDark;
  final bool fullWidth;
  final String? countdownText;
  final String? localTimeLabel;
  final VoidCallback onJoin;

  const _WebinarCard({
    required this.webinar,
    required this.isDark,
    required this.fullWidth,
    required this.countdownText,
    this.localTimeLabel,
    required this.onJoin,
  });

  Color _accentColor() {
    if (webinar.isPromotional) return const Color(0xFFF59E0B);
    switch (webinar.targetTier) {
      case 'Titan':
        return const Color(0xFF8B5CF6);
      case 'Rainmaker':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6366F1);
    }
  }

  bool get _isLive =>
      countdownText != null &&
      (countdownText!.toLowerCase().contains('live') ||
          countdownText!.toLowerCase().contains('started'));

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final hasImage = webinar.imageUrl != null && webinar.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: webinar.zoomLink != null ? onJoin : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.95),
                accent.withValues(alpha: 0.72),
                const Color(0xFF0F172A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasImage)
                  SizedBox(
                    height: fullWidth ? 120 : 96,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          webinar.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    fullWidth ? 20 : 18,
                    hasImage ? 16 : 18,
                    fullWidth ? 20 : 18,
                    fullWidth ? 20 : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (webinar.isPromotional)
                            _badge('Promo', const Color(0xFFF59E0B)),
                          if (webinar.targetTier != null &&
                              webinar.targetTier!.isNotEmpty &&
                              webinar.targetTier != 'Consultant')
                            _badge(webinar.targetTier!, accent),
                          if (countdownText != null)
                            _badge(
                              countdownText!,
                              _isLive
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withValues(alpha: 0.16),
                              textColor: Colors.white,
                              icon: _isLive
                                  ? Icons.circle
                                  : Icons.schedule_rounded,
                              iconSize: _isLive ? 8 : 12,
                            ),
                        ],
                      ),
                      SizedBox(height: fullWidth ? 14 : 12),
                      Text(
                        webinar.title,
                        maxLines: fullWidth ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fullWidth ? 19 : 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (webinar.description != null &&
                          webinar.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          webinar.description!.trim(),
                          maxLines: fullWidth ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (localTimeLabel != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localTimeLabel!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: fullWidth ? 16 : 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: webinar.zoomLink != null ? onJoin : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: accent,
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.35),
                            padding: EdgeInsets.symmetric(
                              vertical: fullWidth ? 14 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            webinar.zoomLink != null
                                ? Icons.videocam_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            webinar.zoomLink != null ? 'Join webinar' : 'Details',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }

  Widget _badge(
    String label,
    Color color, {
    Color textColor = Colors.white,
    IconData? icon,
    double iconSize = 12,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
