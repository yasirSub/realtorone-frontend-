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

  // Points history (per activity)
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _todayEntries = [];
  List<Map<String, dynamic>> _olderEntries = [];
  int _todayPoints = 0;
  bool _showFullHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchRewards();
    _fetchPointsHistory();
  }

  Future<void> _fetchRewards() async {
    setState(() => _isLoading = true);
    try {
      final response = await UserApi.getRewards();
      if (mounted && response['success'] == true) {
        setState(() {
          _totalRewards = response['total_rewards'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPointsHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await UserApi.getPointsHistory(limit: 100);
      if (mounted && response['success'] == true) {
        final List<Map<String, dynamic>> raw =
            List<Map<String, dynamic>>.from(response['data'] ?? []);

        final now = DateTime.now();
        final todayKey =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final today = <Map<String, dynamic>>[];
        final older = <Map<String, dynamic>>[];

        for (final entry in raw) {
          final dateStr = entry['date']?.toString() ?? '';
          if (dateStr == todayKey) {
            today.add(entry);
          } else {
            older.add(entry);
          }
        }

        final todayPts = today.fold<int>(
          0,
          (sum, e) => sum + ((e['points'] as num?)?.toInt() ?? 0),
        );

        setState(() {
          _todayEntries = today;
          _olderEntries = older;
          _todayPoints = todayPts;
          _isLoadingHistory = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      debugPrint('Error fetching points history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
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
          'POINTS',
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
              onRefresh: () async {
                await _fetchRewards();
                await _fetchPointsHistory();
              },
              color: Colors.amber,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTotalPointsCard(isDark),
                    const SizedBox(height: 32),
                    _buildTodaySection(isDark),
                    const SizedBox(height: 24),
                    _buildHistorySection(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalPointsCard(bool isDark) {
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
        mainAxisSize: MainAxisSize.min,
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
            'TOTAL POINTS',
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

  Widget _buildTodaySection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_todayPoints',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'points today',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_todayEntries.isEmpty && !_isLoadingHistory)
            Text(
              'Complete your tasks to start earning points today.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: _todayEntries.take(3).map((entry) {
                final title = entry['title']?.toString() ?? 'Activity';
                final pts = (entry['points'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2933),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$pts',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _olderEntries.isEmpty
                ? null
                : () {
                    setState(() {
                      _showFullHistory = !_showFullHistory;
                    });
                  },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color(0xFF667eea),
            ),
            icon: Icon(
              _showFullHistory
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _olderEntries.isEmpty
                  ? 'No past history yet'
                  : (_showFullHistory ? 'Hide history' : 'Show history'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_showFullHistory && _olderEntries.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _olderEntries.take(20).map((entry) {
                final title = entry['title']?.toString() ?? 'Activity';
                final pts = (entry['points'] as num?)?.toInt() ?? 0;
                final dateStr = entry['date']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2933),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$pts',
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
