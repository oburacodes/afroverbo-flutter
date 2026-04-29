class Lesson {
  final int id;
  final String title;
  final String content;
  final String level;
  final Map<String, dynamic> language;
  final Map<String, dynamic> tutor;

  Lesson({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.language,
    required this.tutor,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      level: json['level'],
      language: json['language'],
      tutor: json['tutor'],
    );
  }
}
