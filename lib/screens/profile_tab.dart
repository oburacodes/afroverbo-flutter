import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _progressSummary;
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  List<dynamic> _allLanguages = [];
  List<dynamic> _enrolledLanguages = [];
  bool _languagesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null || auth.isAdmin) return; // ✅ skip for tutors

    try {
      final service = LanguageService();
      final all = await service.getAllLanguages();
      final enrolled = await service.getEnrolledLanguages(auth.userId!);
      if (!mounted) return;
      setState(() {
        _allLanguages = all;
        _enrolledLanguages = enrolled;
        _languagesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _languagesLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;

    try {
      final progressResponse = await ApiService.getUserProgressSummary(
        auth.userId!,
      );
      final bookingsResponse = await ApiService.getStudentBookings(
        auth.userId!,
      );

      if (!mounted) return;
      setState(() {
        if (progressResponse.statusCode == 200) {
          _progressSummary = jsonDecode(progressResponse.body);
        }
        if (bookingsResponse.statusCode == 200) {
          _bookings = jsonDecode(bookingsResponse.body);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _isEnrolled(int languageId) {
    return _enrolledLanguages.any((e) => e['language']['id'] == languageId);
  }

  Future<void> _selectLanguage(
    Map<String, dynamic> lang,
    AuthProvider auth,
  ) async {
    final langId = lang['id'] as int;
    final service = LanguageService();

    try {
      if (_isEnrolled(langId)) {
        await service.switchLanguage(auth.userId!, langId);
      } else {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Learn ${lang['name']}?'),
            content: Text(
              'You\'ll be enrolled in ${lang['name']}. '
              'Your progress in other languages is saved and you can switch back anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006B3C),
                ),
                child: const Text(
                  'Enroll',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await service.enrollInLanguage(auth.userId!, langId);
        await _loadLanguages();
      }

      await auth.refreshUser();
      await _loadProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${lang['name']} ${lang['flagEmoji'] ?? ''}',
            ),
            backgroundColor: const Color(0xFF006B3C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.blue;
      case 'PAID':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      case 'COMPLETED':
        return Icons.done_all;
      case 'PAID':
        return Icons.verified;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  List<dynamic> get _badges {
    final badges = _progressSummary?['badges'];
    return badges is List ? badges : const [];
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF006B3C)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfileData();
        await _loadLanguages();
      },
      color: const Color(0xFF006B3C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Card ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006B3C), Color(0xFF00A35C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      (auth.username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006B3C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.username ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      auth.isAdmin ? '👨‍🏫 Tutor' : '🎓 Student',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (auth.activeLanguage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Learning: ${auth.activeLanguage!['flagEmoji'] ?? '🌍'} ${auth.activeLanguage!['name']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Progress Summary ─────────────────────────
            if (_progressSummary != null) ...[
              const Text(
                'My Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006B3C),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(
                          '${_progressSummary!['completedLessons']}',
                          'Completed',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _statCard(
                          '${_progressSummary!['totalLessons']}',
                          'Total',
                          Icons.menu_book,
                          const Color(0xFF006B3C),
                        ),
                        _statCard(
                          '${_progressSummary!['progressPercentage'] ?? 0}%',
                          'Score',
                          Icons.trending_up,
                          const Color(0xFFFFD700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(
                          '${_progressSummary!['completionPercentage'] ?? 0}%',
                          'Completion',
                          Icons.flag,
                          Colors.blue,
                        ),
                        _statCard(
                          '${_progressSummary!['attemptedLessons'] ?? 0}',
                          'Attempted',
                          Icons.edit_note,
                          Colors.orange,
                        ),
                        _statCard(
                          '${_progressSummary!['totalAttempts'] ?? 0}',
                          'Attempts',
                          Icons.repeat,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value:
                            ((_progressSummary!['progressPercentage'] ?? 0)
                                    as int)
                                .toDouble() /
                            100,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF006B3C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score progress is based on best quiz scores. Completion progress tracks passed lessons.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_badges.isNotEmpty) ...[
              const Text(
                'Badges',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006B3C),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _badges.map((badge) {
                  final icon = badge['badgeIcon']?.toString() ?? '🏅';
                  final name = badge['badgeName']?.toString() ?? 'Badge';
                  final description =
                      badge['description']?.toString() ??
                      'Achievement unlocked';
                  return Container(
                    width: 160,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 8),
                        Text(
                          name.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006B3C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Language Switcher (students only) ────────
            if (!auth.isAdmin) ...[
              const Text(
                'Learning Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006B3C),
                ),
              ),
              const SizedBox(height: 12),
              _languagesLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF006B3C),
                      ),
                    )
                  : Container(
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
                      child: Column(
                        children: _allLanguages.map((lang) {
                          final isActive =
                              auth.activeLanguage != null &&
                              auth.activeLanguage!['id'] == lang['id'];
                          final enrolled = _isEnrolled(lang['id']);

                          return ListTile(
                            leading: Text(
                              lang['flagEmoji'] ?? '🌍',
                              style: const TextStyle(fontSize: 28),
                            ),
                            title: Text(
                              lang['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              isActive
                                  ? 'Currently learning'
                                  : enrolled
                                  ? 'Tap to switch'
                                  : 'Tap to enroll',
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF006B3C)
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isActive
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF006B3C),
                                  )
                                : enrolled
                                ? const Icon(
                                    Icons.swap_horiz,
                                    color: Colors.blue,
                                  )
                                : const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.grey,
                                  ),
                            onTap: isActive
                                ? null
                                : () => _selectLanguage(lang, auth),
                          );
                        }).toList(),
                      ),
                    ),
              const SizedBox(height: 24),
            ], // ✅ end of student-only language switcher
            // ─── My Bookings ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Bookings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006B3C),
                  ),
                ),
                Text(
                  '${_bookings.length} total',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_bookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text('📅', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text(
                      'No bookings yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Book a tutor session to get started!',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  final status = booking['status'] ?? 'PENDING';
                  final statusColor = _getStatusColor(status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF006B3C),
                                    radius: 24,
                                    child: Text(
                                      booking['tutor']['username'][0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking['tutor']['username'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Text(
                                        'Your Tutor',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF006B3C,
                                  ).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF006B3C,
                                    ).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF006B3C),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Session Scheduled',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _formatDate(
                                            booking['sessionDate'].toString(),
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF006B3C),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF006B3C),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Time',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(
                                            booking['sessionDate'].toString(),
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF006B3C),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '💰 Amount:',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    'KES ${booking['amountPaid']?.toStringAsFixed(0) ?? '0'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF006B3C),
                                    ),
                                  ),
                                ],
                              ),
                              if (booking['notes'] != null &&
                                  booking['notes'].toString().isNotEmpty) ...[
                                const Divider(),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.notes,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Your Notes:',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  booking['notes'],
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (booking['tutorReply'] != null &&
                                  booking['tutorReply']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tutor Reply:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    booking['tutorReply'],
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              if (status == 'CONFIRMED') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final String phoneNumber =
                                          '+254712345678';

                                      var response =
                                          await ApiService.payForBooking(
                                            booking['id'],
                                            phoneNumber,
                                          );

                                      if (!mounted) return;

                                      if (response.statusCode == 200) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Payment successful! 🎉 Session locked in!',
                                            ),
                                            backgroundColor: Color(0xFF006B3C),
                                          ),
                                        );
                                        _loadProfileData();
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Payment failed. Please try again.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFD700),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    icon: const Icon(Icons.payment, size: 20),
                                    label: const Text(
                                      'Pay Now to Confirm Session',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Booked on: ${_formatDate(booking['bookedAt'].toString())}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // ─── Logout Button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await auth.logout();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/welcome');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Logout', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
