import 'package:flutter/material.dart';

import '../../api/activities_api.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class HomeActivityLogWidget extends StatefulWidget {
  const HomeActivityLogWidget({super.key});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final bodyColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final visibleActivities = _todayActivities.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activityLogTitle,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.activityLogSubtitle,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.activities),
                child: Text(l10n.activityLogOpen),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                label: l10n.activityLogStreak,
                value: '$_currentStreak',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                label: l10n.activityLogPoints,
                value: '$_todayPoints',
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const SizedBox(height: 84, child: Center(child: EliteLoader()))
          else if (visibleActivities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                      padding: const EdgeInsets.only(bottom: 10),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
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
    final subtitle = (activity['category'] ?? 'Progress update').toString();
    final points = (activity['points'] ?? 0).toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
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
