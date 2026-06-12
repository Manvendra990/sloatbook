import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/slot_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SlotRepository — all Firestore reads for the slot booking screen
// ─────────────────────────────────────────────────────────────────────────────
class SlotRepository {
  final _db = FirebaseFirestore.instance;

  // ── Ground data stream ─────────────────────────────────────────────────────
  Stream<DocumentSnapshot<Map<String, dynamic>>> groundStream(
    String groundId,
  ) => _db.collection('grounds').doc(groundId).snapshots();

  // ── Raw bookings stream for a ground (all dates) ───────────────────────────
  // We fetch ALL bookings for the ground and filter client-side by date.
  // This avoids needing a composite Firestore index on groundId + startTime.
  Stream<QuerySnapshot<Map<String, dynamic>>> bookingsStream(String groundId) =>
      _db
          .collection('admin_bookings')
          .where('groundId', isEqualTo: groundId)
          .snapshots();

  // ── Build the merged slot list for a given date ────────────────────────────
  //
  // Strategy:
  //   1. Generate all 18 hourly slots (5 AM – 10 PM) as 'available'.
  //   2. For each Firestore booking that falls on the selected date,
  //      find the matching hour slot and replace it with the booking data.
  //
  // This ensures the grid ALWAYS shows 18 slots regardless of how many
  // bookings exist, and booked slots are correctly marked.

  List<SlotModel> mergeSlots({
    required DateTime selectedDate,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs,
    required int pricePerHour,
  }) {
    final selectedDay = DateFormat('yyyy-MM-dd').format(selectedDate);

    final result =
        bookingDocs
            .where((doc) {
              final match = _matchesDate(doc.data(), selectedDay);

              print('MATCH => $match');
              print('DOC DATA => ${doc.data()}');

              return match;
            })
            .map((doc) {
              final slot = SlotModel.fromDoc(doc);

              print('SLOT => ${slot.label}');
              print('STATUS => ${slot.bookingStatus}');

              return slot;
            })
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    print('TOTAL SLOTS => ${result.length}');

    return result;
  }

  // ── Check if a Firestore booking doc falls on the selected date ───────────
  bool _matchesDate(Map<String, dynamic> data, String selectedDay) {
    if (data['slotDate'] is Timestamp) {
      final d = (data['slotDate'] as Timestamp).toDate();

      print(
        'SLOT DATE => ${DateFormat('yyyy-MM-dd').format(d)} | SELECTED => $selectedDay',
      );

      return DateFormat('yyyy-MM-dd').format(d) == selectedDay;
    }

    if (data['startTime'] is Timestamp) {
      final d = (data['startTime'] as Timestamp).toDate();

      return DateFormat('yyyy-MM-dd').format(d) == selectedDay;
    }

    return false;
  }
}
