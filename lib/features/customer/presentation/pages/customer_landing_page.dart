import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/stripe_service.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/location_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../worker/presentation/worker_list_screen.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../../location/presentation/pages/workers_map_screen.dart';
import '../../../reviews/presentation/submit_review_screen.dart';
import 'customer_jobs_list_page.dart';
import 'create_job_screen.dart';
import '../../../../data/models/worker_model.dart';
import '../../../../data/models/bid_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

class CustomerLandingPage extends StatefulWidget {
  final UserModel user;
  const CustomerLandingPage({super.key, required this.user});

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
    setState(() => _isLoadingLocation = true);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _currentLocation = result.data);
    }
    if (!mounted) return;
    setState(() => _isLoadingLocation = false);
  }

  Future<void> _selectLocationOnMap() async {
    final selectedLocation = await LocationPickerScreen.pickLocation(
      context,
      initialLocation: _currentLocation,
      title: 'Select Your Location',
    );
    if (!mounted) return;
    if (selectedLocation != null) {
      setState(() => _currentLocation = selectedLocation);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated: ${selectedLocation.address ?? "Location set"}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _cancelJobRequest(String jobId) async {
    try {
      await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
        'status': AppConstants.jobStatusCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job request cancelled'), backgroundColor: AppColors.warning),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel job: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showCreateJobRequestDialog({String? presetService}) async {
    await CreateJobScreen.show(
      context,
      customerId:      widget.user.id,
      initialLocation: _currentLocation,
      presetService:   presetService,
    );
  }

  final List<Map<String, dynamic>> _services = [
    {'title': 'Plumbing',   'icon': Icons.plumbing,             'color': AppColors.info,    'description': 'Fix leaks, install fixtures'},
    {'title': 'Electrical', 'icon': Icons.electrical_services,  'color': Color(0xFFD97706), 'description': 'Wiring, repairs, installations'},
    {'title': 'Carpentry',  'icon': Icons.carpenter,            'color': Color(0xFF92400E), 'description': 'Furniture, repairs, installations'},
    {'title': 'Cleaning',   'icon': Icons.cleaning_services,    'color': AppColors.success, 'description': 'Home and office cleaning'},
    {'title': 'Painting',   'icon': Icons.format_paint,         'color': AppColors.admin,   'description': 'Interior and exterior painting'},
    {'title': 'HVAC',       'icon': Icons.thermostat,           'color': AppColors.error,   'description': 'Heating and cooling services'},
  ];

  Future<void> _signOut() async => _authRepository.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 24),
            _buildActiveRequestsSection(),
            const SizedBox(height: 20),
            _buildRequestHistorySection(),
            const SizedBox(height: 28),
            _buildServicesSection(),
            const SizedBox(height: 28),
            _buildQuickActionsSection(),
            const SizedBox(height: 28),
            _buildTrustSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'WorkConnect',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
          ),
        ],
      ),
      actions: [
        PopupMenuButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Center(
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          onSelected: (value) { if (value == 'logout') _signOut(); },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(widget.user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2, color: AppColors.border),
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return WcCard(
      backgroundColor: AppColors.primary,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(22),
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
                      'Welcome back,\n${widget.user.name.split(' ')[0]}.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Find skilled professionals for any job.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: 'Browse Workers',
                  icon: Icons.people_outline_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerListScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(
                  label: 'Map View',
                  icon: Icons.map_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WorkersMapScreen(initialLocation: _currentLocation),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location Card ─────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return WcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Location',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    if (_isLoadingLocation)
                      Row(children: [
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        const Text('Detecting location...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ])
                    else if (_currentLocation != null)
                      Text(
                        _currentLocation!.address ??
                            '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text('Location not set', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: WcOutlinedButton(
                  label: 'Use Current',
                  icon: Icons.my_location_rounded,
                  borderColor: AppColors.success,
                  textColor: AppColors.success,
                  onPressed: _loadCurrentLocation,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WcPrimaryButton(
                  label: 'Select on Map',
                  icon: Icons.map_outlined,
                  backgroundColor: AppColors.success,
                  onPressed: _selectLocationOnMap,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Services Grid ─────────────────────────────────────────────────────
  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WcSectionHeader(
          title: 'Popular Services',
          subtitle: 'Tap a category to browse available workers',
          trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerListScreen())),
            child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _services.length,
          itemBuilder: (_, i) {
            final s = _services[i];
            return WcCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorkerListScreen(serviceFilter: s['title'] as String)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (s['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (s['color'] as Color).withValues(alpha: 0.3), width: 1),
                    ),
                    child: Icon(s['icon'] as IconData, size: 24, color: s['color'] as Color),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s['description'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WcSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: WcCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => WorkerListScreen(emergencyOnly: true),
                )),
                padding: const EdgeInsets.all(16),
                borderColor: AppColors.error,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.emergency_rounded, color: AppColors.error, size: 22),
                    ),
                    const SizedBox(height: 10),
                    const Text('Emergency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    const Text('Immediate help', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WcCard(
                onTap: _showCreateJobRequestDialog,
                padding: const EdgeInsets.all(16),
                borderColor: AppColors.info,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.post_add_rounded, color: AppColors.info, size: 22),
                    ),
                    const SizedBox(height: 10),
                    const Text('Post a Job', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    const Text('Describe your need', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Job filter shortcuts
        WcCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          hasShadow: false,
          borderColor: AppColors.borderLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildJobTabShortcut('All',       Icons.list_rounded,        CustomerJobsScope.all),
              _buildJobTabShortcut('Pending',   Icons.schedule_rounded,    CustomerJobsScope.pending),
              _buildJobTabShortcut('Completed', Icons.check_circle_outline,CustomerJobsScope.completed),
              _buildJobTabShortcut('History',   Icons.history_rounded,     CustomerJobsScope.history),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobTabShortcut(String label, IconData icon, CustomerJobsScope scope) {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerJobsListPage(
            title: '$label Jobs',
            customerId: widget.user.id,
            scope: scope,
          ),
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Trust Section ─────────────────────────────────────────────────────
  Widget _buildTrustSection() {
    return WcCard(
      backgroundColor: AppColors.infoLight,
      borderColor: AppColors.info.withValues(alpha: 0.4),
      hasShadow: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why WorkConnect?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          _buildTrustRow(Icons.verified_rounded,     'Verified Professionals',  'All workers are background checked'),
          _buildTrustRow(Icons.star_rounded,          'Rated & Reviewed',        'Choose based on real customer reviews'),
          _buildTrustRow(Icons.support_agent_rounded, '24/7 Support',            'Get help whenever you need it'),
        ],
      ),
    );
  }

  Widget _buildTrustRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Requests ───────────────────────────────────────────────────
  Widget _buildActiveRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConstants.jobsCollection)
          .where('customerId', isEqualTo: widget.user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return WcCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const WcSkeleton(width: double.infinity, height: 20),
                const SizedBox(height: 12),
                WcSkeleton(width: double.infinity, height: 100, borderRadius: BorderRadius.circular(10)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return WcCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Your Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                SizedBox(height: 8),
                Text('Could not load your requests right now.', style: TextStyle(color: AppColors.textSecondary)),
              ],
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

        return WcCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active Requests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
                    ),
                  ),
                  WcStatusBadge(
                    label: '${trackedJobs.length} active',
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Track every active request until a worker accepts it.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (trackedJobs.isEmpty)
                WcEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No active requests',
                  subtitle: 'Create a job request and it will appear here.',
                  action: WcPrimaryButton(
                    label: 'Create Request',
                    icon: Icons.post_add_rounded,
                    onPressed: _showCreateJobRequestDialog,
                  ),
                )
              else ...[
                ...trackedJobs.map((job) => _buildActiveJobCard(job)),
                const SizedBox(height: 8),
                WcOutlinedButton(
                  label: 'Create Another Request',
                  icon: Icons.add_rounded,
                  width: double.infinity,
                  onPressed: _showCreateJobRequestDialog,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveJobCard(JobModel job) {
    final status = _getJobStatusLabel(job.status);
    final statusColor = _getJobStatusColor(job.status);
    final progressIndex = _getJobProgressIndex(job.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
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
                    Text(job.serviceType,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(job.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              WcStatusBadge(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _buildJobProgressStepper(progressIndex),
          const SizedBox(height: 12),
          Text(job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: JobLiveMap(
              jobId: job.id,
              initialLocation: LocationModel.fromGeoPoint(job.location, metadata: {'address': job.address}),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (job.agreedPrice != null)
                Text(
                  '\$${job.agreedPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              const Spacer(),
              if (job.status == AppConstants.jobStatusRequested)
                TextButton.icon(
                  onPressed: () => _showBidsModal(job),
                  icon: const Icon(Icons.gavel_rounded, size: 16),
                  label: const Text('View Bids', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (job.status != AppConstants.jobStatusCompleted &&
                  job.status != AppConstants.jobStatusCancelled) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Request'),
                        content: const Text('Do you want to cancel this job request?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await _cancelJobRequest(job.id);
                  },
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 16),
                  label: const Text('Cancel', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                _formatJobTime(job.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── History ───────────────────────────────────────────────────────────
  Widget _buildRequestHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConstants.jobsCollection)
          .where('customerId', isEqualTo: widget.user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();

        final historyJobs = snapshot.data?.docs
                .map((doc) => JobModel.fromFirestore(doc))
                .where((job) => job.status == AppConstants.jobStatusCompleted)
                .toList() ??
            [];

        if (historyJobs.isEmpty) return const SizedBox.shrink();
        historyJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return WcCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Completed Jobs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
                    ),
                  ),
                  WcStatusBadge(label: '${historyJobs.length} done', color: AppColors.admin),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Completed requests — pay or leave a review.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...historyJobs.take(5).map((job) => _buildHistoryJobCard(job)),
              if (historyJobs.length > 5) ...[
                const SizedBox(height: 4),
                WcOutlinedButton(
                  label: 'View All ${historyJobs.length} Completed Jobs',
                  icon: Icons.history_rounded,
                  width: double.infinity,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerJobsListPage(
                        title: 'Completed Jobs',
                        customerId: widget.user.id,
                        scope: CustomerJobsScope.completed,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryJobCard(JobModel job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.admin, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(job.serviceType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              WcStatusBadge(label: 'Completed', color: AppColors.admin),
            ],
          ),
          const SizedBox(height: 8),
          Text(job.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_formatJobTime(job.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          if (job.agreedPrice != null)
            if (job.isPaid)
              Align(
                alignment: Alignment.centerRight,
                child: WcStatusBadge(
                  label: job.paymentMethod == 'cash' ? 'Paid - Cash' : 'Paid - Card',
                  color: AppColors.success,
                  filled: true,
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: WcPrimaryButton(
                  label: 'Pay \$${job.agreedPrice!.toStringAsFixed(2)}',
                  icon: Icons.payment_rounded,
                  backgroundColor: AppColors.success,
                  onPressed: () => _showPaymentMethodSheet(job),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
              ),
          if (job.status == AppConstants.jobStatusCompleted && !job.hasReview && job.workerId != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: WcOutlinedButton(
                  label: 'Leave Review',
                  icon: Icons.rate_review_outlined,
                  borderColor: AppColors.admin,
                  textColor: AppColors.admin,
                  onPressed: () async {
                    try {
                      final workerDoc = await _firestore
                          .collection(AppConstants.workersCollection)
                          .doc(job.workerId)
                          .get();
                      if (!mounted) return;
                      if (!workerDoc.exists) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Worker not found')),
                        );
                        return;
                      }
                      final worker = WorkerModel.fromFirestore(workerDoc);
                      final result = await Navigator.of(context).push<bool?>(
                        MaterialPageRoute(builder: (_) => SubmitReviewScreen(job: job, worker: worker)),
                      );
                      if (!mounted) return;
                      if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thank you for your review!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bids Modal ────────────────────────────────────────────────────────
  Future<void> _showBidsModal(JobModel job) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Worker Bids', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text(job.serviceType, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.borderLight),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.bidsCollection)
                      .where('jobId', isEqualTo: job.id)
                      .where('status', isEqualTo: AppConstants.bidStatusPending)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bids = snap.data?.docs.map((d) => BidModel.fromFirestore(d)).toList() ?? [];
                    bids.sort((a, b) => a.amount.compareTo(b.amount));
                    if (bids.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text('No bids yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                              SizedBox(height: 6),
                              Text('Workers nearby will place bids soon.', style: TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: bids.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildBidCard(bids[i], job, () {
                        Navigator.pop(ctx);
                        _acceptBid(job, bids[i]);
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidCard(BidModel bid, JobModel job, VoidCallback onAccept) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    bid.workerName.isNotEmpty ? bid.workerName[0].toUpperCase() : 'W',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bid.workerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(_formatJobTime(bid.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Text(
                  '\$${bid.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success),
                ),
              ),
            ],
          ),
          if (bid.message != null && bid.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2), width: 1),
              ),
              child: Text(bid.message!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Accept This Bid', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptBid(JobModel job, BidModel bid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Bid'),
        content: Text('Hire ${bid.workerName} for \$${bid.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Yes, Hire'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final batch = _firestore.batch();
      batch.update(
        _firestore.collection(AppConstants.jobsCollection).doc(job.id),
        {
          'workerId': bid.workerId,
          'agreedPrice': bid.amount,
          'status': AppConstants.jobStatusAccepted,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.update(
        _firestore.collection(AppConstants.bidsCollection).doc(bid.id),
        {'status': AppConstants.bidStatusAccepted},
      );
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${bid.workerName} hired for \$${bid.amount.toStringAsFixed(2)}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept bid: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Payment Sheet ─────────────────────────────────────────────────────
  Future<void> _showPaymentMethodSheet(JobModel job) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pay \$${job.agreedPrice!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text('Choose your payment method', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            _PaymentOption(
              icon: Icons.credit_card_rounded,
              iconColor: AppColors.success,
              iconBg: AppColors.successLight,
              title: 'Pay by Card',
              subtitle: 'Secure online payment via Stripe',
              onTap: () => Navigator.pop(ctx, 'card'),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              icon: Icons.payments_outlined,
              iconColor: AppColors.warning,
              iconBg: AppColors.warningLight,
              title: 'Pay in Cash',
              subtitle: 'Hand cash directly to the worker',
              onTap: () => Navigator.pop(ctx, 'cash'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'cash') {
      await _firestore.collection(AppConstants.jobsCollection).doc(job.id).update({
        'isPaid': true, 'paymentMethod': 'cash', 'paidAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash payment recorded. Please pay the worker directly.'), backgroundColor: AppColors.warning),
      );
    } else {
      try {
        final paid = await StripeService.processCardPayment(
          amount: job.agreedPrice!, jobId: job.id, customerId: widget.user.id, context: context,
        );
        if (paid) {
          await _firestore.collection(AppConstants.jobsCollection).doc(job.id).update({
            'isPaid': true, 'paymentMethod': 'card', 'paidAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card payment successful!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _formatJobTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  int _getJobProgressIndex(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:    return 1;
      case AppConstants.jobStatusInProgress:  return 2;
      case AppConstants.jobStatusCompleted:   return 3;
      default:                                return 0;
    }
  }

  String _getJobStatusLabel(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:    return 'Worker Picked';
      case AppConstants.jobStatusInProgress:  return 'In Progress';
      case AppConstants.jobStatusCompleted:   return 'Completed';
      default:                                return 'Open for Bids';
    }
  }

  Color _getJobStatusColor(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:    return AppColors.success;
      case AppConstants.jobStatusInProgress:  return AppColors.info;
      case AppConstants.jobStatusCompleted:   return AppColors.admin;
      default:                                return AppColors.primary;
    }
  }

  String _statusForStep(int index) {
    switch (index) {
      case 1: return AppConstants.jobStatusAccepted;
      case 2: return AppConstants.jobStatusInProgress;
      case 3: return AppConstants.jobStatusCompleted;
      default: return AppConstants.jobStatusRequested;
    }
  }

  Widget _buildJobProgressStepper(int currentStep) {
    const steps = [
      ('Bids Open', Icons.gavel_rounded),
      ('Worker Picked', Icons.check_circle_outline),
      ('On the Way', Icons.directions_car_outlined),
      ('Completed', Icons.verified_outlined),
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        final isLast = index == steps.length - 1;
        final color = isActive ? _getJobStatusColor(_statusForStep(index)) : AppColors.borderLight;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive ? color : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? color : AppColors.borderLight,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(steps[index].$2, size: 14, color: isActive ? Colors.white : AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index].$1,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? color : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14,
                    height: 1.5,
                    color: index < currentStep ? _getJobStatusColor(_statusForStep(index)) : AppColors.borderLight,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Hero action button (inside the hero card)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: const [BoxShadow(color: AppColors.shadow, offset: Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment option tile
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: const [BoxShadow(color: AppColors.shadow, offset: Offset(3, 3), blurRadius: 0)],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JobLiveMap — live worker tracking widget (business logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class JobLiveMap extends StatefulWidget {
  final String jobId;
  final LocationModel initialLocation;

  const JobLiveMap({super.key, required this.jobId, required this.initialLocation});

  @override
  State<JobLiveMap> createState() => _JobLiveMapState();
}

class _JobLiveMapState extends State<JobLiveMap> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _pollTimer;
  Timer? _interpTimer;
  AnimationController? _pulseController;
  LatLng? _workerLatLng;
  LatLng? _prevLatLng;
  LatLng? _jobCenter;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    // Fetch immediately, then every 5 seconds
    _fetchWorkerLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchWorkerLocation());
  }

  Future<void> _fetchWorkerLocation() async {
    if (!mounted) return;
    try {
      final doc = await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(widget.jobId)
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};

      // Update job center on first fetch
      if (_jobCenter == null && data['location'] is GeoPoint) {
        final p = data['location'] as GeoPoint;
        setState(() => _jobCenter = LatLng(p.latitude, p.longitude));
      }

      final gp = data['workerLocation'];
      if (gp is! GeoPoint) {
        if (_workerLatLng != null) setState(() => _workerLatLng = null);
        return;
      }
      final next = LatLng(gp.latitude, gp.longitude);
      if (_workerLatLng == null) {
        setState(() => _workerLatLng = next);
      } else {
        _prevLatLng = _workerLatLng;
        _startInterpolation(_prevLatLng!, next);
      }
    } catch (_) {}
  }

  void _startInterpolation(LatLng from, LatLng to) {
    _cancelInterp();
    const steps = 10;
    int step = 0;
    _interpTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      step++;
      final tVal = step / steps;
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _workerLatLng = LatLng(
          from.latitude  + (to.latitude  - from.latitude)  * tVal,
          from.longitude + (to.longitude - from.longitude) * tVal,
        );
      });
      if (step >= steps) t.cancel();
    });
  }

  void _cancelInterp() {
    _interpTimer?.cancel();
    _interpTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _interpTimer?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _jobCenter
        ?? LatLng(widget.initialLocation.latitude, widget.initialLocation.longitude);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('job_location'),
        position: center,
        infoWindow: InfoWindow(title: 'Job Location', snippet: widget.initialLocation.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    final circles = <Circle>{};

    if (_workerLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('worker_location'),
        position: _workerLatLng!,
        infoWindow: const InfoWindow(title: 'Worker'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      final pulseRadius = 20.0 + 40.0 * (_pulseController?.value ?? 0.0);
      circles.add(Circle(
        circleId: const CircleId('worker_pulse'),
        center: _workerLatLng!,
        radius: pulseRadius,
        fillColor: AppColors.success.withValues(alpha: 0.12),
        strokeColor: AppColors.success.withValues(alpha: 0.4),
        strokeWidth: 1,
      ));
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 14),
            markers: markers,
            circles: circles,
            zoomControlsEnabled: false,
            myLocationEnabled: false,
            liteModeEnabled: true,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
            ),
          ),
        ),
        if (_workerLatLng != null)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 6),
                  SizedBox(width: 5),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
