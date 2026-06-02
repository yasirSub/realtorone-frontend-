import 'package:flutter/material.dart';

import '../../api/activities_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class HomeActivityLogWidget extends StatefulWidget {
  const HomeActivityLogWidget({super.key, this.onOpenActivities});

  final VoidCallback? onOpenActivities;

  @override
  State<HomeActivityLogWidget> createState() => _HomeActivityLogWidgetState();
}

class _HomeActivityLogWidgetState extends State<HomeActivityLogWidget> {
  bool _isLoading = true;
  int _currentStreak = 0;
  int _todayPoints = 0;
  List<Map<String, dynamic>> _todayActivities = [];

  @override
  void initState() {
    super.initState();
    _loadActivityLog();
  }

  Future<void> _loadActivityLog() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final activitiesResponse = await ActivitiesApi.getActivities();
      final progressResponse = await ActivitiesApi.getProgress();

      if (!mounted) {
        return;
      }

      setState(() {
        if (activitiesResponse['success'] == true) {
          _todayActivities = List<Map<String, dynamic>>.from(
            activitiesResponse['data'] ?? [],
          );
          _todayPoints = 0;
          for (final activity in _todayActivities) {
            final isCompleted =
                activity['is_completed'] == true ||
                activity['is_completed'] == 1;
            if (!isCompleted) {
              continue;
            }

            final rawPoints = activity['points'];
            if (rawPoints is num) {
              _todayPoints += rawPoints.toInt();
            } else if (rawPoints is String) {
              _todayPoints += int.tryParse(rawPoints) ?? 0;
            }
          }
        }

        if (progressResponse['success'] == true) {
          _currentStreak = progressResponse['data']?['current_streak'] ?? 0;
        }

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading home activity log: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openActivities() {
    if (widget.onOpenActivities != null) {
      widget.onOpenActivities!();
      return;
    }
    Navigator.pushNamed(context, AppRoutes.activities);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final bodyColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final ctaAccent = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    final ctaSurface = ctaAccent.withValues(alpha: isDark ? 0.2 : 0.1);
    final ctaBorder = ctaAccent.withValues(alpha: isDark ? 0.42 : 0.25);
    final ctaText = isDark ? const Color(0xFFEDE9FE) : ctaAccent;
    final visibleActivities = _todayActivities.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      label: l10n.activityLogStreak,
                      value: '$_currentStreak',
                      color: const Color(0xFFF59E0B),
                    ),
                    _buildStatChip(
                      label: l10n.activityLogPoints,
                      value: '$_todayPoints',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openActivities,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ctaSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ctaBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.activityLogOpen,
                          style: TextStyle(
                            color: ctaText,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ctaAccent.withValues(alpha: isDark ? 0.3 : 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: ctaText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const SizedBox(height: 84, child: Center(child: EliteLoader()))
          else if (visibleActivities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                l10n.activityLogEmpty,
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: visibleActivities
                  .map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildActivityTile(activity, isDark),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final compactLabel = label.length > 8 ? '${label.substring(0, 8)}.' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            compactLabel,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity, bool isDark) {
    final isCompleted =
        activity['is_completed'] == true || activity['is_completed'] == 1;
    final title = (activity['title'] ?? activity['type'] ?? 'Activity')
        .toString();
    final subtitle = (activity['category'] ?? '').toString();
    final showSubtitle =
        subtitle.trim().isNotEmpty &&
        subtitle.trim().toLowerCase() != 'activity' &&
        subtitle.trim().toLowerCase() != title.trim().toLowerCase();
    final points = (activity['points'] ?? 0).toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFF667eea))
                      .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.schedule_rounded,
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : const Color(0xFF667eea),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$points',
            style: TextStyle(
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : const Color(0xFF667eea),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
