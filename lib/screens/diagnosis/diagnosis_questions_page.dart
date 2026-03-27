import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api/diagnosis_api.dart';
import '../../routes/app_routes.dart';

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
        backgroundColor: Color(0xFF1E293B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E293B),
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
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
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
    );
  }

  Widget _buildProgressHeader(double progress) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION ${_currentQuestion + 1}/${_questions.length}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ECDC4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(DiagnosisQuestion question) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            question.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 40),
          ...question.options.asMap().entries.map(
            (entry) => _buildOption(question.id, entry.key, entry.value),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _nextQuestion,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _selectOption(questionId, idx),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4ECDC4).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFF4ECDC4) : Colors.white10,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4ECDC4) : Colors.white,
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4ECDC4),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (idx * 100).ms).slideX(begin: 0.05);
  }
}
