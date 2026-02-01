import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/location_model.dart';
import '../../core/services/location_service.dart';

/// A customizable Google Maps widget with common functionality
class GoogleMapWidget extends StatefulWidget {
  /// Initial camera position
  final LocationModel? initialLocation;

  /// Whether to show user's current location
  final bool showMyLocation;

  /// Whether to show the location button
  final bool showMyLocationButton;

  /// Custom markers to display
  final Set<Marker>? markers;

  /// Custom polylines (routes)
  final Set<Polyline>? polylines;

  /// Custom circles (radius indicators)
  final Set<Circle>? circles;

  /// Map type (normal, satellite, terrain, hybrid)
  final MapType mapType;

  /// Callback when map is created
  final Function(GoogleMapController)? onMapCreated;

  /// Callback when map is tapped
  final Function(LatLng)? onTap;

  /// Callback when map is long pressed
  final Function(LatLng)? onLongPress;

  /// Callback when camera moves
  final Function(CameraPosition)? onCameraMove;

  /// Callback when camera stops moving
  final VoidCallback? onCameraIdle;

  /// Initial zoom level
  final double initialZoom;

  /// Minimum zoom level
  final double minZoom;

  /// Maximum zoom level
  final double maxZoom;

  /// Whether to enable zoom gestures
  final bool zoomGesturesEnabled;

  /// Whether to enable scroll gestures
  final bool scrollGesturesEnabled;

  /// Whether to enable rotate gestures
  final bool rotateGesturesEnabled;

  /// Whether to enable tilt gestures
  final bool tiltGesturesEnabled;

  /// Padding for the map
  final EdgeInsets padding;

  const GoogleMapWidget({
    super.key,
    this.initialLocation,
    this.showMyLocation = true,
    this.showMyLocationButton = true,
    this.markers,
    this.polylines,
    this.circles,
    this.mapType = MapType.normal,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onCameraMove,
    this.onCameraIdle,
    this.initialZoom = 15.0,
    this.minZoom = 1.0,
    this.maxZoom = 20.0,
    this.zoomGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _controller;
  final LocationService _locationService = LocationService();
  LatLng _defaultLocation = const LatLng(37.7749, -122.4194); // San Francisco default
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      _defaultLocation = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
    } else {
      final result = await _locationService.getCurrentLocation(includeAddress: false);
      if (result.isSuccess && result.data != null) {
        _defaultLocation = LatLng(
          result.data!.latitude,
          result.data!.longitude,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _defaultLocation,
        zoom: widget.initialZoom,
      ),
      mapType: widget.mapType,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: widget.showMyLocationButton,
      markers: widget.markers ?? {},
      polylines: widget.polylines ?? {},
      circles: widget.circles ?? {},
      zoomGesturesEnabled: widget.zoomGesturesEnabled,
      scrollGesturesEnabled: widget.scrollGesturesEnabled,
      rotateGesturesEnabled: widget.rotateGesturesEnabled,
      tiltGesturesEnabled: widget.tiltGesturesEnabled,
      minMaxZoomPreference: MinMaxZoomPreference(widget.minZoom, widget.maxZoom),
      padding: widget.padding,
      onMapCreated: (controller) {
        _controller = controller;
        widget.onMapCreated?.call(controller);
      },
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
    );
  }
}

/// A widget for displaying worker locations on a map
class WorkerMapWidget extends StatefulWidget {
  /// The center location (usually user's location)
  final LocationModel centerLocation;

  /// List of workers with their locations
  final List<WorkerMarkerData> workers;

  /// Callback when a worker marker is tapped
  final Function(String workerId)? onWorkerTapped;

  /// Radius to show (in km)
  final double? radiusKm;

  /// Radius circle color
  final Color radiusColor;

  const WorkerMapWidget({
    super.key,
    required this.centerLocation,
    required this.workers,
    this.onWorkerTapped,
    this.radiusKm,
    this.radiusColor = const Color(0x304CAF50),
  });

  @override
  State<WorkerMapWidget> createState() => _WorkerMapWidgetState();
}

class _WorkerMapWidgetState extends State<WorkerMapWidget> {
  GoogleMapController? _controller;

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add center marker (user location)
    markers.add(Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(
        widget.centerLocation.latitude,
        widget.centerLocation.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Your Location'),
    ));

    // Add worker markers
    for (final worker in widget.workers) {
      markers.add(Marker(
        markerId: MarkerId(worker.workerId),
        position: LatLng(
          worker.location.latitude,
          worker.location.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: worker.name,
          snippet: worker.snippet,
        ),
        onTap: () => widget.onWorkerTapped?.call(worker.workerId),
      ));
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    if (widget.radiusKm == null) return {};

    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(
          widget.centerLocation.latitude,
          widget.centerLocation.longitude,
        ),
        radius: widget.radiusKm! * 1000, // Convert km to meters
        fillColor: widget.radiusColor,
        strokeColor: widget.radiusColor.withOpacity(0.8),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMapWidget(
      initialLocation: widget.centerLocation,
      markers: _buildMarkers(),
      circles: _buildCircles(),
      onMapCreated: (controller) {
        _controller = controller;
        _fitBounds();
      },
    );
  }

  void _fitBounds() {
    if (_controller == null || widget.workers.isEmpty) return;

    final bounds = _calculateBounds();
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  LatLngBounds _calculateBounds() {
    double minLat = widget.centerLocation.latitude;
    double maxLat = widget.centerLocation.latitude;
    double minLng = widget.centerLocation.longitude;
    double maxLng = widget.centerLocation.longitude;

    for (final worker in widget.workers) {
      if (worker.location.latitude < minLat) minLat = worker.location.latitude;
      if (worker.location.latitude > maxLat) maxLat = worker.location.latitude;
      if (worker.location.longitude < minLng) minLng = worker.location.longitude;
      if (worker.location.longitude > maxLng) maxLng = worker.location.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

/// Data class for worker markers
class WorkerMarkerData {
  final String workerId;
  final String name;
  final String? snippet;
  final LocationModel location;

  WorkerMarkerData({
    required this.workerId,
    required this.name,
    this.snippet,
    required this.location,
  });
}

/// A widget displaying a small static map preview
class MapPreviewWidget extends StatelessWidget {
  final LocationModel location;
  final double height;
  final double width;
  final VoidCallback? onTap;
  final double zoom;

  const MapPreviewWidget({
    super.key,
    required this.location,
    this.height = 150,
    this.width = double.infinity,
    this.onTap,
    this.zoom = 15,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(location.latitude, location.longitude),
                zoom: zoom,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('location'),
                  position: LatLng(location.latitude, location.longitude),
                ),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              liteModeEnabled: true,
            ),
            if (onTap != null)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A widget showing location with address text
class LocationDisplayWidget extends StatelessWidget {
  final LocationModel location;
  final bool showMap;
  final double mapHeight;
  final VoidCallback? onMapTap;
  final VoidCallback? onAddressTap;

  const LocationDisplayWidget({
    super.key,
    required this.location,
    this.showMap = true,
    this.mapHeight = 120,
    this.onMapTap,
    this.onAddressTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMap)
          MapPreviewWidget(
            location: location,
            height: mapHeight,
            onTap: onMapTap,
          ),
        if (showMap) const SizedBox(height: 8),
        GestureDetector(
          onTap: onAddressTap,
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location.formattedAddress,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
