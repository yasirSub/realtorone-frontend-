import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/diagnosis_api.dart';
import '../../routes/app_routes.dart';
import '../../theme/realtorone_brand.dart';

class DiagnosisQuestionsPage extends StatefulWidget {
  const DiagnosisQuestionsPage({super.key});

  @override
  State<DiagnosisQuestionsPage> createState() => _DiagnosisQuestionsPageState();
}

class _DiagnosisQuestionsPageState extends State<DiagnosisQuestionsPage> {
  final PageController _pageController = PageController();
  int _currentQuestion = 0;
  bool _isLoading = true;
  final Map<int, int> _answers = {};
  final Map<String, int> _blockerScores = {
    'leadGeneration': 0,
    'confidence': 0,
    'closing': 0,
    'discipline': 0,
  };
  List<DiagnosisQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final remote = await DiagnosisApi.getQuestions();
      if (!mounted) return;
      setState(() {
        _questions = remote;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = [];
        _isLoading = false;
      });
    }
  }

  void _selectOption(int questionId, int optionIndex) {
    setState(() {
      _answers[questionId] = optionIndex;
    });
    Future.delayed(const Duration(milliseconds: 300), _nextQuestion);
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _calculateResults();
    }
  }

  /// Jumps to the last question; on that screen SKIP finishes to results.
  void _skipToFinalQuestion() {
    final lastIndex = _questions.length - 1;
    if (_currentQuestion >= lastIndex) {
      _calculateResults();
      return;
    }
    _pageController.animateToPage(
      lastIndex,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _calculateResults() {
    _blockerScores.updateAll((key, value) => 0);
    for (final entry in _answers.entries) {
      final question = _questions.firstWhere((q) => q.id == entry.key);
      final selectedOption = question.options[entry.value];
      _blockerScores[selectedOption.blockerType] =
          (_blockerScores[selectedOption.blockerType] ?? 0) +
          selectedOption.score;
    }
    String primaryBlocker = 'leadGeneration';
    int maxScore = -1;
    _blockerScores.forEach((key, value) {
      if (value > maxScore) {
        maxScore = value;
        primaryBlocker = key;
      }
    });
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.diagnosisResult,
      arguments: {
        'primaryBlocker': primaryBlocker,
        'scores': Map<String, int>.from(_blockerScores),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: RealtorOneBrand.scaffoldDark,
        body: Center(
          child: CircularProgressIndicator(
            color: RealtorOneBrand.accentTeal,
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: RealtorOneBrand.scaffoldDark,
        body: Center(
          child: Text(
            'No signup questions configured.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final progress = (_currentQuestion + 1) / _questions.length;

    return Scaffold(
      backgroundColor: RealtorOneBrand.scaffoldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: RealtorOneGridPainter(
                  color: Colors.white.withValues(alpha: 0.028),
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RealtorOneBrand.seed.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildProgressHeader(progress),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentQuestion = index),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) =>
                        _buildQuestionCard(_questions[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION ${_currentQuestion + 1}/${_questions.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.8,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: RealtorOneBrand.accentTeal,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: RealtorOneBrand.accentTeal.withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildGradientProgressBar(progress),
        ],
      ),
    );
  }

  Widget _buildGradientProgressBar(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 8,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: clamped <= 0 ? 0.001 : clamped,
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    RealtorOneBrand.accentIndigo,
                    RealtorOneBrand.accentTeal,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: RealtorOneBrand.accentTeal.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(DiagnosisQuestion question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.6,
            ),
          ).animate().fadeIn().slideY(begin: 0.08),
          const SizedBox(height: 28),
          ...question.options.asMap().entries.map(
            (entry) => _buildOption(question.id, entry.key, entry.value),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _skipToFinalQuestion,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: const Text(
                'SKIP',
                style: TextStyle(
                  color: RealtorOneBrand.accentTeal,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int questionId, int idx, DiagnosisQuestionOption option) {
    final isSelected = _answers[questionId] == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectOption(questionId, idx),
          borderRadius: BorderRadius.circular(20),
          splashColor: RealtorOneBrand.accentTeal.withValues(alpha: 0.12),
          highlightColor: RealtorOneBrand.accentTeal.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isSelected
                  ? RealtorOneBrand.accentTeal.withValues(alpha: 0.12)
                  : RealtorOneBrand.surfaceDark.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? RealtorOneBrand.accentTeal
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                if (isSelected)
                  BoxShadow(
                    color: RealtorOneBrand.accentTeal.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      color: isSelected
                          ? RealtorOneBrand.accentTeal
                          : Colors.white.withValues(alpha: 0.92),
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: RealtorOneBrand.accentTeal,
                    size: 26,
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (idx * 100).ms).slideX(begin: 0.04);
  }
}
