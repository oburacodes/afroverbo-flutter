import 'dart:convert';
import 'api_service.dart';

class LanguageService {
  // Get all available languages
  Future<List<dynamic>> getAllLanguages() async {
    final response = await ApiService.getLanguages();
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load languages');
  }

  // Get languages user is enrolled in
  Future<List<dynamic>> getEnrolledLanguages(int userId) async {
    final response = await ApiService.getEnrolledLanguages(userId);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load enrolled languages');
  }

  // Enroll in a new language and switch to it
  Future<Map<String, dynamic>> enrollInLanguage(
    int userId,
    int languageId,
  ) async {
    final response = await ApiService.enrollInLanguage(userId, languageId);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(response.body);
  }

  // Switch to an already-enrolled language
  Future<Map<String, dynamic>> switchLanguage(
    int userId,
    int languageId,
  ) async {
    final response = await ApiService.switchLanguage(userId, languageId);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(response.body);
  }
}
