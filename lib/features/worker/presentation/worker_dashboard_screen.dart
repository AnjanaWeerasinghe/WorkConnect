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

  List<String> _parseSkills(String input) {
    return input
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();
  }

  Future<void> _saveProfileUpdates({
    required String skillsInput,
    required String bio,
    required String address,
    required String hourlyRateInput,
  }) async {
    if (_workerProfile == null) return;

    final skills = _parseSkills(skillsInput);
    final hourlyRate = double.tryParse(hourlyRateInput.trim());

    if (skills.isEmpty) {
      throw Exception('Please add at least one skill');
    }

    if (bio.trim().isEmpty) {
      throw Exception('Please add a bio');
    }

    if (hourlyRate == null || hourlyRate < 0) {
      throw Exception('Please enter a valid hourly rate');
    }

    final updatedWorker = _workerProfile!.copyWith(
      skills: skills,
      bio: bio.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
      hourlyRate: hourlyRate,
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.workersCollection)
        .doc(_workerProfile!.id)
        .set(updatedWorker.toFirestore(), SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      _workerProfile = updatedWorker;
    });
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProfileInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Container(
      width: isWide ? (MediaQuery.of(context).size.width - 64) / 2 : double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
            // Profile Summary
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _userProfile!.name,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (_workerProfile!.isVerified)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue[200]!),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified, size: 14, color: Colors.blue),
                                          SizedBox(width: 4),
                                          Text(
                                            'Verified',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _userProfile!.email,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              RatingDisplay(
                                rating: _workerProfile!.avgRating,
                                reviewCount: _workerProfile!.ratingCount,
                                starSize: 18,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusChip(
                                    _isOnline ? 'Online' : 'Offline',
                                    _isOnline ? Colors.green : Colors.grey,
                                  ),
                                  _buildStatusChip(
                                    '${_workerProfile!.totalJobs} jobs',
                                    Colors.orange,
                                  ),
                                  _buildStatusChip(
                                    '\$${_workerProfile!.hourlyRate.toStringAsFixed(0)}/hr',
                                    Colors.teal,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildProfileInfoTile(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: _userProfile!.phone.isNotEmpty
                                    ? _userProfile!.phone
                                    : 'Not set',
                              ),
                              _buildProfileInfoTile(
                                icon: Icons.location_on_outlined,
                                label: 'Service Area',
                                value: _workerProfile!.address?.isNotEmpty == true
                                    ? _workerProfile!.address!
                                    : 'Not set',
                              ),
                              _buildProfileInfoTile(
                                icon: Icons.map_outlined,
                                label: 'Location',
                                value: _workerProfile!.location != null
                                    ? '${_workerProfile!.location!.latitude.toStringAsFixed(4)}, ${_workerProfile!.location!.longitude.toStringAsFixed(4)}'
                                    : 'Not shared',
                              ),
                              _buildProfileInfoTile(
                                icon: Icons.workspace_premium_outlined,
                                label: 'Certifications',
                                value: '${_workerProfile!.certificationImages.length}',
                              ),
                              _buildProfileInfoTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'Joined',
                                value: _formatDate(_userProfile!.createdAt),
                              ),
                              _buildProfileInfoTile(
                                icon: Icons.update_outlined,
                                label: 'Updated',
                                value: _formatDate(_workerProfile!.updatedAt),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Skills',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _workerProfile!.skills.isEmpty
                        ? Text(
                            'No skills added yet',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _workerProfile!.skills
                                .map(
                                  (skill) => Chip(
                                    label: Text(skill),
                                    backgroundColor: Colors.orange[100],
                                  ),
                                )
                                .toList(),
                          ),
                    const SizedBox(height: 16),
                    Text(
                      'About Me',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _workerProfile!.bio.isEmpty
                            ? 'No bio added yet'
                            : _workerProfile!.bio,
                        style: TextStyle(
                          color: _workerProfile!.bio.isEmpty ? Colors.grey[600] : Colors.black87,
                          height: 1.45,
                        ),
                      ),
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
    if (_workerProfile == null) return;

    final skillsController = TextEditingController(text: _workerProfile!.skills.join(', '));
    final bioController = TextEditingController(text: _workerProfile!.bio);
    final addressController = TextEditingController(text: _workerProfile!.address ?? '');
    final hourlyRateController = TextEditingController(text: _workerProfile!.hourlyRate.toStringAsFixed(0));

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveChanges() async {
              if (isSaving) return;

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _saveProfileUpdates(
                  skillsInput: skillsController.text,
                  bio: bioController.text,
                  address: addressController.text,
                  hourlyRateInput: hourlyRateController.text,
                );

                if (!mounted) return;

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (mounted) {
                  setDialogState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: skillsController,
                      decoration: const InputDecoration(
                        labelText: 'Skills',
                        hintText: 'Plumbing, Wiring, Repairs',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell customers about your experience',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hourlyRateController,
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate',
                        prefixText: '\$',
                        hintText: '25',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address / Service Area',
                        hintText: 'City, neighborhood, or service area',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}