import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ── Unavailable booking statuses ──────────────────────────────────────────────
const _unavailableStatuses = {'booked', 'confirmed', 'blocked', 'pending'};

// ─────────────────────────────────────────────────────────────────────────────
// SlotModel — represents one hourly slot in the grid
// ─────────────────────────────────────────────────────────────────────────────
class SlotModel {
  final String slotId; // e.g. "0500"
  final String label; // e.g. "5:00 AM – 6:00 AM"
  final DateTime start;
  final DateTime end;
  final String durationLabel; // e.g. "1h"
  final int amount; // price in ₹
  final String bookingStatus; // 'available' | 'booked' | 'confirmed' | etc.
  final String paymentStatus;
  final String adminId;
  final String docId; // Firestore doc id (empty for generated slots)

  const SlotModel({
    required this.slotId,
    required this.label,
    required this.start,
    required this.end,
    required this.durationLabel,
    required this.amount,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.adminId,
    this.docId = '',
  });

  bool get isAvailable =>
      !_unavailableStatuses.contains(bookingStatus.toLowerCase());

  bool get isPast => end.isBefore(DateTime.now());

  bool get isDisabled => !isAvailable || isPast;

  // ── Factory: generate a blank available slot for a given hour ──────────────
  factory SlotModel.available({
    required DateTime date,
    required int hour,
    required int pricePerHour,
  }) {
    final start = DateTime(date.year, date.month, date.day, hour);
    final end = start.add(const Duration(hours: 1));
    final slotId = '${hour.toString().padLeft(2, '0')}00';
    return SlotModel(
      slotId: slotId,
      label:
          '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
      start: start,
      end: end,
      durationLabel: '1h',
      amount: pricePerHour,
      bookingStatus: 'available',
      paymentStatus: '',
      adminId: '',
    );
  }

  // ── Factory: parse from a Firestore booking document ──────────────────────
  factory SlotModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // Parse start/end — convert to local time
    final startTs = data['startTime'] as Timestamp?;
    final endTs = data['endTime'] as Timestamp?;
    var start = startTs?.toDate().toLocal() ?? DateTime.now();
    var end = endTs?.toDate().toLocal() ?? start.add(const Duration(hours: 1));

    // Guard: end must be after start
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    final durationLabel = _parseDuration(data, start, end);
    final rawStatus =
        (data['bookingStatus'] as String?)?.toLowerCase().trim() ?? 'available';
    final status = _unavailableStatuses.contains(rawStatus)
        ? rawStatus
        : 'available';
    final slotId = '${start.hour.toString().padLeft(2, '0')}00';

    return SlotModel(
      docId: doc.id,
      slotId: slotId,
      label:
          '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
      start: start,
      end: end,
      durationLabel: durationLabel,
      amount: _parseAmount(data['amount']),
      bookingStatus: status,
      paymentStatus: data['paymentStatus'] as String? ?? '',
      adminId: data['adminId'] as String? ?? '',
    );
  }

  // ── Convert to Map for payment payload ────────────────────────────────────
  Map<String, dynamic> toPaymentPayload({
    required String groundId,
    required String groundName,
    required String userId,
    required String userPhone,
    required String date,
  }) => {
    'groundId': groundId,
    'groundName': groundName,
    'userId': userId,
    'userPhone': userPhone,
    'date': date,
    'slotId': slotId,
    'slotLabel': label,
    'startTime': start,
    'endTime': end,
    'durationLabel': durationLabel,
    'timeDuretion': {
      'hour': end.difference(start).inHours.abs(),
      'minute': end.difference(start).inMinutes.remainder(60).abs(),
    },
    'amount': amount,
    'bookingStatus': bookingStatus,
    'paymentStatus': paymentStatus.isEmpty ? 'unpaid' : paymentStatus,
    'adminId': adminId,
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

int _parseAmount(dynamic raw) {
  if (raw == null) return 0;
  if (raw is int) return raw;
  if (raw is double) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

String _parseDuration(Map<String, dynamic> data, DateTime start, DateTime end) {
  if (data['timeDuretion'] is Map) {
    final m = Map<String, dynamic>.from(data['timeDuretion'] as Map);
    final h = m['hour'] is num ? (m['hour'] as num).toInt() : 0;
    final min = m['minute'] is num ? (m['minute'] as num).toInt() : 0;
    if (h > 0 && min > 0) return '${h}h ${min}m';
    if (h > 0) return '${h}h';
    if (min > 0) return '${min}m';
  }
  final diff = end.difference(start);
  final h = diff.inHours.abs();
  final min = diff.inMinutes.remainder(60).abs();
  if (h > 0 && min > 0) return '${h}h ${min}m';
  if (h > 0) return '${h}h';
  if (min > 0) return '${min}m';
  return '1h';
}
