import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SlotBookingScreen extends StatefulWidget {
  final String groundId;
  const SlotBookingScreen({super.key, required this.groundId});

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);
  static const _bg = Color(0xFFF5F7F5);

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlotId;
  Map<String, dynamic>? _selectedSlotData;
  bool _isBooking = false;

  List<Map<String, String>> get _timeSlots {
    final slots = <Map<String, String>>[];
    for (int h = 5; h <= 22; h++) {
      final start = TimeOfDay(hour: h, minute: 0);
      final end = TimeOfDay(hour: h + 1, minute: 0);
      slots.add({
        'id': '${h.toString().padLeft(2, '0')}00',
        'start': _formatTime(start),
        'end': _formatTime(end),
        'label': '${_formatTime(start)} – ${_formatTime(end)}',
      });
    }
    return slots;
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:00 $period';
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  int _parsePrice(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  String _formatDurationLabel(
    Map<String, dynamic>? data,
    DateTime start,
    DateTime end,
  ) {
    if (data != null && data['timeDuretion'] is Map) {
      final durationMap = Map<String, dynamic>.from(
        data['timeDuretion'] as Map,
      );
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

    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '1h';
  }

  Map<String, dynamic> _normalizeSlotEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final startTimestamp = data['startTime'] as Timestamp?;
    final endTimestamp = data['endTime'] as Timestamp?;
    final start = startTimestamp?.toDate() ?? DateTime.now();
    final end = endTimestamp?.toDate() ?? start.add(const Duration(hours: 1));
    final durationLabel = _formatDurationLabel(data, start, end);
    final amount = _parsePrice(data['amount']);
    final status =
        (data['bookingStatus'] as String?)?.toLowerCase() ?? 'available';
    final slotKey = '${start.hour.toString().padLeft(2, '0')}00';

    return {
      'docId': doc.id,
      'slotId': slotKey,
      'label':
          '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
      'start': start,
      'end': end,
      'durationLabel': durationLabel,
      'amount': amount,
      'bookingStatus': status,
      'paymentStatus': data['paymentStatus'] as String? ?? '',
      'adminId': data['adminId'] as String? ?? '',
      'raw': data,
    };
  }

  bool _bookingMatchesSelectedDate(Map<String, dynamic> data) {
    final selectedDay = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (data['slotDate'] is Timestamp) {
      return DateFormat(
            'yyyy-MM-dd',
          ).format((data['slotDate'] as Timestamp).toDate()) ==
          selectedDay;
    }
    if (data['date'] is String) {
      return data['date'] == selectedDay;
    }
    return false;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _green,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0E1A13),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlotId = null;
        _selectedSlotData = null;
      });
    }
  }

  // ── Book Slot — navigate to payment with the selected slot data ───────
  Future<void> _bookSlot(Map<String, dynamic> groundData) async {
    if (_selectedSlotId == null || _selectedSlotData == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login to book a slot.');
      return;
    }

    final slot = _selectedSlotData!;
    final amount =
        slot['amount'] as int? ?? _parsePrice(groundData['pricePerHour']);
    final start = slot['start'] as DateTime;
    final end = slot['end'] as DateTime;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormat('EEE, MMM d yyyy').format(_selectedDate),
            ),
            const SizedBox(height: 8),
            _ConfirmRow(
              icon: Icons.access_time_rounded,
              label: 'Slot',
              value: slot['label'] as String,
            ),
            const SizedBox(height: 8),
            _ConfirmRow(
              icon: Icons.payments_outlined,
              label: 'Amount',
              value: '₹$amount',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final paymentPayload = {
      'groundId': widget.groundId,
      'groundName': groundData['name'] ?? '',
      'userId': user.uid,
      'userPhone': user.phoneNumber ?? '',
      'date': _dateKey,
      'slotId': _selectedSlotId,
      'slotLabel': slot['label'],
      'startTime': start,
      'endTime': end,
      'durationLabel': slot['durationLabel'],
      'timeDuretion': {
        'hour': end.difference(start).inHours,
        'minute': end.difference(start).inMinutes.remainder(60),
      },
      'amount': amount,
      'bookingStatus': slot['bookingStatus'] as String? ?? 'available',
      'paymentStatus': slot['paymentStatus'] as String? ?? 'unpaid',
      'adminId': slot['adminId'] as String? ?? '',
    };

    if (!mounted) return;
    context.go('/user/payment', extra: paymentPayload);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: _greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _green,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0E1A13),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your slot has been booked successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE0DD)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
        title: const Text(
          'Book a Slot',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E1A13),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('grounds')
            .doc(widget.groundId)
            .snapshots(),
        builder: (context, groundSnap) {
          if (!groundSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }
          final groundData = groundSnap.data!.data() ?? {};
          final pricePerHour = _parsePrice(groundData['pricePerHour']);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('groundId', isEqualTo: widget.groundId)
                .snapshots(),
            builder: (context, bookingSnap) {
              if (bookingSnap.connectionState == ConnectionState.waiting &&
                  !bookingSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _green),
                );
              }

              final docs = bookingSnap.data?.docs ?? [];
              final slotEntries =
                  docs
                      .where((d) => _bookingMatchesSelectedDate(d.data()))
                      .map(_normalizeSlotEntry)
                      .toList()
                    ..sort(
                      (a, b) => (a['start'] as DateTime).compareTo(
                        b['start'] as DateTime,
                      ),
                    );
              final hasNoBookings = slotEntries.isEmpty;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroundSummary(groundData),
                          const SizedBox(height: 20),
                          _buildDateSelector(),
                          const SizedBox(height: 20),
                          if (hasNoBookings) _buildNoBookingsBanner(),
                          _buildLegend(),
                          const SizedBox(height: 16),
                          _buildSlotGrid(slotEntries, pricePerHour),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildBookButton(groundData),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoBookingsBanner() {
    final isToday = _dateKey == DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: _green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? 'All slots available today!'
                      : 'Bookings coming soon',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isToday
                      ? 'No bookings yet for today. Pick any slot below.'
                      : 'No bookings found for this date. All slots are open.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroundSummary(Map<String, dynamic> data) {
    final price = _parsePrice(data['pricePerHour']);
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_outlined, color: _green, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Ground',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
                Text(
                  '${data['address'] ?? ''}, ${data['city'] ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _green,
                ),
              ),
              Text(
                'per hour',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E1A13),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final date = DateTime.now().add(Duration(days: i));
              final isSelected =
                  _dateKey == DateFormat('yyyy-MM-dd').format(date);
              final isToday = i == 0;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = date;
                  _selectedSlotId = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? _green : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _green : const Color(0xFFDDE0DD),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF0E1A13),
                        ),
                      ),
                      if (isToday)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : _green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.date_range_rounded, size: 14, color: _green),
                    SizedBox(width: 4),
                    Text(
                      'Pick Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        const Text(
          'Available Slots',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E1A13),
          ),
        ),
        const Spacer(),
        _LegendDot(color: Colors.white, label: 'Available', border: true),
        const SizedBox(width: 12),
        const _LegendDot(color: _green, label: 'Selected'),
        const SizedBox(width: 12),
        _LegendDot(color: Colors.grey[200]!, label: 'Booked'),
      ],
    );
  }

  Widget _buildSlotGrid(
    List<Map<String, dynamic>> slotEntries,
    int pricePerHour,
  ) {
    final now = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemCount: slotEntries.length,
      itemBuilder: (context, i) {
        final slot = slotEntries[i];
        final slotId = slot['slotId'] as String;
        final isSelected = _selectedSlotId == slotId;
        final start = slot['start'] as DateTime;
        final end = slot['end'] as DateTime;
        final status = (slot['bookingStatus'] as String).toLowerCase();
        final isBooked = status != 'available';
        final isPastSlot = end.isBefore(now);
        final disabled = isBooked || isPastSlot;
        final label = slot['label'] as String;
        final durationLabel = slot['durationLabel'] as String;
        final amount = slot['amount'] as int;
        final statusLabel = isBooked
            ? status[0].toUpperCase() + status.substring(1)
            : 'Available';

        return GestureDetector(
          onTap: disabled
              ? null
              : () => setState(() {
                  if (isSelected) {
                    _selectedSlotId = null;
                    _selectedSlotData = null;
                  } else {
                    _selectedSlotId = slotId;
                    _selectedSlotData = slot;
                  }
                }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isBooked
                  ? Colors.grey[200]
                  : isPastSlot
                  ? Colors.grey[100]
                  : isSelected
                  ? _green
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _green
                    : isBooked
                    ? Colors.grey[300]!
                    : const Color(0xFFDDE0DD),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _green.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isBooked || isPastSlot
                          ? Colors.grey[400]
                          : isSelected
                          ? Colors.white
                          : const Color(0xFF0E1A13),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBooked
                        ? '$statusLabel · $durationLabel'
                        : '₹$amount · $durationLabel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isBooked || isPastSlot
                          ? Colors.grey[400]
                          : isSelected
                          ? Colors.white.withOpacity(0.85)
                          : _green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookButton(Map<String, dynamic> groundData) {
    final price = _parsePrice(groundData['pricePerHour']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedSlotId != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: _green),
                const SizedBox(width: 6),
                Text(
                  _selectedSlotData != null
                      ? _selectedSlotData!['label'] as String
                      : _timeSlots.firstWhere(
                          (s) => s['id'] == _selectedSlotId,
                        )['label']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0E1A13),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${_selectedSlotData != null ? _selectedSlotData!['amount'] : price}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_selectedSlotId == null || _isBooking)
                  ? null
                  : () => _bookSlot(groundData),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _selectedSlotId == null
                          ? 'Select a Slot to Continue'
                          : 'Proceed to Payment',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm Row ───────────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D5C3A)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0E1A13),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Legend Dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;
  const _LegendDot({
    required this.color,
    required this.label,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: Colors.grey[400]!) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
