import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/worker_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/star_rating_widget.dart';

class WorkerListScreen extends StatefulWidget {
  final String? serviceFilter;
  final bool emergencyOnly;

  const WorkerListScreen({
    Key? key, 
    this.serviceFilter,
    this.emergencyOnly = false,
  }) : super(key: key);

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // Set initial category filter if provided
    if (widget.serviceFilter != null) {
      _selectedCategory = widget.serviceFilter!;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      Query query = _firestore.collection(AppConstants.workersCollection);

      if (_selectedCategory != 'All') {
        query = query.where('skills', arrayContains: _selectedCategory);
      }

      final QuerySnapshot snapshot = await query.get();
      
      List<Map<String, dynamic>> workers = [];
      
      for (var doc in snapshot.docs) {
        final worker = WorkerModel.fromFirestore(doc);
        
        // Get user details
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(worker.userId)
            .get();
        
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          
          // Calculate distance if both user and worker have location
          double? distance;
          if (_currentPosition != null && worker.location != null) {
            distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              worker.location!.latitude,
              worker.location!.longitude,
            ) / 1000; // Convert to kilometers
          }
          
          workers.add({
            'worker': worker,
            'user': user,
            'distance': distance,
          });
        }
      }

      // Sort by distance if available, otherwise by rating
      workers.sort((a, b) {
        if (a['distance'] != null && b['distance'] != null) {
          return a['distance'].compareTo(b['distance']);
        }
        return b['worker'].avgRating.compareTo(a['worker'].avgRating);
      });

      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading workers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Workers'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Category Filter
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: AppConstants.serviceCategories.length + 1,
              itemBuilder: (context, index) {
                final category = index == 0 ? 'All' : AppConstants.serviceCategories[index - 1];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _isLoading = true;
                      });
                      _loadWorkers();
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),

          // Workers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _workers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No workers found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _workers.length,
                        itemBuilder: (context, index) {
                          final workerData = _workers[index];
                          final worker = workerData['worker'] as WorkerModel;
                          final user = workerData['user'] as UserModel;
                          final distance = workerData['distance'] as double?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                _showWorkerDetails(context, worker, user);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.orange[100],
                                          backgroundImage: user.profileImageUrl != null
                                              ? NetworkImage(user.profileImageUrl!)
                                              : null,
                                          child: user.profileImageUrl == null
                                              ? const Icon(Icons.person, color: Colors.orange, size: 35)
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                worker.skills.take(2).join(', '),
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  RatingDisplay(
                                                    rating: worker.avgRating,
                                                    reviewCount: worker.ratingCount,
                                                    starSize: 16,
                                                  ),
                                                  if (distance != null) ...[
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${distance.toStringAsFixed(1)} km',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '\$${worker.hourlyRate.toStringAsFixed(0)}/hr',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: worker.isOnline ? Colors.green : Colors.grey,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                worker.isOnline ? 'Online' : 'Offline',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (worker.bio.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        worker.bio,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showWorkerDetails(BuildContext context, WorkerModel worker, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.orange[100],
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? const Icon(Icons.person, color: Colors.orange, size: 45)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RatingDisplay(
                          rating: worker.avgRating,
                          reviewCount: worker.ratingCount,
                          starSize: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${worker.hourlyRate.toStringAsFixed(0)}/hour',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Skills
              Text(
                'Skills',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: worker.skills
                    .map((skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Colors.orange[100],
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),

              // Bio
              if (worker.bio.isNotEmpty) ...[
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  worker.bio,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],

              // Stats
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '${worker.totalJobs}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text('Jobs Completed'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              worker.avgRating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text('Average Rating'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Contact Button
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement contact functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact feature coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Contact Worker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}