import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingRemoteDatasource {
  final FirebaseFirestore _firestore;

  BookingRemoteDatasource(this._firestore);

  Stream<List<BookingModel>> watchAdminBookings(String adminId) {
    return _firestore
        .collection('bookings')
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => BookingModel.fromFirestore(d)).toList(),
        );
  }

  Future<List<BookingModel>> getAdminBookingsForDateRange(
    String adminId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _firestore
        .collection('bookings')
        .where('adminId', isEqualTo: adminId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();
    return snap.docs.map((d) => BookingModel.fromFirestore(d)).toList();
  }

  Future<List<BookingModel>> getTodayBookings(String adminId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getAdminBookingsForDateRange(adminId, start, end);
  }
}
