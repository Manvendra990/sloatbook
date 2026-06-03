import 'package:cloud_firestore/cloud_firestore.dart';

class PricingModel {
  final double morning;
  final double afternoon;
  final double evening;
  final double weekend;

  const PricingModel({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.weekend,
  });

  factory PricingModel.fromMap(Map<String, dynamic> map) => PricingModel(
    morning: (map['morning'] ?? 0).toDouble(),
    afternoon: (map['afternoon'] ?? 0).toDouble(),
    evening: (map['evening'] ?? 0).toDouble(),
    weekend: (map['weekend'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'morning': morning,
    'afternoon': afternoon,
    'evening': evening,
    'weekend': weekend,
  };
}

class GroundModel {
  final String id;
  final String adminId;
  final String name;
  final String sportType;
  final String city;
  final String location;
  final double latitude;
  final double longitude;
  final List<String> images;
  final List<String> amenities;
  final String rules;
  final String status; // pending/approved/rejected/active/inactive
  final PricingModel pricing;
  final DateTime createdAt;

  const GroundModel({
    required this.id,
    required this.adminId,
    required this.name,
    required this.sportType,
    required this.city,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.amenities,
    required this.rules,
    required this.status,
    required this.pricing,
    required this.createdAt,
  });

  factory GroundModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroundModel(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      name: data['name'] ?? '',
      sportType: data['sportType'] ?? '',
      city: data['city'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      images: List<String>.from(data['images'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      rules: data['rules'] ?? '',
      status: data['status'] ?? 'pending',
      pricing: PricingModel.fromMap(data['pricing'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'adminId': adminId,
    'name': name,
    'sportType': sportType,
    'city': city,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'images': images,
    'amenities': amenities,
    'rules': rules,
    'status': status,
    'pricing': pricing.toMap(),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  GroundModel copyWith({
    String? name,
    String? sportType,
    String? city,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? images,
    List<String>? amenities,
    String? rules,
    String? status,
    PricingModel? pricing,
  }) => GroundModel(
    id: id,
    adminId: adminId,
    name: name ?? this.name,
    sportType: sportType ?? this.sportType,
    city: city ?? this.city,
    location: location ?? this.location,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    images: images ?? this.images,
    amenities: amenities ?? this.amenities,
    rules: rules ?? this.rules,
    status: status ?? this.status,
    pricing: pricing ?? this.pricing,
    createdAt: createdAt,
  );
}
