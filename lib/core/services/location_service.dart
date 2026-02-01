import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/location_model.dart';

/// Result class for location operations
class LocationResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  LocationResult.success(this.data)
      : error = null,
        isSuccess = true;

  LocationResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

/// Service for handling location-related operations
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<LocationModel> _locationController =
      StreamController<LocationModel>.broadcast();

  /// Stream of location updates
  Stream<LocationModel> get locationStream => _locationController.stream;

  /// Check and request location permissions
  Future<LocationResult<bool>> checkAndRequestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          'Location services are disabled. Please enable location services in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            'Location permission denied. Please grant location access to use this feature.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          'Location permissions are permanently denied. Please enable them in app settings.',
        );
      }

      return LocationResult.success(true);
    } catch (e) {
      return LocationResult.failure('Error checking location permission: $e');
    }
  }

  /// Get current location
  Future<LocationResult<LocationModel>> getCurrentLocation({
    bool includeAddress = true,
  }) async {
    try {
      final permissionResult = await checkAndRequestPermission();
      if (!permissionResult.isSuccess) {
        return LocationResult.failure(permissionResult.error);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      LocationModel location = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      if (includeAddress) {
        final addressResult = await getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (addressResult.isSuccess && addressResult.data != null) {
          location = addressResult.data!;
        }
      }

      return LocationResult.success(location);
    } catch (e) {
      return LocationResult.failure('Error getting current location: $e');
    }
  }

  /// Get last known location (faster, but may not be accurate)
  Future<LocationResult<LocationModel>> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return LocationResult.failure('No last known location available');
      }

      return LocationResult.success(LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (e) {
      return LocationResult.failure('Error getting last known location: $e');
    }
  }

  /// Get address from coordinates (reverse geocoding)
  Future<LocationResult<LocationModel>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return LocationResult.success(LocationModel(
          latitude: latitude,
          longitude: longitude,
        ));
      }

      final placemark = placemarks.first;
      
      // Build street address
      final addressParts = <String>[];
      if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
        addressParts.add(placemark.subThoroughfare!);
      }
      if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
        addressParts.add(placemark.thoroughfare!);
      }
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        addressParts.add(placemark.subLocality!);
      }

      return LocationResult.success(LocationModel(
        latitude: latitude,
        longitude: longitude,
        address: addressParts.isNotEmpty ? addressParts.join(', ') : null,
        city: placemark.locality,
        state: placemark.administrativeArea,
        country: placemark.country,
        postalCode: placemark.postalCode,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      // Return location without address if geocoding fails
      return LocationResult.success(LocationModel(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Get coordinates from address (forward geocoding)
  Future<LocationResult<LocationModel>> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return LocationResult.failure('No location found for the given address');
      }

      final location = locations.first;
      
      // Get full address details
      return getAddressFromCoordinates(location.latitude, location.longitude);
    } catch (e) {
      return LocationResult.failure('Error getting coordinates from address: $e');
    }
  }

  /// Start listening to location updates
  Future<LocationResult<bool>> startLocationUpdates({
    int distanceFilter = 10,
    Duration? interval,
  }) async {
    try {
      final permissionResult = await checkAndRequestPermission();
      if (!permissionResult.isSuccess) {
        return LocationResult.failure(permissionResult.error);
      }

      await stopLocationUpdates();

      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        timeLimit: interval,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          final addressResult = await getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          if (addressResult.isSuccess && addressResult.data != null) {
            _locationController.add(addressResult.data!);
          } else {
            _locationController.add(LocationModel(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
            ));
          }
        },
        onError: (error) {
          // Handle stream errors
          print('Location stream error: $error');
        },
      );

      return LocationResult.success(true);
    } catch (e) {
      return LocationResult.failure('Error starting location updates: $e');
    }
  }

  /// Stop listening to location updates
  Future<void> stopLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Calculate distance between two locations in kilometers
  double calculateDistance(LocationModel from, LocationModel to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ) / 1000; // Convert meters to kilometers
  }

  /// Calculate bearing between two locations in degrees
  double calculateBearing(LocationModel from, LocationModel to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Check if a location is within a certain radius of another location
  bool isWithinRadius(
    LocationModel center,
    LocationModel point,
    double radiusKm,
  ) {
    final distance = calculateDistance(center, point);
    return distance <= radiusKm;
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings for permission management
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Convert LocationModel to Firestore GeoPoint
  GeoPoint toGeoPoint(LocationModel location) {
    return location.toGeoPoint();
  }

  /// Convert Firestore GeoPoint to LocationModel
  LocationModel fromGeoPoint(GeoPoint geoPoint) {
    return LocationModel(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
  }

  /// Dispose of resources
  void dispose() {
    stopLocationUpdates();
    _locationController.close();
  }
}
