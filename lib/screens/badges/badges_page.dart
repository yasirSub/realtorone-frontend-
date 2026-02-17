import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _badges = [];
  int _earnedCount = 0;
  int _totalCount = 0;
  int _completionPercent = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    final response = await ApiClient.get(
      ApiEndpoints.badges,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      final data = response['data'] ?? {};
      setState(() {
        _badges = data['badges'] ?? [];
        _earnedCount = data['earned_count'] ?? 0;
        _totalCount = data['total_count'] ?? 0;
        _completionPercent = data['completion_percent'] ?? 0;
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Badge Collection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
            )
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Progress header
                  _buildProgressHeader(),
                  const SizedBox(height: 24),

                  // Badge categories
                  _buildBadgeSection(
                    '🔥 Streak Badges',
                    _badges
                        .where(
                          (b) => (b['slug'] ?? '').toString().startsWith(
                            'streak_',
                          ),
                        )
                        .toList(),
                  ),
                  _buildBadgeSection(
                    '💯 Score Badges',
                    _badges
                        .where(
                          (b) => [
                            'perfect_day',
                            'momentum_builder',
                            'identity_master',
                          ].contains(b['slug']),
                        )
                        .toList(),
                  ),
                  _buildBadgeSection(
                    '🎯 Deal Badges',
                    _badges
                        .where(
                          (b) =>
                              (b['slug'] ?? '').toString().contains('deal') ||
                              b['slug'] == 'first_deal',
                        )
                        .toList(),
                  ),
                  _buildBadgeSection(
                    '📅 Consistency Badges',
                    _badges
                        .where(
                          (b) => [
                            'full_week',
                            'five_day_warrior',
                          ].contains(b['slug']),
                        )
                        .toList(),
                  ),
                  _buildBadgeSection(
                    '🏅 Milestone Badges',
                    _badges
                        .where(
                          (b) => (b['slug'] ?? '').toString().startsWith(
                            'activity_',
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            const Color(0xFF00D4AA).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Circular progress
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.03);
              return Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _completionPercent / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFFD700),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_completionPercent%',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Complete',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '$_earnedCount / $_totalCount Badges Earned',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _completionPercent >= 80
                ? '🏆 You\'re almost a legend!'
                : _completionPercent >= 50
                ? '⚡ Halfway there! Keep pushing.'
                : _completionPercent >= 20
                ? '🚀 Great start! More badges await.'
                : '💪 Your journey begins. Earn your first badges!',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(String title, List<dynamic> badges) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) => _badgeCard(badges[index]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _badgeCard(dynamic badge) {
    final earned = badge['earned'] == true;
    final rarity = badge['rarity'] ?? 1;
    final rarityLabel = rarity == 4
        ? 'LEGENDARY'
        : rarity == 3
        ? 'EPIC'
        : rarity == 2
        ? 'RARE'
        : 'COMMON';
    final rarityColor = rarity == 4
        ? const Color(0xFFE74C3C)
        : rarity == 3
        ? const Color(0xFF9B59B6)
        : rarity == 2
        ? const Color(0xFF3498DB)
        : Colors.grey;

    Color badgeColor;
    try {
      String colorStr = (badge['color'] ?? '#FFD700').toString().replaceFirst(
        '#',
        '',
      );
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      badgeColor = Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      badgeColor = const Color(0xFFFFD700);
    }

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: earned
              ? badgeColor.withValues(alpha: 0.1)
              : const Color(0xFF1A1F36).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: earned ? badgeColor.withValues(alpha: 0.5) : Colors.white12,
            width: earned ? 1.5 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: earned ? 1.0 : 0.3,
              child: Text(
                badge['icon'] ?? '🏆',
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge['name'] ?? '',
              style: TextStyle(
                color: earned ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (earned ? rarityColor : Colors.grey).withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rarityLabel,
                style: TextStyle(
                  color: earned ? rarityColor : Colors.white24,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(dynamic badge) {
    final earned = badge['earned'] == true;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1F36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge['icon'] ?? '🏆', style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                badge['name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge['description'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: earned
                      ? const Color(0xFF00D4AA).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  earned ? '✅ Earned!' : '🔒 Not yet earned',
                  style: TextStyle(
                    color: earned ? const Color(0xFF00D4AA) : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF00D4AA)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
