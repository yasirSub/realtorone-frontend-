import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/user_api.dart';
import '../../widgets/elite_loader.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _isLoading = true;
  int _totalRewards = 0;
  List<dynamic> _breakdown = [];

  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  Future<void> _fetchRewards() async {
    setState(() => _isLoading = true);
    try {
      final response = await UserApi.getRewards();
      if (mounted && response['success'] == true) {
        setState(() {
          _totalRewards = response['total_rewards'] ?? 0;
          _breakdown = response['breakdown'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            size: 20,
          ),
        ),
        title: Text(
          'MASTERY REWARDS',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: EliteLoader())
          : RefreshIndicator(
              onRefresh: _fetchRewards,
              color: Colors.amber,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildTotalScoreCard(isDark),
                    const SizedBox(height: 32),
                    _buildBreakdownSection(isDark),
                    const SizedBox(height: 32),
                    _buildRedeemSection(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalScoreCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 48)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
              ),
          const SizedBox(height: 16),
          Text(
            '$_totalRewards',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 1,
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 8),
          const Text(
            'TOTAL MASTERY POINTS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINT SOURCES',
          style: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        ..._breakdown.map((item) {
          final category = item['category'] ?? 'Unknown';
          final points = item['total'] ?? 0;
          final isSubconscious = category == 'subconscious';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSubconscious
                    ? const Color(0xFF667eea).withValues(alpha: 0.3)
                    : const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (isSubconscious
                                ? const Color(0xFF667eea)
                                : const Color(0xFF4ECDC4))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isSubconscious
                        ? Icons.psychology_rounded
                        : Icons.bolt_rounded,
                    color: isSubconscious
                        ? const Color(0xFF667eea)
                        : const Color(0xFF4ECDC4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toString().toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      isSubconscious
                          ? 'Mindset & Belief'
                          : 'Action & Execution',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '+$points',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRedeemSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF94A3B8),
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'REWARDS STORE LOCKED',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep accumulating mastery points to unlock exclusive coaching sessions, report upgrades, and premium content.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
