import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/User/booking/bookinghistory.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';

enum TxnDateFilter { all, today, thisWeek, thisMonth, older }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  TxnDateFilter _activeFilter = TxnDateFilter.all;

  // FIX 1: lazy getter so uid is never stale
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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
  static const _amber = Color(0xFFD97706);
  static const _red = Color(0xFFDC2626);
  static const _purpleBg = Color(0xFFEDE9FE);
  static const _purpleIco = Color(0xFF7C3AED);
  // ────────────────────────────────────────────────────

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    switch (_activeFilter) {
      case TxnDateFilter.all:
        return (null, null);
      case TxnDateFilter.today:
        return (todayStart, todayEnd);
      case TxnDateFilter.thisWeek:
        return (todayStart.subtract(Duration(days: now.weekday - 1)), todayEnd);
      case TxnDateFilter.thisMonth:
        return (DateTime(now.year, now.month, 1), todayEnd);
      case TxnDateFilter.older:
        return (DateTime(2000), todayStart);
    }
  }

  // FIX 2: correct collection + null-safe uid
  Query<Map<String, dynamic>>? get _query {
    final uid = _uid;
    if (uid == null) return null;

    var q = FirebaseFirestore.instance
        .collection('user_transactions') // ← was 'user_bookings'
        .where('userId', isEqualTo: uid);
    // .orderBy('createdAt', descending: true);

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

  // FIX 3: use transactionType field, not bookingStatus
  bool _isRefund(Map<String, dynamic> d) =>
      (d['transactionType'] as String? ?? '') == 'refund';

  // FIX 4: success is the paid state in user_transactions
  bool _isPaid(Map<String, dynamic> d) =>
      (d['paymentStatus'] as String? ?? '') == 'success' && !_isRefund(d);

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

            _buildDateFilterChips(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 2),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // GestureDetector(
          //   onTap: () => context.pop(),
          //   child: Container(
          //     width: 36,
          //     height: 36,
          //     decoration: const BoxDecoration(
          //       color: _surfaceBg,
          //       shape: BoxShape.circle,
          //     ),
          //     child: const Icon(
          //       Icons.arrow_back_ios_new,
          //       color: _textPrim,
          //       size: 17,
          //     ),
          //   ),
          // ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Transactions',
              style: TextStyle(
                color: _textPrim,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _surfaceBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded, color: _accent, size: 17),
          ),
        ],
      ),
    );
  }

  // Widget _buildTabs() {
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
  //     child: Container(
  //       decoration: BoxDecoration(
  //         color: _surfaceBg,
  //         borderRadius: BorderRadius.circular(14),
  //       ),
  //       padding: const EdgeInsets.all(3),
  //       child: Row(
  //         children: [
  //           _tabItem(
  //             'Bookings',
  //             false,
  //             onTap: () => context.push('/user/booking_history'),
  //           ),
  //           _tabItem('Transactions', true),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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
    final filters = TxnDateFilter.values;
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
    final query = _query;
    if (query == null) {
      return _buildEmpty(
        'Please log in to view transactions',
        Icons.lock_outline,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        // surface Firestore errors (e.g. missing index)
        if (snap.hasError) {
          debugPrint('TransactionHistory Firestore error: ${snap.error}');
          return _buildEmpty(
            'Error loading transactions.\nCheck Firestore index.',
            Icons.error_outline,
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            'No transactions found',
            Icons.receipt_long_outlined,
          );
        }

        final groups = _groupByDate(docs);
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        // FIX 4: correct summary calculation
        int totalPaid = 0, totalRefund = 0;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = data['amount'] as int? ?? 0;
          if (_isRefund(data))
            totalRefund += amount;
          else if (_isPaid(data))
            totalPaid += amount;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _buildSummaryRow(totalPaid, totalRefund),
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
                  (doc) => _buildTxnCard(doc.data() as Map<String, dynamic>),
                ),
              ];
            }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(int paid, int refund) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: _summaryPill('Total paid', '₹${_fmt(paid)}', _green)),
          const SizedBox(width: 8),
          Expanded(child: _summaryPill('Refunds', '₹${_fmt(refund)}', _amber)),
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

  Widget _buildTxnCard(Map<String, dynamic> data) {
    final isRefund = _isRefund(data);
    final amount = data['amount'] as int? ?? 0;
    final groundName = (data['groundName'] as String? ?? '');
    final slotLabel = (data['slotLabel'] as String? ?? '');
    // final paymentId = (data['razorpayPaymentId'] as String? ?? '');
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final txnLabel = isRefund
        ? 'Refund – Booking cancelled'
        : 'Slot booking – $slotLabel';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isRefund ? _purpleBg : _greenBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isRefund
                  ? Icons.keyboard_return_rounded
                  : Icons.arrow_upward_rounded,
              color: isRefund ? _purpleIco : _green,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txnLabel,
                  style: const TextStyle(
                    color: _textPrim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$groundName · ${DateFormat('h:mm a').format(createdAt)}',
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                // if (paymentId.isNotEmpty) ...[
                //   const SizedBox(height: 2),
                //   Text(
                //     paymentId,
                //     style: const TextStyle(
                //       color: _textHint,
                //       fontSize: 10,
                //       fontFamily: 'monospace',
                //     ),
                //     overflow: TextOverflow.ellipsis,
                //   ),
                // ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isRefund ? '+' : '-'}₹$amount',
                style: TextStyle(
                  color: isRefund ? _green : _red,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(color: _textHint, fontSize: 11),
              ),
            ],
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
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textHint, fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => NumberFormat('#,##,###').format(n);
}
