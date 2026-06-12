import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

enum TxnDateFilter { all, today, thisWeek, thisMonth, older }

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  TxnDateFilter _activeFilter = TxnDateFilter.all;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const _green = AppTheme.success;
  static const _greenBg = Color(0xFFDCFCE7);
  static const _amber = Color(0xFFD97706);
  static const _amberBg = Color(0xFFFEF3C7);
  static const _refundIco = Color(0xFF7C3AED);
  static const _refundBg = Color(0xFFEDE9FE);

  // ── Date range ─────────────────────────────────────────────────────────────
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

  Query<Map<String, dynamic>>? get _query {
    final uid = _uid;
    if (uid == null) return null;
    var q = FirebaseFirestore.instance
        .collection('user_transactions')
        .where('userId', isEqualTo: uid);
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

  bool _isRefund(Map<String, dynamic> d) =>
      (d['transactionType'] as String? ?? '') == 'refund';
  bool _isPaid(Map<String, dynamic> d) =>
      (d['paymentStatus'] as String? ?? '') == 'success' && !_isRefund(d);

  String _formatDate(DateTime dt) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
    List<QueryDocumentSnapshot> docs,
  ) {
    final groups = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['createdAt'] as Timestamp).toDate();
      groups
          .putIfAbsent(DateFormat('yyyy-MM-dd').format(ts), () => [])
          .add(doc);
    }
    return groups;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildFilterChips(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 2),
    );
  }

  // ── Header — large bold title + red left bar ───────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Red left accent bar
          Container(
            width: 5,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Transactions',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Filter icon button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips — pill style ──────────────────────────────────────────────
  Widget _buildFilterChips() {
    final labels = ['All', 'Today', 'This Week', 'This Month', 'Older'];
    final filters = TxnDateFilter.values;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isActive = _activeFilter == filters[i];
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryRed : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primaryRed
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final query = _query;
    if (query == null)
      return _buildEmpty(
        'Please log in to view transactions',
        Icons.lock_outline,
      );

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return _buildEmpty(
            'Error loading.\nCheck Firestore index.',
            Icons.error_outline,
          );
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryRed),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return _buildEmpty(
            'No transactions found',
            Icons.receipt_long_outlined,
          );

        final groups = _groupByDate(docs);
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _buildSummaryRow(totalPaid, totalRefund),
            ...dates.expand((date) {
              final dayDocs = groups[date]!;
              return [
                // ── Date label ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _formatDate(DateTime.parse(date)) == 'Today'
                              ? AppTheme.primaryRed
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(DateTime.parse(date)).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(color: Colors.grey.shade200, height: 1),
                      ),
                    ],
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

  // ── Summary cards — icon top, label, big amount ────────────────────────────
  Widget _buildSummaryRow(int paid, int refund) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_upward_rounded,
            iconBg: AppTheme.lightRed,
            iconColor: AppTheme.primaryRed,
            label: 'TOTAL PAID',
            value: '₹${_fmt(paid)}',
            valueColor: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.keyboard_return_rounded,
            iconBg: Colors.grey.shade100,
            iconColor: Colors.grey.shade500,
            label: 'REFUNDS',
            value: '₹${_fmt(refund)}',
            valueColor: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Transaction card — colored left bar, bold amount right ─────────────────
  Widget _buildTxnCard(Map<String, dynamic> data) {
    final isRefund = _isRefund(data);
    final amount = data['amount'] as int? ?? 0;
    final groundName = data['groundName'] as String? ?? '';
    final slotLabel = data['slotLabel'] as String? ?? '';
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    // Title line: "Slot booking — 1:10 PM" or "Refund — Squash Court" etc.
    final title = isRefund
        ? 'Refund — $groundName'
        : 'Slot booking — ${DateFormat('h:mm a').format(createdAt)}';

    // Subtitle: ground name + time or "Cancellation #xxx"
    final subtitle = isRefund
        ? 'Cancellation'
        : '$groundName · ${DateFormat('h:mm a').format(createdAt)}';

    // Left bar color
    final barColor = isRefund ? _green : AppTheme.primaryRed;

    // Icon
    final iconBg = isRefund ? _greenBg : AppTheme.lightRed;
    final iconColor = isRefund ? _green : AppTheme.primaryRed;
    final iconData = isRefund
        ? Icons.keyboard_return_rounded
        : Icons.arrow_upward_rounded;

    // Amount display
    final amountStr = isRefund ? '+₹$amount' : '-₹$amount';
    final amountColor = isRefund ? _green : AppTheme.primaryRed;
    final dateStr = _formatDate(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Colored left bar ───────────────────────────────────────
              Container(width: 4, color: barColor),

              // ── Main content ───────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Amount + date (right aligned)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            amountStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => NumberFormat('#,##,###').format(n);
}

// ── Summary Card — icon top, small label, large amount ───────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in circle/rounded bg
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          // Label — small uppercase
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          // Value — large bold
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
