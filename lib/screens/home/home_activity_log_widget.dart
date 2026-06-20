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
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    const accent = Color(0xFF667EEA);
    final visibleActivities = _todayActivities.take(3).toList();
    final completedCount = _todayActivities.where((activity) {
      return activity['is_completed'] == true || activity['is_completed'] == 1;
    }).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_todayPoints points today',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completedCount == 0
                          ? l10n.activityLogEmpty
                          : '$completedCount activit${completedCount == 1 ? 'y' : 'ies'} logged',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const SizedBox(height: 88, child: Center(child: EliteLoader()))
          else if (visibleActivities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 28,
                    color: bodyColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.activityLogEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openActivities,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                l10n.activityLogOpen,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
    final statusColor =
        isCompleted ? const Color(0xFF10B981) : const Color(0xFF667eea);

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
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.schedule_rounded,
              color: statusColor,
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
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
