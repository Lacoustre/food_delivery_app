import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final Timestamp? createdAt; // ✅ Made nullable
  final bool isDefault;

  Address({
    required this.id,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    this.latitude,
    this.longitude,
    this.createdAt, // ✅ Accept null safely
    this.isDefault = false,
  });

  factory Address.fromMap(String id, Map<String, dynamic> data) => Address(
    id: id,
    street: data['street'] as String,
    city: data['city'] as String,
    state: data['state'] as String,
    zipCode: data['zipCode'] as String,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    createdAt: data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null, // ✅ Prevent crash if null or missing
    isDefault: data['isDefault'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'street': street,
    'city': city,
    'state': state,
    'zipCode': zipCode,
    'latitude': latitude,
    'longitude': longitude,
    'createdAt': Timestamp.now(), // Optional
    'isDefault': isDefault,
  };
}
