import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/diagnosis_api.dart';
import '../../models/diagnosis_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class DiagnosisResultPage extends StatefulWidget {
  const DiagnosisResultPage({super.key});

  @override
  State<DiagnosisResultPage> createState() => _DiagnosisResultPageState();
}

class _DiagnosisResultPageState extends State<DiagnosisResultPage> {
  bool _isSaving = true;
  bool _savedSuccessfully = false;
  late String _primaryBlockerStr;
  late Map<String, int> _scores;
  late BlockerType _primaryBlocker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _primaryBlockerStr = args?['primaryBlocker'] as String? ?? 'leadGeneration';
    _scores = Map<String, int>.from(args?['scores'] as Map? ?? {});
    _primaryBlocker = BlockerType.values.firstWhere(
      (e) => e.name == _primaryBlockerStr,
      orElse: () => BlockerType.leadGeneration,
    );

    if (_isSaving && !_savedSuccessfully) {
      _saveDiagnosis();
    }
  }

  Future<void> _saveDiagnosis() async {
    try {
      final response = await DiagnosisApi.submitDiagnosis(
        primaryBlocker: _primaryBlockerStr,
        scores: _scores,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _savedSuccessfully = response['success'] == true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBlockerColor(_primaryBlocker);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Premium Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.8),
                    color,
                    color.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader().animate().fadeIn().slideY(begin: -0.1),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBlockerHeroCard(color),
                            const SizedBox(height: 40),
                            const Text(
                              'PERFORMANCE ANALYSIS',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildAdvancedScores(color),
                            const SizedBox(height: 40),
                            _buildInsightPremiumCard(color),
                            const SizedBox(height: 40),
                            _buildPathTimeline(color),
                            const SizedBox(height: 60),
                            _buildCTA(
                              color,
                            ).animate().fadeIn(delay: 1000.ms).scale(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving) ...[EliteLoader.top()],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'DIAGNOSIS COMPLETE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Realtor Strategy Protocol',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockerHeroCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _primaryBlocker.icon,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRIMARY BLOCKER',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _primaryBlocker.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1);
  }

  Widget _buildAdvancedScores(Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: BlockerType.values.map((blocker) {
          final score = _scores[blocker.name] ?? 0;
          final percentage = score / 12;
          final isPrimary = blocker == _primaryBlocker;
          final bColor = _getBlockerColor(blocker);

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      blocker.title.split(' ')[0],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isPrimary ? color : const Color(0xFF1E293B),
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isPrimary ? color : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(
                      isPrimary ? color : bColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildInsightPremiumCard(Color color) {
    final insights = _getInsights(_primaryBlocker);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'STRATEGIC INSIGHTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).scale();
  }

  Widget _buildPathTimeline(Color color) {
    final path = _getRecommendedPath(_primaryBlocker);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR RECOMMENDED PROTOCOL',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: Color(0xFF64748B),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 24),
        ...path.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (idx < path.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['description']!,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCTA(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.main),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
        ),
        child: const Text(
          'INITIALIZE SYSTEM',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Color _getBlockerColor(BlockerType blocker) {
    switch (blocker) {
      case BlockerType.leadGeneration:
        return const Color(0xFFFF6B6B);
      case BlockerType.confidence:
        return const Color(0xFF4ECDC4);
      case BlockerType.closing:
        return const Color(0xFF45B7D1);
      case BlockerType.discipline:
        return const Color(0xFF96CEB4);
    }
  }

  List<String> _getInsights(BlockerType blocker) {
    switch (blocker) {
      case BlockerType.leadGeneration:
        return [
          'Income ceiling due to lead scarcity',
          'Systematic outreach is your multiplier',
          'Automating flow will liberate your time',
        ];
      case BlockerType.confidence:
        return [
          '犹豫 costs you high-value commissions',
          'Authority building is your key metric',
          'Expertise gaps affect your negotiation leverage',
        ];
      case BlockerType.closing:
        return [
          'High effort, low conversion fatigue',
          'Closing protocol refinement needed',
          'NLP techniques will boost ROI per lead',
        ];
      case BlockerType.discipline:
        return [
          'Inconsistent execution is the primary enemy',
          'Habit stacked routines will compound results',
          'Structure creates the freedom to scale',
        ];
    }
  }

  List<Map<String, String>> _getRecommendedPath(BlockerType blocker) {
    switch (blocker) {
      case BlockerType.leadGeneration:
        return [
          {
            'title': 'Foundational Lead Gen',
            'description':
                '5 proven methods for consistent high-quality leads.',
          },
          {
            'title': 'Outreach Protocol',
            'description': 'Daily habits for aggressive portfolio expansion.',
          },
          {
            'title': 'Social Magnetism',
            'description': 'Transforming profiles into automated lead engines.',
          },
        ];
      case BlockerType.confidence:
        return [
          {
            'title': 'Market Intelligence',
            'description': 'Deep-dive mastery of Dubai real estate specifics.',
          },
          {
            'title': 'State Management',
            'description': 'NLP techniques for peak performance anytime.',
          },
          {
            'title': 'High Stakes Negotiation',
            'description': 'Simulation based training for premium deals.',
          },
        ];
      case BlockerType.closing:
        return [
          {
            'title': 'The Art of the Close',
            'description': 'Advanced objection annihilation techniques.',
          },
          {
            'title': 'Deal Structuring',
            'description': 'Engineering win-win architectures for velocity.',
          },
          {
            'title': 'Post-Sale Ecosystem',
            'description': 'Turning every close into a referral engine.',
          },
        ];
      case BlockerType.discipline:
        return [
          {
            'title': 'The Ritual Framework',
            'description': 'Morning habits used by top 0.1% realtors.',
          },
          {
            'title': 'Metrics Tracking',
            'description': 'What gets measured gets optimized. Scaling data.',
          },
          {
            'title': 'Executive Reflection',
            'description': 'Weekly analysis protocol for rapid iteration.',
          },
        ];
    }
  }
}
