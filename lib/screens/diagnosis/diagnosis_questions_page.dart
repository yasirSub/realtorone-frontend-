import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../routes/app_routes.dart';

class DiagnosisQuestionsPage extends StatefulWidget {
  const DiagnosisQuestionsPage({super.key});

  @override
  State<DiagnosisQuestionsPage> createState() => _DiagnosisQuestionsPageState();
}

class _DiagnosisQuestionsPageState extends State<DiagnosisQuestionsPage> {
  final PageController _pageController = PageController();
  int _currentQuestion = 0;
  final Map<int, int> _answers = {};
  final Map<String, int> _blockerScores = {
    'leadGeneration': 0,
    'confidence': 0,
    'closing': 0,
    'discipline': 0,
  };

  final List<_DiagnosisQuestionData> _questions = [
    _DiagnosisQuestionData(
      id: 1,
      question: 'How often do you get new client inquiries?',
      options: [
        _OptionData(
          'Rarely - I struggle to find new leads',
          'leadGeneration',
          3,
        ),
        _OptionData('Sometimes - It\'s inconsistent', 'leadGeneration', 2),
        _OptionData('Often - I have a steady flow', 'leadGeneration', 1),
        _OptionData(
          'Always - I have more than I can handle',
          'leadGeneration',
          0,
        ),
      ],
    ),
    _DiagnosisQuestionData(
      id: 2,
      question: 'When meeting a high-value client, how do you feel?',
      options: [
        _OptionData('Very nervous - I doubt myself', 'confidence', 3),
        _OptionData(
          'Somewhat nervous - I need more experience',
          'confidence',
          2,
        ),
        _OptionData('Confident but careful', 'confidence', 1),
        _OptionData('Completely confident - I know my stuff', 'confidence', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 3,
      question: 'How many of your interested leads convert to actual deals?',
      options: [
        _OptionData('Very few - Less than 10%', 'closing', 3),
        _OptionData('Some - Around 10-25%', 'closing', 2),
        _OptionData('Good rate - Around 25-40%', 'closing', 1),
        _OptionData('Excellent - Over 40%', 'closing', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 4,
      question: 'How consistent are you with your daily work routine?',
      options: [
        _OptionData(
          'Not consistent - I work when I feel like it',
          'discipline',
          3,
        ),
        _OptionData('Somewhat - I try but get distracted', 'discipline', 2),
        _OptionData(
          'Mostly consistent - I have good days and bad',
          'discipline',
          1,
        ),
        _OptionData(
          'Very consistent - I follow my schedule daily',
          'discipline',
          0,
        ),
      ],
    ),
    _DiagnosisQuestionData(
      id: 5,
      question: 'What is your biggest challenge right now?',
      options: [
        _OptionData('Finding enough potential clients', 'leadGeneration', 3),
        _OptionData('Feeling confident in negotiations', 'confidence', 3),
        _OptionData('Converting inquiries into signed deals', 'closing', 3),
        _OptionData('Staying focused and productive daily', 'discipline', 3),
      ],
    ),
    _DiagnosisQuestionData(
      id: 6,
      question: 'How do you handle objections from clients?',
      options: [
        _OptionData('I struggle and often lose the deal', 'closing', 3),
        _OptionData('I try but don\'t have a clear strategy', 'closing', 2),
        _OptionData('I handle most, but some throw me off', 'closing', 1),
        _OptionData('I confidently address all objections', 'closing', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 7,
      question: 'How would you rate your market knowledge?',
      options: [
        _OptionData('Basic - I\'m still learning', 'confidence', 3),
        _OptionData('Developing - I know some areas well', 'confidence', 2),
        _OptionData(
          'Good - I\'m knowledgeable about most areas',
          'confidence',
          1,
        ),
        _OptionData('Expert - I know the market inside out', 'confidence', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 8,
      question: 'How do you typically start your work day?',
      options: [
        _OptionData(
          'No set routine - I just react to what comes',
          'discipline',
          3,
        ),
        _OptionData('I check messages but no real plan', 'discipline', 2),
        _OptionData('I have a loose routine I follow', 'discipline', 1),
        _OptionData('I have a strict routine and task list', 'discipline', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 9,
      question: 'How active are you in generating your own leads?',
      options: [
        _OptionData(
          'Not active - I wait for leads to come',
          'leadGeneration',
          3,
        ),
        _OptionData('Somewhat - It is not systematic', 'leadGeneration', 2),
        _OptionData(
          'Active - I have some lead gen activities',
          'leadGeneration',
          1,
        ),
        _OptionData('Very active - Multiple lead sources', 'leadGeneration', 0),
      ],
    ),
    _DiagnosisQuestionData(
      id: 10,
      question: 'When you don\'t close a deal, what usually happens?',
      options: [
        _OptionData('I don\'t know why - it just fails', 'closing', 3),
        _OptionData('Client finds a better deal elsewhere', 'confidence', 2),
        _OptionData('I lose momentum in follow-ups', 'discipline', 2),
        _OptionData('I analyze and learn from each loss', 'closing', 0),
      ],
    ),
  ];

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

  Widget _buildQuestionCard(_DiagnosisQuestionData question) {
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

  Widget _buildOption(int questionId, int idx, _OptionData option) {
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

class _DiagnosisQuestionData {
  final int id;
  final String question;
  final List<_OptionData> options;
  _DiagnosisQuestionData({
    required this.id,
    required this.question,
    required this.options,
  });
}

class _OptionData {
  final String text;
  final String blockerType;
  final int score;
  _OptionData(this.text, this.blockerType, this.score);
}
