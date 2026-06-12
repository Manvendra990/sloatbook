import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookingPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingPaymentScreen({super.key, required this.bookingData});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  bool _isProcessing = false;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
    return DateFormat('EEE, MMM d, yyyy').format(value);
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'N/A';
    return DateFormat('h:mm a').format(value);
  }

  String _formatDuration() {
    if (widget.bookingData['durationLabel'] is String) {
      return widget.bookingData['durationLabel'] as String;
    }
    final durationMap = widget.bookingData['timeDuretion'];
    if (durationMap is Map) {
      final hours = durationMap['hour'] is num
          ? (durationMap['hour'] as num).toInt()
          : 0;
      final minutes = durationMap['minute'] is num
          ? (durationMap['minute'] as num).toInt()
          : 0;
      if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
      if (hours > 0) return '${hours}h';
      if (minutes > 0) return '${minutes}m';
    }
    return '1 Hour';
  }

  int get _amount {
    final raw = widget.bookingData['amount'];
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  DateTime? get _startTime => _toDateTime(widget.bookingData['startTime']);
  DateTime? get _endTime => _toDateTime(widget.bookingData['endTime']);

  String get _userId => widget.bookingData['userId'] as String? ?? '';
  String get _userPhone => widget.bookingData['userPhone'] as String? ?? '';
  String get _adminId => widget.bookingData['adminId'] as String? ?? '';
  String get _groundId => widget.bookingData['groundId'] as String? ?? '';
  String get _groundName =>
      widget.bookingData['groundName'] as String? ?? 'Ground';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Confirm & Save ───────────────────────────────────────────────────────

  Future<void> _confirmBooking() async {
    if (_isProcessing) return;

    // Slot availability check
    final alreadyBooked = await FirebaseFirestore.instance
        .collection('admin_bookings')
        .where('groundId', isEqualTo: _groundId)
        .where('date', isEqualTo: widget.bookingData['date'])
        .where('slotId', isEqualTo: widget.bookingData['slotId'])
        .where('bookingStatus', isEqualTo: 'confirmed')
        .get();

    if (alreadyBooked.docs.isNotEmpty) {
      _showSnack('This slot is already booked. Please choose another.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _saveBooking();

      if (!mounted) return;

      // Success dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Booking Confirmed 🎉'),
          content: const Text(
            'Your slot has been confirmed.\nYou can view it in your bookings.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!mounted) return;
      // Navigate to home
      context.go('/user/home');
    } catch (e) {
      _showSnack('Failed to confirm booking: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Firestore writes ─────────────────────────────────────────────────────
  Future<void> _saveBooking() async {
    final startTime = _startTime;
    final endTime = _endTime;
    final now = DateTime.now();

    final dateKey = widget.bookingData['date'] is String
        ? widget.bookingData['date'] as String
        : startTime != null
        ? DateFormat('yyyy-MM-dd').format(startTime)
        : DateFormat('yyyy-MM-dd').format(now);

    final durationMap =
        widget.bookingData['timeDuretion'] ??
        {
          'hour': (startTime != null && endTime != null)
              ? endTime.difference(startTime).inHours
              : 0,
          'minute': (startTime != null && endTime != null)
              ? endTime.difference(startTime).inMinutes.remainder(60)
              : 0,
        };

    final db = FirebaseFirestore.instance;
    final bookingRef = db.collection('user_bookings').doc();
    final bookingId = bookingRef.id;

    // 1. user_bookings
    final bookingDoc = {
      'bookingId': bookingId,
      'userId': _userId,
      'userPhone': _userPhone,
      'groundId': _groundId,
      'groundName': _groundName,
      'adminId': _adminId,
      'date': dateKey,
      'slotId': widget.bookingData['slotId'] ?? '',
      'slotLabel': widget.bookingData['slotLabel'] ?? '',
      'slotStart': startTime != null
          ? DateFormat('h:mm a').format(startTime)
          : '',
      'slotEnd': endTime != null ? DateFormat('h:mm a').format(endTime) : '',
      'startTime': startTime != null ? Timestamp.fromDate(startTime) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
      'slotDate': startTime != null
          ? Timestamp.fromDate(
              DateTime(startTime.year, startTime.month, startTime.day),
            )
          : null,
      'timeDuretion': durationMap,
      'amount': _amount,
      'currency': 'INR',
      'paymentMethod': 'cash',
      'bookingStatus': 'confirmed',
      'paymentStatus': 'paid',
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 2. user_transactions
    final transactionDoc = {
      'transactionId': bookingId,
      'bookingId': bookingId,
      'userId': _userId,
      'userPhone': _userPhone,
      'groundId': _groundId,
      'groundName': _groundName,
      'adminId': _adminId,
      'slotId': widget.bookingData['slotId'] ?? '',
      'slotLabel': widget.bookingData['slotLabel'] ?? '',
      'date': dateKey,
      'amount': _amount,
      'currency': 'INR',
      'paymentMethod': 'cash',
      'paymentStatus': 'success',
      'transactionType': 'booking_payment',
      'paidAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 3. admin_revenue
    final adminRevenueDoc = {
      'transactionId': bookingId,
      'bookingId': bookingId,
      'adminId': _adminId,
      'groundId': _groundId,
      'groundName': _groundName,
      'userId': _userId,
      'userPhone': _userPhone,
      'slotId': widget.bookingData['slotId'] ?? '',
      'slotLabel': widget.bookingData['slotLabel'] ?? '',
      'date': dateKey,
      'slotDate': startTime != null
          ? Timestamp.fromDate(
              DateTime(startTime.year, startTime.month, startTime.day),
            )
          : null,
      'amount': _amount,
      'currency': 'INR',
      'paymentMethod': 'cash',
      'paymentStatus': 'success',
      'paidAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = db.batch();

    batch.set(bookingRef, bookingDoc);
    batch.set(
      db.collection('user_transactions').doc(bookingId),
      transactionDoc,
    );

    if (_adminId.isNotEmpty) {
      batch.set(
        db
            .collection('admin_revenue')
            .doc(_adminId)
            .collection('transactions')
            .doc(bookingId),
        adminRevenueDoc,
      );
    }

    // 4. Update admin_bookings — find matching slot using groundId + startTime
    if (startTime == null) {
      throw Exception('Start time is missing');
    }

    debugPrint('================ ADMIN BOOKING UPDATE CHECK ================');
    debugPrint('groundId      : $_groundId');
    debugPrint('startTime     : $startTime');
    debugPrint('bookingStatus : available');
    debugPrint('============================================================');

    final adminBookingQuery = await db
        .collection('admin_bookings')
        .where('groundId', isEqualTo: _groundId)
        .where('startTime', isEqualTo: Timestamp.fromDate(startTime))
        .where('bookingStatus', isEqualTo: 'available')
        .limit(1)
        .get();

    debugPrint('Admin booking found: ${adminBookingQuery.docs.length}');

    if (adminBookingQuery.docs.isEmpty) {
      throw Exception('Slot not found or already booked');
    }

    final adminBookingDoc = adminBookingQuery.docs.first;

    debugPrint('Matched admin_booking docId: ${adminBookingDoc.id}');
    debugPrint('Matched admin_booking data: ${adminBookingDoc.data()}');

    batch.update(adminBookingDoc.reference, {
      'bookingStatus': 'confirmed',
      'paymentStatus': 'paid',
      'userId': _userId,
      'userPhone': _userPhone,
      'bookingId': bookingId,
      'confirmedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    // ─── UI ───────────────────────────────────────────────────────────────────
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = widget.bookingData['slotLabel'] as String? ?? 'Slot';
    final bookingStatus =
        widget.bookingData['bookingStatus'] as String? ?? 'available';

    final timeLabel = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const Text(
                      'Review your selection',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please confirm the details below before proceeding to pay.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Details Card ───────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Ground row
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFFD32F2F),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'GROUND',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _groundName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(height: 1, color: Colors.grey.shade100),

                          // 2x2 grid
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.calendar_today_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'DATE',
                                        value: _formatDate(_startTime),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.access_time_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'TIME',
                                        value: timeLabel,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.bolt_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'DURATION',
                                        value: _formatDuration(),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _GridCell(
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        iconColor: const Color(0xFF2E7D32),
                                        iconBg: const Color(0xFFE8F5E9),
                                        label: 'BOOKING STATUS',
                                        value: bookingStatus.toUpperCase(),
                                        valueColor: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Payment Summary Card ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Booking Fee',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '₹${_amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: List.generate(
                                40,
                                (i) => Expanded(
                                  child: Container(
                                    height: 1,
                                    color: i % 2 == 0
                                        ? Colors.grey.shade300
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '₹$_amount',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Secure Encrypted Payment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        disabledBackgroundColor: const Color(
                          0xFFD32F2F,
                        ).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Pay Now  •  ₹$_amount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
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
}

// ─── Grid cell widget ─────────────────────────────────────────────────────────

class _GridCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color? valueColor;

  const _GridCell({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
