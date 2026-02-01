import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../data/models/worker_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/location_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';

/// Screen showing workers on a map for customers to find nearby workers
class WorkersMapScreen extends StatefulWidget {
  final String? serviceFilter;
  final LocationModel? initialLocation;

  const WorkersMapScreen({
    super.key,
    this.serviceFilter,
    this.initialLocation,
  });

  @override
  State<WorkersMapScreen> createState() => _WorkersMapScreenState();
}

class _WorkersMapScreenState extends State<WorkersMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  
  GoogleMapController? _mapController;
  LocationModel? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  
  List<Map<String, dynamic>> _nearbyWorkers = [];
  Map<String, dynamic>? _selectedWorker;
  
  bool _isLoading = true;
  String _selectedCategory = 'All';
  double _searchRadius = 10.0; // km

  StreamSubscription? _workersSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.serviceFilter != null) {
      _selectedCategory = widget.serviceFilter!;
    }
    _initializeMap();
  }

  @override
  void dispose() {
    _workersSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    // Get current location
    if (widget.initialLocation != null) {
      _currentLocation = widget.initialLocation;
    } else {
      final result = await _locationService.getCurrentLocation();
      if (result.isSuccess && result.data != null) {
        _currentLocation = result.data;
      }
    }

    // Default to San Francisco if no location
    _currentLocation ??= LocationModel(
      latitude: 37.7749,
      longitude: -122.4194,
    );

    _loadNearbyWorkers();
  }

  Future<void> _loadNearbyWorkers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore
          .collection(AppConstants.workersCollection)
          .where('isOnline', isEqualTo: true);

      if (_selectedCategory != 'All') {
        query = query.where('skills', arrayContains: _selectedCategory);
      }

      final snapshot = await query.get();
      
      List<Map<String, dynamic>> workers = [];
      Set<Marker> markers = {};

      // Add current location marker
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      for (var doc in snapshot.docs) {
        final worker = WorkerModel.fromFirestore(doc);
        
        if (worker.location == null) continue;

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          worker.location!.latitude,
          worker.location!.longitude,
        ) / 1000;

        // Only include workers within search radius
        if (distance > _searchRadius) continue;

        // Get user details
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(worker.userId)
            .get();

        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          
          final workerData = {
            'worker': worker,
            'user': user,
            'distance': distance,
          };
          
          workers.add(workerData);

          // Add worker marker
          markers.add(
            Marker(
              markerId: MarkerId(worker.id),
              position: LatLng(worker.location!.latitude, worker.location!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                worker.isVerified ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: user.name,
                snippet: '${worker.skills.join(", ")} • ${distance.toStringAsFixed(1)} km',
              ),
              onTap: () {
                setState(() {
                  _selectedWorker = workerData;
                });
              },
            ),
          );
        }
      }

      // Sort by distance
      workers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      // Add search radius circle
      Set<Circle> circles = {
        Circle(
          circleId: const CircleId('search_radius'),
          center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          radius: _searchRadius * 1000, // Convert to meters
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue.withOpacity(0.5),
          strokeWidth: 2,
        ),
      };

      setState(() {
        _nearbyWorkers = workers;
        _markers = markers;
        _circles = circles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          13,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Workers Near You'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyWorkers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Service Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          items: ['All', ...AppConstants.serviceCategories].map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                            });
                            _loadNearbyWorkers();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Radius selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radar, size: 18, color: Colors.blue),
                            const SizedBox(width: 4),
                            DropdownButton<double>(
                              value: _searchRadius,
                              underline: const SizedBox(),
                              isDense: true,
                              items: [5.0, 10.0, 20.0, 50.0].map((radius) {
                                return DropdownMenuItem(
                                  value: radius,
                                  child: Text('${radius.toInt()} km'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _searchRadius = value!;
                                });
                                _loadNearbyWorkers();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _currentLocation!.latitude,
                            _currentLocation!.longitude,
                          ),
                          zoom: 12,
                        ),
                        onMapCreated: _onMapCreated,
                        markers: _markers,
                        circles: _circles,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                      // My location button
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'my_location',
                          backgroundColor: Colors.white,
                          onPressed: _centerOnCurrentLocation,
                          child: const Icon(Icons.my_location, color: Colors.blue),
                        ),
                      ),
                      // Workers count badge
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              const Icon(Icons.person, size: 18, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '${_nearbyWorkers.length} workers nearby',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Workers list
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _nearbyWorkers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No workers found nearby',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchRadius = _searchRadius * 2;
                                  });
                                  _loadNearbyWorkers();
                                },
                                child: const Text('Expand search area'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _nearbyWorkers.length,
                          itemBuilder: (context, index) {
                            final data = _nearbyWorkers[index];
                            final worker = data['worker'] as WorkerModel;
                            final user = data['user'] as UserModel;
                            final distance = data['distance'] as double;

                            return _buildWorkerCard(worker, user, distance);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildWorkerCard(WorkerModel worker, UserModel user, double distance) {
    final isSelected = _selectedWorker != null && 
                       (_selectedWorker!['worker'] as WorkerModel).id == worker.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWorker = {'worker': worker, 'user': user, 'distance': distance};
        });
        // Center map on this worker
        if (worker.location != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(worker.location!.latitude, worker.location!.longitude),
            ),
          );
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'W',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (worker.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, size: 14, color: Colors.green),
                            ),
                        ],
                      ),
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Skills
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: worker.skills.take(2).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            // Rating and rate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      worker.avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ' (${worker.ratingCount})',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Text(
                  '\$${worker.hourlyRate.toStringAsFixed(0)}/hr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Contact button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showWorkerDetails(worker, user, distance);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkerDetails(WorkerModel worker, UserModel user, double distance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'W',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (worker.isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.verified, color: Colors.green),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(1)} km away',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats
              Row(
                children: [
                  _buildStatCard(Icons.star, worker.avgRating.toStringAsFixed(1), 'Rating', Colors.amber),
                  const SizedBox(width: 12),
                  _buildStatCard(Icons.work, '${worker.totalJobs}', 'Jobs', Colors.blue),
                  const SizedBox(width: 12),
                  _buildStatCard(Icons.attach_money, '\$${worker.hourlyRate.toInt()}', '/hour', Colors.green),
                ],
              ),
              const SizedBox(height: 20),

              // Skills
              const Text(
                'Skills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: worker.skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      skill,
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Bio
              if (worker.bio.isNotEmpty) ...[
                const Text(
                  'About',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  worker.bio,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
              ],

              // Address
              if (worker.address != null) ...[
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        worker.address!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Contact buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement call functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Call feature coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to booking page
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking feature coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Book Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
