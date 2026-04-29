import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  //static const String baseUrl = 'https://afroverbo-backend.onrender.com/api';

  static const String baseUrl = 'http://10.0.2.2:8080/api';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> publicHeaders() {
    return {'Content-Type': 'application/json'};
  }

  // ─── AUTH ────────────────────────────────────────────

  static Future<http.Response> register(
    String username,
    String email,
    String password,
    String role,
    int? languageId,
  ) async {
    final url = languageId != null
        ? '$baseUrl/auth/register?languageId=$languageId'
        : '$baseUrl/auth/register';

    return await http.post(
      Uri.parse(url),
      headers: publicHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      }),
    );
  }

  static Future<http.Response> login(String username, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: publicHeaders(),
      body: jsonEncode({'username': username, 'password': password}),
    );
  }

  static Future<http.Response> getUserByUsername(String username) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/users/username/$username'),
      headers: headers,
    );
  }

  // ✅ Get user by ID
  static Future<http.Response> getUserById(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: headers,
    );
  }

  // ─── LANGUAGES ───────────────────────────────────────

  static Future<http.Response> getLanguages() async {
    try {
      print('Fetching languages from: $baseUrl/languages');
      final response = await http.get(
        Uri.parse('$baseUrl/languages'),
        headers: publicHeaders(),
      );
      print('Languages response status: ${response.statusCode}');
      print('Languages response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error fetching languages: $e');
      rethrow;
    }
  }

  // ✅ Get all languages a user is enrolled in
  static Future<http.Response> getEnrolledLanguages(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/user-languages/user/$userId'),
      headers: headers,
    );
  }

  // ✅ Enroll in a new language (also switches active language)
  static Future<http.Response> enrollInLanguage(
    int userId,
    int languageId,
  ) async {
    final headers = await authHeaders();
    return await http.post(
      Uri.parse('$baseUrl/user-languages/user/$userId/enroll/$languageId'),
      headers: headers,
    );
  }

  // ✅ Switch to an already-enrolled language
  static Future<http.Response> switchLanguage(
    int userId,
    int languageId,
  ) async {
    final headers = await authHeaders();
    return await http.put(
      Uri.parse('$baseUrl/user-languages/user/$userId/switch/$languageId'),
      headers: headers,
    );
  }

  // ─── LESSONS ─────────────────────────────────────────

  static Future<http.Response> getLessonsByLanguage(int languageId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/lessons/language/$languageId'),
      headers: headers,
    );
  }

  static Future<http.Response> getLesson(int lessonId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/lessons/$lessonId'),
      headers: headers,
    );
  }

  // ─── PROGRESS ────────────────────────────────────────

  static Future<http.Response> getProgressSummary(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/progress/user/$userId/summary'),
      headers: headers,
    );
  }

  static Future<http.Response> getCompletedLessons(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/progress/user/$userId/completed'),
      headers: headers,
    );
  }

  static Future<http.Response> completeLesson(
    int userId,
    int lessonId,
    int score,
  ) async {
    final headers = await authHeaders();
    return await http.post(
      Uri.parse(
        '$baseUrl/progress/user/$userId/lesson/$lessonId?completed=true&score=$score',
      ),
      headers: headers,
    );
  }

  // ─── TUTORS ──────────────────────────────────────────

  static Future<http.Response> getTutors({
    String? query,
    String? specialization,
    double? minRate,
    double? maxRate,
    bool? available,
  }) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$baseUrl/tutors').replace(
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (specialization != null && specialization.isNotEmpty)
          'specialization': specialization,
        if (minRate != null) 'minRate': minRate.toString(),
        if (maxRate != null) 'maxRate': maxRate.toString(),
        if (available != null) 'available': available.toString(),
      },
    );
    return await http.get(uri, headers: headers);
  }

  static Future<http.Response> getTutorsBySpecialization(
    String specialization,
  ) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/tutors/specialization/$specialization'),
      headers: headers,
    );
  }

  // ✅ Update tutor profile
  static Future<http.Response> updateTutorProfile(
    int profileId,
    Map<String, dynamic> data,
  ) async {
    final headers = await authHeaders();
    return await http.put(
      Uri.parse('$baseUrl/tutors/$profileId'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  // ✅ Get tutor profile by user ID
  static Future<http.Response> getTutorProfileByUserId(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/tutors/user/$userId'),
      headers: headers,
    );
  }

  // ✅ Get tutor-specific report
  static Future<http.Response> getTutorReport(int tutorId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/reports/tutor/$tutorId'),
      headers: headers,
    );
  }

  static Future<http.Response> downloadTutorReport(int tutorId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/reports/tutor/$tutorId/download'),
      headers: headers,
    );
  }

  static Future<http.Response> getTutorAvailability(int profileId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/tutors/$profileId/availability'),
      headers: headers,
    );
  }

  static Future<http.Response> updateTutorAvailability(
    int profileId,
    List<Map<String, dynamic>> slots,
  ) async {
    final headers = await authHeaders();
    return await http.put(
      Uri.parse('$baseUrl/tutors/$profileId/availability'),
      headers: headers,
      body: jsonEncode(slots),
    );
  }

  // ─── BOOKINGS ────────────────────────────────────────

  static Future<http.Response> bookTutor(
    int studentId,
    int tutorId,
    String sessionDate,
    String notes,
  ) async {
    final headers = await authHeaders();
    return await http.post(
      Uri.parse(
        '$baseUrl/bookings?studentId=$studentId&tutorId=$tutorId&sessionDate=$sessionDate&notes=$notes',
      ),
      headers: headers,
    );
  }

  static Future<http.Response> getStudentBookings(
    int studentId, {
    String? status,
    String? query,
  }) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$baseUrl/bookings/student/$studentId').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return await http.get(
      uri,
      headers: headers,
    );
  }

  static Future<http.Response> getTutorBookings(
    int tutorId, {
    String? status,
    String? query,
  }) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$baseUrl/bookings/tutor/$tutorId').replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return await http.get(
      uri,
      headers: headers,
    );
  }

  static Future<http.Response> updateBookingStatus(
    int bookingId,
    String status,
    String? tutorReply,
  ) async {
    final headers = await authHeaders();
    String url = '$baseUrl/bookings/$bookingId/status?status=$status';
    if (tutorReply != null && tutorReply.isNotEmpty) {
      url += '&tutorReply=${Uri.encodeComponent(tutorReply)}';
    }
    return await http.put(Uri.parse(url), headers: headers);
  }

  static Future<http.Response> payForBooking(
    int bookingId,
    String phoneNumber,
  ) async {
    final headers = await authHeaders();
    return await http.put(
      Uri.parse(
        '$baseUrl/bookings/$bookingId/pay?phoneNumber=${Uri.encodeComponent(phoneNumber)}',
      ),
      headers: headers,
    );
  }

  // ─── PASSWORD ────────────────────────────────────────

  static Future<http.Response> forgotPassword(String email) async {
    return await http.post(
      Uri.parse('$baseUrl/password/forgot?email=${Uri.encodeComponent(email)}'),
      headers: publicHeaders(),
    );
  }

  static Future<http.Response> verifyEmail(String email, String otp) async {
    return await http.post(
      Uri.parse(
        '$baseUrl/auth/verify?email=${Uri.encodeComponent(email)}&otp=$otp',
      ),
      headers: publicHeaders(),
    );
  }

  static Future<http.Response> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    return await http.post(
      Uri.parse(
        '$baseUrl/password/reset?email=${Uri.encodeComponent(email)}&otp=$otp&newPassword=${Uri.encodeComponent(newPassword)}',
      ),
      headers: publicHeaders(),
    );
  }

  // ─── REPORTS ─────────────────────────────────────────

  static Future<http.Response> getReports() async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/reports/summary'),
      headers: headers,
    );
  }

  // ─── COURSES ─────────────────────────────────────────

  static Future<http.Response> getCoursesByLanguage(int languageId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/courses/language/$languageId'),
      headers: headers,
    );
  }

  static Future<http.Response> getCourse(int courseId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/courses/$courseId'),
      headers: headers,
    );
  }

  // ─── MODULES ─────────────────────────────────────────

  static Future<http.Response> getModulesByCourse(int courseId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/modules/course/$courseId'),
      headers: headers,
    );
  }

  // ─── LESSON CONTENTS ─────────────────────────────────

  static Future<http.Response> getLessonsByModule(int moduleId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/lesson-contents/module/$moduleId'),
      headers: headers,
    );
  }

  static Future<http.Response> getLessonContent(int lessonId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/lesson-contents/$lessonId'),
      headers: headers,
    );
  }

  // ─── QUIZ ─────────────────────────────────────────────

  static Future<http.Response> getQuizByLesson(int lessonId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/quiz/lesson/$lessonId'),
      headers: headers,
    );
  }

  // ─── USER PROGRESS ────────────────────────────────────

  static Future<http.Response> getUserProgressSummary(int userId) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse('$baseUrl/user-progress/user/$userId/summary'),
      headers: headers,
    );
  }

  static Future<http.Response> getLessonAttempts(
    int userId,
    int lessonId,
  ) async {
    final headers = await authHeaders();
    return await http.get(
      Uri.parse(
        '$baseUrl/user-progress/user/$userId/lesson/$lessonId/attempts',
      ),
      headers: headers,
    );
  }

  static Future<http.Response> updateUserProgress(
    int userId,
    int lessonId,
    bool completed,
    int? quizScore,
  ) async {
    final headers = await authHeaders();
    String url =
        '$baseUrl/user-progress/user/$userId/lesson/$lessonId?completed=$completed';
    if (quizScore != null) {
      url += '&quizScore=$quizScore';
    }
    return await http.post(Uri.parse(url), headers: headers);
  }
}
