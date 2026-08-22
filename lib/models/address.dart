class Address {
  final String id;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final bool isDefault;

  Address({
    required this.id,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.isDefault = false,
  });

  /// From a Supabase `addresses` row.
  factory Address.fromRow(Map<String, dynamic> row) => Address(
    id: row['id'] as String,
    street: row['street'] as String? ?? '',
    city: row['city'] as String? ?? '',
    state: row['state'] as String? ?? '',
    zipCode: row['zip'] as String? ?? '',
    latitude: (row['lat'] as num?)?.toDouble(),
    longitude: (row['lng'] as num?)?.toDouble(),
    createdAt: row['created_at'] != null
        ? DateTime.tryParse(row['created_at'] as String)
        : null,
    isDefault: row['is_default'] as bool? ?? false,
  );

  Map<String, dynamic> toRow() => {
    'street': street,
    'city': city,
    'state': state,
    'zip': zipCode,
    'lat': latitude,
    'lng': longitude,
    'is_default': isDefault,
  };
}
