import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

enum DateFilter { all, today, thisWeek, thisMonth, older }

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  DateFilter _activeFilter = DateFilter.all;
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  // ── Light Theme Palette ──────────────────────────────
  static const _pageBg = Color(0xFFF5F6FA);
  static const _white = Color(0xFFFFFFFF);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _surfaceBg = Color(0xFFECEEF5);
  static const _accent = Color(0xFF5B5FED);
  static const _textPrim = Color(0xFF1A1D2E);
  static const _textMuted = Color(0xFF888BA0);
  static const _textHint = Color(0xFFB0B3C4);
  static const _border = Color(0xFFECEEF5);
  static const _green = Color(0xFF16A34A);
  static const _greenBg = Color(0xFFDCFCE7);
  static const _greenTxt = Color(0xFF166534);
  static const _redBg = Color(0xFFFEE2E2);
  static const _redTxt = Color(0xFF991B1B);
  static const _redBar = Color(0xFFDC2626);
  static const _amberBg = Color(0xFFFEF3C7);
  static const _amberTxt = Color(0xFF92400E);
  static const _amberBar = Color(0xFFD97706);
  // ────────────────────────────────────────────────────

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    switch (_activeFilter) {
      case DateFilter.all:
        return (null, null);
      case DateFilter.today:
        return (todayStart, todayEnd);
      case DateFilter.thisWeek:
        return (todayStart.subtract(Duration(days: now.weekday - 1)), todayEnd);
      case DateFilter.thisMonth:
        return (DateTime(now.year, now.month, 1), todayEnd);
      case DateFilter.older:
        return (DateTime(2000), todayStart);
    }
  }

  Query<Map<String, dynamic>> get _query {
    var q = FirebaseFirestore.instance
        .collection('user_bookings')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);
    final (from, to) = _dateRange;
    if (from != null)
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    if (to != null)
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
    return q;
  }

  Color _statusBarColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _green;
      case 'cancelled':
        return _redBar;
      default:
        return _amberBar;
    }
  }

  Color _badgeBg(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _greenBg;
      case 'cancelled':
        return _redBg;
      default:
        return _amberBg;
    }
  }

  Color _badgeTxt(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _greenTxt;
      case 'cancelled':
        return _redTxt;
      default:
        return _amberTxt;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
    List<QueryDocumentSnapshot> docs,
  ) {
    final groups = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['createdAt'] as Timestamp).toDate();
      final key = DateFormat('yyyy-MM-dd').format(ts);
      groups.putIfAbsent(key, () => []).add(doc);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabs(),
            _buildDateFilterChips(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _circleBtn(
            Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My History',
              style: TextStyle(
                color: _textPrim,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _circleBtn(Icons.tune_rounded, iconColor: _accent),
        ],
      ),
    );
  }

  Widget _circleBtn(
    IconData icon, {
    VoidCallback? onTap,
    Color iconColor = _textPrim,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: _surfaceBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 17),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _tabItem('Bookings', true),
            _tabItem(
              'Transactions',
              false,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, bool active, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? _accent : _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChips() {
    final labels = ['All', 'Today', 'This Week', 'This Month', 'Older'];
    final filters = DateFilter.values;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final isActive = _activeFilter == filters[i];
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filters[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? _accent : _white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _accent : _border),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: isActive ? _white : _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return _buildEmpty(
            'No bookings found',
            Icons.calendar_today_outlined,
          );

        final groups = _groupByDate(docs);
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
        final spent = docs
            .where((d) => (d.data() as Map)['paymentStatus'] == 'paid')
            .fold<int>(
              0,
              (s, d) => s + ((d.data() as Map)['amount'] as int? ?? 0),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _buildSummaryRow(docs.length.toString(), '₹${_fmt(spent)}'),
            ...dates.expand((date) {
              final dayDocs = groups[date]!;
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(
                    _formatDate(DateTime.parse(date)).toUpperCase(),
                    style: const TextStyle(
                      color: _textHint,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                ...dayDocs.map(
                  (doc) =>
                      _buildBookingCard(doc.data() as Map<String, dynamic>),
                ),
              ];
            }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String total, String spent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: _summaryPill('Total bookings', total, _textPrim)),
          const SizedBox(width: 8),
          Expanded(child: _summaryPill('Amount spent', spent, _green)),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> data) {
    final status = (data['bookingStatus'] ?? 'pending') as String;
    final amount = data['amount'] as int? ?? 0;
    final bookingId = (data['bookingId'] ?? '') as String;
    final groundName = (data['groundName'] ?? '') as String;
    final slotLabel = (data['slotLabel'] ?? '') as String;
    final paymentStatus = (data['paymentStatus'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: _statusBarColor(status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        groundName,
                        style: const TextStyle(
                          color: _textPrim,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBg(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          color: _badgeTxt(status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: _textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      slotLabel,
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.credit_card_rounded,
                      size: 13,
                      color: _textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paymentStatus[0].toUpperCase() +
                          paymentStatus.substring(1),
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹$amount',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '#${bookingId.length > 8 ? bookingId.substring(bookingId.length - 8) : bookingId}',
                      style: const TextStyle(
                        color: _textHint,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: _textHint),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: _textHint, fontSize: 15)),
        ],
      ),
    );
  }

  String _fmt(int n) => NumberFormat('#,##,###').format(n);
}

// Stub import — replace with actual import path
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold();
}
