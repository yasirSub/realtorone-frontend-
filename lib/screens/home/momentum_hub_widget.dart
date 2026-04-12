import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api/dashboard_api.dart';

class MomentumHubWidget extends StatefulWidget {
  const MomentumHubWidget({super.key});

  @override
  State<MomentumHubWidget> createState() => _MomentumHubWidgetState();
}

class _MomentumHubWidgetState extends State<MomentumHubWidget> {
  bool _isLoading = true;
  int _momentumScore = 0;
  int _subconsciousScore = 0;
  int _consciousScore = 0;
  int _resultsScore = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await DashboardApi.getMomentumData();

      if (mounted) {
        setState(() {
          if (response['success'] == true) {
            final data = response['data'] as Map<String, dynamic>;
            _momentumScore = data['momentum_score'] ?? 0;
            _subconsciousScore = data['subconscious'] ?? 0;
            _consciousScore = data['conscious'] ?? 0;
            _resultsScore = data['results'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error loading momentum data: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

    return _buildMomentumScoreCard()
        .animate()
        .fadeIn(delay: 100.ms)
        .slideY(begin: 0.1);
  }

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
            Color.lerp(const Color(0xFF1E293B), scoreColor, 0.08) ??
                const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
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
            ],
          ),
          const SizedBox(height: 28),
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
          Row(
            children: [
              _buildPillarChip(
                'BELIEF',
                _subconsciousScore,
                40,
                const Color(0xFFD946EF),
              ),
              const SizedBox(width: 10),
              _buildPillarChip(
                'FOCUS',
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
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
                      color: Colors.white.withOpacity(0.25),
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
}
