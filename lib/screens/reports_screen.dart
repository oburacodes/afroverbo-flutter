import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B3C),
        title: const Text(
          '📊 My Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.summarize, size: 18), text: 'Summary'),
            Tab(icon: Icon(Icons.table_rows, size: 18), text: 'All Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_SummaryTab(), _BookingsTableTab()],
      ),
    );
  }
}

// =============================================================================
// TAB 1 — SUMMARY
// =============================================================================
class _SummaryTab extends StatefulWidget {
  const _SummaryTab();
  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  static const _g = Color(0xFF006B3C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService.getTutorReport(auth.userId!);
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() {
          _report = jsonDecode(r.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _download() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _downloading = true);
    try {
      final r = await ApiService.downloadTutorReport(auth.userId!);
      if (!mounted) return;
      if (r.statusCode == 200) {
        _showCsvSheet('summary-report', r.body);
      } else {
        _snack('Download failed', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showCsvSheet(String filename, String csv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.download, color: _g),
                  const SizedBox(width: 8),
                  Text(
                    '$filename.csv',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _g));
    if (_error != null)
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

    final r = _report!;
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
            // Header card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${auth.username ?? 'Tutor'}\'s Report',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Performance overview',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Download summary CSV
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _g,
                  side: const BorderSide(color: _g),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _downloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _g,
                        ),
                      )
                    : const Icon(Icons.download, size: 16),
                label: Text(
                  _downloading ? 'Preparing...' : 'Download Summary CSV',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Booking counts grid
            _sectionTitle('📅 Bookings Overview'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _statCard(
                  '${r['totalBookings']}',
                  'Total',
                  Icons.calendar_today,
                  _g,
                ),
                _statCard(
                  '${r['pendingBookings']}',
                  'Pending',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
                _statCard(
                  '${r['confirmedBookings']}',
                  'Confirmed',
                  Icons.check_circle,
                  Colors.blue,
                ),
                _statCard(
                  '${r['paidBookings']}',
                  'Paid',
                  Icons.payment,
                  Colors.green,
                ),
                _statCard(
                  '${r['completedBookings']}',
                  'Completed',
                  Icons.done_all,
                  Colors.teal,
                ),
                _statCard(
                  '${r['cancelledBookings']}',
                  'Cancelled',
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Earnings
            _sectionTitle('💰 Earnings Breakdown'),
            const SizedBox(height: 10),
            _card(
              Column(
                children: [
                  _row(
                    '💵 Total Session Revenue',
                    'KES ${_fmt(r['totalRevenue'])}',
                    _g,
                  ),
                  const Divider(),
                  _row(
                    '🏦 Platform Cut (20%)',
                    'KES ${_fmt(r['platformCut'])}',
                    Colors.red,
                  ),
                  const Divider(),
                  _row(
                    '🤑 My Earnings (80%)',
                    'KES ${_fmt(r['tutorEarnings'])}',
                    Colors.green,
                  ),
                  const Divider(),
                  _row(
                    '📊 Avg per Booking',
                    'KES ${_fmt(r['averageBookingValue'])}',
                    Colors.indigo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rates
            _sectionTitle('📈 Performance Rates'),
            const SizedBox(height: 10),
            _card(
              Column(
                children: [
                  _rateRow(
                    '✅ Confirmation Rate',
                    _pct(r['confirmationRate']),
                    Colors.blue,
                  ),
                  const Divider(),
                  _rateRow(
                    '🏁 Completion Rate',
                    _pct(r['completionRate']),
                    Colors.teal,
                  ),
                  const Divider(),
                  _rateRow(
                    '❌ Cancellation Rate',
                    _pct(r['cancellationRate']),
                    Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Monthly bar chart
            _sectionTitle('📆 Monthly Bookings'),
            const SizedBox(height: 10),
            _monthlyChart(r),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF006B3C),
    ),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _statCard(String value, String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _row(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  Widget _rateRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _monthlyChart(Map<String, dynamic> r) {
    final months = (r['monthlyPerformance'] as List<dynamic>?) ?? [];
    if (months.isEmpty) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No monthly data yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final maxB = months
        .map((m) => (m['bookings'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final barMax = maxB < 1 ? 1.0 : maxB;
    const mNames = [
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
    return _card(
      SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: months.map((m) {
            final idx = (m['month'] as num).toInt() - 1;
            final count = (m['bookings'] as num).toDouble();
            final frac = count / barMax;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${count.toInt()}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: (frac * 100).clamp(4.0, 100.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006B3C).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mNames[idx.clamp(0, 11)],
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _fmt(dynamic v) => v == null ? '0' : (v as num).toStringAsFixed(0);
  String _pct(dynamic v) =>
      v == null ? '0%' : '${(v as num).toStringAsFixed(1)}%';
  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}

// =============================================================================
// TAB 2 — DETAILED BOOKINGS TABLE
// =============================================================================
class _BookingsTableTab extends StatefulWidget {
  const _BookingsTableTab();
  @override
  State<_BookingsTableTab> createState() => _BookingsTableTabState();
}

class _BookingsTableTabState extends State<_BookingsTableTab> {
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  // Filters
  String? _statusFilter;
  String? _paymentFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _search = TextEditingController();

  // Sort
  int _sortColIndex = 2; // default: date
  bool _sortAsc = false;

  static const _g = Color(0xFF006B3C);
  static const _cols = [
    '#',
    'Student',
    'Date',
    'Time',
    'Status',
    'Payment',
    'Amount (KES)',
    'Earnings (KES)',
    'Receipt',
    'Notes',
  ];
  static const _sortKeys = [
    'id',
    'student',
    'date',
    'time',
    'status',
    'payment',
    'amount',
    'earnings',
    'receipt',
    'notes',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
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
        _applyFilter();
      } else {
        setState(() {
          _error = 'Failed (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((b) {
        final student = (b['student']?['username'] ?? '')
            .toString()
            .toLowerCase();
        final status = (b['status'] ?? '').toString();
        final pay = (b['paymentStatus'] ?? '').toString();
        final notes = (b['notes'] ?? '').toString().toLowerCase();

        final matchQ = q.isEmpty || student.contains(q) || notes.contains(q);
        final matchS = _statusFilter == null || status == _statusFilter;
        final matchP = _paymentFilter == null || pay == _paymentFilter;

        DateTime? dt;
        try {
          dt = DateTime.parse(b['sessionDate'].toString());
        } catch (_) {}
        final matchFrom =
            _fromDate == null || (dt != null && !dt.isBefore(_fromDate!));
        final matchTo =
            _toDate == null || (dt != null && !dt.isAfter(_toDate!));

        return matchQ && matchS && matchP && matchFrom && matchTo;
      }).toList();
      _doSort();
    });
  }

  void _doSort() {
    _filtered.sort((a, b) {
      final key = _sortKeys[_sortColIndex];
      dynamic va, vb;
      switch (key) {
        case 'id':
          va = (a['id'] as num?) ?? 0;
          vb = (b['id'] as num?) ?? 0;
          break;
        case 'student':
          va = a['student']?['username'] ?? '';
          vb = b['student']?['username'] ?? '';
          break;
        case 'date':
        case 'time':
          va = a['sessionDate'] ?? '';
          vb = b['sessionDate'] ?? '';
          break;
        case 'status':
          va = a['status'] ?? '';
          vb = b['status'] ?? '';
          break;
        case 'payment':
          va = a['paymentStatus'] ?? '';
          vb = b['paymentStatus'] ?? '';
          break;
        case 'amount':
          va = (a['amountPaid'] as num?) ?? 0;
          vb = (b['amountPaid'] as num?) ?? 0;
          break;
        case 'earnings':
          va = (a['tutorCut'] as num?) ?? 0;
          vb = (b['tutorCut'] as num?) ?? 0;
          break;
        default:
          va = '';
          vb = '';
      }
      int cmp;
      if (va is num && vb is num) {
        cmp = va.compareTo(vb);
      } else {
        cmp = va.toString().compareTo(vb.toString());
      }
      return _sortAsc ? cmp : -cmp;
    });
  }

  void _onSort(int colIndex, bool ascending) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = ascending;
      _doSort();
    });
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _statusFilter = null;
      _paymentFilter = null;
      _fromDate = null;
      _toDate = null;
    });
    _applyFilter();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, ch) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _g)),
        child: ch!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom)
        _fromDate = picked;
      else
        _toDate = picked;
    });
    _applyFilter();
  }

  // Build CSV from currently filtered rows
  Future<void> _downloadFiltered() async {
    if (_filtered.isEmpty) {
      _snack('No data to download', Colors.orange);
      return;
    }
    setState(() => _downloading = true);
    try {
      final sb = StringBuffer();
      sb.writeln(
        'ID,Student,Date,Time,Status,Payment Status,'
        'Amount (KES),Earnings (KES),M-Pesa Receipt,Notes',
      );
      for (final b in _filtered) {
        DateTime? dt;
        try {
          dt = DateTime.parse(b['sessionDate'].toString());
        } catch (_) {}
        final date = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '';
        final time = dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '';
        final fields = [
          b['id'],
          '"${b['student']?['username'] ?? ''}"',
          date,
          time,
          b['status'] ?? '',
          b['paymentStatus'] ?? '',
          (b['amountPaid'] as num?)?.toStringAsFixed(0) ?? '0',
          (b['tutorCut'] as num?)?.toStringAsFixed(0) ?? '0',
          '"${b['mpesaReceiptNumber'] ?? ''}"',
          '"${(b['notes'] ?? '').toString().replaceAll('"', "'")}"',
        ];
        sb.writeln(fields.join(','));
      }
      if (!mounted) return;
      final label = [
        if (_statusFilter != null) _statusFilter,
        if (_paymentFilter != null) _paymentFilter,
        if (_fromDate != null) '${_fromDate!.day}-${_fromDate!.month}',
        if (_toDate != null) 'to-${_toDate!.day}-${_toDate!.month}',
      ].join('_');
      _showCsvSheet(
        'bookings${label.isNotEmpty ? '-$label' : '-all'}',
        sb.toString(),
      );
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showCsvSheet(String filename, String csv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.download, color: _g),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$filename.csv',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_filtered.length} rows',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _g));
    if (_error != null)
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

    // Compute totals from filtered list
    final totalRevenue = _filtered.fold<double>(
      0,
      (s, b) => s + ((b['amountPaid'] as num?)?.toDouble() ?? 0),
    );
    final totalEarnings = _filtered.fold<double>(
      0,
      (s, b) => s + ((b['tutorCut'] as num?)?.toDouble() ?? 0),
    );
    final paidCount = _filtered
        .where((b) => b['paymentStatus'] == 'PAID')
        .length;
    final hasFilters =
        _statusFilter != null ||
        _paymentFilter != null ||
        _fromDate != null ||
        _toDate != null ||
        _search.text.isNotEmpty;

    return Column(
      children: [
        // ── FILTER PANEL ─────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search by student name or notes...',
                  prefixIcon: const Icon(Icons.search, color: _g, size: 18),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _search.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _g, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              // Status + payment filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    _chip('All', _statusFilter == null, () {
                      setState(() => _statusFilter = null);
                      _applyFilter();
                    }),
                    _chip('Pending', _statusFilter == 'PENDING', () {
                      setState(() => _statusFilter = 'PENDING');
                      _applyFilter();
                    }),
                    _chip('Confirmed', _statusFilter == 'CONFIRMED', () {
                      setState(() => _statusFilter = 'CONFIRMED');
                      _applyFilter();
                    }),
                    _chip('Completed', _statusFilter == 'COMPLETED', () {
                      setState(() => _statusFilter = 'COMPLETED');
                      _applyFilter();
                    }),
                    _chip('Cancelled', _statusFilter == 'CANCELLED', () {
                      setState(() => _statusFilter = 'CANCELLED');
                      _applyFilter();
                    }),
                    const SizedBox(width: 12),
                    const Text(
                      'Pay: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    _chip('All', _paymentFilter == null, () {
                      setState(() => _paymentFilter = null);
                      _applyFilter();
                    }),
                    _chip('Paid', _paymentFilter == 'PAID', () {
                      setState(() => _paymentFilter = 'PAID');
                      _applyFilter();
                    }),
                    _chip('Unpaid', _paymentFilter == 'UNPAID', () {
                      setState(() => _paymentFilter = 'UNPAID');
                      _applyFilter();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Date range + clear
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(true),
                      child: _dateTile(
                        _fromDate != null
                            ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}'
                            : 'From date',
                        _fromDate != null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(false),
                      child: _dateTile(
                        _toDate != null
                            ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}'
                            : 'To date',
                        _toDate != null,
                      ),
                    ),
                  ),
                  if (hasFilters) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── TOTALS BAR ────────────────────────────────────────────────────────
        Container(
          color: _g.withOpacity(0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _badge('${_filtered.length}', 'Bookings', Colors.black87),
              const SizedBox(width: 16),
              _badge('$paidCount', 'Paid', Colors.green),
              const SizedBox(width: 16),
              _badge('KES ${totalRevenue.toStringAsFixed(0)}', 'Revenue', _g),
              const SizedBox(width: 16),
              _badge(
                'KES ${totalEarnings.toStringAsFixed(0)}',
                'Earnings',
                Colors.teal,
              ),
              const Spacer(),
              // Download button
              GestureDetector(
                onTap: _downloading ? null : _downloadFiltered,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _g,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _downloading
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 14,
                            ),
                      const SizedBox(width: 6),
                      const Text(
                        'CSV',
                        style: TextStyle(
                          color: Colors.white,
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

        // ── DATA TABLE ────────────────────────────────────────────────────────
        if (_filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, color: Colors.grey, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No bookings match your filters',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    _g.withOpacity(0.09),
                  ),
                  border: TableBorder.all(
                    color: Colors.grey.shade200,
                    width: 0.5,
                  ),
                  columnSpacing: 14,
                  horizontalMargin: 12,
                  sortColumnIndex: _sortColIndex,
                  sortAscending: _sortAsc,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 12),
                  columns: List.generate(_cols.length, (i) {
                    final sortable =
                        i < _sortKeys.length &&
                        !['receipt', 'notes', 'time'].contains(_sortKeys[i]);
                    return DataColumn(
                      label: Text(_cols[i]),
                      onSort: sortable ? _onSort : null,
                    );
                  }),
                  rows: _filtered.map((b) {
                    DateTime? dt;
                    try {
                      dt = DateTime.parse(b['sessionDate'].toString());
                    } catch (_) {}
                    final date = dt != null
                        ? '${dt.day}/${dt.month}/${dt.year}'
                        : '—';
                    final time = dt != null
                        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                        : '—';
                    final status = (b['status'] ?? '—').toString();
                    final pay = (b['paymentStatus'] ?? '—').toString();
                    final amount =
                        (b['amountPaid'] as num?)?.toStringAsFixed(0) ?? '0';
                    final earnings =
                        (b['tutorCut'] as num?)?.toStringAsFixed(0) ?? '0';
                    final receipt = (b['mpesaReceiptNumber'] ?? '').toString();
                    final notes = (b['notes'] ?? '').toString();
                    final student = (b['student']?['username'] ?? '—')
                        .toString();

                    return DataRow(
                      cells: [
                        // ID
                        DataCell(
                          Text(
                            '${b['id']}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        // Student
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: const Color(0xFFFFD700),
                                child: Text(
                                  student.isNotEmpty
                                      ? student[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                student,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Date
                        DataCell(
                          Text(date, style: const TextStyle(fontSize: 12)),
                        ),
                        // Time
                        DataCell(
                          Text(time, style: const TextStyle(fontSize: 12)),
                        ),
                        // Status chip
                        DataCell(_statusBadge(status)),
                        // Payment chip
                        DataCell(_payBadge(pay)),
                        // Amount
                        DataCell(
                          Text(
                            '$amount',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _g,
                            ),
                          ),
                        ),
                        // Earnings
                        DataCell(
                          Text(
                            '$earnings',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        // Receipt
                        DataCell(
                          receipt.isEmpty
                              ? const Text(
                                  '—',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                )
                              : Text(
                                  receipt,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        // Notes
                        DataCell(
                          SizedBox(
                            width: 130,
                            child: Text(
                              notes.isEmpty ? '—' : notes,
                              style: TextStyle(
                                fontSize: 11,
                                color: notes.isEmpty
                                    ? Colors.grey
                                    : Colors.black87,
                                fontStyle: notes.isEmpty
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? _g : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _g : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget _dateTile(String label, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: active ? _g : Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.date_range, size: 14, color: active ? _g : Colors.grey),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: active ? _g : Colors.grey),
        ),
      ],
    ),
  );

  Widget _badge(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ],
  );

  Widget _statusBadge(String status) {
    final colors = {
      'PENDING': Colors.orange,
      'CONFIRMED': Colors.blue,
      'COMPLETED': Colors.teal,
      'CANCELLED': Colors.red,
      'PAID': Colors.green,
    };
    final c = colors[status.toUpperCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _payBadge(String status) {
    final colors = {
      'PAID': Colors.green,
      'UNPAID': Colors.orange,
      'PENDING': Colors.blue,
      'FAILED': Colors.red,
      'CANCELLED': Colors.grey,
    };
    final c = colors[status.toUpperCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}
