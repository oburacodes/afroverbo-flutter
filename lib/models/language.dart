class Language {
  final int id;
  final String name;
  final String? description;
  final String? flagEmoji;

  Language({
    required this.id,
    required this.name,
    this.description,
    this.flagEmoji,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      flagEmoji: json['flagEmoji'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
