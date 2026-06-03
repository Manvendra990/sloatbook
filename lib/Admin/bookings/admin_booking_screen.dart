import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/Admin/navbar/adminNavbar.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const _green = Color(0xFF0D5C3A);

  bool _showUpcoming = true;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERFORMANCE DASHBOARD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'My Booked Slots',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1A13),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Toggle tabs ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TabChip(
                          label: 'Upcoming',
                          isActive: _showUpcoming,
                          onTap: () => setState(() => _showUpcoming = true),
                        ),
                        _TabChip(
                          label: 'Past History',
                          isActive: !_showUpcoming,
                          onTap: () => setState(() => _showUpcoming = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // ✅ NO orderBy — simple where only, zero index required
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('adminId', isEqualTo: _uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _green),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red[400]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // final now = DateTime.now();
                  final today = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  );
                  final allDocs = snapshot.data?.docs ?? [];

                  // ✅ Filter upcoming vs past in Dart
                  final docs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final slotDate = (data['slotDate'] as Timestamp?)?.toDate();
                    if (slotDate == null) return false;
                    // return _showUpcoming
                    //     ? slotDate.isAfter(now)
                    //     : slotDate.isBefore(now);

                    final bookingDate = DateTime(
                      slotDate.year,
                      slotDate.month,
                      slotDate.day,
                    );

                    return _showUpcoming
                        ? !bookingDate.isBefore(today)
                        : bookingDate.isBefore(today);
                  }).toList();

                  // ✅ Sort in Dart — no Firestore index needed
                  docs.sort((a, b) {
                    final aDate = ((a.data() as Map)['slotDate'] as Timestamp?)
                        ?.toDate();
                    final bDate = ((b.data() as Map)['slotDate'] as Timestamp?)
                        ?.toDate();
                    if (aDate == null || bDate == null) return 0;
                    return _showUpcoming
                        ? aDate.compareTo(bDate) // upcoming: earliest first
                        : bDate.compareTo(aDate); // past: latest first
                  });

                  // Active slot count
                  final activeCount = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final slotDate = (data['slotDate'] as Timestamp?)?.toDate();
                    // return slotDate != null && slotDate.isAfter(now);
                    if (slotDate == null) return false;

                    final bookingDate = DateTime(
                      slotDate.year,
                      slotDate.month,
                      slotDate.day,
                    );

                    return !bookingDate.isBefore(today);
                  }).length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Active slots summary card ──────────────────────
                        _SummaryCard(activeCount: activeCount),
                        const SizedBox(height: 24),

                        // ── Bookings list ──────────────────────────────────
                        if (docs.isEmpty)
                          _EmptyState(isUpcoming: _showUpcoming)
                        else
                          ...docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _BookingCard(
                                bookingId: doc.id,
                                data: data,
                                onEdit: () =>
                                    _showEditDialog(context, doc.id, data),
                                onDetails: () =>
                                    _showDetailsSheet(context, doc.id, data),
                                onDelete: () => _deleteSlot(context, doc.id),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Nav bar ──────────────────────────────────────────────────────
            const AdminNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  // ── Edit booking dialog ────────────────────────────────────────────────────
  void _showEditDialog(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    String status = data['bookingStatus'] ?? 'available';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Update Booking Status',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['available', 'cancelled'].map((s) {
              return RadioListTile<String>(
                value: s,
                groupValue: status,
                title: Text(
                  s.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                activeColor: _green,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setDialogState(() => status = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('Delete Slot'),
                    content: const Text(
                      'Are you sure you want to delete this slot?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => confirmCtx.pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => confirmCtx.pop(true),
                        child: const Text(
                          'Yes',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(bookingId)
                      .delete();
                  if (mounted) ctx.pop();
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(bookingId)
                    .update({'bookingStatus': status});
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Details bottom sheet ───────────────────────────────────────────────────
  void _showDetailsSheet(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    final endTime = (data['endTime'] as Timestamp?)?.toDate();
    final slotDate = (data['slotDate'] as Timestamp?)?.toDate();
    final amount = data['amount'] ?? 0;
    final bookingStatus = data['bookingStatus'] ?? 'available';
    final paymentStatus = data['paymentStatus'] ?? 'unpaid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Booking ID',
              value: '#${bookingId.substring(0, 8).toUpperCase()}',
            ),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: slotDate != null
                  ? DateFormat('dd MMM yyyy').format(slotDate)
                  : '-',
            ),
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: (startTime != null && endTime != null)
                  ? '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'
                  : '-',
            ),
            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Amount',
              value: '₹$amount',
            ),
            _DetailRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Booking Status',
              value: bookingStatus.toUpperCase(),
            ),
            _DetailRow(
              icon: Icons.payment_rounded,
              label: 'Payment Status',
              value: paymentStatus.toUpperCase(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete slot ────────────────────────────────────────────────────────────
  void _deleteSlot(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Slot',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text(
          'Are you sure you want to delete this slot? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(bookingId)
                  .delete();
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int activeCount;
  static const _green = Color(0xFF0D5C3A);

  const _SummaryCard({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL ACTIVE SLOTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Row(
                children: List.generate(
                  3,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$activeCount',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            activeCount > 0
                ? 'You have $activeCount slot${activeCount > 1 ? 's' : ''} scheduled. Keep up the momentum!'
                : 'No active slots. Create new slots to get started.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking Card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit, onDetails, onDelete;

  static const _green = Color(0xFF0D5C3A);

  const _BookingCard({
    required this.bookingId,
    required this.data,
    required this.onEdit,
    required this.onDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    final endTime = (data['endTime'] as Timestamp?)?.toDate();
    final slotDate = (data['slotDate'] as Timestamp?)?.toDate(); // date added
    final bookingStatus = data['bookingStatus'] ?? 'available';
    final amount = data['amount'] ?? 0;
    final groundId = data['groundId'] ?? '';

    final timeStr = (startTime != null && endTime != null)
        ? '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'
        : '--:-- - --:--';

    //------- date variable -----
    final dateStr = slotDate != null
        ? DateFormat('dd MMM yyyy').format(slotDate)
        : '--';

    // ── Determine display status for past/expired slots ─────────────────
    // final now = DateTime.now();
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // final isSlotPast = slotDate != null && slotDate.isBefore(now);
    // final today = DateTime(
    //   DateTime.now().year,
    //   DateTime.now().month,
    //   DateTime.now().day,
    // );

    final isSlotPast =
        slotDate != null &&
        DateTime(slotDate.year, slotDate.month, slotDate.day).isBefore(today);

    final displayStatus = isSlotPast
        ? (bookingStatus == 'available' ? 'expired' : 'completed')
        : bookingStatus;

    final shortId = '#KN-${bookingId.substring(0, 4).toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status + booking ID ────────────────────────────────────────
            Row(
              children: [
                _StatusBadge(status: displayStatus),
                const SizedBox(width: 10),
                Text(
                  'Booking ID: $shortId',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Ground name ────────────────────────────────────────────────
            FutureBuilder<DocumentSnapshot>(
              future: groundId.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collection('grounds')
                        .doc(groundId)
                        .get()
                  : Future.value(null as DocumentSnapshot?),
              builder: (context, snap) {
                final groundName =
                    (snap.data?.data() as Map<String, dynamic>?)?['name'] ??
                    'Ground';
                final groundCity =
                    (snap.data?.data() as Map<String, dynamic>?)?['city'] ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groundName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E1A13),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ------------date-- time --- location -----------------------
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            groundCity,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // ── Action buttons ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isSlotPast ? onDelete : onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isSlotPast ? Colors.red.shade600 : _green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isSlotPast ? 'Delete' : 'Edit Booking',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, textColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = const Color(0xFFE8F5EE);
        textColor = const Color(0xFF0D5C3A);
        break;
      case 'paid':
        bg = const Color(0xFFE3F0FF);
        textColor = const Color(0xFF1A6BB5);
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        textColor = Colors.red.shade600;
        break;
      case 'completed':
        bg = const Color(0xFFE8F5EE);
        textColor = const Color(0xFF0D5C3A);
        break;
      case 'expired':
        bg = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
      default:
        bg = const Color(0xFFF0F4FF);
        textColor = const Color(0xFF4A5DA0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Detail Row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D5C3A)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E1A13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Chip ──────────────────────────────────────────────────────────────────
class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF0E1A13) : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isUpcoming;
  const _EmptyState({required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              isUpcoming
                  ? Icons.calendar_today_outlined
                  : Icons.history_rounded,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming slots' : 'No past bookings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'Create slots from the Slots tab'
                  : 'Your completed bookings will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
