import 'package:flutter/material.dart';

import '../theme/realtorone_brand.dart';

int aiCoachInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

String aiCoachFmtLimit(int n) => n <= 0 ? 'Unlimited' : n.toString();

double aiCoachBarFrac(int used, int limit) {
  if (limit <= 0) return used > 0 ? 0.12 : 0;
  return (used / limit).clamp(0.0, 1.0);
}

Widget aiCoachUsageMeter({
  required String label,
  required int used,
  required String limitLabel,
  required int? remaining,
  required double fraction,
  required bool isDark,
  Color accent = const Color(0xFF6366F1),
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            '$used / $limitLabel TK${remaining != null ? ' · $remaining left' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
          minHeight: 8,
          backgroundColor: isDark ? Colors.white10 : Colors.black12,
          color: accent,
        ),
      ),
    ],
  );
}

Widget aiCoachExceededBanner(Map<String, dynamic> q) {
  if (q['exceeded'] == null || '$q[exceeded]'.isEmpty) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Limit reached — resets ${q['exceeded'] == 'monthly' ? 'next month' : 'tomorrow'}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.amber,
        ),
      ),
    ),
  );
}

BoxDecoration aiCoachCardDecoration(bool isDark) {
  return BoxDecoration(
    color: isDark ? const Color(0xFF1E293B) : Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.25),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
        blurRadius: 16,
      ),
    ],
  );
}

List<Map<String, dynamic>> aiCoachRecentSessions(Map<String, dynamic> q) {
  final sessions = q['recent_sessions'];
  if (sessions is! List) return const [];
  return sessions
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
