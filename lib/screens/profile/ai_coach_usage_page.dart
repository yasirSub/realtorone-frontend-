import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/chat_api.dart';
import '../../theme/realtorone_brand.dart';
import '../../widgets/ai_coach_usage_widgets.dart';
import '../../widgets/elite_loader.dart';

class AiCoachUsagePage extends StatefulWidget {
  const AiCoachUsagePage({super.key});

  @override
  State<AiCoachUsagePage> createState() => _AiCoachUsagePageState();
}

class _AiCoachUsagePageState extends State<AiCoachUsagePage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _quota;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ChatApi.getAiQuota();
      if (!mounted) return;

      if (response['success'] == true &&
          response['visible'] != false &&
          response['data'] is Map) {
        setState(() {
          _quota = Map<String, dynamic>.from(response['data'] as Map);
          _isLoading = false;
        });
      } else if (response['visible'] == false) {
        setState(() {
          _error = response['message']?.toString() ??
              'AI usage stats are hidden by your administrator.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ??
              'Could not load AI Coach usage.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load AI Coach usage. Check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('AI Coach usage'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuota,
        child: _isLoading
            ? const Center(child: EliteLoader())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: _loadQuota,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final q = _quota!;
    final todayUsed = aiCoachInt(q['tokens_today']);
    final monthUsed = aiCoachInt(q['tokens_month']);
    final dailyLimit = aiCoachInt(q['daily_limit']);
    final monthlyLimit = aiCoachInt(q['monthly_limit']);
    final remainDay = q['remaining_daily'];
    final remainMonth = q['remaining_monthly'];
    final callsToday = aiCoachInt(q['calls_today']);
    final callsMonth = aiCoachInt(q['calls_month']);
    final recent = aiCoachRecentSessions(q);
    final tier = (q['tier'] ?? 'Consultant').toString();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: aiCoachCardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: RealtorOneBrand.accentIndigo,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '$tier · token limits per billing period',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              aiCoachExceededBanner(q),
              const SizedBox(height: 20),
              aiCoachUsageMeter(
                label: 'Today',
                used: todayUsed,
                limitLabel: aiCoachFmtLimit(dailyLimit),
                remaining:
                    remainDay is int ? remainDay : int.tryParse('$remainDay'),
                fraction: aiCoachBarFrac(todayUsed, dailyLimit),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              aiCoachUsageMeter(
                label: 'This month',
                used: monthUsed,
                limitLabel: aiCoachFmtLimit(monthlyLimit),
                remaining: remainMonth is int
                    ? remainMonth
                    : int.tryParse('$remainMonth'),
                fraction: aiCoachBarFrac(monthUsed, monthlyLimit),
                isDark: isDark,
                accent: Colors.amber,
              ),
              if (callsToday > 0 || callsMonth > 0) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statChip(
                        label: 'Chats today',
                        value: '$callsToday',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statChip(
                        label: 'Chats this month',
                        value: '$callsMonth',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'RECENT CHATS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: aiCoachCardDecoration(isDark),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 36,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No AI Coach chats yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a conversation with Reven to see usage here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map((s) => _sessionTile(s, isDark)),
      ],
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> s, bool isDark) {
    final title = (s['title'] ?? 'Chat').toString();
    final tokens = aiCoachInt(s['tokens']);
    final replies = aiCoachInt(s['ai_replies']);
    final updatedRaw = s['updated_at']?.toString();
    String? whenLabel;
    if (updatedRaw != null && updatedRaw.isNotEmpty) {
      try {
        final dt = DateTime.parse(updatedRaw).toLocal();
        whenLabel = DateFormat('MMM d · h:mm a').format(dt);
      } catch (_) {
        whenLabel = null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: aiCoachCardDecoration(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RealtorOneBrand.accentIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat_rounded,
              color: RealtorOneBrand.accentIndigo,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (whenLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    whenLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
                if (replies > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$replies AI ${replies == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$tokens TK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: RealtorOneBrand.accentIndigo,
            ),
          ),
        ],
      ),
    );
  }
}
