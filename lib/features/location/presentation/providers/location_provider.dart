import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/location_model.dart';
import '../../../../data/repositories/location_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/widgets/map_widgets.dart';

/// Provider for managing location state throughout the app
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final LocationRepository _locationRepository = LocationRepository();

  LocationModel? _currentLocation;
  List<WorkerWithLocation> _nearbyWorkers = [];
  bool _isLoading = false;
  String? _error;
  double _searchRadius = 10.0; // Default 10 km

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  List<WorkerWithLocation> get nearbyWorkers => _nearbyWorkers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get searchRadius => _searchRadius;
  bool get hasLocation => _currentLocation != null;

  /// Initialize location tracking
  Future<void> initializeLocation() async {
    _setLoading(true);
    _error = null;

    final result = await _locationService.getCurrentLocation();
    
    if (result.isSuccess && result.data != null) {
      _currentLocation = result.data;
    } else {
      _error = result.error;
    }

    _setLoading(false);
  }

  /// Update current location
  Future<void> updateCurrentLocation() async {
    final result = await _locationService.getCurrentLocation();
    
    if (result.isSuccess && result.data != null) {
      _currentLocation = result.data;
      _error = null;
      notifyListeners();
    } else {
      _error = result.error;
      notifyListeners();
    }
  }

  /// Set a custom location
  void setLocation(LocationModel location) {
    _currentLocation = location;
    _error = null;
    notifyListeners();
  }

  /// Set search radius
  void setSearchRadius(double radiusKm) {
    _searchRadius = radiusKm;
    notifyListeners();
  }

  /// Find nearby workers
  Future<void> findNearbyWorkers({String? serviceType}) async {
    if (_currentLocation == null) {
      _error = 'Current location not available';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      _nearbyWorkers = await _locationRepository.findNearbyWorkers(
        center: _currentLocation!,
        radiusKm: _searchRadius,
        serviceType: serviceType,
      );
    } catch (e) {
      _error = 'Error finding nearby workers: $e';
    }

    _setLoading(false);
  }

  /// Update worker location (for workers)
  Future<bool> updateWorkerLocation(String workerId) async {
    if (_currentLocation == null) {
      await initializeLocation();
    }

    if (_currentLocation == null) {
      _error = 'Could not get current location';
      notifyListeners();
      return false;
    }

    return await _locationRepository.updateWorkerLocation(
      workerId,
      _currentLocation!,
    );
  }

  /// Start continuous location tracking
  Future<void> startTracking({int distanceFilter = 10}) async {
    final result = await _locationService.startLocationUpdates(
      distanceFilter: distanceFilter,
    );

    if (result.isSuccess) {
      _locationService.locationStream.listen((location) {
        _currentLocation = location;
        notifyListeners();
      });
    } else {
      _error = result.error;
      notifyListeners();
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _locationService.stopLocationUpdates();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}

/// Widget that provides location context to its children
class LocationProviderWidget extends StatelessWidget {
  final Widget child;

  const LocationProviderWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider()..initializeLocation(),
      child: child,
    );
  }
}

/// A widget that shows nearby workers on a map
class NearbyWorkersMapScreen extends StatefulWidget {
  final String? serviceType;
  final Function(WorkerWithLocation)? onWorkerSelected;

  const NearbyWorkersMapScreen({
    super.key,
    this.serviceType,
    this.onWorkerSelected,
  });

  @override
  State<NearbyWorkersMapScreen> createState() => _NearbyWorkersMapScreenState();
}

class _NearbyWorkersMapScreenState extends State<NearbyWorkersMapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<LocationProvider>();
    await provider.initializeLocation();
    await provider.findNearbyWorkers(serviceType: widget.serviceType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Workers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRadiusSettings,
          ),
        ],
      ),
      body: Consumer<LocationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.currentLocation == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null && provider.currentLocation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.currentLocation == null) {
            return const Center(
              child: Text('Unable to get current location'),
            );
          }

          return Stack(
            children: [
              WorkerMapWidget(
                centerLocation: provider.currentLocation!,
                workers: provider.nearbyWorkers
                    .map((w) => WorkerMarkerData(
                          workerId: w.workerId,
                          name: 'Worker',
                          snippet: '${w.formattedDistance} • ⭐ ${w.avgRating.toStringAsFixed(1)}',
                          location: w.location,
                        ))
                    .toList(),
                onWorkerTapped: (workerId) {
                  final worker = provider.nearbyWorkers.firstWhere(
                    (w) => w.workerId == workerId,
                  );
                  widget.onWorkerSelected?.call(worker);
                },
                radiusKm: provider.searchRadius,
              ),
              // Loading overlay
              if (provider.isLoading)
                Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              // Worker count indicator
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.nearbyWorkers.length} workers nearby',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRadiusSettings() {
    final provider = context.read<LocationProvider>();
    double tempRadius = provider.searchRadius;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Radius',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_searching),
                      Expanded(
                        child: Slider(
                          value: tempRadius,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '${tempRadius.toInt()} km',
                          onChanged: (value) {
                            setState(() {
                              tempRadius = value;
                            });
                          },
                        ),
                      ),
                      Text('${tempRadius.toInt()} km'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        provider.setSearchRadius(tempRadius);
                        provider.findNearbyWorkers(
                          serviceType: widget.serviceType,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
