import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  int? _userId;
  String? _username;
  String? _role;
  String? _token;
  Map<String, dynamic>? _languageLearning;
  Map<String, dynamic>? _activeLanguage; // ✅ new

  bool get isLoggedIn => _isLoggedIn;
  int? get userId => _userId;
  String? get username => _username;
  String? get role => _role;
  String? get token => _token; // ✅ new
  Map<String, dynamic>? get languageLearning => _languageLearning;
  Map<String, dynamic>? get activeLanguage => _activeLanguage; // ✅ new
  bool get isAdmin => _role == 'ADMIN';

  // ✅ Check if user is already logged in on app start
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = prefs.getInt('user_id');
    final username = prefs.getString('username');
    final role = prefs.getString('role');
    final languageJson = prefs.getString('language_learning');
    final activeLanguageJson = prefs.getString('active_language'); // ✅ new

    if (token != null && userId != null) {
      _isLoggedIn = true;
      _userId = userId;
      _username = username;
      _role = role;
      _token = token; // ✅ new
      _languageLearning = languageJson != null
          ? jsonDecode(languageJson)
          : null;
      _activeLanguage =
          activeLanguageJson !=
              null // ✅ new
          ? jsonDecode(activeLanguageJson)
          : null;
      notifyListeners();
    }
  }

  // ✅ Login
  Future<bool> login(String username, String password) async {
    final response = await ApiService.login(username, password);

    if (response.statusCode == 200) {
      final token = response.body;
      _token = token; // ✅ new
      await ApiService.saveToken(token);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ✅ Save user details after login
  Future<void> saveUserDetails(
    int userId,
    String username,
    String role,
    Map<String, dynamic>? languageLearning, {
    Map<String, dynamic>? activeLanguage, // ✅ new optional param
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setString('username', username);
    await prefs.setString('role', role);

    if (languageLearning != null) {
      await prefs.setString('language_learning', jsonEncode(languageLearning));
    }

    // ✅ Save active language — fall back to languageLearning if not provided
    final effectiveActiveLanguage = activeLanguage ?? languageLearning;
    if (effectiveActiveLanguage != null) {
      await prefs.setString(
        'active_language',
        jsonEncode(effectiveActiveLanguage),
      );
    }

    _isLoggedIn = true;
    _userId = userId;
    _username = username;
    _role = role;
    _languageLearning = languageLearning;
    _activeLanguage = effectiveActiveLanguage; // ✅ new
    notifyListeners();
  }

  // ✅ Refresh user from backend — called after switching language
  Future<void> refreshUser() async {
    if (_userId == null) return;

    try {
      final response = await ApiService.getUserById(_userId!);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final activeLanguage = data['activeLanguage'];
        final languageLearning = data['languageLearning'];

        // Update in memory
        _activeLanguage = activeLanguage;
        _languageLearning = languageLearning;

        // Persist to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (activeLanguage != null) {
          await prefs.setString('active_language', jsonEncode(activeLanguage));
        }
        if (languageLearning != null) {
          await prefs.setString(
            'language_learning',
            jsonEncode(languageLearning),
          );
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('refreshUser error: $e');
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await ApiService.clearToken();

    _isLoggedIn = false;
    _userId = null;
    _username = null;
    _role = null;
    _token = null; // ✅ new
    _languageLearning = null;
    _activeLanguage = null; // ✅ new
    notifyListeners();
  }
}
