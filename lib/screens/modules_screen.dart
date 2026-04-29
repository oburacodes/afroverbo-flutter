import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'lesson_content_screen.dart';

class ModulesScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const ModulesScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    try {
      final response = await ApiService.getModulesByCourse(widget.courseId);
      if (response.statusCode == 200) {
        setState(() {
          _modules = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B3C),
        title: Text(
          widget.courseTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF006B3C)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _modules.length,
              itemBuilder: (context, index) {
                final module = _modules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF006B3C),
                      child: Text(
                        '${module['orderNumber']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      module['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      module['description'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    children: [LessonsList(moduleId: module['id'])],
                  ),
                );
              },
            ),
    );
  }
}

class LessonsList extends StatefulWidget {
  final int moduleId;

  const LessonsList({super.key, required this.moduleId});

  @override
  State<LessonsList> createState() => _LessonsListState();
}

class _LessonsListState extends State<LessonsList> {
  List<dynamic> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final response = await ApiService.getLessonsByModule(widget.moduleId);
      if (response.statusCode == 200) {
        setState(() {
          _lessons = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: Color(0xFF006B3C)),
      );
    }

    return Column(
      children: _lessons.map((lesson) {
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFD700),
            radius: 16,
            child: Icon(Icons.menu_book, size: 16, color: Colors.black),
          ),
          title: Text(
            lesson['title'],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Color(0xFF006B3C),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonContentScreen(
                lessonId: lesson['id'],
                lessonTitle: lesson['title'],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
