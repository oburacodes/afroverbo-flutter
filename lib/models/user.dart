class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final Language? languageLearning; // initial language
  final Language? activeLanguage; // ✅ currently active
  final bool verified;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.languageLearning,
    this.activeLanguage,
    required this.verified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'] ?? 'USER',
      languageLearning: json['languageLearning'] != null
          ? Language.fromJson(json['languageLearning'])
          : null,
      activeLanguage: json['activeLanguage'] != null
          ? Language.fromJson(json['activeLanguage'])
          : null,
      verified: json['verified'] ?? false,
    );
  }
}

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
}
