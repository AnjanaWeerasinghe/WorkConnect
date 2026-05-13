import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/review_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../worker/presentation/worker_dashboard_screen.dart';
import '../../../location/presentation/pages/jobs_map_screen.dart';

class WorkerLandingPage extends StatefulWidget {
  final UserModel user;

  const WorkerLandingPage({Key? key, required this.user}) : super(key: key);

  @override
  State<WorkerLandingPage> createState() => _WorkerLandingPageState();
}

class _WorkerLandingPageState extends State<WorkerLandingPage> {
  final AuthRepository _authRepository = AuthRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables for real data
  int _pendingJobs = 0;
  int _completedJobs = 0;
  double _monthlyEarnings = 0.0;
  double _rating = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkerStats();
  }

  Future<void> _loadWorkerStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch pending jobs (jobs assigned to this worker with status 'requested' or 'accepted')
        final pendingSnapshot = await _firestore
            .collection(AppConstants.jobsCollection)
            .where('workerId', isEqualTo: user.uid)
            .where('status', whereIn: [
              AppConstants.jobStatusRequested,
              AppConstants.jobStatusAccepted,
            ])
            .get();

        // Fetch completed jobs
        final completedSnapshot = await _firestore
            .collection(AppConstants.jobsCollection)
            .where('workerId', isEqualTo: user.uid)
            .where('status', isEqualTo: AppConstants.jobStatusCompleted)
            .get();

        // Calculate total earnings from completed jobs
        double earnings = 0.0;
        for (final doc in completedSnapshot.docs) {
          final job = JobModel.fromFirestore(doc);
          if (job.agreedPrice != null) {
            earnings += job.agreedPrice!;
          }
        }

        // Fetch worker's average rating
        final reviewsSnapshot = await _firestore
            .collection(AppConstants.reviewsCollection)
            .where('workerId', isEqualTo: user.uid)
            .get();

        double avgRating = 0.0;
        if (reviewsSnapshot.docs.isNotEmpty) {
          double totalRating = 0.0;
          for (final doc in reviewsSnapshot.docs) {
            final rating = doc['rating'] as num?;
            if (rating != null) {
              totalRating += rating.toDouble();
            }
          }
          avgRating = totalRating / reviewsSnapshot.docs.length;
        }

        if (mounted) {
          setState(() {
            _pendingJobs = pendingSnapshot.docs.length;
            _completedJobs = completedSnapshot.docs.length;
            _monthlyEarnings = earnings;
            _rating = avgRating;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading worker stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            Icon(Icons.work, size: 28),
            SizedBox(width: 8),
            Text(
              'WorkConnect Pro',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Navigate to notifications
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notifications coming soon!')),
                  );
                },
                icon: Icon(Icons.notifications_outlined),
              ),
              if (_pendingJobs > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_pendingJobs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'W',
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
                    Text(
                      'Professional Worker',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            )
          : SingleChildScrollView(
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
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
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
                              'Good ${_getTimeGreeting()}, ${widget.user.name.split(' ')[0]}! 👋',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ready to take on new jobs today?',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.work_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
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
                                builder: (context) => WorkerDashboardScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dashboard, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Dashboard',
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
                                builder: (context) => JobsMapScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Find Jobs',
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

            SizedBox(height: 32),

            // Stats Overview
            Text(
              'Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // Stats Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Pending Jobs',
                  '$_pendingJobs',
                  Icons.pending_actions,
                  Colors.orange,
                  'New requests',
                ),
                _buildStatCard(
                  'Completed',
                  '$_completedJobs',
                  Icons.check_circle,
                  Colors.green,
                  'This month',
                ),
                _buildStatCard(
                  'Rating',
                  '${_rating > 0 ? _rating.toStringAsFixed(1) : '0.0'} ⭐',
                  Icons.star,
                  Colors.amber,
                  'Customer reviews',
                ),
                _buildStatCard(
                  'Earnings',
                  '\$${_monthlyEarnings.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.blue,
                  'This month',
                ),
              ],
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

            // Action Buttons
            Column(
              children: [
                _buildActionButton(
                  'View Job Requests',
                  Icons.work_outline,
                  Colors.orange,
                  'Check new job opportunities',
                  () {
                    _showPendingJobsModal();
                  },
                ),
                SizedBox(height: 12),
                _buildActionButton(
                  'Update Availability',
                  Icons.schedule,
                  Colors.blue,
                  'Set your working hours',
                  () {
                    _showAvailabilityDialog();
                  },
                ),
                SizedBox(height: 12),
                _buildActionButton(
                  'Manage Profile',
                  Icons.person,
                  Colors.purple,
                  'Update your skills and info',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 32),

            // Tips Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildTipItem('💬', 'Respond to job requests within 1 hour for better visibility'),
                  _buildTipItem('📷', 'Upload photos of your completed work to build trust'),
                  _buildTipItem('⭐', 'Maintain a 4.5+ rating to get more job offers'),
                  _buildTipItem('🕐', 'Keep your availability updated to receive relevant jobs'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return GestureDetector(
      onTap: () {
        if (title == 'Rating') {
          _showRatingsModal();
        } else if (title == 'Earnings') {
          _showEarningsModal();
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              Spacer(),
              if (title == 'Pending Jobs' && _pendingJobs > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildActionButton(
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String emoji, String tip) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPendingJobsModal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch pending jobs for this worker
      final snapshot = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: user.uid)
          .where('status', whereIn: [
            AppConstants.jobStatusRequested,
            AppConstants.jobStatusAccepted,
          ])
          .orderBy('createdAt', descending: true)
          .get();

      final jobs =
          snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Text(
                          'Pending Jobs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${jobs.length}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: jobs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending jobs',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: jobs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final job = jobs[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: job.status ==
                                                      'requested'
                                                  ? Colors.orange[100]
                                                  : Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              job.status == 'requested'
                                                  ? 'New'
                                                  : 'Accepted',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: job.status ==
                                                        'requested'
                                                    ? Colors.orange[700]
                                                    : Colors.green[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        job.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (job.agreedPrice != null)
                                            Text(
                                              '\$${job.agreedPrice!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          Text(
                                            'Created ${_formatDate(job.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              },
                            ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing pending jobs: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading jobs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRatingsModal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch all reviews for this worker
      final snapshot = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('workerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      if (!mounted) return;

      // Calculate rating distribution
      Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in reviews) {
        ratingCounts[review.rating] = (ratingCounts[review.rating] ?? 0) + 1;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Ratings',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Overall rating card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Average Rating',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        _rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: List.generate(
                                          5,
                                          (index) => Icon(
                                            Icons.star,
                                            size: 12,
                                            color: index < _rating.toInt()
                                                ? Colors.amber
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${reviews.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Rating distribution
                        ...List.generate(
                          5,
                          (index) {
                            final stars = 5 - index;
                            final count = ratingCounts[stars] ?? 0;
                            final percentage = reviews.isEmpty
                                ? 0.0
                                : (count / reviews.length) * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '$stars★',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey[200],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.amber[600]!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      count.toString(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: reviews.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: reviews.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                Icons.star,
                                                size: 16,
                                                color: i < review.rating
                                                    ? Colors.amber
                                                    : Colors.grey[300],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatDate(review.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        review.comment,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              },
                            ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing ratings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ratings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEarningsModal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch all completed jobs with earnings
      final snapshot = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: user.uid)
          .where('status', isEqualTo: AppConstants.jobStatusCompleted)
          .orderBy('completedAt', descending: true)
          .get();

      final completedJobs = snapshot.docs
          .map((doc) => JobModel.fromFirestore(doc))
          .toList();

      if (!mounted) return;

      // Calculate breakdown
      double totalEarnings = 0.0;
      for (final job in completedJobs) {
        if (job.agreedPrice != null) {
          totalEarnings += job.agreedPrice!;
        }
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Earnings',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${totalEarnings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${completedJobs.length} jobs',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: completedJobs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No completed jobs yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: completedJobs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final job = completedJobs[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '\$${(job.agreedPrice ?? 0).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          Text(
                                            _formatDate(job.completedAt ??
                                                DateTime.now()),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              },
                            ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing earnings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading earnings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  void _showAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Update Availability'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This feature is coming soon! You\'ll be able to:'),
              SizedBox(height: 16),
              _buildFeatureItem('Set working hours'),
              _buildFeatureItem('Mark availability for urgent jobs'),
              _buildFeatureItem('Schedule time off'),
              _buildFeatureItem('Set service areas'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}