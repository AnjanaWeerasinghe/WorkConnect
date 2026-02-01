import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/location_model.dart';
import '../../core/services/location_service.dart';

/// Repository for managing location data with Firestore
class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  /// Update worker's current location
  Future<bool> updateWorkerLocation(String workerId, LocationModel location) async {
    try {
      await _firestore.collection('workers').doc(workerId).update({
        'location': location.toGeoPoint(),
        'address': location.address,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating worker location: $e');
      return false;
    }
  }

  /// Get worker's location
  Future<LocationModel?> getWorkerLocation(String workerId) async {
    try {
      final doc = await _firestore.collection('workers').doc(workerId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['location'] == null) return null;

      final geoPoint = data['location'] as GeoPoint;
      return LocationModel.fromGeoPoint(geoPoint, metadata: {
        'address': data['address'],
      });
    } catch (e) {
      print('Error getting worker location: $e');
      return null;
    }
  }

  /// Find workers within a radius (in kilometers)
  Future<List<WorkerWithLocation>> findNearbyWorkers({
    required LocationModel center,
    required double radiusKm,
    String? serviceType,
    int limit = 20,
  }) async {
    try {
      // Calculate bounding box for initial query
      final bounds = _calculateBoundingBox(center, radiusKm);

      Query query = _firestore
          .collection('workers')
          .where('isOnline', isEqualTo: true)
          .where('isVerified', isEqualTo: true);

      if (serviceType != null) {
        query = query.where('skills', arrayContains: serviceType);
      }

      final snapshot = await query.limit(limit * 2).get(); // Get extra for filtering

      final workers = <WorkerWithLocation>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final geoPoint = data['location'] as GeoPoint?;

        if (geoPoint == null) continue;

        final workerLocation = LocationModel(
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
          address: data['address'],
        );

        // Filter by actual distance (more accurate than bounding box)
        final distance = _locationService.calculateDistance(center, workerLocation);
        if (distance <= radiusKm) {
          workers.add(WorkerWithLocation(
            workerId: doc.id,
            userId: data['userId'] ?? '',
            skills: List<String>.from(data['skills'] ?? []),
            bio: data['bio'] ?? '',
            hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
            avgRating: (data['avgRating'] ?? 0.0).toDouble(),
            ratingCount: data['ratingCount'] ?? 0,
            location: workerLocation,
            distance: distance,
          ));
        }
      }

      // Sort by distance
      workers.sort((a, b) => a.distance.compareTo(b.distance));

      return workers.take(limit).toList();
    } catch (e) {
      print('Error finding nearby workers: $e');
      return [];
    }
  }

  /// Get job location
  Future<LocationModel?> getJobLocation(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['location'] == null) return null;

      final geoPoint = data['location'] as GeoPoint;
      return LocationModel(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
        address: data['address'],
      );
    } catch (e) {
      print('Error getting job location: $e');
      return null;
    }
  }

  /// Stream worker location updates
  Stream<LocationModel?> streamWorkerLocation(String workerId) {
    return _firestore
        .collection('workers')
        .doc(workerId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null || data['location'] == null) return null;

      final geoPoint = data['location'] as GeoPoint;
      return LocationModel(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
        address: data['address'],
      );
    });
  }

  /// Save location history for a worker
  Future<bool> saveLocationHistory(
    String workerId,
    LocationModel location,
  ) async {
    try {
      await _firestore
          .collection('workers')
          .doc(workerId)
          .collection('locationHistory')
          .add({
        'location': location.toGeoPoint(),
        'address': location.address,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error saving location history: $e');
      return false;
    }
  }

  /// Get location history for a worker
  Future<List<LocationModel>> getLocationHistory(
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('workers')
          .doc(workerId)
          .collection('locationHistory')
          .orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final geoPoint = data['location'] as GeoPoint;
        return LocationModel(
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
          address: data['address'],
          timestamp: data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    } catch (e) {
      print('Error getting location history: $e');
      return [];
    }
  }

  /// Calculate bounding box for geospatial queries
  _BoundingBox _calculateBoundingBox(LocationModel center, double radiusKm) {
    // Approximate degrees per km
    const double latDegPerKm = 1 / 111.0;
    final double lngDegPerKm = 1 / (111.0 * _cos(center.latitude * 3.14159 / 180));

    final double latDelta = radiusKm * latDegPerKm;
    final double lngDelta = radiusKm * lngDegPerKm;

    return _BoundingBox(
      minLat: center.latitude - latDelta,
      maxLat: center.latitude + latDelta,
      minLng: center.longitude - lngDelta,
      maxLng: center.longitude + lngDelta,
    );
  }

  double _cos(double radians) {
    // Simple cosine approximation
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }
}

/// Helper class for bounding box calculations
class _BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  _BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

/// Model for worker with location and distance
class WorkerWithLocation {
  final String workerId;
  final String userId;
  final List<String> skills;
  final String bio;
  final double hourlyRate;
  final double avgRating;
  final int ratingCount;
  final LocationModel location;
  final double distance; // Distance in km

  WorkerWithLocation({
    required this.workerId,
    required this.userId,
    required this.skills,
    required this.bio,
    required this.hourlyRate,
    required this.avgRating,
    required this.ratingCount,
    required this.location,
    required this.distance,
  });

  /// Get formatted distance string
  String get formattedDistance {
    if (distance < 1) {
      return '${(distance * 1000).toInt()} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }
}
