import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a geographic location with additional metadata
class LocationModel {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final DateTime? timestamp;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.timestamp,
  });

  /// Create from Firestore GeoPoint
  factory LocationModel.fromGeoPoint(GeoPoint geoPoint, {Map<String, dynamic>? metadata}) {
    return LocationModel(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      address: metadata?['address'],
      city: metadata?['city'],
      state: metadata?['state'],
      country: metadata?['country'],
      postalCode: metadata?['postalCode'],
      timestamp: metadata?['timestamp'] != null
          ? (metadata!['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create from JSON/Map
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }

  /// Convert to Firestore GeoPoint
  GeoPoint toGeoPoint() {
    return GeoPoint(latitude, longitude);
  }

  /// Convert to JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  /// Convert to Firestore format with metadata
  Map<String, dynamic> toFirestore() {
    return {
      'location': toGeoPoint(),
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }

  /// Calculate distance to another location in kilometers using Haversine formula
  double distanceTo(LocationModel other) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    final double lat1Rad = _toRadians(latitude);
    final double lat2Rad = _toRadians(other.latitude);
    final double deltaLat = _toRadians(other.latitude - latitude);
    final double deltaLng = _toRadians(other.longitude - longitude);

    final double a = _haversine(deltaLat) +
        _haversine(deltaLng) * _cos(lat1Rad) * _cos(lat2Rad);
    final double c = 2 * _asin(_sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180.0;
  double _haversine(double value) => _pow(_sin(value / 2), 2);
  double _sin(double value) => _dartMath.sin(value);
  double _cos(double value) => _dartMath.cos(value);
  double _asin(double value) => _dartMath.asin(value);
  double _sqrt(double value) => _dartMath.sqrt(value);
  double _pow(double base, int exp) => _dartMath.pow(base, exp).toDouble();

  static final _dartMath = _DartMath();

  /// Get formatted address string
  String get formattedAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  /// Get short address (city, state)
  String get shortAddress {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  /// Check if location is valid
  bool get isValid => 
      latitude >= -90 && latitude <= 90 && 
      longitude >= -180 && longitude <= 180;

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    DateTime? timestamp,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() {
    return 'LocationModel(lat: $latitude, lng: $longitude, address: $address)';
  }
}

/// Simple math helper class to avoid importing dart:math directly
class _DartMath {
  double sin(double radians) {
    // Taylor series approximation for sin
    double result = radians;
    double term = radians;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double cos(double radians) {
    return sin(radians + 1.5707963267948966); // sin(x + π/2)
  }

  double sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }

  double asin(double value) {
    if (value.abs() > 1) return double.nan;
    // Taylor series approximation for asin
    double result = value;
    double term = value;
    for (int i = 1; i <= 15; i++) {
      term *= value * value * (2 * i - 1) * (2 * i - 1) / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  num pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
