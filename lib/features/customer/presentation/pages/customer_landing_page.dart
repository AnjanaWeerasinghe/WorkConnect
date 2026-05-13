import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/location_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../worker/presentation/worker_list_screen.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../../location/presentation/pages/workers_map_screen.dart';

class CustomerLandingPage extends StatefulWidget {
  final UserModel user;

  const CustomerLandingPage({Key? key, required this.user}) : super(key: key);

  @override
  State<CustomerLandingPage> createState() => _CustomerLandingPageState();
}

class _CustomerLandingPageState extends State<CustomerLandingPage> {
  final AuthRepository _authRepository = AuthRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  
  LocationModel? _currentLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    final result = await _locationService.getCurrentLocation();
    
    if (!mounted) return;
    
    if (result.isSuccess && result.data != null) {
      setState(() {
        _currentLocation = result.data;
      });
    }
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = false;
    });
  }

  Future<void> _selectLocationOnMap() async {
    final selectedLocation = await LocationPickerScreen.pickLocation(
      context,
      initialLocation: _currentLocation,
      title: 'Select Your Location',
    );
    
    if (!mounted) return;
    
    if (selectedLocation != null) {
      setState(() {
        _currentLocation = selectedLocation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated: ${selectedLocation.address ?? "Location set"}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _createJobRequest({
    required String serviceType,
    required String description,
    required String address,
    required String budgetInput,
    required LocationModel location,
  }) async {
    final trimmedService = serviceType.trim();
    final trimmedDescription = description.trim();
    final trimmedAddress = address.trim();
    final budget = budgetInput.trim().isEmpty ? null : double.tryParse(budgetInput.trim());

    if (trimmedService.isEmpty) {
      throw Exception('Please select a service');
    }

    if (trimmedDescription.isEmpty) {
      throw Exception('Please describe the job');
    }

    if (trimmedAddress.isEmpty && location.address == null) {
      throw Exception('Please add an address or select a location');
    }

    if (budgetInput.trim().isNotEmpty && budget == null) {
      throw Exception('Please enter a valid budget');
    }

    final job = JobModel(
      id: '',
      customerId: widget.user.id,
      workerId: null,
      serviceType: trimmedService,
      description: trimmedDescription,
      location: GeoPoint(location.latitude, location.longitude),
      address: trimmedAddress.isNotEmpty ? trimmedAddress : location.address ?? '',
      status: AppConstants.jobStatusRequested,
      agreedPrice: budget,
      imageUrls: const [],
      hasReview: false,
      createdAt: DateTime.now(),
      acceptedAt: null,
      completedAt: null,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection(AppConstants.jobsCollection).add(job.toFirestore());
  }

  Future<void> _showCreateJobRequestDialog({String? presetService}) async {
    final descriptionController = TextEditingController();
    final budgetController = TextEditingController();
    final addressController = TextEditingController(
      text: _currentLocation?.address ?? '',
    );

    String selectedService = presetService ?? AppConstants.serviceCategories.first;
    LocationModel? selectedLocation = _currentLocation;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickLocation() async {
              final pickedLocation = await LocationPickerScreen.pickLocation(
                context,
                initialLocation: selectedLocation,
                title: 'Select Job Location',
              );

              if (!mounted || pickedLocation == null) {
                return;
              }

              setDialogState(() {
                selectedLocation = pickedLocation;
                if (pickedLocation.address != null && pickedLocation.address!.isNotEmpty) {
                  addressController.text = pickedLocation.address!;
                }
              });
            }

            Future<void> submitRequest() async {
              if (isSubmitting || selectedLocation == null) return;

              setDialogState(() {
                isSubmitting = true;
              });

              try {
                await _createJobRequest(
                  serviceType: selectedService,
                  description: descriptionController.text,
                  address: addressController.text,
                  budgetInput: budgetController.text,
                  location: selectedLocation!,
                );

                if (!mounted) return;

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job request created successfully'),
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
                    isSubmitting = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Create Job Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedService,
                      decoration: const InputDecoration(
                        labelText: 'Service Category',
                        border: OutlineInputBorder(),
                      ),
                      items: AppConstants.serviceCategories
                          .map(
                            (service) => DropdownMenuItem(
                              value: service,
                              child: Text(service),
                            ),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedService = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Job Description',
                        hintText: 'Describe what needs to be done',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget (optional)',
                        prefixText: '\$',
                        hintText: 'e.g. 50',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter the job location address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedLocation?.address ??
                                (selectedLocation != null
                                    ? '${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}'
                                    : 'No location selected'),
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: isSubmitting ? null : pickLocation,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Choose on Map'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Request'),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController.dispose();
    budgetController.dispose();
    addressController.dispose();
  }

  final List<Map<String, dynamic>> _services = [
    {
      'title': 'Plumbing',
      'icon': Icons.plumbing,
      'color': Colors.blue,
      'description': 'Fix leaks, install fixtures'
    },
    {
      'title': 'Electrical',
      'icon': Icons.electrical_services,
      'color': Colors.amber,
      'description': 'Wiring, repairs, installations'
    },
    {
      'title': 'Carpentry',
      'icon': Icons.carpenter,
      'color': Colors.brown,
      'description': 'Furniture, repairs, installations'
    },
    {
      'title': 'Cleaning',
      'icon': Icons.cleaning_services,
      'color': Colors.green,
      'description': 'Home and office cleaning'
    },
    {
      'title': 'Painting',
      'icon': Icons.format_paint,
      'color': Colors.purple,
      'description': 'Interior and exterior painting'
    },
    {
      'title': 'HVAC',
      'icon': Icons.thermostat,
      'color': Colors.red,
      'description': 'Heating and cooling services'
    },
  ];

  Future<void> _signOut() async {
    await _authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.work_outline, size: 28),
            SizedBox(width: 8),
            Text(
              'WorkConnect',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      widget.user.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Divider(),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.user.name.split(' ')[0]}! 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find skilled professionals for any job',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkerListScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.list, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'List View',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkersMapScreen(
                                  initialLocation: _currentLocation,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Map View',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Current Location Card
            _buildLocationCard(),

            SizedBox(height: 20),

            _buildActiveRequestsSection(),

            SizedBox(height: 20),

            _buildRequestHistorySection(),

            SizedBox(height: 32),

            // Popular Services Section
            Text(
              'Popular Services',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // Services Grid
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerListScreen(
                          serviceFilter: service['title'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: service['color'].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            service['icon'],
                            size: 32,
                            color: service['color'],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          service['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          service['description'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 32),

            // Quick Actions Section
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // Quick Action Cards
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Emergency Service',
                    Icons.emergency,
                    Colors.red,
                    'Get immediate help',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkerListScreen(
                            emergencyOnly: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    'Create Job Request',
                    Icons.post_add,
                    Colors.blue,
                    'Post what you need done',
                    () {
                      _showCreateJobRequestDialog();
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),

            // Why Choose Us Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why Choose WorkConnect?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.verified,
                    'Verified Professionals',
                    'All workers are background checked',
                  ),
                  _buildFeatureItem(
                    Icons.star,
                    'Rated & Reviewed',
                    'Choose based on real customer reviews',
                  ),
                  _buildFeatureItem(
                    Icons.support_agent,
                    '24/7 Support',
                    'Get help whenever you need it',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
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

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    if (_isLoadingLocation)
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Getting location...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    else if (_currentLocation != null)
                      Text(
                        _currentLocation!.address ?? 
                          '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Location not set',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadCurrentLocation,
                  icon: Icon(Icons.my_location, size: 18),
                  label: Text('Use Current'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectLocationOnMap,
                  icon: Icon(Icons.map, size: 18),
                  label: Text('Select on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConstants.jobsCollection)
          .where('customerId', isEqualTo: widget.user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Requests',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Could not load your requests right now.'),
                ],
              ),
            ),
          );
        }

        final jobs = snapshot.data?.docs
                .map((doc) => JobModel.fromFirestore(doc))
            .where((job) =>
              job.status == AppConstants.jobStatusRequested ||
              job.status == AppConstants.jobStatusAccepted ||
              job.status == AppConstants.jobStatusInProgress)
                .toList() ??
            [];

        jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final trackedJobs = jobs.take(5).toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Your Requests',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${trackedJobs.length} active',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Track every active request until a worker accepts it.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (trackedJobs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No active requests yet',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create a job request and it will appear here until a worker accepts it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showCreateJobRequestDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.post_add),
                          label: const Text('Create Request'),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: trackedJobs.map((job) {
                      final progressIndex = _getJobProgressIndex(job.status);
                      final status = _getJobStatusLabel(job.status);
                      final statusColor = _getJobStatusColor(job.status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.serviceType,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        job.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildJobProgressStepper(progressIndex),
                            const SizedBox(height: 12),
                            Text(
                              job.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (job.agreedPrice != null)
                                  Text(
                                    '\$${job.agreedPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  _formatJobTime(job.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatJobTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  int _getJobProgressIndex(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:
        return 1;
      case AppConstants.jobStatusInProgress:
        return 2;
      case AppConstants.jobStatusCompleted:
        return 3;
      case AppConstants.jobStatusRequested:
      default:
        return 0;
    }
  }

  String _getJobStatusLabel(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:
        return 'Accepted by a worker';
      case AppConstants.jobStatusInProgress:
        return 'Worker on the way';
      case AppConstants.jobStatusCompleted:
        return 'Completed';
      case AppConstants.jobStatusRequested:
      default:
        return 'Waiting for a worker';
    }
  }

  Color _getJobStatusColor(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:
        return Colors.green;
      case AppConstants.jobStatusInProgress:
        return Colors.blue;
      case AppConstants.jobStatusCompleted:
        return Colors.purple;
      case AppConstants.jobStatusRequested:
      default:
        return Colors.orange;
    }
  }

  Widget _buildJobProgressStepper(int currentStep) {
    const steps = [
      ('Requested', Icons.send_outlined),
      ('Accepted', Icons.check_circle_outline),
      ('Worker on the way', Icons.directions_car_outlined),
      ('Completed', Icons.verified_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(steps.length, (index) {
            final isActive = index <= currentStep;
            final isLast = index == steps.length - 1;
            final color = isActive ? _getJobStatusColor(_statusForStep(index)) : Colors.grey.shade300;

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isActive ? color : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              steps[index].$2,
                              key: ValueKey('${steps[index].$1}-$isActive'),
                              size: 16,
                              color: isActive ? Colors.white : Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[index].$1,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? color : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        width: 18,
                        height: 2,
                        color: index < currentStep ? color : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRequestHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConstants.jobsCollection)
          .where('customerId', isEqualTo: widget.user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final historyJobs = snapshot.data?.docs
                .map((doc) => JobModel.fromFirestore(doc))
                .where((job) => job.status == AppConstants.jobStatusCompleted)
                .toList() ??
            [];

        if (historyJobs.isEmpty) {
          return const SizedBox.shrink();
        }

        historyJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'History',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${historyJobs.length} completed',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Completed requests move here after the worker finishes the job.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: historyJobs.take(3).map((job) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_outlined, color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job.serviceType,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatJobTime(job.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusForStep(int index) {
    switch (index) {
      case 1:
        return AppConstants.jobStatusAccepted;
      case 2:
        return AppConstants.jobStatusInProgress;
      case 3:
        return AppConstants.jobStatusCompleted;
      case 0:
      default:
        return AppConstants.jobStatusRequested;
    }
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
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
    );
  }
}