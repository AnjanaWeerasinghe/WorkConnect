import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/worker_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/star_rating_widget.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  WorkerModel? _workerProfile;
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  Future<void> _loadWorkerProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user data
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          _userProfile = UserModel.fromFirestore(userDoc);

          // Get or create worker profile
          final workerQuery = await _firestore
              .collection(AppConstants.workersCollection)
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (workerQuery.docs.isNotEmpty) {
            _workerProfile = WorkerModel.fromFirestore(workerQuery.docs.first);
            _isOnline = _workerProfile!.isOnline;
          } else {
            // Create new worker profile
            await _createWorkerProfile(user.uid);
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading worker profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createWorkerProfile(String userId) async {
    try {
      final newWorker = WorkerModel(
        id: '',
        userId: userId,
        skills: [],
        bio: '',
        hourlyRate: 0.0,
        isOnline: false,
        certificationImages: [],
        isVerified: false,
        totalJobs: 0,
        avgRating: 0.0,
        ratingCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(AppConstants.workersCollection)
          .add(newWorker.toFirestore());

      _workerProfile = newWorker.copyWith(id: docRef.id);
    } catch (e) {
      print('Error creating worker profile: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_workerProfile == null) return;

    try {
      final newStatus = !_isOnline;
      
      await _firestore
          .collection(AppConstants.workersCollection)
          .doc(_workerProfile!.id)
          .update({
        'isOnline': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isOnline = newStatus;
        _workerProfile = _workerProfile!.copyWith(isOnline: newStatus);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'You are now online' : 'You are now offline'),
          backgroundColor: newStatus ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      print('Error updating online status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateLocation() async {
    if (_workerProfile == null) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        
        await _firestore
            .collection(AppConstants.workersCollection)
            .doc(_workerProfile!.id)
            .update({
          'location': GeoPoint(position.latitude, position.longitude),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating location'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_workerProfile == null || _userProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Worker Dashboard'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Error loading profile'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.toggle_on : Icons.toggle_off),
            onPressed: _toggleOnlineStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.orange[100],
                          backgroundImage: _userProfile!.profileImageUrl != null
                              ? NetworkImage(_userProfile!.profileImageUrl!)
                              : null,
                          child: _userProfile!.profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.orange, size: 45)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userProfile!.name,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              RatingDisplay(
                                rating: _workerProfile!.avgRating,
                                reviewCount: _workerProfile!.ratingCount,
                                starSize: 18,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isOnline ? 'Online' : 'Offline',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _toggleOnlineStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isOnline ? Colors.grey : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_isOnline ? 'Go Offline' : 'Go Online'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _updateLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Update Location'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '${_workerProfile!.totalJobs}',
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
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '\$${_workerProfile!.hourlyRate.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Text('Hourly Rate'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Profile completion prompt
            if (_workerProfile!.skills.isEmpty || _workerProfile!.bio.isEmpty) ...[
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Complete Your Profile',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your skills and bio to attract more customers and get more job opportunities.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _showEditProfileDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Skills Section
            Text(
              'Skills',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _workerProfile!.skills.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('No skills added yet'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _showEditProfileDialog,
                            child: const Text('Add Skills'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    children: _workerProfile!.skills
                        .map((skill) => Chip(
                              label: Text(skill),
                              backgroundColor: Colors.orange[100],
                            ))
                        .toList(),
                  ),

            const SizedBox(height: 20),

            // Bio Section
            Text(
              'About Me',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _workerProfile!.bio.isEmpty
                    ? Column(
                        children: [
                          const Text('No bio added yet'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _showEditProfileDialog,
                            child: const Text('Add Bio'),
                          ),
                        ],
                      )
                    : Text(_workerProfile!.bio),
              ),
            ),

            const SizedBox(height: 20),

            // Edit Profile Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showEditProfileDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    // TODO: Implement edit profile dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile editing feature coming soon!')),
    );
  }
}