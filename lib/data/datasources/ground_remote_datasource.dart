import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/ground_model.dart';

class GroundRemoteDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  GroundRemoteDatasource(this._firestore, this._storage);

  Stream<List<GroundModel>> watchAdminGrounds(String adminId) {
    return _firestore
        .collection('grounds')
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => GroundModel.fromFirestore(d)).toList(),
        );
  }

  Future<GroundModel?> getGround(String groundId) async {
    final doc = await _firestore.collection('grounds').doc(groundId).get();
    if (!doc.exists) return null;
    return GroundModel.fromFirestore(doc);
  }

  Future<String> addGround(GroundModel ground) async {
    final ref = _firestore.collection('grounds').doc();
    await ref.set({...ground.toMap(), 'status': 'pending'});
    return ref.id;
  }

  Future<void> updateGround(String groundId, Map<String, dynamic> data) async {
    await _firestore.collection('grounds').doc(groundId).update(data);
  }

  Future<void> toggleGroundStatus(String groundId, bool isActive) async {
    await _firestore.collection('grounds').doc(groundId).update({
      'status': isActive ? 'active' : 'inactive',
    });
  }

  Future<List<String>> uploadGroundImages(
    String groundId,
    List<File> files,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final name = const Uuid().v4();
      final ref = _storage.ref('grounds/$groundId/$name.jpg');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> deleteGroundImage(String groundId, String imageUrl) async {
    await _storage.refFromURL(imageUrl).delete();
    await _firestore.collection('grounds').doc(groundId).update({
      'images': FieldValue.arrayRemove([imageUrl]),
    });
  }
}
