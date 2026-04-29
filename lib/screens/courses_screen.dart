import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'modules_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _loadedLanguageId; // ✅ track which language we last loaded for

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Reload if active language changed since last load
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final activeId = auth.activeLanguage?['id'];
    if (activeId != null && activeId != _loadedLanguageId) {
      _loadCourses();
    }
  }

  Future<void> _loadCourses() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final language = auth.activeLanguage ?? auth.languageLearning;
    if (language == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getCoursesByLanguage(language['id']);
      if (!mounted) return; // ✅ add this
      if (response.statusCode == 200) {
        setState(() {
          final levelOrder = {'BEGINNER': 0, 'INTERMEDIATE': 1, 'ADVANCED': 2};
          _courses = jsonDecode(response.body);
          _courses.sort((a, b) {
            final aOrder = levelOrder[a['level']] ?? 99;
            final bOrder = levelOrder[b['level']] ?? 99;
            return aOrder.compareTo(bOrder);
          });
          _loadedLanguageId = language['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // ✅ add this
      setState(() {
        _errorMessage = 'Failed to load courses';
        _isLoading = false;
      });
    }
  }

  Color _getLevelColor(String? level) {
    switch (level) {
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
    // ✅ Listen to auth changes so UI rebuilds when language switches
    final auth = Provider.of<AuthProvider>(context);
    final language = auth.activeLanguage ?? auth.languageLearning;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF006B3C)),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📚', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text(
              'No courses available yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: const Color(0xFF006B3C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                  // ✅ Shows active language name and flag
                  Text(
                    '${language?['flagEmoji'] ?? '🌍'} ${language?['name'] ?? ''} Courses',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_courses.length} courses available — All FREE!',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Courses List ──
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                final level = course['level'] ?? 'BEGINNER';
                final levelColor = _getLevelColor(level);

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModulesScreen(
                        courseId: course['id'],
                        courseTitle: course['title'],
                      ),
                    ),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (course['imageUrl'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: Image.network(
                              course['imageUrl'],
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 150,
                                    color: const Color(0xFF006B3C),
                                    child: const Center(
                                      child: Text(
                                        '📚',
                                        style: TextStyle(fontSize: 60),
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: levelColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: levelColor),
                                    ),
                                    child: Text(
                                      level,
                                      style: TextStyle(
                                        color: levelColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text(
                                      '✅ FREE',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                course['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                course['description'] ?? '',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Color(0xFF006B3C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course['estimatedHours'] ?? 0} hours',
                                    style: const TextStyle(
                                      color: Color(0xFF006B3C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Start Learning →',
                                    style: TextStyle(
                                      color: Color(0xFF006B3C),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
