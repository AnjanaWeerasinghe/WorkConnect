import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/review_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../worker/presentation/worker_dashboard_screen.dart';
import '../../../location/presentation/pages/jobs_map_screen.dart';
import 'worker_notifications_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

class WorkerLandingPage extends StatefulWidget {
  final UserModel user;
  const WorkerLandingPage({super.key, required this.user});

  @override
  State<WorkerLandingPage> createState() => _WorkerLandingPageState();
}

class _WorkerLandingPageState extends State<WorkerLandingPage> {
  final AuthRepository _authRepository = AuthRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription<Position>> _locationSubscriptions = {};

  int _pendingJobs = 0;
  int _inProgressJobs = 0;
  int _completedJobs = 0;
  double _monthlyEarnings = 0.0;
  double _rating = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkerStats();
  }

  @override
  void didUpdateWidget(covariant WorkerLandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      setState(() {
        _pendingJobs = 0;
        _inProgressJobs = 0;
        _completedJobs = 0;
        _monthlyEarnings = 0.0;
        _rating = 0.0;
        _isLoading = true;
      });
      _loadWorkerStats();
    }
  }

  @override
  void dispose() {
    for (final sub in _locationSubscriptions.values) { sub.cancel(); }
    _locationSubscriptions.clear();
    super.dispose();
  }

  Future<void> _loadWorkerStats() async {
    try {
      final pendingSnap = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', whereIn: [AppConstants.jobStatusRequested, AppConstants.jobStatusAccepted])
          .get();

      final inProgressSnap = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', isEqualTo: AppConstants.jobStatusInProgress)
          .get();

      final completedSnap = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', isEqualTo: AppConstants.jobStatusCompleted)
          .get();

      double earnings = 0.0;
      for (final doc in completedSnap.docs) {
        final job = JobModel.fromFirestore(doc);
        if (job.agreedPrice != null) earnings += job.agreedPrice!;
      }

      final reviewsSnap = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .get();

      double avgRating = 0.0;
      if (reviewsSnap.docs.isNotEmpty) {
        double total = 0.0;
        for (final doc in reviewsSnap.docs) {
          final r = doc['rating'] as num?;
          if (r != null) total += r.toDouble();
        }
        avgRating = total / reviewsSnap.docs.length;
      }

      if (mounted) {
        setState(() {
          _pendingJobs = pendingSnap.docs.length;
          _inProgressJobs = inProgressSnap.docs.length;
          _completedJobs = completedSnap.docs.length;
          _monthlyEarnings = earnings;
          _rating = avgRating;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worker stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async => _authRepository.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.worker))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 28),
                  const WcSectionHeader(title: 'Overview'),
                  const SizedBox(height: 14),
                  _buildStatsGrid(),
                  const SizedBox(height: 28),
                  const WcSectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 14),
                  _buildActionList(),
                  const SizedBox(height: 28),
                  _buildTipsCard(),
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
              color: AppColors.worker,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('WorkConnect Pro',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorkerNotificationsPage(worker: widget.user)),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
            if (_pendingJobs > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '$_pendingJobs',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
        PopupMenuButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.workerLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Center(
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'W',
                style: const TextStyle(color: AppColors.worker, fontWeight: FontWeight.w800, fontSize: 14),
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
                  const Text('Professional Worker', style: TextStyle(color: AppColors.worker, fontSize: 11, fontWeight: FontWeight.w700)),
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

  Widget _buildHeroCard() {
    return WcCard(
      backgroundColor: AppColors.worker,
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
                      'Good ${_getTimeGreeting()},\n${widget.user.name.split(' ')[0]}.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Ready to take on new jobs today?',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                child: const Icon(Icons.work_outline_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _WorkerHeroButton(
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerDashboardScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorkerHeroButton(
                  label: 'Find Jobs',
                  icon: Icons.map_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsMapScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        WcStatCard(
          label: 'Pending Jobs',
          value: '$_pendingJobs',
          icon: Icons.pending_actions_rounded,
          accentColor: AppColors.primary,
          subtitle: 'New requests',
          badge: _pendingJobs > 0 ? WcStatusBadge(label: 'NEW', color: AppColors.error, filled: true) : null,
          onTap: _showPendingJobsModal,
        ),
        WcStatCard(
          label: 'In Progress',
          value: '$_inProgressJobs',
          icon: Icons.directions_car_rounded,
          accentColor: AppColors.worker,
          subtitle: 'Active jobs',
          badge: _inProgressJobs > 0 ? WcStatusBadge(label: 'LIVE', color: AppColors.worker, filled: true) : null,
          onTap: _showInProgressJobsModal,
        ),
        WcStatCard(
          label: 'Completed',
          value: '$_completedJobs',
          icon: Icons.check_circle_rounded,
          accentColor: AppColors.info,
          subtitle: 'All time',
          onTap: _showEarningsModal,
        ),
        WcStatCard(
          label: 'Avg Rating',
          value: _rating > 0 ? _rating.toStringAsFixed(1) : '—',
          icon: Icons.star_rounded,
          accentColor: AppColors.rating,
          subtitle: 'From reviews',
          onTap: _showRatingsModal,
        ),
        WcStatCard(
          label: 'Total Earnings',
          value: '\$${_monthlyEarnings.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AppColors.success,
          subtitle: 'All completed jobs',
          onTap: _showEarningsModal,
        ),
      ],
    );
  }

  Widget _buildActionList() {
    return Column(
      children: [
        WcActionRow(
          title: 'View Job Requests',
          subtitle: 'Check new job opportunities',
          icon: Icons.work_outline_rounded,
          iconColor: AppColors.primary,
          onTap: _showPendingJobsModal,
        ),
        const SizedBox(height: 10),
        WcActionRow(
          title: 'View In-Progress Jobs',
          subtitle: 'Track and manage active jobs',
          icon: Icons.directions_car_rounded,
          iconColor: AppColors.worker,
          onTap: _showInProgressJobsModal,
        ),
        const SizedBox(height: 10),
        WcActionRow(
          title: 'Update Availability',
          subtitle: 'Set your working hours',
          icon: Icons.schedule_rounded,
          iconColor: AppColors.info,
          onTap: _showAvailabilityDialog,
        ),
        const SizedBox(height: 10),
        WcActionRow(
          title: 'Manage Profile',
          subtitle: 'Update skills and information',
          icon: Icons.manage_accounts_rounded,
          iconColor: AppColors.admin,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerDashboardScreen())),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return WcCard(
      backgroundColor: AppColors.warningLight,
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      hasShadow: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              const Text('Pro Tips',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          _buildTip(Icons.timer_outlined,        'Respond to job requests within 1 hour for better visibility'),
          _buildTip(Icons.photo_camera_outlined,  'Upload photos of completed work to build trust'),
          _buildTip(Icons.star_border_rounded,    'Maintain a 4.5+ rating to receive more job offers'),
          _buildTip(Icons.event_available_outlined,'Keep your availability updated for relevant job matches'),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Modals (business logic fully preserved) ───────────────────────────────

  Future<void> _showPendingJobsModal() async {
    final snapshot = await _firestore
        .collection(AppConstants.jobsCollection)
        .where('workerId', isEqualTo: widget.user.id)
        .where('status', whereIn: [AppConstants.jobStatusRequested, AppConstants.jobStatusAccepted])
        .orderBy('createdAt', descending: true)
        .get();

    final jobs = snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (modalCtx, setModalState) => Column(
            children: [
              _buildSheetHandle(),
              _buildSheetHeader('Job Requests', jobs.length, AppColors.primary),
              Expanded(
                child: jobs.isEmpty
                    ? const WcEmptyState(
                        icon: Icons.work_off_outlined,
                        title: 'No pending jobs',
                        subtitle: 'New job requests will appear here.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: jobs.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          final jobId = job.id;
                          return _buildPendingJobCard(
                            context: context,
                            job: job,
                            onStatusUpdate: (status) async {
                              await _updateJobStatus(jobId, status, job);
                              setModalState(() => jobs.removeWhere((j) => j.id == jobId));
                            },
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

  Widget _buildPendingJobCard({
    required BuildContext context,
    required JobModel job,
    required Future<void> Function(String) onStatusUpdate,
  }) {
    final isNew      = job.status == AppConstants.jobStatusRequested;
    final isAccepted = job.status == AppConstants.jobStatusAccepted;

    return WcCard(
      padding: const EdgeInsets.all(16),
      borderColor: isNew ? AppColors.primary : AppColors.worker,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.serviceType,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(job.address,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              WcStatusBadge(
                label: isNew ? 'New Request' : 'Accepted',
                color: isNew ? AppColors.primary : AppColors.worker,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Description ────────────────────────────────────────────
          Text(job.description,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),

          // ── Price row ──────────────────────────────────────────────
          Row(children: [
            if (job.agreedPrice != null) ...[
              GestureDetector(
                onTap: () => _setJobPrice(context, job),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.15), offset: const Offset(2, 2), blurRadius: 0)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.attach_money_rounded, size: 14, color: AppColors.success),
                    Text(job.agreedPrice!.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
                    const SizedBox(width: 5),
                    const Icon(Icons.edit_rounded, size: 12, color: AppColors.success),
                  ]),
                ),
              ),
            ] else if (isAccepted) ...[
              // Accepted but no price — prompt to set one
              GestureDetector(
                onTap: () => _setJobPrice(context, job),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.warning, width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.warning.withValues(alpha: 0.2), offset: const Offset(2, 2), blurRadius: 0)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 14, color: AppColors.warning),
                    SizedBox(width: 4),
                    Text('Set Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                  ]),
                ),
              ),
            ] else if (isNew)
              const Text('Price set when you accept',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const Spacer(),
            Text(_formatDate(job.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 12),

          // ── Actions ────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            // New request → "Accept + Set Price"
            if (isNew)
              _SmallButton(
                label: 'Accept Job',
                icon:  Icons.handshake_rounded,
                color: AppColors.worker,
                onTap: () => _showAcceptJobDialog(context, job, onStatusUpdate),
              ),

            // Accepted → "On the Way"
            if (isAccepted)
              _SmallButton(
                label: 'On the Way',
                icon:  Icons.navigation_rounded,
                color: AppColors.info,
                onTap: () => onStatusUpdate(AppConstants.jobStatusInProgress),
              ),

            _SmallButton(label: 'Navigate',
                icon: Icons.directions_rounded, color: AppColors.info,
                onTap: () => _navigateToJob(context, job)),

            if (!isNew) // Can complete an accepted job
              _SmallButton(label: 'Complete',
                  icon: Icons.check_circle_rounded, color: AppColors.admin,
                  onTap: () => _confirmAction(context, 'Complete Job',
                      'Mark this job as completed?',
                      () => onStatusUpdate(AppConstants.jobStatusCompleted))),

            _SmallButton(label: 'Cancel',
                icon: Icons.cancel_rounded, color: AppColors.error,
                onTap: () => _confirmAction(context, 'Cancel Job',
                    'Are you sure you want to cancel this job?',
                    () => onStatusUpdate(AppConstants.jobStatusCancelled))),
          ]),
        ],
      ),
    );
  }

  /// Shows a price-entry dialog, then sets the job to accepted with the quoted price.
  Future<void> _showAcceptJobDialog(
    BuildContext context,
    JobModel job,
    Future<void> Function(String) onStatusUpdate,
  ) async {
    final priceCtrl  = TextEditingController();
    // Capture before any await to avoid cross-async-gap BuildContext use.
    final messenger  = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${job.serviceType}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(job.address,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2),
            const SizedBox(height: 16),
            const Text('Set your price for this job',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
                'The customer will be charged this amount upon completion.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your price',
                prefixIcon: Icon(Icons.attach_money_rounded),
                hintText: '0.00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          WcPrimaryButton(
            label: 'Accept Job',
            backgroundColor: AppColors.worker,
            onPressed: () => Navigator.pop(ctx, true),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceCtrl.text.trim());

    // Update job: set status to accepted and store the worker's quoted price
    try {
      final updates = <String, dynamic>{
        'status':     AppConstants.jobStatusAccepted,
        'workerId':   widget.user.id,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt':  FieldValue.serverTimestamp(),
        if (price != null && price > 0) 'agreedPrice': price,
      };
      await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(job.id)
          .update(updates);
      await _loadWorkerStats();
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Job accepted'), backgroundColor: AppColors.worker),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Failed to accept job: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  // ── Standalone price-set / price-edit ────────────────────────────────────
  /// Opens a price dialog and writes `agreedPrice` to Firestore.
  /// Works for any job status — does NOT change the status field.
  Future<void> _setJobPrice(BuildContext context, JobModel job) async {
    final priceCtrl = TextEditingController(
      text: job.agreedPrice != null ? job.agreedPrice!.toStringAsFixed(2) : '',
    );
    final messenger = ScaffoldMessenger.of(context);

    final isEdit     = job.agreedPrice != null;
    final confirmed  = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.attach_money_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 10),
          Text(isEdit ? 'Edit Price' : 'Set Price'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.work_outline_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job.serviceType,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(job.address,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Update your quoted price:' : 'Enter your price for this job:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'The customer will see and pay this amount when the job is completed.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                hintText: '0.00',
                suffixText: 'USD',
                suffixStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          WcPrimaryButton(
            label: isEdit ? 'Update Price' : 'Set Price',
            icon: Icons.check_rounded,
            backgroundColor: AppColors.success,
            onPressed: () => Navigator.pop(ctx, true),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceCtrl.text.trim());
    if (price == null || price <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid price greater than 0')),
      );
      return;
    }

    try {
      await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(job.id)
          .update({'agreedPrice': price, 'updatedAt': FieldValue.serverTimestamp()});
      await _loadWorkerStats();
      messenger.showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Price updated to \$${price.toStringAsFixed(2)}' : 'Price set to \$${price.toStringAsFixed(2)}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save price: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showInProgressJobsModal() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection(AppConstants.jobsCollection)
              .where('workerId', isEqualTo: widget.user.id)
              .where('status', isEqualTo: AppConstants.jobStatusInProgress)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final jobs = snapshot.hasData
                ? snapshot.data!.docs.map((d) => JobModel.fromFirestore(d)).toList()
                : <JobModel>[];
            return Column(
              children: [
                _buildSheetHandle(),
                _buildSheetHeader('In-Progress Jobs', jobs.length, AppColors.worker),
                Expanded(
                  child: !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator(color: AppColors.worker))
                      : jobs.isEmpty
                          ? const WcEmptyState(
                              icon: Icons.directions_car_outlined,
                              title: 'No jobs in progress',
                              subtitle: 'Accept a job request to start working.',
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: jobs.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                return WcCard(
                                  padding: const EdgeInsets.all(16),
                                  borderColor: AppColors.worker,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(job.serviceType, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                                const SizedBox(height: 3),
                                                Text(job.address, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          WcStatusBadge(label: 'Active', color: AppColors.worker),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(job.description, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 10),
                                      // Price row with edit/set button
                                      Row(
                                        children: [
                                          if (job.agreedPrice != null) ...[
                                            GestureDetector(
                                              onTap: () => _setJobPrice(context, job),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.successLight,
                                                  borderRadius: BorderRadius.circular(7),
                                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
                                                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.15), offset: const Offset(2, 2), blurRadius: 0)],
                                                ),
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  const Icon(Icons.attach_money_rounded, size: 14, color: AppColors.success),
                                                  Text(job.agreedPrice!.toStringAsFixed(2),
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
                                                  const SizedBox(width: 5),
                                                  const Icon(Icons.edit_rounded, size: 12, color: AppColors.success),
                                                ]),
                                              ),
                                            ),
                                          ] else ...[
                                            GestureDetector(
                                              onTap: () => _setJobPrice(context, job),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warningLight,
                                                  borderRadius: BorderRadius.circular(7),
                                                  border: Border.all(color: AppColors.warning, width: 1.5),
                                                  boxShadow: [BoxShadow(color: AppColors.warning.withValues(alpha: 0.2), offset: const Offset(2, 2), blurRadius: 0)],
                                                ),
                                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                                  Icon(Icons.add_rounded, size: 14, color: AppColors.warning),
                                                  SizedBox(width: 4),
                                                  Text('Set Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                                                ]),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(_formatDate(job.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _SmallButton(label: 'Navigate', icon: Icons.directions_rounded, color: AppColors.info,
                                              onTap: () => _navigateToJob(context, job)),
                                          _SmallButton(label: 'Complete', icon: Icons.check_circle_rounded, color: AppColors.admin,
                                              onTap: () => _confirmAction(context, 'Complete Job', 'Mark this job as completed? The customer will be prompted to pay.', () async {
                                                await _updateJobStatus(job.id, AppConstants.jobStatusCompleted, job);
                                                if (modalContext.mounted) Navigator.pop(modalContext);
                                              })),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showRatingsModal() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .orderBy('createdAt', descending: true)
          .get();
      final reviews = snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
      if (!mounted) return;

      final Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final r in reviews) {
        ratingCounts[r.rating] = (ratingCounts[r.rating] ?? 0) + 1;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => Column(
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer Ratings',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 14),
                    WcCard(
                      backgroundColor: AppColors.warningLight,
                      borderColor: AppColors.rating.withValues(alpha: 0.4),
                      hasShadow: false,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Average Rating', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(_rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.rating, letterSpacing: -1)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.rating,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: Text(
                              '${reviews.length} reviews',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(5, (i) {
                      final stars = 5 - i;
                      final count = ratingCounts[stars] ?? 0;
                      final pct = reviews.isEmpty ? 0.0 : count / reviews.length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Text('$stars★', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.rating, fontSize: 13))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: AppColors.surfaceAlt,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rating),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(width: 24, child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: reviews.isEmpty
                    ? const WcEmptyState(icon: Icons.star_border_rounded, title: 'No reviews yet', subtitle: 'Reviews from customers will appear here.')
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: reviews.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return WcCard(
                            hasShadow: false,
                            borderColor: AppColors.borderLight,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Row(
                                      children: List.generate(5, (i) => Icon(
                                        i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 16,
                                        color: AppColors.rating,
                                      )),
                                    ),
                                    const Spacer(),
                                    Text(_formatDate(review.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                                if (review.comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(review.comment, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing ratings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ratings: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showEarningsModal() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', isEqualTo: AppConstants.jobStatusCompleted)
          .orderBy('completedAt', descending: true)
          .get();
      final jobs = snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();
      if (!mounted) return;

      double total = 0.0;
      for (final job in jobs) {
        if (job.agreedPrice != null) total += job.agreedPrice!;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => Column(
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Earnings', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: -1)),
                      ],
                    ),
                    const Spacer(),
                    WcStatusBadge(label: '${jobs.length} jobs', color: AppColors.success, filled: true),
                  ],
                ),
              ),
              Expanded(
                child: jobs.isEmpty
                    ? const WcEmptyState(icon: Icons.trending_up_rounded, title: 'No completed jobs yet', subtitle: 'Completed jobs and earnings will appear here.')
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: jobs.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return WcCard(
                            hasShadow: false,
                            borderColor: AppColors.borderLight,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(job.serviceType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(job.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      Text(_formatDate(job.completedAt ?? DateTime.now()), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '\$${(job.agreedPrice ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing earnings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading earnings: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Shared sheet helpers ──────────────────────────────────────────────────

  Widget _buildSheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
            ),
          ),
          WcStatusBadge(label: '$count', color: color),
        ],
      ),
    );
  }

  // ── Job update / navigation logic (unchanged) ────────────────────────────

  Future<void> _updateJobStatus(String jobId, String status, JobModel job) async {
    try {
      final docRef = _firestore.collection(AppConstants.jobsCollection).doc(jobId);
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == AppConstants.jobStatusInProgress || status == 'in_progress') {
        updates['workerId'] = widget.user.id;
        updates['acceptedAt'] = job.acceptedAt != null
            ? Timestamp.fromDate(job.acceptedAt!)
            : FieldValue.serverTimestamp();
      }
      if (status == AppConstants.jobStatusCompleted || status == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
        _stopLocationStream(jobId);
      }
      if (status == AppConstants.jobStatusCancelled || status == 'cancelled') {
        updates['cancelledAt'] = FieldValue.serverTimestamp();
        _stopLocationStream(jobId);
      }

      await docRef.update(updates);

      if (status == AppConstants.jobStatusInProgress || status == 'in_progress') {
        await _startLocationStream(jobId);
      }

      await _loadWorkerStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job updated')),
      );
    } catch (e) {
      debugPrint('Error updating job status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _startLocationStream(String jobId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
        return;
      }
      if (_locationSubscriptions.containsKey(jobId)) return;

      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10),
      ).listen((pos) async {
        try {
          await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
            'workerLocation': GeoPoint(pos.latitude, pos.longitude),
            'workerLocationUpdatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error writing location for job $jobId: $e');
        }
      });

      _locationSubscriptions[jobId] = stream;
    } catch (e) {
      debugPrint('Error starting location stream: $e');
    }
  }

  void _stopLocationStream(String jobId) {
    try {
      _locationSubscriptions[jobId]?.cancel();
      _locationSubscriptions.remove(jobId);
    } catch (e) {
      debugPrint('Error stopping location stream: $e');
    }
  }

  Future<void> _navigateToJob(BuildContext context, JobModel job) async {
    try {
      double lat = job.location.latitude;
      double lng = job.location.longitude;
      if ((lat == 0 && lng == 0) || lat.isNaN || lng.isNaN) {
        final places = await locationFromAddress(job.address);
        if (places.isNotEmpty) {
          lat = places.first.latitude;
          lng = places.first.longitude;
          await _firestore.collection(AppConstants.jobsCollection).doc(job.id).update({
            'location': GeoPoint(lat, lng),
            'locationResolvedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve address: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() onConfirm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirm();
  }

  void _showAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This feature is coming soon. You will be able to:'),
            const SizedBox(height: 14),
            ...[
              'Set working hours',
              'Mark availability for urgent jobs',
              'Schedule time off',
              'Set service areas',
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.worker, size: 16),
                  const SizedBox(width: 8),
                  Text(t, style: const TextStyle(fontSize: 14)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker hero button
// ─────────────────────────────────────────────────────────────────────────────
class _WorkerHeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _WorkerHeroButton({required this.label, required this.icon, required this.onTap});

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
            Icon(icon, size: 18, color: AppColors.worker),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: AppColors.worker, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small action button inside job cards
// ─────────────────────────────────────────────────────────────────────────────
class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
