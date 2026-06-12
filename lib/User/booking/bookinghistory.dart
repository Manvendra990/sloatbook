import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

enum DateFilter { all, today, thisWeek, thisMonth, older }

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  DateFilter _activeFilter = DateFilter.all;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Status colours (kept local — not part of AppTheme) ───────────────────
  static const _green = AppTheme.success;
  static const _greenBg = Color(0xFFDCFCE7);
  static const _greenTxt = Color(0xFF166534);
  static const _redBg = Color(0xFFFEE2E2);
  static const _redTxt = Color(0xFF991B1B);
  static const _amberBg = Color(0xFFFEF3C7);
  static const _amberTxt = Color(0xFF92400E);
  static const _amberBar = Color(0xFFD97706);

  // ── Date range ─────────────────────────────────────────────────────────────
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

  Query<Map<String, dynamic>>? get _query {
    final uid = _uid;
    if (uid == null) return null;
    var q = FirebaseFirestore.instance
        .collection('user_bookings')
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

  Color _statusBarColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _green;
      case 'cancelled':
        return AppTheme.error;
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
      backgroundColor: AppTheme.background,
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
      bottomNavigationBar: const UserNavBar(currentIndex: 1),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Red accent bar
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: AppText.headlineMedium('Booking History')),
          // Stats icon button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildDateFilterChips() {
    final labels = ['All', 'Today', 'This Week', 'This Month', 'Older'];
    final filters = DateFilter.values;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        height: 36,
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
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryRed : AppTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primaryRed
                        : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    if (query == null) {
      return _buildEmpty('Please log in to view bookings', Icons.lock_outline);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildEmpty(
            'Error loading bookings.\nCheck Firestore index.',
            Icons.error_outline,
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryRed),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            'No bookings found',
            Icons.calendar_today_outlined,
          );
        }

        final groups = _groupByDate(docs);
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
        final spent = docs
            .where((d) => (d.data() as Map)['paymentStatus'] == 'paid')
            .fold<int>(
              0,
              (s, d) => s + ((d.data() as Map)['amount'] as int? ?? 0),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildSummaryRow(docs.length, spent),
            const SizedBox(height: 4),
            ...dates.expand((date) {
              final dayDocs = groups[date]!;
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppText.label(
                        _formatDate(DateTime.parse(date)).toUpperCase(),
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Divider(color: Colors.grey.shade200, height: 1),
                      ),
                    ],
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

  // ── Summary Row ────────────────────────────────────────────────────────────
  Widget _buildSummaryRow(int total, int spent) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.confirmation_number_outlined,
            label: 'Total Bookings',
            value: total.toString(),
            valueColor: AppTheme.textPrimary,
            iconBg: AppTheme.lightRed,
            iconColor: AppTheme.primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_outlined,
            label: 'Amount Spent',
            value: '₹${NumberFormat('#,##,###').format(spent)}',
            valueColor: _green,
            iconBg: _greenBg,
            iconColor: _green,
          ),
        ),
      ],
    );
  }

  // ── Booking Card ───────────────────────────────────────────────────────────
  Widget _buildBookingCard(Map<String, dynamic> data) {
    final status = (data['bookingStatus'] as String? ?? 'pending');
    final amount = data['amount'] as int? ?? 0;
    final groundName = (data['groundName'] as String? ?? 'Unknown Ground');
    final slotLabel = (data['slotLabel'] as String? ?? '—');
    final rawPayment = (data['paymentStatus'] as String? ?? '');
    final paymentLabel = rawPayment.isNotEmpty
        ? rawPayment[0].toUpperCase() + rawPayment.substring(1)
        : 'Unknown';
    final statusLabel = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : 'Pending';

    // Date from createdAt
    String dateStr = '';
    if (data['createdAt'] is Timestamp) {
      dateStr = DateFormat(
        'd MMM · h:mm a',
      ).format((data['createdAt'] as Timestamp).toDate());
    }

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
              // Left status bar
              Container(width: 4, color: _statusBarColor(status)),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ground name + badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sport icon
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.lightRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sports_outlined,
                              color: AppTheme.primaryRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText.bodyLarge(
                                  groundName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (dateStr.isNotEmpty)
                                  AppText.bodyMedium(dateStr),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
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
                              statusLabel,
                              style: TextStyle(
                                color: _badgeTxt(status),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade100, height: 1),
                      const SizedBox(height: 10),

                      // Slot + payment + amount
                      Row(
                        children: [
                          // Slot time
                          _InfoChip(
                            icon: Icons.access_time_rounded,
                            label: slotLabel,
                          ),
                          const SizedBox(width: 8),
                          // Payment status
                          _InfoChip(
                            icon: Icons.credit_card_rounded,
                            label: paymentLabel,
                            color: rawPayment.toLowerCase() == 'paid'
                                ? _green
                                : _amberTxt,
                          ),
                          const Spacer(),
                          // Amount
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.lightRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AppText(
                              '₹$amount',
                              variant: AppTextVariant.bodyLarge,
                              color: AppTheme.primaryRed,
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

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 16),
          AppText.bodyMedium(msg, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color iconBg;
  final Color iconColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.bodyMedium(label),
              AppText(
                value,
                variant: AppTextVariant.titleLarge,
                color: valueColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info Chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        AppText.bodyMedium(label, color: c),
      ],
    );
  }
}
