import 'package:flutter/material.dart';
import '../../api/learning_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/elite_loader.dart';

class CourseExamPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseExamPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseExamPage> createState() => _CourseExamPageState();
}

class _CourseExamPageState extends State<CourseExamPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _exam;
  final Map<int, int> _answers = {}; // questionId -> selectedIndex
  bool _submitted = false;
  int? _scorePercent;
  bool? _passed;
  int? _correct;
  int? _total;
  String? _startedAt;

  @override
  void initState() {
    super.initState();
    _loadExam();
  }

  Future<void> _loadExam() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _exam = null;
      _answers.clear();
      _submitted = false;
    });
    try {
      final res = await LearningApi.getCourseExam(widget.courseId);
      if (res['success'] == true && res['data'] != null) {
        _startedAt = DateTime.now().toIso8601String();
        setState(() {
          _exam = res['data'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Could not load exam';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitExam() async {
    final questions = _exam!['questions'] as List<dynamic>? ?? [];
    if (questions.isEmpty) return;
    final answers = <Map<String, dynamic>>[];
    for (final q in questions) {
      final id = q['id'] as int?;
      if (id != null && _answers.containsKey(id)) {
        answers.add({
          'question_id': id,
          'selected_index': _answers[id],
        });
      }
    }
    if (answers.length != questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting.'),
          backgroundColor: Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await LearningApi.submitCourseExam(
        courseId: widget.courseId,
        answers: answers,
        startedAt: _startedAt,
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _scorePercent = data['score_percent'] as int?;
          _passed = data['passed'] as bool?;
          _correct = data['correct'] as int?;
          _total = data['total'] as int?;
          _submitted = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Submit failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _submitted ? 'Certification result' : 'Certification exam',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      body: _isLoading && !_submitted
          ? const Center(child: EliteLoader())
          : _error != null && !_submitted
              ? _buildError()
              : _submitted
                  ? _buildResult()
                  : _buildExam(),
    );
  }

  Widget _buildExamMeta(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to course'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final passed = _passed ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              passed ? Icons.celebration_rounded : Icons.refresh_rounded,
              size: 72,
              color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 20),
            Text(
              passed ? 'You passed!' : 'Keep practicing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              passed
                  ? 'You\'ve earned your certification.'
                  : 'Review the modules and try again.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Text(
              'Score: $_scorePercent% ($_correct / $_total correct)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            if (passed) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  // Certificate download will be added soon
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate download coming soon.'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download certificate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Back to course'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExam() {
    final exam = _exam;
    if (exam == null) return const SizedBox.shrink();
    final questions = (exam['questions'] as List<dynamic>?) ?? [];
    final passingPercent = exam['passing_percent'] as int? ?? 70;
    final timeMinutes = exam['time_minutes'] as int?;
    final examTitle = exam['title'] as String? ?? 'Certification exam';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1).withOpacity(0.08),
                const Color(0xFF8B5CF6).withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      examTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildExamMeta('${questions.length}', 'questions'),
                  const SizedBox(width: 16),
                  _buildExamMeta('$passingPercent%', 'to pass'),
                  if (timeMinutes != null) ...[
                    const SizedBox(width: 16),
                    _buildExamMeta('$timeMinutes min', 'time limit'),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i] as Map<String, dynamic>;
              final id = q['id'] as int? ?? 0;
              final text = q['question_text'] as String? ?? '';
              final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? [];
              final selected = _answers[id];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected != null
                        ? const Color(0xFF6366F1).withOpacity(0.4)
                        : Colors.grey.shade200,
                    width: selected != null ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. $text',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(options.length, (j) {
                        final isSelected = selected == j;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _answers[id] = j);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1).withOpacity(0.12)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      options[j],
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ElevatedButton(
              onPressed: _submitExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Submit for certification',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
