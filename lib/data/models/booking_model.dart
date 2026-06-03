import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  final String adminId;
  final String groundId;
  final String groundName;
  final String slotId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double amount;
  final String paymentStatus; // pending/paid/failed/refunded
  final String bookingStatus; // upcoming/completed/cancelled
  final String razorpayPaymentId;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.adminId,
    required this.groundId,
    required this.groundName,
    required this.slotId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.amount,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.razorpayPaymentId,
    required this.createdAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      adminId: data['adminId'] ?? '',
      groundId: data['groundId'] ?? '',
      groundName: data['groundName'] ?? '',
      slotId: data['slotId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paymentStatus: data['paymentStatus'] ?? 'pending',
      bookingStatus: data['bookingStatus'] ?? 'upcoming',
      razorpayPaymentId: data['razorpayPaymentId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'adminId': adminId,
    'groundId': groundId,
    'groundName': groundName,
    'slotId': slotId,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'amount': amount,
    'paymentStatus': paymentStatus,
    'bookingStatus': bookingStatus,
    'razorpayPaymentId': razorpayPaymentId,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
