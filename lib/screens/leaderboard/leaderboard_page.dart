import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _isLoading = true;
  String _selectedCategory = 'consistency';
  List<dynamic> _categories = [];
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myPosition;
  int _totalParticipants = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final response = await ApiClient.get(
      ApiEndpoints.leaderboardCategories,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      setState(() => _categories = response['data'] ?? []);
    }
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    final cat = _categories.isNotEmpty
        ? _categories.firstWhere(
            (c) => c['key'] == _selectedCategory,
            orElse: () => _categories[0],
          )
        : {'period': 'weekly'};

    final response = await ApiClient.get(
      '${ApiEndpoints.leaderboard}?category=$_selectedCategory&period=${cat['period'] ?? 'weekly'}',
      requiresAuth: true,
    );

    if (response['success'] == true) {
      final data = response['data'] ?? {};
      setState(() {
        _leaderboard = data['leaderboard'] ?? [];
        _myPosition = data['my_position'];
        _totalParticipants = data['total_participants'] ?? 0;
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          children: [
            // Premium header
            _buildHeader(),

            // Category selector
            _buildCategoryTabs(),

            // Leaderboard content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D4AA),
                      ),
                    )
                  : _buildLeaderboardContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F36), Color(0xFF0A0E21)],
        ),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_totalParticipants active agents',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Color(0xFF00D4AA),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat['key'] == _selectedCategory;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat['key']);
              _loadLeaderboard();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
                      )
                    : null,
                color: isSelected ? null : const Color(0xFF1A1F36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white12,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cat['icon'] ?? '🏆',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat['name']?.toString().split(' ').first ?? '',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    final currentCat = _categories.isNotEmpty
        ? _categories.firstWhere(
            (c) => c['key'] == _selectedCategory,
            orElse: () => _categories[0],
          )
        : null;

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Category description
          if (currentCat != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F36),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                currentCat['description'] ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          // My position card (protective psychology)
          if (_myPosition != null) _buildMyPositionCard(),

          // Top 3 podium
          if (_leaderboard.length >= 3) _buildPodium(),

          const SizedBox(height: 16),

          // Remaining list
          ..._leaderboard.asMap().entries.map((entry) {
            if (entry.key < 3) return const SizedBox.shrink(); // skip top 3
            return _buildLeaderEntry(entry.value, entry.key + 1);
          }),

          if (_leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text('📊', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'No data yet',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Complete activities to appear on the leaderboard!',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMyPositionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4AA).withValues(alpha: 0.15),
            const Color(0xFF3498DB).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00D4AA).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Your Position',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${_myPosition!['rank']}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _myPosition!['message'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(
            child: _podiumItem(
              _leaderboard[1],
              2,
              130,
              const Color(0xFFC0C0C0),
            ),
          ),
          const SizedBox(width: 8),
          // 1st place
          Expanded(
            child: _podiumItem(
              _leaderboard[0],
              1,
              170,
              const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(
            child: _podiumItem(
              _leaderboard[2],
              3,
              100,
              const Color(0xFFCD7F32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _podiumItem(dynamic entry, int rank, double height, Color color) {
    final medal = rank == 1
        ? '👑'
        : rank == 2
        ? '🥈'
        : '🥉';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          entry['user_name'] ?? 'Agent',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry['score']}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Rank badge hidden for now (design change)
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildLeaderEntry(dynamic entry, int displayRank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Per-entry rank label hidden for now
          const SizedBox(width: 0),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.2),
            child: Text(
              (entry['user_name'] ?? 'A')[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF00D4AA),
                fontWeight: FontWeight.bold,
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (entry['streak'] != null && entry['streak'] > 0)
                  Text(
                    '🔥 ${entry['streak']} day streak',
                    style: const TextStyle(color: Colors.orange, fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry['score']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
