import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../chatbot/chatbot_floating_button.dart';
import 'widgets/leaderboard_header_card.dart';
import 'widgets/leaderboard_my_rank_card.dart';
import 'widgets/leaderboard_ranking_card.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _isLoading = true;
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myPosition;
  int _totalParticipants = 0;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final response = await ApiClient.get(
      '${ApiEndpoints.leaderboard}?category=top_realtor&period=weekly',
      requiresAuth: true,
    );

    if (!mounted) {
      return;
    }

    if (response['success'] == true) {
      final data = response['data'] ?? <String, dynamic>{};
      setState(() {
        _leaderboard = data['leaderboard'] ?? <dynamic>[];
        _myPosition = data['my_position'] as Map<String, dynamic>?;
        _totalParticipants = data['total_participants'] ?? 0;
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Top Realtor',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: const ChatbotFloatingButton(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667EEA)),
            )
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: const Color(0xFF667EEA),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  LeaderboardHeaderCard(
                    totalParticipants: _totalParticipants,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  if (_myPosition != null) ...[
                    LeaderboardMyRankCard(
                      myPosition: _myPosition!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                  ],
                  LeaderboardRankingCard(
                    leaderboard: _leaderboard,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
    );
  }
}
