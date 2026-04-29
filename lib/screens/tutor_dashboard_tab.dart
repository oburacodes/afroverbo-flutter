import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class TutorDashboardTab extends StatefulWidget {
  const TutorDashboardTab({super.key});
  @override
  State<TutorDashboardTab> createState() => _TutorDashboardTabState();
}

class _TutorDashboardTabState extends State<TutorDashboardTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: const Color(0xFF006B3C),
        child: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Bookings'),
            Tab(icon: Icon(Icons.schedule, size: 18), text: 'Availability'),
            Tab(icon: Icon(Icons.person, size: 18), text: 'My Profile'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: const [_BookingsTab(), _AvailabilityTab(), _ProfileTab()],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKINGS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _BookingsTab extends StatefulWidget {
  const _BookingsTab();
  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  List<dynamic> _all = [], _filtered = [];
  bool _loading = true;
  String? _error, _statusFilter;
  final _search = TextEditingController();
  static const _g = Color(0xFF006B3C);

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService.getTutorBookings(auth.userId!);
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() {
          _all = jsonDecode(r.body);
          _filtered = List.from(_all);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((b) {
        final s = (b['student']?['username'] ?? '').toString().toLowerCase();
        final n = (b['notes'] ?? '').toString().toLowerCase();
        final st = (b['status'] ?? '').toString();
        return (q.isEmpty || s.contains(q) || n.contains(q)) &&
            (_statusFilter == null || st == _statusFilter);
      }).toList();
    });
  }

  Future<void> _act(int id, String status) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              status == 'CONFIRMED' ? Icons.check_circle : Icons.cancel,
              color: status == 'CONFIRMED' ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(status == 'CONFIRMED' ? 'Confirm' : 'Decline'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == 'CONFIRMED'
                  ? 'Message to student (optional):'
                  : 'Reason (recommended):',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'CONFIRMED' ? _g : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(status == 'CONFIRMED' ? 'Confirm' : 'Decline'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.updateBookingStatus(
      id,
      status,
      ctrl.text.isEmpty ? null : ctrl.text,
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      _snack(
        'Booking $status!',
        status == 'CONFIRMED' ? Colors.green : Colors.red,
      );
      _load();
    } else {
      _snack('Failed', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _all.where((b) => b['status'] == 'PENDING').length;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _g));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _g),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _g,
      child: Column(
        children: [
          // Stats
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('${_all.length}', 'Total', Colors.grey),
                _stat('$pending', 'Pending', Colors.orange),
                _stat(
                  '${_all.where((b) => b['status'] == 'CONFIRMED').length}',
                  'Confirmed',
                  Colors.blue,
                ),
                _stat(
                  '${_all.where((b) => b['paymentStatus'] == 'PAID').length}',
                  'Paid',
                  Colors.green,
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search student name...',
                prefixIcon: const Icon(Icons.search, color: _g),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _filter();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _g, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [null, 'PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED']
                  .map((s) {
                    final sel = _statusFilter == s;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _statusFilter = s);
                        _filter();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? _g : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _g : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          s ?? 'All',
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No bookings',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _card(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l, Color c) => Column(
    children: [
      Text(
        v,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c),
      ),
      Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );

  Widget _card(Map<String, dynamic> b) {
    final status = b['status'] ?? 'PENDING';
    final sc =
        {
          'CONFIRMED': Colors.green,
          'CANCELLED': Colors.red,
          'COMPLETED': Colors.blue,
          'PAID': Colors.teal,
        }[status] ??
        Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: sc,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (b['paymentStatus'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: b['paymentStatus'] == 'PAID'
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: b['paymentStatus'] == 'PAID'
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    child: Text(
                      b['paymentStatus'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: b['paymentStatus'] == 'PAID'
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFD700),
                      radius: 20,
                      child: Text(
                        b['student']['username'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['student']['username'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Text(
                          'Student',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: _g),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDate(b['sessionDate'].toString()),
                      style: const TextStyle(
                        color: _g,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.access_time, size: 14, color: _g),
                    const SizedBox(width: 6),
                    Text(
                      _fmtTime(b['sessionDate'].toString()),
                      style: const TextStyle(
                        color: _g,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Session Amount:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'KES ${(b['amountPaid'] ?? 0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _g,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Earnings:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'KES ${(b['tutorCut'] ?? 0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (b['mpesaReceiptNumber'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'M-Pesa Receipt:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        b['mpesaReceiptNumber'],
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (b['notes'] != null && b['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📝 ${b['notes']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (b['tutorReply'] != null &&
                    b['tutorReply'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '💬 ${b['tutorReply']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (status == 'PENDING') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _act(b['id'], 'CANCELLED'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _act(b['id'], 'CONFIRMED'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _g,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String r) {
    try {
      final d = DateTime.parse(r);
      const m = [
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
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return r.split('T')[0];
    }
  }

  String _fmtTime(String r) {
    try {
      final d = DateTime.parse(r);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY TAB — specific date + time ranges
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY TAB — drop-in replacement for _AvailabilityTab in tutor_dashboard_tab.dart
// Changes:
//   1. Per-slot "label" field removed
//   2. A single "General Availability Note" text box added at the top
//      → this saves to TutorProfile.availableTimes (already in the backend)
//      → students see this note on the tutor card and in the booking dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();
  @override
  State<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<_AvailabilityTab> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _slots = [];
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _savingNote = false;

  static const _g = Color(0xFF006B3C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final r = await ApiService.getTutorProfileByUserId(auth.userId!);
      if (r.statusCode == 200 && mounted) {
        final p = jsonDecode(r.body);
        final raw = (p['availabilitySlots'] as List<dynamic>?) ?? [];
        setState(() {
          _profile = p;
          _noteCtrl.text = p['availableTimes'] ?? '';
          _slots = raw
              .map<Map<String, dynamic>>(
                (s) => {
                  'startDateTime': DateTime.parse(
                    s['startDateTime'].toString(),
                  ),
                  'endDateTime': DateTime.parse(s['endDateTime'].toString()),
                  'active': s['active'] ?? true,
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('slots load error: $e');
    }
  }

  // Save the general availability note (availableTimes field)
  Future<void> _saveNote() async {
    if (_profile == null) return;
    setState(() => _savingNote = true);
    try {
      final r = await ApiService.updateTutorProfile(_profile!['id'], {
        'bio': _profile!['bio'],
        'hourlyRate': _profile!['hourlyRate'],
        'specialization': _profile!['specialization'],
        'qualifications': _profile!['qualifications'],
        'level': _profile!['level'],
        'experience': _profile!['experience'],
        'profilePicture': _profile!['profilePicture'],
        'payoutPhoneNumber': _profile!['payoutPhoneNumber'],
        'available': _profile!['available'],
        'availableTimes': _noteCtrl.text.trim(),
      });
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() => _profile = jsonDecode(r.body));
        _snack('Availability note saved! Students will see this.', _g);
      } else {
        _snack('Failed to save note', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  void _add() {
    final base = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(base.year, base.month, base.day, 9, 0);
    setState(
      () => _slots.add({
        'startDateTime': start,
        'endDateTime': start.add(const Duration(hours: 8)),
        'active': true,
      }),
    );
  }

  Future<void> _saveSlots() async {
    if (_profile == null) return;
    for (final s in _slots) {
      if (!(s['endDateTime'] as DateTime).isAfter(
        s['startDateTime'] as DateTime,
      )) {
        _snack('End must be after start time for each slot', Colors.red);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = _slots
          .map(
            (s) => {
              'startDateTime': (s['startDateTime'] as DateTime)
                  .toIso8601String()
                  .split('.')[0],
              'endDateTime': (s['endDateTime'] as DateTime)
                  .toIso8601String()
                  .split('.')[0],
              'active': s['active'],
            },
          )
          .toList();
      final r = await ApiService.updateTutorAvailability(
        _profile!['id'],
        payload,
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        _snack('✅ Booking slots saved!', _g);
        await _load();
      } else {
        _snack(r.body.isNotEmpty ? r.body : 'Save failed', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDt(int i, bool isStart) async {
    final cur =
        (_slots[i][isStart ? 'startDateTime' : 'endDateTime']) as DateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, ch) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _g)),
        child: ch!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(cur),
      builder: (c, ch) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _g)),
        child: ch!,
      ),
    );
    if (time == null) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _slots[i]['startDateTime'] = dt;
        if (!(_slots[i]['endDateTime'] as DateTime).isAfter(dt))
          _slots[i]['endDateTime'] = dt.add(const Duration(hours: 8));
      } else {
        _slots[i]['endDateTime'] = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _g,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION 1: General availability note (what students see) ─────
            const Text(
              '📢 What Students See',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _g,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _g.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This message is shown to students on your profile card and '
                    'in the booking dialog — before they pick a date. '
                    'Use it to tell them your general availability.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Available Mon–Fri 9am–5pm and Saturday mornings. '
                          'Book at least 24hrs in advance.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _g, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Preview of what student sees
                  if (_noteCtrl.text.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 13,
                                color: Colors.green,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Student preview:',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _noteCtrl.text,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savingNote ? null : _saveNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _g,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _savingNote
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_savingNote ? 'Saving...' : 'Save Note'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── SECTION 2: Booking slots (exact windows students can book) ───
            const Text(
              '📅 Bookable Time Slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _g,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _g.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _g.withOpacity(0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _g, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Students can only book sessions that fall within these exact windows. '
                      'Add each available window with a start and end date/time.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_slots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_busy, size: 44, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No booking slots yet',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap "Add Slot" to create your first window',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_slots.length, _slotCard),

            const SizedBox(height: 14),

            // Add / Save buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _add,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _g,
                      side: const BorderSide(color: _g),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Slot'),
                  ),
                ),
                if (_slots.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSlots,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _g,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_saving ? 'Saving...' : 'Save Slots'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _slotCard(int i) {
    final s = _slots[i];
    final start = s['startDateTime'] as DateTime;
    final end = s['endDateTime'] as DateTime;
    final active = s['active'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _g.withOpacity(0.25) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active ? _g : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Slot ${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: active ? _g : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Switch(
                  value: active,
                  activeColor: _g,
                  onChanged: (v) => setState(() => _slots[i]['active'] = v),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _slots.removeAt(i)),
                  tooltip: 'Remove slot',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Start datetime
            _dtTile('Start', start, () => _pickDt(i, true)),
            const SizedBox(height: 8),

            // End datetime
            _dtTile('End', end, () => _pickDt(i, false)),
            const SizedBox(height: 10),

            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _g.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timelapse, size: 14, color: _g),
                  const SizedBox(width: 6),
                  Text(
                    _dur(start, end),
                    style: const TextStyle(
                      color: _g,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dtTile(String label, DateTime dt, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(
                label == 'Start'
                    ? Icons.play_circle_outline
                    : Icons.stop_circle_outlined,
                color: _g,
                size: 18,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    _fmtDt(dt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.edit_calendar, size: 16, color: Colors.grey),
            ],
          ),
        ),
      );

  String _fmtDt(DateTime dt) {
    const m = [
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
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dur(DateTime s, DateTime e) {
    if (!e.isAfter(s)) return 'Invalid range';
    final d = e.difference(s);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? 'Duration: ${h}h' : 'Duration: ${h}h ${m}m';
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB — edit info, picture, payout number, NO progress section
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true, _editing = false, _saving = false;
  final _bio = TextEditingController();
  final _rate = TextEditingController();
  final _spec = TextEditingController();
  final _qual = TextEditingController();
  final _exp = TextEditingController();
  final _pic = TextEditingController();
  final _payout = TextEditingController();
  String? _level;
  bool _avail = true;
  static const _g = Color(0xFF006B3C);
  static const _levels = ['BEGINNER', 'INTERMEDIATE', 'EXPERT'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bio, _rate, _spec, _qual, _exp, _pic, _payout]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _loading = true);
    try {
      final r = await ApiService.getTutorProfileByUserId(auth.userId!);
      if (r.statusCode == 200 && mounted) {
        final p = jsonDecode(r.body);
        setState(() {
          _profile = p;
          _bio.text = p['bio'] ?? '';
          _rate.text = p['hourlyRate']?.toString() ?? '';
          _spec.text = p['specialization'] ?? '';
          _qual.text = p['qualifications'] ?? '';
          _exp.text = p['experience'] ?? '';
          _pic.text = p['profilePicture'] ?? '';
          _payout.text = p['payoutPhoneNumber'] ?? '';
          _level = p['level'];
          _avail = p['available'] ?? true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_profile == null) return;
    setState(() => _saving = true);
    try {
      final r = await ApiService.updateTutorProfile(_profile!['id'], {
        'bio': _bio.text,
        'hourlyRate': double.tryParse(_rate.text) ?? _profile!['hourlyRate'],
        'specialization': _spec.text,
        'qualifications': _qual.text,
        'experience': _exp.text,
        'profilePicture': _pic.text,
        'payoutPhoneNumber': _payout.text,
        'level': _level,
        'available': _avail,
        'availableTimes': _profile!['availableTimes'],
      });
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() {
          _profile = jsonDecode(r.body);
          _editing = false;
        });
        _snack('Profile saved!', _g);
      } else {
        _snack('Failed to save', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _g));
    }
    if (_profile == null) return const Center(child: Text('Profile not found'));
    final auth = Provider.of<AuthProvider>(context);

    return RefreshIndicator(
      onRefresh: _load,
      color: _g,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_g, Color(0xFF00A35C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        backgroundImage: _pic.text.isNotEmpty
                            ? NetworkImage(_pic.text) as ImageProvider
                            : null,
                        child: _pic.text.isEmpty
                            ? Text(
                                (auth.username ?? 'T')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 42,
                                  color: _g,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (_editing)
                        GestureDetector(
                          onTap: _picDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: _g,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.username ?? 'Tutor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_spec.text.isNotEmpty)
                    Text(
                      '${_spec.text} Specialist',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _editing
                        ? () => setState(() => _avail = !_avail)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _avail ? Colors.white : Colors.white30,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _avail ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: _avail ? _g : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _avail ? 'Available for bookings' : 'Not available',
                            style: TextStyle(
                              color: _avail ? _g : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Edit/Save bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _editing
                  ? [
                      TextButton(
                        onPressed: () {
                          setState(() => _editing = false);
                          _load();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _g,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 16),
                        label: Text(_saving ? 'Saving...' : 'Save Changes'),
                      ),
                    ]
                  : [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _editing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _g,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Profile'),
                      ),
                    ],
            ),
            const SizedBox(height: 8),

            // Basic info
            _sec('👤 Basic Info', [
              _f(
                'Bio / About Me',
                _bio,
                maxLines: 3,
                hint: 'Tell students about yourself...',
              ),
              _f(
                'Specialization / Language',
                _spec,
                hint: 'e.g. Swahili, Luo, Kikuyu',
              ),
              _dd(
                'Teaching Level',
                _level,
                _levels,
                (v) => setState(() => _level = v),
              ),
              _f('Experience', _exp, hint: 'e.g. 5 years teaching Swahili'),
              _f(
                'Qualifications',
                _qual,
                maxLines: 2,
                hint: 'e.g. BA Linguistics, TESOL Certified',
              ),
            ]),

            // Rates
            _sec('💰 Rates & Payments', [
              _f(
                'Hourly Rate (KES)',
                _rate,
                kb: TextInputType.number,
                hint: 'e.g. 1500',
              ),
              if (_profile!['hourlyRate'] != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pill(
                        'Session Fee',
                        'KES ${(_profile!['hourlyRate'] as num).toStringAsFixed(0)}',
                        Colors.blue,
                      ),
                      _pill(
                        'Platform (20%)',
                        'KES ${(_profile!['platformFee'] ?? 0).toStringAsFixed(0)}',
                        Colors.orange,
                      ),
                      _pill(
                        'Your Cut (80%)',
                        'KES ${(_profile!['tutorEarnings'] ?? 0).toStringAsFixed(0)}',
                        Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _f(
                'M-Pesa Payout Number',
                _payout,
                kb: TextInputType.phone,
                hint: '2547XXXXXXXX',
                icon: Icons.phone_android,
              ),
              const Text(
                'Earnings will be sent to this number after each paid session.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ]),

            // Profile picture
            _sec('🖼 Profile Picture', [
              if (_pic.text.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _pic.text,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 60,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Text(
                          'Invalid URL',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _f(
                'Picture URL',
                _pic,
                hint: 'https://your-image-host.com/photo.jpg',
                icon: Icons.link,
              ),
              const Text(
                'Upload your photo to Imgur or Cloudinary and paste the direct link.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _picDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Update Profile Picture'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paste a direct image URL:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pic,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {});
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _g,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    ),
  );

  Widget _sec(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _g,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _f(
    String label,
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
    TextInputType kb = TextInputType.text,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _editing
        ? TextField(
            controller: c,
            maxLines: maxLines,
            keyboardType: kb,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: icon != null ? Icon(icon, color: _g, size: 18) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _g, width: 2),
              ),
              isDense: true,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                c.text.isNotEmpty ? c.text : '—',
                style: const TextStyle(fontSize: 14),
              ),
              const Divider(height: 16),
            ],
          ),
  );

  Widget _dd(
    String label,
    String? val,
    List<String> opts,
    ValueChanged<String?> onChange,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _editing
        ? DropdownButtonFormField<String>(
            initialValue: val,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _g, width: 2),
              ),
              isDense: true,
            ),
            items: opts
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onChange,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(val ?? '—', style: const TextStyle(fontSize: 14)),
              const Divider(height: 16),
            ],
          ),
  );

  Widget _pill(String label, String val, Color c) => Column(
    children: [
      Text(
        val,
        style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 12),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    ],
  );

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}
