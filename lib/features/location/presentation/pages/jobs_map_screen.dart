import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../data/models/job_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/location_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';

/// Screen showing job requests on a map for workers to find nearby jobs
class JobsMapScreen extends StatefulWidget {
  final String? serviceFilter;
  final LocationModel? initialLocation;

  const JobsMapScreen({
    super.key,
    this.serviceFilter,
    this.initialLocation,
  });

  @override
  State<JobsMapScreen> createState() => _JobsMapScreenState();
}

class _JobsMapScreenState extends State<JobsMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  
  GoogleMapController? _mapController;
  LocationModel? _currentLocation;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  
  List<Map<String, dynamic>> _nearbyJobs = [];
  Map<String, dynamic>? _selectedJob;
  
  bool _isLoading = true;
  String _selectedCategory = 'All';
  double _searchRadius = 15.0; // km

  StreamSubscription? _jobsSubscription;

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
    _jobsSubscription?.cancel();
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

    // Update worker's location in database
    _updateWorkerLocation();
    
    _loadNearbyJobs();
  }

  Future<void> _updateWorkerLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentLocation != null) {
      try {
        await _firestore.collection(AppConstants.workersCollection).doc(user.uid).update({
          'location': GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
          'address': _currentLocation!.address,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      } catch (e) {
        print('Error updating worker location: $e');
      }
    }
  }

  Future<void> _loadNearbyJobs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Query for jobs with 'requested' status (open jobs)
      Query query = _firestore
          .collection(AppConstants.jobsCollection)
          .where('status', isEqualTo: AppConstants.jobStatusRequested);

      if (_selectedCategory != 'All') {
        query = query.where('serviceType', isEqualTo: _selectedCategory);
      }

      final snapshot = await query.get();
      
      List<Map<String, dynamic>> jobs = [];
      Set<Marker> markers = {};

      // Add current location marker (worker's position)
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      for (var doc in snapshot.docs) {
        final job = JobModel.fromFirestore(doc);

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          job.location.latitude,
          job.location.longitude,
        ) / 1000;

        // Only include jobs within search radius
        if (distance > _searchRadius) continue;

        // Get customer details
        final customerDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(job.customerId)
            .get();

        if (customerDoc.exists) {
          final customer = UserModel.fromFirestore(customerDoc);
          
          final jobData = {
            'job': job,
            'customer': customer,
            'distance': distance,
          };
          
          jobs.add(jobData);

          // Add job marker
          markers.add(
            Marker(
              markerId: MarkerId(job.id),
              position: LatLng(job.location.latitude, job.location.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: job.serviceType,
                snippet: '${job.address} • ${distance.toStringAsFixed(1)} km',
              ),
              onTap: () {
                setState(() {
                  _selectedJob = jobData;
                });
              },
            ),
          );
        }
      }

      // Sort by distance
      jobs.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      // Add search radius circle
      Set<Circle> circles = {
        Circle(
          circleId: const CircleId('search_radius'),
          center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          radius: _searchRadius * 1000, // Convert to meters
          fillColor: Colors.green.withOpacity(0.1),
          strokeColor: Colors.green.withOpacity(0.5),
          strokeWidth: 2,
        ),
      };

      setState(() {
        _nearbyJobs = jobs;
        _markers = markers;
        _circles = circles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading jobs: $e');
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

  Future<void> _acceptJob(JobModel job) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection(AppConstants.jobsCollection).doc(job.id).update({
        'workerId': user.uid,
        'status': AppConstants.jobStatusAccepted,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job accepted! The customer has been notified.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadNearbyJobs(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Jobs Near You'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyJobs,
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
                            labelText: 'Job Type',
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
                            _loadNearbyJobs();
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
                            const Icon(Icons.radar, size: 18, color: Colors.green),
                            const SizedBox(width: 4),
                            DropdownButton<double>(
                              value: _searchRadius,
                              underline: const SizedBox(),
                              isDense: true,
                              items: [5.0, 10.0, 15.0, 25.0, 50.0].map((radius) {
                                return DropdownMenuItem(
                                  value: radius,
                                  child: Text('${radius.toInt()} km'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _searchRadius = value!;
                                });
                                _loadNearbyJobs();
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
                          child: const Icon(Icons.my_location, color: Colors.green),
                        ),
                      ),
                      // Jobs count badge
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
                              const Icon(Icons.work, size: 18, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                '${_nearbyJobs.length} jobs available',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Jobs list
                Container(
                  height: 220,
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
                  child: _nearbyJobs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work_off, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No jobs found nearby',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchRadius = _searchRadius * 2;
                                  });
                                  _loadNearbyJobs();
                                },
                                child: const Text('Expand search area'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _nearbyJobs.length,
                          itemBuilder: (context, index) {
                            final data = _nearbyJobs[index];
                            final job = data['job'] as JobModel;
                            final customer = data['customer'] as UserModel;
                            final distance = data['distance'] as double;

                            return _buildJobCard(job, customer, distance);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildJobCard(JobModel job, UserModel customer, double distance) {
    final isSelected = _selectedJob != null && 
                       (_selectedJob!['job'] as JobModel).id == job.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedJob = {'job': job, 'customer': customer, 'distance': distance};
        });
        // Center map on this job
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(job.location.latitude, job.location.longitude),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade200,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getServiceColor(job.serviceType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getServiceIcon(job.serviceType),
                    color: _getServiceColor(job.serviceType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.serviceType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            // Customer info
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showJobDetails(job, customer, distance);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View & Accept', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDetails(JobModel job, UserModel customer, double distance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
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
              
              // Job Type Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getServiceColor(job.serviceType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getServiceIcon(job.serviceType),
                      color: _getServiceColor(job.serviceType),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.serviceType,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimeAgo(job.createdAt),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance & Location
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${distance.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            job.address,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Job Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  job.description,
                  style: TextStyle(color: Colors.grey[800], height: 1.4),
                ),
              ),
              const SizedBox(height: 20),

              // Customer Info
              const Text(
                'Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            customer.phone.isNotEmpty ? customer.phone : 'No phone provided',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Images if any
              if (job.imageUrls.isNotEmpty) ...[
                const Text(
                  'Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(job.imageUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Accept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptJob(job),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Accept This Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service.toLowerCase()) {
      case 'plumber':
      case 'plumbing':
        return Icons.plumbing;
      case 'electrician':
      case 'electrical':
        return Icons.electrical_services;
      case 'carpenter':
      case 'carpentry':
        return Icons.carpenter;
      case 'cleaner':
      case 'cleaning':
        return Icons.cleaning_services;
      case 'painter':
      case 'painting':
        return Icons.format_paint;
      case 'mechanic':
        return Icons.build;
      case 'technician':
        return Icons.engineering;
      case 'gardener':
        return Icons.grass;
      case 'ac repair':
        return Icons.ac_unit;
      case 'appliance repair':
        return Icons.kitchen;
      default:
        return Icons.work;
    }
  }

  Color _getServiceColor(String service) {
    switch (service.toLowerCase()) {
      case 'plumber':
      case 'plumbing':
        return Colors.blue;
      case 'electrician':
      case 'electrical':
        return Colors.amber.shade700;
      case 'carpenter':
      case 'carpentry':
        return Colors.brown;
      case 'cleaner':
      case 'cleaning':
        return Colors.green;
      case 'painter':
      case 'painting':
        return Colors.purple;
      case 'mechanic':
        return Colors.grey.shade700;
      case 'technician':
        return Colors.teal;
      case 'gardener':
        return Colors.lightGreen;
      case 'ac repair':
        return Colors.cyan;
      case 'appliance repair':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
