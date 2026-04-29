import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/tutor.dart';

class TutorTab extends StatefulWidget {
  const TutorTab({super.key});

  @override
  State<TutorTab> createState() => _TutorTabState();
}

class _TutorTabState extends State<TutorTab> {
  List<TutorProfile> _tutors = [];
  List<TutorProfile> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String? _selectedSpecialization;
  final double _minRate = 0;
  final double _maxRate = 10000;

  @override
  void initState() {
    super.initState();
    _loadTutors();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTutors({
    String? query,
    String? specialization,
    double? minRate,
    double? maxRate,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getTutors(
        query: query,
        specialization: specialization,
        minRate: minRate != null && minRate > 0 ? minRate : null,
        maxRate: maxRate != null && maxRate < 10000 ? maxRate : null,
        available: true,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded['content'] != null) {
          data = decoded['content'];
        } else if (decoded['data'] != null) {
          data = decoded['data'];
        } else {
          throw Exception("Unexpected response format");
        }
        setState(() {
          _tutors = data.map((e) => TutorProfile.fromJson(e)).toList();
          _filtered = List.from(_tutors);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load tutors';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _tutors.where((t) {
        final name = (t.user['username'] ?? '').toString().toLowerCase();
        final spec = (t.specialization ?? '').toLowerCase();
        final bio = (t.bio).toLowerCase();
        final matchesQuery =
            q.isEmpty ||
            name.contains(q) ||
            spec.contains(q) ||
            bio.contains(q);
        final matchesSpec =
            _selectedSpecialization == null ||
            t.specialization == _selectedSpecialization;
        final matchesRate =
            t.hourlyRate >= _minRate && t.hourlyRate <= _maxRate;
        return matchesQuery && matchesSpec && matchesRate;
      }).toList();
    });
  }

  // ── Booking flow ─────────────────────────────────────────────────────────
  Future<void> _bookTutor(TutorProfile tutor) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Parse active slots — handle active as bool OR string from JSON
    bool isActiveSlot(dynamic s) {
      final v = s['active'];
      if (v == null) return true;
      if (v is bool) return v;
      return v.toString().toLowerCase() == 'true';
    }

    final rawSlots = (tutor.availabilitySlots ?? [])
        .where((s) => isActiveSlot(s))
        .toList();

    // If tutor has no slots configured, fall back to free date/time picker
    final bool hasSlots = rawSlots.isNotEmpty;

    // Parse all active slots — keep ALL, don't filter by date (tutor manages expiry)
    final List<Map<String, dynamic>> futureSlots = [];
    for (final s in rawSlots) {
      try {
        final start = DateTime.parse(s['startDateTime'].toString());
        final end = DateTime.parse(s['endDateTime'].toString());
        futureSlots.add({
          'start': start,
          'end': end,
          'label': s['label']?.toString() ?? '',
        });
      } catch (_) {}
    }
    // Sort by start time
    futureSlots.sort(
      (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
    );

    // State for the dialog
    int? selectedSlotIndex; // which slot the student picked
    DateTime? selectedDateTime; // the exact session start within that slot
    DateTime? selectedDate; // fallback (no slots)
    TimeOfDay? selectedTime; // fallback (no slots)
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ── Helper: time picker within a slot ──────────────────────────
          Future<void> pickTimeInSlot(int slotIdx) async {
            final slot = futureSlots[slotIdx];
            final start = slot['start'] as DateTime;
            final end = slot['end'] as DateTime;

            // Show a time picker restricted to slot's day
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
              builder: (c, ch) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF006B3C),
                  ),
                ),
                child: ch!,
              ),
            );
            if (picked == null) return;

            // Build full datetime on the slot's date
            final candidate = DateTime(
              start.year,
              start.month,
              start.day,
              picked.hour,
              picked.minute,
            );

            // Validate: must be within slot and session end (+ 1h) must not exceed slot end
            final sessionEnd = candidate.add(const Duration(hours: 1));
            if (candidate.isBefore(start) || sessionEnd.isAfter(end)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please pick a time between '
                      '${_fmt2(start.hour)}:${_fmt2(start.minute)} and '
                      '${_fmt2(end.hour - 1)}:${_fmt2(end.minute)} '
                      '(session is 1 hour)',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            setDialogState(() {
              selectedSlotIndex = slotIdx;
              selectedDateTime = candidate;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF006B3C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Book ${tutor.user['username']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rateBox(tutor),
                  const SizedBox(height: 12),
                  _paymentNotice(),

                  // ── General availability note ──────────────────────────
                  if (tutor.availableTimes != null &&
                      tutor.availableTimes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tutor.availableTimes!.trim(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── SLOT SELECTOR (or fallback free picker) ────────────
                  if (hasSlots && futureSlots.isNotEmpty) ...[
                    // Header
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006B3C).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF006B3C).withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            color: Color(0xFF006B3C),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Select one of the tutor\'s available slots, then pick your start time within it.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Slot cards
                    ...List.generate(futureSlots.length, (i) {
                      final slot = futureSlots[i];
                      final start = slot['start'] as DateTime;
                      final end = slot['end'] as DateTime;
                      final isSelected = selectedSlotIndex == i;
                      const months = [
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

                      return GestureDetector(
                        onTap: () => pickTimeInSlot(i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF006B3C).withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF006B3C)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Date badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF006B3C)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${start.day}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      months[start.month - 1],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Time range
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_fmt2(start.hour)}:${_fmt2(start.minute)} – '
                                      '${_fmt2(end.hour)}:${_fmt2(end.minute)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isSelected
                                            ? const Color(0xFF006B3C)
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (slot['label'] as String).isNotEmpty
                                          ? slot['label'] as String
                                          : _slotDuration(start, end),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Selected time badge or tap hint
                              if (isSelected && selectedDateTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006B3C),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_fmt2(selectedDateTime!.hour)}:${_fmt2(selectedDateTime!.minute)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  'Tap to pick time',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Show selected summary
                    if (selectedDateTime != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Session: ${_fmtFullDate(selectedDateTime!)} at '
                              '${_fmt2(selectedDateTime!.hour)}:${_fmt2(selectedDateTime!.minute)} '
                              '(1 hour)',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (hasSlots && futureSlots.isEmpty) ...[
                    // All slots are in the past
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This tutor has no upcoming available slots. '
                              'Please check back later.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // No slots set — free date/time picker fallback
                    const Text(
                      'Select your preferred date and time:',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _datePicker(
                      selectedDate,
                      (d) => setDialogState(() => selectedDate = d),
                    ),
                    const SizedBox(height: 12),
                    _timePicker(
                      context,
                      selectedTime,
                      (t) => setDialogState(() => selectedTime = t),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes for tutor (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'What do you want to learn?',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                // Enable only when a valid time is selected
                onPressed:
                    (hasSlots
                        ? (selectedDateTime != null)
                        : (selectedDate != null && selectedTime != null))
                    ? () => Navigator.pop(context, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006B3C),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next: Pay'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || auth.userId == null) return;

    // Build sessionDate from slot selection or fallback picker
    final DateTime sessionDateTime;
    if (hasSlots && selectedDateTime != null) {
      sessionDateTime = selectedDateTime!;
    } else if (!hasSlots && selectedDate != null && selectedTime != null) {
      sessionDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
    } else {
      return; // nothing selected
    }

    final sessionDate = sessionDateTime.toIso8601String().split('.')[0];

    if (!mounted) return;
    final bookingResponse = await ApiService.bookTutor(
      auth.userId!,
      tutor.user['id'],
      sessionDate,
      notesController.text,
    );

    if (!mounted) return;

    if (bookingResponse.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bookingResponse.body.isNotEmpty
                ? bookingResponse.body
                : 'Booking failed. Try another time.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final booking = jsonDecode(bookingResponse.body);
    final bookingId = booking['id'] as int;

    // M-Pesa payment step
    final phoneController = TextEditingController(text: '254');
    final payConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Color(0xFF006B3C)),
            SizedBox(width: 8),
            Text('M-Pesa Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF006B3C).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF006B3C).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount to pay:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'KES ${tutor.hourlyRate.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006B3C),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your Safaricom number:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '2547XXXXXXXX',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF006B3C)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF006B3C),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Format: 2547XXXXXXXX or 2541XXXXXXXX',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006B3C),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.payment, size: 16),
            label: const Text('Pay Now'),
          ),
        ],
      ),
    );

    if (!mounted || payConfirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF006B3C)),
            SizedBox(width: 16),
            Text('Processing payment...'),
          ],
        ),
      ),
    );

    final payResponse = await ApiService.payForBooking(
      bookingId,
      phoneController.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payResponse.statusCode == 200
              ? '✅ Booking & payment successful! Check your M-Pesa.'
              : (payResponse.body.isNotEmpty
                    ? payResponse.body
                    : 'Payment failed. Please try again.'),
        ),
        backgroundColor: payResponse.statusCode == 200
            ? const Color(0xFF006B3C)
            : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final specializations =
        _tutors
            .map((t) => t.specialization)
            .where((s) => s.isNotEmpty)
            .toSet()
            .cast<String>()
            .toList()
          ..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tutors by name, language...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF006B3C)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF006B3C),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        if (specializations.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _filterChip('All', _selectedSpecialization == null, () {
                  setState(() => _selectedSpecialization = null);
                  _applyFilter();
                }),
                ...specializations.map(
                  (s) => _filterChip(s, _selectedSpecialization == s, () {
                    setState(
                      () => _selectedSpecialization =
                          _selectedSpecialization == s ? null : s,
                    );
                    _applyFilter();
                  }),
                ),
              ],
            ),
          ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF006B3C)),
      );
    if (_errorMessage != null)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTutors,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006B3C),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    if (_filtered.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍🏫', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              _tutors.isEmpty
                  ? 'No tutors available yet'
                  : 'No tutors match your search',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    return RefreshIndicator(
      onRefresh: _loadTutors,
      color: const Color(0xFF006B3C),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtered.length,
        itemBuilder: (context, index) => _tutorCard(_filtered[index]),
      ),
    );
  }

  Widget _tutorCard(TutorProfile tutor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child:
                tutor.profilePicture != null && tutor.profilePicture!.isNotEmpty
                ? Image.network(
                    tutor.profilePicture!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarFallback(tutor),
                  )
                : _avatarFallback(tutor),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tutor.user['username'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (tutor.level != null) _levelBadge(tutor.level!),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '🌍 ${tutor.specialization} Specialist',
                  style: const TextStyle(
                    color: Color(0xFF006B3C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tutor.bio,
                  style: const TextStyle(color: Colors.black87, height: 1.5),
                ),
                if (tutor.qualifications != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.school, size: 15, color: Color(0xFF006B3C)),
                      SizedBox(width: 6),
                      Text(
                        'Qualifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006B3C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tutor.qualifications!,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
                if (tutor.experience != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.work,
                        size: 15,
                        color: Color(0xFF006B3C),
                      ),
                      const SizedBox(width: 6),
                      Text(tutor.experience!),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006B3C).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hourly Rate',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            'KES ${tutor.hourlyRate.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006B3C),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text(
                          '✅ Available',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Availability display on tutor card ────────────────────────
                _tutorCardAvailability(tutor),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _bookTutor(tutor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006B3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text(
                      'Pay & Book Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Availability widgets ──────────────────────────────────────────────────

  /// Shows on the tutor card — general note first, then slot chips if any
  Widget _tutorCardAvailability(TutorProfile tutor) {
    final hasNote =
        tutor.availableTimes != null && tutor.availableTimes!.trim().isNotEmpty;
    final hasSlots =
        tutor.availabilitySlots != null && tutor.availabilitySlots!.isNotEmpty;

    if (!hasNote && !hasSlots) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // General note
        if (hasNote)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, color: Colors.green, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tutor.availableTimes!.trim(),
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        // Slot chips (actual bookable windows)
        if (hasSlots) ...[
          const SizedBox(height: 8),
          _slotsChips(tutor.availabilitySlots!),
        ],
      ],
    );
  }

  /// Shows inside the booking dialog — same info, slightly different heading
  Widget _availabilitySection(TutorProfile tutor) {
    final hasNote =
        tutor.availableTimes != null && tutor.availableTimes!.trim().isNotEmpty;
    final hasSlots =
        tutor.availabilitySlots != null && tutor.availabilitySlots!.isNotEmpty;

    if (!hasNote && !hasSlots) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // General note
        if (hasNote)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Tutor\'s availability:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tutor.availableTimes!.trim(),
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ],
            ),
          ),
        // Bookable slot chips
        if (hasSlots) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_available, color: Colors.blue, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Bookable windows:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _slotsChips(tutor.availabilitySlots!),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Renders chips like "21 Apr  09:00–17:00" for each active slot
  Widget _slotsChips(List<dynamic> slots) {
    final active = slots.where((s) => s['active'] == true).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    const months = [
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

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: active.map((s) {
        try {
          final start = DateTime.parse(s['startDateTime'].toString());
          final end = DateTime.parse(s['endDateTime'].toString());
          final label =
              '${start.day} ${months[start.month - 1]}  '
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
              ' – '
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  // ── Reusable booking dialog widgets ───────────────────────────────────────

  Widget _rateBox(TutorProfile tutor) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF006B3C).withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF006B3C).withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Session Rate:'),
            Text(
              'KES ${tutor.hourlyRate.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Payment:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'KES ${tutor.hourlyRate.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF006B3C),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _paymentNotice() => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Colors.amber, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Payment via M-Pesa required to confirm booking',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _datePicker(
    DateTime? selected,
    void Function(DateTime) onPicked,
  ) => GestureDetector(
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF006B3C)),
          ),
          child: child!,
        ),
      );
      if (date != null) onPicked(date);
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected != null ? const Color(0xFF006B3C) : Colors.grey,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF006B3C), size: 18),
          const SizedBox(width: 8),
          Text(
            selected != null
                ? '${selected.day}/${selected.month}/${selected.year}'
                : 'Select Session Date',
            style: TextStyle(
              color: selected != null ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timePicker(
    BuildContext ctx,
    TimeOfDay? selected,
    void Function(TimeOfDay) onPicked,
  ) => GestureDetector(
    onTap: () async {
      final time = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF006B3C)),
          ),
          child: child!,
        ),
      );
      if (time != null) onPicked(time);
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected != null ? const Color(0xFF006B3C) : Colors.grey,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Color(0xFF006B3C), size: 18),
          const SizedBox(width: 8),
          Text(
            selected != null ? selected.format(ctx) : 'Select Session Time',
            style: TextStyle(
              color: selected != null ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF006B3C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF006B3C) : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );

  Widget _levelBadge(String level) {
    final colors = {
      'EXPERT': Colors.purple,
      'INTERMEDIATE': Colors.blue,
      'BEGINNER': Colors.green,
    };
    final icons = {
      'EXPERT': Icons.star,
      'INTERMEDIATE': Icons.star_half,
      'BEGINNER': Icons.star_border,
    };
    final c = colors[level] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[level] ?? Icons.star_border, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            level,
            style: TextStyle(
              fontSize: 12,
              color: c,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(TutorProfile tutor) => Container(
    width: double.infinity,
    height: 200,
    color: const Color(0xFF006B3C),
    child: Center(
      child: Text(
        tutor.user['username'][0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  // ── Slot helper formatters ──────────────────────────────────────────────
  String _fmt2(int n) => n.toString().padLeft(2, '0');

  String _slotDuration(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return '';
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? 'Duration: ${h}h window' : 'Duration: ${h}h ${m}m window';
  }

  String _fmtFullDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
