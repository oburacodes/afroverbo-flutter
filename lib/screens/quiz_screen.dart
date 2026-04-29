import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  final String lessonTitle;
  final int userId;

  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.userId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _questions = [];
  List<dynamic> _attempts = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  bool _quizCompleted = false;
  bool _savingResult = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final response = await ApiService.getQuizByLesson(widget.lessonId);
      if (response.statusCode == 200) {
        setState(() {
          _questions = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttempts() async {
    try {
      final response = await ApiService.getLessonAttempts(
        widget.userId,
        widget.lessonId,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _attempts = jsonDecode(response.body) as List<dynamic>;
        });
      }
    } catch (_) {}
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
    });

    final question = _questions[_currentIndex];
    final isCorrect = answer == question['correctAnswer'];
    if (isCorrect) _score++;

    _results.add({
      'question': question['question'],
      'selected': answer,
      'correct': question['correctAnswer'],
      'isCorrect': isCorrect,
      'explanation': question['explanation'],
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final percentage = (_score / _questions.length * 100).round();
    setState(() => _savingResult = true);
    await ApiService.updateUserProgress(
      widget.userId,
      widget.lessonId,
      percentage >= 70,
      percentage,
    );
    await _loadAttempts();
    if (!mounted) return;
    setState(() {
      _savingResult = false;
      _quizCompleted = true;
    });
  }

  Color _getOptionColor(String option) {
    if (!_answered) return Colors.white;
    final question = _questions[_currentIndex];
    if (option == question['correctAnswer']) return Colors.green.shade50;
    if (option == _selectedAnswer) return Colors.red.shade50;
    return Colors.white;
  }

  Color _getOptionBorderColor(String option) {
    if (!_answered) {
      return _selectedAnswer == option
          ? const Color(0xFF006B3C)
          : Colors.grey.shade300;
    }
    final question = _questions[_currentIndex];
    if (option == question['correctAnswer']) return Colors.green;
    if (option == _selectedAnswer) return Colors.red;
    return Colors.grey.shade300;
  }

  IconData? _getOptionIcon(String option) {
    if (!_answered) return null;
    final question = _questions[_currentIndex];
    if (option == question['correctAnswer']) return Icons.check_circle;
    if (option == _selectedAnswer) return Icons.cancel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF006B3C),
          title: const Text('Quiz', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF006B3C)),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF006B3C),
          title: const Text('Quiz', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📝', style: TextStyle(fontSize: 60)),
              SizedBox(height: 16),
              Text(
                'No quiz available for this lesson yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_quizCompleted) {
      return _buildResultsScreen();
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B3C),
        title: Text(
          'Quiz - ${widget.lessonTitle}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Question Counter ──
            Text(
              'Question ${_currentIndex + 1} of ${_questions.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // ── Question ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                question['question'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Options ──
            ...['A', 'B', 'C', 'D'].map((option) {
              final optionText = question['option$option'];
              final optionColor = _getOptionColor(option);
              final borderColor = _getOptionBorderColor(option);
              final icon = _getOptionIcon(option);

              return GestureDetector(
                onTap: () => _selectAnswer(option),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: optionColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: borderColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optionText ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (icon != null)
                        Icon(
                          icon,
                          color: option == question['correctAnswer']
                              ? Colors.green
                              : Colors.red,
                        ),
                    ],
                  ),
                ),
              );
            }),

            // ── Explanation ──
            if (_answered && question['explanation'] != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question['explanation'],
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Next Button ──
            if (_answered)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _savingResult ? null : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006B3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentIndex < _questions.length - 1
                        ? 'Next Question →'
                        : 'Finish Quiz 🎉',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_score / _questions.length * 100).round();
    final passed = percentage >= 70;
    final bestScore = _attempts.isEmpty
        ? percentage
        : _attempts
              .map((attempt) => (attempt['score'] as num?)?.toInt() ?? 0)
              .fold<int>(
                0,
                (currentBest, score) =>
                    score > currentBest ? score : currentBest,
              );
    final attemptCount = _attempts.isEmpty ? 1 : _attempts.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B3C),
        title: const Text(
          'Quiz Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Score Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: passed
                      ? [const Color(0xFF006B3C), const Color(0xFF00A35C)]
                      : [Colors.orange, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    passed ? '🎉' : '💪',
                    style: const TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    passed ? 'Excellent Work!' : 'Keep Practicing!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_score / ${_questions.length} correct',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passed
                        ? 'Lesson completed! ✅'
                        : 'Your score is saved. Reach 70% or above to complete the lesson.',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Attempt $attemptCount • Best score: $bestScore%',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Review Answers ──
            if (_attempts.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attempt History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006B3C),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._attempts.reversed.take(5).map((attempt) {
                final score = (attempt['score'] as num?)?.toInt() ?? 0;
                final completed = attempt['completed'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: completed
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      child: Text(
                        '$score%',
                        style: TextStyle(
                          color: completed
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text('Attempt ${attempt['attemptNumber'] ?? ''}'),
                    subtitle: Text(
                      completed
                          ? 'Completed lesson'
                          : 'Saved as practice attempt',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review Answers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006B3C),
                ),
              ),
            ),
            const SizedBox(height: 12),

            ..._results.map((result) {
              final isCorrect = result['isCorrect'] as bool;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result['question'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isCorrect)
                        Text(
                          'Your answer: ${result['selected']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      Text(
                        'Correct answer: ${result['correct']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      if (result['explanation'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          result['explanation'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                        _selectedAnswer = null;
                        _answered = false;
                        _score = 0;
                        _quizCompleted = false;
                        _savingResult = false;
                        _results = [];
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF006B3C),
                      side: const BorderSide(color: Color(0xFF006B3C)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006B3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Lesson'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
