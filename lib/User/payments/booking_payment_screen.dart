//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_service.dart';

class BookingPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingPaymentScreen({super.key, required this.bookingData});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  static const _razorpayKey = 'rzp_test_Sx8TW4wytAZwan';
  late RazorpayService _razorpayService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

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
    return '1h';
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

  // ─── Payment flow ─────────────────────────────────────────────────────────

  Future<void> _openCheckout() async {
    if (_isProcessing) return;
    if (_amount <= 0) {
      _showSnack('Invalid payment amount.');
      return;
    }

    final alreadyBooked = await FirebaseFirestore.instance
        .collection('bookings')
        .where('groundId', isEqualTo: _groundId)
        .where('date', isEqualTo: widget.bookingData['date'])
        .where('slotId', isEqualTo: widget.bookingData['slotId'])
        .where('status', isEqualTo: 'confirmed')
        .get();

    if (alreadyBooked.docs.isNotEmpty) {
      _showSnack('This slot is already booked. Please choose another.');
      return;
    }

    final options = {
      'key': _razorpayKey,
      'amount': _amount * 100,
      'name': _groundName,
      'description':
          widget.bookingData['slotLabel'] as String? ?? 'Slot payment',
      'prefill': {'contact': _userPhone},
      'theme': {'color': '#0D5C3A'},
    };

    try {
      await _razorpayService.openCheckout(options: options);
    } catch (e) {
      _showSnack('Unable to open payment gateway.');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);

    try {
      await _saveBookingAndTransaction(response.paymentId ?? '');

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Payment Successful 🎉'),
          content: const Text(
            'Your booking has been confirmed.\nYou can view it in your bookings.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C3A),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnack('Failed to save booking: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment error code   : ${response.code}');
    debugPrint('Payment error message: ${response.message}');
    _showSnack('Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnack('External wallet selected: ${response.walletName}');
  }

  // ─── Firestore writes ─────────────────────────────────────────────────────
  //
  //  Three collections written atomically in one batch:
  //
  //  1. /user_bookings/{bookingId}
  //       → queried by userId  → user's booking history screen
  //
  //  2. /user_transactions/{bookingId}
  //       → queried by userId  → user's payment / transaction history screen
  //
  //  3. /admin_revenue/{adminId}/transactions/{bookingId}
  //       → scoped under adminId → admin revenue & income report
  //
  //  All three share the same bookingId so cross-collection joins are trivial.
  //
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _saveBookingAndTransaction(String razorpayPaymentId) async {
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

    // ── 1. /user_bookings/{bookingId} ─────────────────────────────────────
    final bookingDoc = {
      'bookingId': bookingId,

      // ── User (for user-side booking history queries) ──
      'userId': _userId,
      'userPhone': _userPhone,

      // ── Ground & admin ──
      'groundId': _groundId,
      'groundName': _groundName,
      'adminId': _adminId,

      // ── Slot ──
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

      // ── Payment ──
      'amount': _amount,
      'currency': 'INR',
      'razorpayPaymentId': razorpayPaymentId,

      // ── Status ──
      'bookingStatus': 'confirmed',
      'paymentStatus': 'paid',
      'status': 'confirmed',

      'createdAt': FieldValue.serverTimestamp(),
    };

    // ── 2. /user_transactions/{bookingId} ─────────────────────────────────
    final transactionDoc = {
      'transactionId': bookingId,
      'bookingId': bookingId, // ← cross-ref to user_bookings
      // ── User (primary key for user transaction history) ──
      'userId': _userId,
      'userPhone': _userPhone,

      // ── What was paid for ──
      'groundId': _groundId,
      'groundName': _groundName,
      'adminId': _adminId, // ← cross-ref to admin_revenue
      'slotId': widget.bookingData['slotId'] ?? '',
      'slotLabel': widget.bookingData['slotLabel'] ?? '',
      'date': dateKey,

      // ── Payment details ──
      'amount': _amount,
      'currency': 'INR',
      'paymentMethod': 'razorpay',
      'razorpayPaymentId': razorpayPaymentId,
      'paymentStatus': 'success',
      'transactionType': 'booking_payment',

      'paidAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ── 3. /admin_revenue/{adminId}/transactions/{bookingId} ──────────────
    final adminRevenueDoc = {
      'transactionId': bookingId,
      'bookingId': bookingId, // ← cross-ref to user_bookings
      // ── Admin (document path already scopes to adminId) ──
      'adminId': _adminId,

      // ── Ground ──
      'groundId': _groundId,
      'groundName': _groundName,

      // ── User (admin can see who paid) ──
      'userId': _userId, // ← key link for admin → user lookup
      'userPhone': _userPhone,

      // ── Slot ──
      'slotId': widget.bookingData['slotId'] ?? '',
      'slotLabel': widget.bookingData['slotLabel'] ?? '',
      'date': dateKey,
      'slotDate': startTime != null
          ? Timestamp.fromDate(
              DateTime(startTime.year, startTime.month, startTime.day),
            )
          : null,

      // ── Revenue figures ──
      'amount': _amount,
      'currency': 'INR',
      'paymentMethod': 'razorpay',
      'razorpayPaymentId': razorpayPaymentId,
      'paymentStatus': 'success',

      'paidAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ── Atomic batch — all three succeed or all three fail ────────────────
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

    await batch.commit();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final slotLabel = widget.bookingData['slotLabel'] as String? ?? 'Slot';
    final bookingStatus =
        widget.bookingData['bookingStatus'] as String? ?? 'unavailable';
    final paymentStatus =
        widget.bookingData['paymentStatus'] as String? ?? 'unpaid';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm your booking details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0E1A13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(
                        title: 'Ground',
                        value: _groundName,
                        icon: Icons.sports_outlined,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Slot',
                        value: slotLabel,
                        icon: Icons.access_time_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Date',
                        value: _formatDate(_startTime),
                        icon: Icons.calendar_today_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Time',
                        value:
                            '${_formatTime(_startTime)} – ${_formatTime(_endTime)}',
                        icon: Icons.schedule_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Duration',
                        value: _formatDuration(),
                        icon: Icons.timeline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Amount',
                        value: '₹$_amount',
                        icon: Icons.payments_outlined,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Booking status',
                        value: bookingStatus.toUpperCase(),
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Payment status',
                        value: paymentStatus.toUpperCase(),
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      if (_adminId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'Admin ID',
                          value: _adminId,
                          icon: Icons.admin_panel_settings_rounded,
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _openCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5C3A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Pay ₹$_amount',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable info card ────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0D5C3A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6E7D72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
