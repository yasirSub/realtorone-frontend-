import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/activities_api.dart';
import '../../api/dashboard_api.dart';

class MomentumHubWidget extends StatefulWidget {
  const MomentumHubWidget({super.key});

  @override
  State<MomentumHubWidget> createState() => _MomentumHubWidgetState();
}

class _MomentumHubWidgetState extends State<MomentumHubWidget>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  int _momentumScore = 0;
  int _subconsciousScore = 0;
  int _consciousScore = 0;
  int _resultsScore = 0;
  int _streak = 0;
  List<Map<String, dynamic>> _activityTypes = [];
  String _selectedCategory = 'conscious';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _tabController.index == 0
              ? 'conscious'
              : 'subconscious';
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DashboardApi.getMomentumData(),
        ActivitiesApi.getActivityTypes(),
      ]);

      final momentumRes = results[0];
      final typesRes = results[1];

      if (mounted) {
        setState(() {
          if (momentumRes['success'] == true) {
            final data = momentumRes['data'];
            _momentumScore = data['momentum_score'] ?? 0;
            _subconsciousScore = data['subconscious'] ?? 0;
            _consciousScore = data['conscious'] ?? 0;
            _resultsScore = data['results'] ?? 0;
            _streak = data['streak'] ?? 0;
          }
          if (typesRes['success'] == true) {
            _activityTypes = List<Map<String, dynamic>>.from(
              typesRes['data'] ?? [],
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading momentum data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logActivity(Map<String, dynamic> actType) async {
    final int points = actType['points'] ?? 0;
    final int originalScore = _momentumScore;

    // Optimistic UI Update
    if (mounted) {
      setState(() {
        _momentumScore = (_momentumScore + points).clamp(0, 100);
      });
    }

    try {
      final response = await ActivitiesApi.logActivity(
        type: actType['type_key'] ?? actType['name'],
        category: actType['category'] ?? 'conscious',
        quantity: 1,
      );

      if (response['success'] == true) {
        // Refresh silently in background to sync all metrics
        final momentumRes = await DashboardApi.getMomentumData();
        if (mounted && momentumRes['success'] == true) {
          final data = momentumRes['data'];
          setState(() {
            _momentumScore = data['momentum_score'] ?? 0;
            _subconsciousScore = data['subconscious'] ?? 0;
            _consciousScore = data['conscious'] ?? 0;
            _resultsScore = data['results'] ?? 0;
            _streak = data['streak'] ?? 0;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF4ECDC4)),
                  const SizedBox(width: 10),
                  Text(
                    '+$points PTS — ${actType['name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Rollback on failure
        if (mounted) setState(() => _momentumScore = originalScore);
      }
    } catch (e) {
      debugPrint('Error logging activity: $e');
      if (mounted) setState(() => _momentumScore = originalScore);
    }
  }

  Color _getScoreColor(int score) {
    if (score <= 40) return const Color(0xFFEF4444);
    if (score <= 70) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF667eea)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ MOMENTUM SCORE RING ═══
        _buildMomentumScoreCard()
            .animate()
            .fadeIn(delay: 100.ms)
            .slideY(begin: 0.1),
        const SizedBox(height: 28),

        // ═══ BEHAVIORAL PROTOCOL SHEET ═══
        _buildProtocolSheet()
            .animate()
            .fadeIn(delay: 300.ms)
            .slideY(begin: 0.1),
        const SizedBox(height: 28),

        // ═══ RESULTS INTELLIGENCE ═══
        _buildResultsIntelligence()
            .animate()
            .fadeIn(delay: 500.ms)
            .slideY(begin: 0.1),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  MOMENTUM SCORE RING — Compact version showing all 3 dimensions
  // ════════════════════════════════════════════════════════════════
  Widget _buildMomentumScoreCard() {
    final scoreColor = _getScoreColor(_momentumScore);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            Color.lerp(const Color(0xFF1E293B), scoreColor, 0.08)!,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header + Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOMENTUM SCORE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Daily Protocol Execution',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFF97316),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_streak',
                      style: const TextStyle(
                        color: Color(0xFFF97316),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Score Ring
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _momentumScore / 100.0,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_momentumScore',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      'OF 100',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3 Pillars — Subconscious / Conscious / Results
          Row(
            children: [
              _buildPillarChip(
                'IDENTITY CONDITIONING',
                _subconsciousScore,
                40,
                const Color(0xFFD946EF),
              ),
              const SizedBox(width: 10),
              _buildPillarChip(
                'REVENUE ACTIONS',
                _consciousScore,
                45,
                const Color(0xFFA855F7),
              ),
              const SizedBox(width: 10),
              _buildPillarChip(
                'RESULTS',
                _resultsScore,
                15,
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarChip(String label, int score, int max, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$score',
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: '/$max',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: max > 0 ? (score / max).clamp(0.0, 1.0) : 0,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BEHAVIORAL PROTOCOL SHEET — Tappable activity grid
  // ════════════════════════════════════════════════════════════════
  Widget _buildProtocolSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredTypes = _activityTypes
        .where((t) => t['category'] == _selectedCategory)
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOG ACTIVITY',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to log your daily protocols',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadData,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? Colors.white38
                  : const Color(0xFF64748B),
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
              tabs: const [
                Tab(text: 'REVENUE ACTIONS'),
                Tab(text: 'IDENTITY CONDITIONING'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Activity Grid
          if (filteredTypes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Text(
                'No ${_selectedCategory == 'conscious' ? 'revenue actions' : 'identity conditioning'} activities defined',
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: filteredTypes.length,
              itemBuilder: (context, index) {
                final act = filteredTypes[index];
                return _buildProtocolTile(act, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProtocolTile(Map<String, dynamic> act, bool isDark) {
    final isConscious = act['category'] == 'conscious';
    final color = isConscious
        ? const Color(0xFF667eea)
        : const Color(0xFFD946EF);
    final icon = _getActivityIcon(act['icon'] ?? act['type_key'] ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _logActivity(act),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                (act['name'] ?? '').toString().length > 12
                    ? '${(act['name'] ?? '').toString().substring(0, 12)}...'
                    : act['name'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '+${act['points'] ?? 0} PTS',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  RESULTS INTELLIGENCE — Log Leads & Deals
  // ════════════════════════════════════════════════════════════════
  Widget _buildResultsIntelligence() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  Color.lerp(
                    const Color(0xFF1E293B),
                    const Color(0xFF10B981),
                    0.06,
                  )!,
                ]
              : [
                  Colors.white,
                  Color.lerp(Colors.white, const Color(0xFF10B981), 0.04)!,
                ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESULTS INTELLIGENCE',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Convert behavioral momentum into revenue',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Hot Leads
          _buildResultRow(
            icon: Icons.person_add_rounded,
            label: 'HOT LEADS',
            points: '+5',
            color: const Color(0xFF3B82F6),
            onLog: () => _logActivity({
              'type_key': 'hot_lead',
              'name': 'Hot Lead',
              'category': 'conscious',
              'points': 5,
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Deals Closed
          _buildResultRow(
            icon: Icons.handshake_rounded,
            label: 'DEALS CLOSED',
            points: '+20',
            color: const Color(0xFF10B981),
            onLog: () => _logActivity({
              'type_key': 'deal_closed',
              'name': 'Deal Closed',
              'category': 'conscious',
              'points': 20,
            }),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String points,
    required Color color,
    required VoidCallback onLog,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$points PTS EACH',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onLog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'LOG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String? iconKey) {
    switch (iconKey?.toLowerCase()) {
      case 'phone':
      case 'cold_calling':
        return Icons.phone_rounded;
      case 'camera':
      case 'content_creation':
        return Icons.camera_alt_rounded;
      case 'share2':
      case 'content_posting':
        return Icons.share_rounded;
      case 'messagecircle':
      case 'dm_conversations':
        return Icons.chat_rounded;
      case 'send':
      case 'whatsapp_broadcast':
        return Icons.send_rounded;
      case 'mail':
      case 'mass_emailing':
        return Icons.email_rounded;
      case 'users':
      case 'client_meetings':
        return Icons.groups_rounded;
      case 'search':
      case 'prospecting':
        return Icons.search_rounded;
      case 'refreshcw':
      case 'follow_ups':
        return Icons.replay_rounded;
      case 'briefcase':
      case 'deal_negotiation':
        return Icons.business_center_rounded;
      case 'hearthandshake':
      case 'client_servicing':
        return Icons.handshake_rounded;
      case 'database':
      case 'crm_update':
        return Icons.storage_rounded;
      case 'mappin':
      case 'site_visits':
        return Icons.location_on_rounded;
      case 'userplus':
      case 'referral_ask':
        return Icons.person_add_rounded;
      case 'zap':
      case 'skill_training':
        return Icons.bolt_rounded;
      case 'eye':
      // Identity Conditioning
      case 'journaling':
      case 'bookheart':
        return Icons.book_rounded;
      case 'webinar':
      case 'video':
        return Icons.videocam_rounded;
      case 'visualization':
        return Icons.visibility_rounded;
      case 'affirmations':
      case 'repeat':
        return Icons.loop_rounded;
      case 'inner_game_audio':
      case 'headphones':
        return Icons.headphones_rounded;
      case 'guided_reset':
      case 'wind':
        return Icons.air_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }
}
