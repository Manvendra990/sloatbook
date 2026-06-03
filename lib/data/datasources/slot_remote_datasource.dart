import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/slot_model.dart';

class SlotRemoteDatasource {
  final FirebaseFirestore _firestore;

  SlotRemoteDatasource(this._firestore);

  Stream<List<SlotModel>> watchSlotsForGround(String groundId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _firestore
        .collection('slots')
        .where('groundId', isEqualTo: groundId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => SlotModel.fromFirestore(d)).toList(),
        );
  }

  Future<void> addSlot(SlotModel slot) async {
    await _firestore.collection('slots').add(slot.toMap());
  }

  Future<void> bulkAddSlots(List<SlotModel> slots) async {
    final batch = _firestore.batch();
    for (final slot in slots) {
      final ref = _firestore.collection('slots').doc();
      batch.set(ref, slot.toMap());
    }
    await batch.commit();
  }

  Future<void> updateSlotStatus(String slotId, String status) async {
    await _firestore.collection('slots').doc(slotId).update({'status': status});
  }

  Future<void> updateSlotPrice(String slotId, double price) async {
    await _firestore.collection('slots').doc(slotId).update({'price': price});
  }

  Future<void> deleteSlot(String slotId) async {
    await _firestore.collection('slots').doc(slotId).delete();
  }
}
