import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/lesson.dart';
import 'lesson_detail_screen.dart';

class StudentLessonsTab extends StatefulWidget {
  const StudentLessonsTab({super.key});

  @override
  State<StudentLessonsTab> createState() => _StudentLessonsTabState();
}

class _StudentLessonsTabState extends State<StudentLessonsTab> {
  List<Lesson> _lessons = [];
  Map<String, dynamic>? _progressSummary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Get language id from user's language
      final languageId = auth.languageLearning?['id'];

      if (languageId == null) {
        setState(() {
          _errorMessage = 'No language selected. Update your profile!';
          _isLoading = false;
        });
        return;
      }

      final lessonsResponse = await ApiService.getLessonsByLanguage(languageId);
      final progressResponse = await ApiService.getProgressSummary(
        auth.userId!,
      );

      setState(() {
        if (lessonsResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(lessonsResponse.body);
          _lessons = data.map((e) => Lesson.fromJson(e)).toList();
        }
        if (progressResponse.statusCode == 200) {
          _progressSummary = jsonDecode(progressResponse.body);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load lessons';
        _isLoading = false;
      });
    }
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'BEGINNER':
        return Colors.green;
      case 'INTERMEDIATE':
        return Colors.orange;
      case 'ADVANCED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF006B3C)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLessons,
      color: const Color(0xFF006B3C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Progress Banner ──────────────────────────
            if (_progressSummary != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006B3C), Color(0xFF00A35C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep going, ${auth.username ?? ''}! 💪',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_progressSummary!['completedLessons']} of ${_progressSummary!['totalLessons']} lessons completed',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Score progress: ${_progressSummary!['progressPercentage'] ?? 0}% • Completion: ${_progressSummary!['completionPercentage'] ?? 0}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value:
                            (_progressSummary!['progressPercentage'] as int)
                                .toDouble() /
                            100,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFD700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_progressSummary!['attemptedLessons'] ?? 0} lessons attempted • ${_progressSummary!['totalAttempts'] ?? 0} total quiz attempts',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ─── Language Label ───────────────────────────
            if (auth.languageLearning != null)
              Row(
                children: [
                  Text(
                    auth.languageLearning!['flagEmoji'] ?? '🌍',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${auth.languageLearning!['name']} Lessons',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006B3C),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // ─── Lessons List ─────────────────────────────
            if (_lessons.isEmpty)
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 40),
                    Text('📚', style: TextStyle(fontSize: 60)),
                    SizedBox(height: 16),
                    Text(
                      'No lessons available yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lessons.length,
                itemBuilder: (context, index) {
                  final lesson = _lessons[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LessonDetailScreen(lesson: lesson),
                          ),
                        ).then((_) => _loadLessons());
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Lesson icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF006B3C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  '📖',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lesson.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lesson.content.length > 60
                                        ? '${lesson.content.substring(0, 60)}...'
                                        : lesson.content,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _levelColor(
                                        lesson.level,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _levelColor(lesson.level),
                                      ),
                                    ),
                                    child: Text(
                                      lesson.level,
                                      style: TextStyle(
                                        color: _levelColor(lesson.level),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
