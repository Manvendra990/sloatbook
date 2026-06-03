import 'package:cloud_firestore/cloud_firestore.dart';

class SlotModel {
  final String id;
  final String groundId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double price;
  final String status; // available/booked/blocked

  const SlotModel({
    required this.id,
    required this.groundId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
  });

  factory SlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SlotModel(
      id: doc.id,
      groundId: data['groundId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      status: data['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toMap() => {
    'groundId': groundId,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'price': price,
    'status': status,
  };

  SlotModel copyWith({String? status, double? price}) => SlotModel(
    id: id,
    groundId: groundId,
    date: date,
    startTime: startTime,
    endTime: endTime,
    price: price ?? this.price,
    status: status ?? this.status,
  );

  bool get isAvailable => status == 'available';
  bool get isBooked => status == 'booked';
  bool get isBlocked => status == 'blocked';
}
