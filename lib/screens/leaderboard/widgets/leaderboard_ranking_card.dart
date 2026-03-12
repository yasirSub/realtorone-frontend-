import 'package:flutter/material.dart';

class LeaderboardRankingCard extends StatelessWidget {
  const LeaderboardRankingCard({
    super.key,
    required this.leaderboard,
    required this.isDark,
  });

  final List<dynamic> leaderboard;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              'No ranking available yet',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final topThree = leaderboard.take(3).toList();
    final remainingEntries = leaderboard.skip(3).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (topThree.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
              child: _TopThreeSection(topThree: topThree, isDark: isDark),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Text(
                  remainingEntries.isEmpty ? 'Leaderboard' : 'Full ranking',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (remainingEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Text(
                'The top three leaders are shown above.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ),
          ...remainingEntries.map(
            (entry) => _RankRow(entry: entry, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _TopThreeSection extends StatelessWidget {
  const _TopThreeSection({required this.topThree, required this.isDark});

  final List<dynamic> topThree;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final second = topThree.length > 1 ? topThree[1] : null;
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 3 this week',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rank 1 stands out first so the leader is easy to spot.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (first != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Leader',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _PodiumTile(
                        entry: second,
                        isDark: isDark,
                        rankLabel: '2',
                        height: 118,
                        avatarRadius: 24,
                        nameSize: 13,
                        scoreSize: 12,
                        gradientColors: const [
                          Color(0xFFE2E8F0),
                          Color(0xFF94A3B8),
                        ], // Silver
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: first == null
                    ? const SizedBox.shrink()
                    : _PodiumTile(
                        entry: first,
                        isDark: isDark,
                        rankLabel: '1',
                        height: 156,
                        avatarRadius: 32,
                        nameSize: 16,
                        scoreSize: 14,
                        highlight: true,
                        gradientColors: const [
                          Color(0xFFFCD34D),
                          Color(0xFFD97706),
                        ], // Gold
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: third == null
                    ? const SizedBox.shrink()
                    : _PodiumTile(
                        entry: third,
                        isDark: isDark,
                        rankLabel: '3',
                        height: 104,
                        avatarRadius: 23,
                        nameSize: 12,
                        scoreSize: 11,
                        gradientColors: const [
                          Color(0xFFFDBA74),
                          Color(0xFF9A3412),
                        ], // Bronze
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  const _PodiumTile({
    required this.entry,
    required this.isDark,
    required this.rankLabel,
    required this.height,
    required this.avatarRadius,
    required this.nameSize,
    required this.scoreSize,
    required this.gradientColors,
    this.highlight = false,
  });

  final dynamic entry;
  final bool isDark;
  final String rankLabel;
  final double height;
  final double avatarRadius;
  final double nameSize;
  final double scoreSize;
  final List<Color> gradientColors;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final userName = entry['user_name'] ?? 'Agent';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                child: Text(
                  userName[0].toUpperCase(),
                  style: TextStyle(
                    color: gradientColors[1],
                    fontSize: highlight ? 22 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (highlight)
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFCD34D), Color(0xFFB45309)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry['score'] ?? 0} pts',
          style: TextStyle(
            color: gradientColors[1],
            fontSize: scoreSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColors[0].withValues(alpha: 0.8),
                gradientColors[1].withValues(alpha: 0.2),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: Radius.circular(8),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            rankLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isDark});

  final dynamic entry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final streak = entry['streak'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry['rank'] ?? '-'}',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF667EEA).withValues(alpha: 0.12),
            child: Text(
              (entry['user_name'] ?? 'A')[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF667EEA),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['user_name'] ?? 'Agent',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (streak > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '$streak day streak',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${entry['score'] ?? 0}',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
