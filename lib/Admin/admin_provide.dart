import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/datasources/ground_remote_datasource.dart';
import '../../data/datasources/slot_remote_datasource.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ground_model.dart';
import '../../data/models/slot_model.dart';

// ── Core Firebase providers ────────────────────────────────────────────────

final _firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final _storageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);

final currentAdminIdProvider = Provider<String>(
  (_) => FirebaseAuth.instance.currentUser!.uid,
);

// ── Datasource providers ───────────────────────────────────────────────────

final groundDatasourceProvider = Provider<GroundRemoteDatasource>(
  (ref) => GroundRemoteDatasource(
    ref.watch(_firestoreProvider),
    ref.watch(_storageProvider),
  ),
);

final bookingDatasourceProvider = Provider<BookingRemoteDatasource>(
  (ref) => BookingRemoteDatasource(ref.watch(_firestoreProvider)),
);

final slotDatasourceProvider = Provider<SlotRemoteDatasource>(
  (ref) => SlotRemoteDatasource(ref.watch(_firestoreProvider)),
);

// ── Grounds ────────────────────────────────────────────────────────────────

final adminGroundsProvider = StreamProvider<List<GroundModel>>((ref) {
  final adminId = ref.watch(currentAdminIdProvider);
  return ref.watch(groundDatasourceProvider).watchAdminGrounds(adminId);
});

final selectedGroundProvider = StateProvider<GroundModel?>((ref) => null);

// ── Bookings ───────────────────────────────────────────────────────────────

final adminBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final adminId = ref.watch(currentAdminIdProvider);
  return ref.watch(bookingDatasourceProvider).watchAdminBookings(adminId);
});

final bookingFilterProvider = StateProvider<String>(
  (ref) => 'all',
); // all/upcoming/completed/cancelled

final filteredBookingsProvider = Provider<AsyncValue<List<BookingModel>>>((
  ref,
) {
  final bookingsAsync = ref.watch(adminBookingsProvider);
  final filter = ref.watch(bookingFilterProvider);
  return bookingsAsync.whenData((list) {
    if (filter == 'all') return list;
    return list.where((b) => b.bookingStatus == filter).toList();
  });
});

// ── Slots ──────────────────────────────────────────────────────────────────

final slotDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final selectedGroundForSlotsProvider = StateProvider<String?>((ref) => null);

final slotsProvider = StreamProvider<List<SlotModel>>((ref) {
  final groundId = ref.watch(selectedGroundForSlotsProvider);
  final date = ref.watch(slotDateProvider);
  if (groundId == null) return const Stream.empty();
  return ref.watch(slotDatasourceProvider).watchSlotsForGround(groundId, date);
});

// ── Dashboard ──────────────────────────────────────────────────────────────

final todayBookingsProvider = FutureProvider<List<BookingModel>>((ref) {
  final adminId = ref.watch(currentAdminIdProvider);
  return ref.watch(bookingDatasourceProvider).getTodayBookings(adminId);
});

final revenueFilterProvider = StateProvider<String>(
  (ref) => 'monthly',
); // daily/weekly/monthly

final revenueDataProvider = FutureProvider.family<List<BookingModel>, String>((
  ref,
  filter,
) async {
  final adminId = ref.watch(currentAdminIdProvider);
  final now = DateTime.now();
  DateTime from;
  switch (filter) {
    case 'daily':
      from = DateTime(now.year, now.month, now.day);
      break;
    case 'weekly':
      from = now.subtract(const Duration(days: 7));
      break;
    default:
      from = DateTime(now.year, now.month, 1);
  }
  return ref
      .watch(bookingDatasourceProvider)
      .getAdminBookingsForDateRange(adminId, from, now);
});
