import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../../../data/models/bid_model.dart';
import '../../../../shared/widgets/wc_components.dart';
import '../../../../core/services/image_upload_service.dart';

class WorkerLandingPage extends StatefulWidget {
  final UserModel user;
  const WorkerLandingPage({super.key, required this.user});

  @override
  State<WorkerLandingPage> createState() => _WorkerLandingPageState();
}

class _WorkerLandingPageState extends State<WorkerLandingPage> {
  final AuthRepository _authRepository = AuthRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _locationTimers = {};

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
    for (final t in _locationTimers.values) { t.cancel(); }
    _locationTimers.clear();
    super.dispose();
  }

  Future<void> _loadWorkerStats() async {
    try {
      // My pending bids (not yet accepted by any customer)
      final pendingSnap = await _firestore
          .collection(AppConstants.bidsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', isEqualTo: AppConstants.bidStatusPending)
          .get();

      // Active jobs: customer accepted my bid (accepted) + already on the way (in_progress)
      final inProgressSnap = await _firestore
          .collection(AppConstants.jobsCollection)
          .where('workerId', isEqualTo: widget.user.id)
          .where('status', whereIn: [AppConstants.jobStatusAccepted, AppConstants.jobStatusInProgress])
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
          label: 'My Bids',
          value: '$_pendingJobs',
          icon: Icons.gavel_rounded,
          accentColor: AppColors.primary,
          subtitle: 'Awaiting response',
          badge: _pendingJobs > 0 ? WcStatusBadge(label: 'OPEN', color: AppColors.primary, filled: true) : null,
          onTap: _showMyBidsModal,
        ),
        WcStatCard(
          label: 'Active Jobs',
          value: '$_inProgressJobs',
          icon: Icons.directions_car_rounded,
          accentColor: AppColors.worker,
          subtitle: 'Accepted + on the way',
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
          title: 'My Bids',
          subtitle: 'Track jobs you have bid on',
          icon: Icons.gavel_rounded,
          iconColor: AppColors.primary,
          onTap: _showMyBidsModal,
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
          _buildTip(Icons.gavel_outlined,          'Place competitive bids quickly to win more jobs'),
          _buildTip(Icons.photo_camera_outlined,  'Upload photos of completed work to build trust'),
          _buildTip(Icons.star_border_rounded,    'Maintain a 4.5+ rating to win more bids'),
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

  // ── My Bids modal ─────────────────────────────────────────────────────────

  Future<void> _showMyBidsModal() async {
    final bidsSnap = await _firestore
        .collection(AppConstants.bidsCollection)
        .where('workerId', isEqualTo: widget.user.id)
        .where('status', isEqualTo: AppConstants.bidStatusPending)
        .orderBy('createdAt', descending: true)
        .get();

    final bids = bidsSnap.docs.map((doc) => BidModel.fromFirestore(doc)).toList();

    // Load associated job for each bid
    final List<Map<String, dynamic>> bidWithJobs = [];
    for (final bid in bids) {
      final jobDoc = await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(bid.jobId)
          .get();
      if (jobDoc.exists) {
        bidWithJobs.add({'bid': bid, 'job': JobModel.fromFirestore(jobDoc)});
      }
    }

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
              _buildSheetHeader('My Bids', bidWithJobs.length, AppColors.primary),
              Expanded(
                child: bidWithJobs.isEmpty
                    ? const WcEmptyState(
                        icon: Icons.gavel_outlined,
                        title: 'No pending bids',
                        subtitle: 'Find jobs on the map and place your bid.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: bidWithJobs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final bid = bidWithJobs[index]['bid'] as BidModel;
                          final job = bidWithJobs[index]['job'] as JobModel;
                          return _buildBidCard(
                            context: context,
                            bid: bid,
                            job: job,
                            onWithdraw: () async {
                              await _withdrawBid(bid.id);
                              setModalState(() => bidWithJobs.removeAt(index));
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

  Widget _buildBidCard({
    required BuildContext context,
    required BidModel bid,
    required JobModel job,
    required VoidCallback onWithdraw,
  }) {
    return WcCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primary,
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
                    Text(job.serviceType,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(job.address,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              WcStatusBadge(label: 'Bid Placed', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(job.description,
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.gavel_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 5),
                Text('Your Bid: \$${bid.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
              ]),
            ),
            const Spacer(),
            Text(_formatDate(bid.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
          if (bid.message != null && bid.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(bid.message!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _SmallButton(
              label: 'Navigate',
              icon: Icons.directions_rounded,
              color: AppColors.info,
              onTap: () => _navigateToJob(context, job),
            ),
            _SmallButton(
              label: 'Withdraw Bid',
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              onTap: () => _confirmAction(
                context,
                'Withdraw Bid',
                'Withdraw your bid of \$${bid.amount.toStringAsFixed(2)}?',
                () async => onWithdraw(),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _withdrawBid(String bidId) async {
    try {
      await _firestore
          .collection(AppConstants.bidsCollection)
          .doc(bidId)
          .update({'status': AppConstants.bidStatusWithdrawn});
      await _loadWorkerStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid withdrawn'), backgroundColor: AppColors.warning),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to withdraw bid: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _addJobImage(String jobId, List<String> currentUrls, {ImageSource source = ImageSource.gallery}) async {
    final path = await ImageUploadService.pickAndSave(source: source);
    if (path == null) return;
    final updated = [...currentUrls, path];
    await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
      'imageUrls': updated,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _removeJobImage(String jobId, List<String> currentUrls, int index) async {
    final path = currentUrls[index];
    final updated = [...currentUrls]..removeAt(index);
    await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
      'imageUrls': updated,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await ImageUploadService.deleteLocal(path);
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
              .where('status', whereIn: [
                AppConstants.jobStatusAccepted,
                AppConstants.jobStatusInProgress,
              ])
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final jobs = snapshot.hasData
                ? snapshot.data!.docs.map((d) => JobModel.fromFirestore(d)).toList()
                : <JobModel>[];
            return Column(
              children: [
                _buildSheetHandle(),
                _buildSheetHeader('Active Jobs', jobs.length, AppColors.worker),
                Expanded(
                  child: !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator(color: AppColors.worker))
                      : jobs.isEmpty
                          ? const WcEmptyState(
                              icon: Icons.directions_car_outlined,
                              title: 'No active jobs',
                              subtitle: 'Place bids on the map — accepted jobs appear here.',
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: jobs.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final job = jobs[index];
                                final isBidWon = job.status == AppConstants.jobStatusAccepted;
                                return WcCard(
                                  padding: const EdgeInsets.all(16),
                                  borderColor: isBidWon ? AppColors.success : AppColors.worker,
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
                                            label: isBidWon ? 'Bid Won!' : 'Active',
                                            color: isBidWon ? AppColors.success : AppColors.worker,
                                            filled: isBidWon,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(job.description,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                                          maxLines: 3, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 10),
                                      // Read-only agreed price (set when customer accepted the bid)
                                      Row(children: [
                                        if (job.agreedPrice != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.successLight,
                                              borderRadius: BorderRadius.circular(7),
                                              border: Border.all(
                                                  color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.attach_money_rounded,
                                                  size: 14, color: AppColors.success),
                                              Text(job.agreedPrice!.toStringAsFixed(2),
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.success)),
                                            ]),
                                          ),
                                        const Spacer(),
                                        Text(_formatDate(job.createdAt),
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      ]),
                                      const SizedBox(height: 12),
                                      // ── Job Photos ───────────────────────
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderLight, width: 1),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.photo_library_outlined, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                const Text('Job Photos',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                                const Spacer(),
                                                GestureDetector(
                                                  onTap: () => _addJobImage(job.id, job.imageUrls, source: ImageSource.camera),
                                                  child: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.worker),
                                                ),
                                                const SizedBox(width: 10),
                                                GestureDetector(
                                                  onTap: () => _addJobImage(job.id, job.imageUrls),
                                                  child: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: AppColors.worker),
                                                ),
                                              ],
                                            ),
                                            if (job.imageUrls.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 80,
                                                child: ListView.separated(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: job.imageUrls.length,
                                                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                                                  itemBuilder: (_, i) {
                                                    final path = job.imageUrls[i];
                                                    return Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: Image.file(
                                                            File(path),
                                                            width: 80,
                                                            height: 80,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, _, _) => Container(
                                                              width: 80, height: 80,
                                                              decoration: BoxDecoration(
                                                                color: AppColors.surfaceAlt,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                                                            ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 2, right: 2,
                                                          child: GestureDetector(
                                                            onTap: () => _removeJobImage(job.id, job.imageUrls, i),
                                                            child: Container(
                                                              padding: const EdgeInsets.all(2),
                                                              decoration: const BoxDecoration(
                                                                color: AppColors.error,
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ] else
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(
                                                  'Tap the icons above to add photos',
                                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (isBidWon)
                                            _SmallButton(
                                              label: 'On the Way',
                                              icon: Icons.navigation_rounded,
                                              color: AppColors.info,
                                              onTap: () => _updateJobStatus(
                                                  job.id, AppConstants.jobStatusInProgress, job),
                                            ),
                                          _SmallButton(
                                            label: 'Navigate',
                                            icon: Icons.directions_rounded,
                                            color: AppColors.info,
                                            onTap: () => _navigateToJob(context, job),
                                          ),
                                          _SmallButton(
                                            label: 'Complete',
                                            icon: Icons.check_circle_rounded,
                                            color: AppColors.admin,
                                            onTap: () => _confirmAction(
                                              context,
                                              'Complete Job',
                                              'Mark this job as completed? The customer will be prompted to pay.',
                                              () async {
                                                await _updateJobStatus(
                                                    job.id, AppConstants.jobStatusCompleted, job);
                                                if (modalContext.mounted) Navigator.pop(modalContext);
                                              },
                                            ),
                                          ),
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

  Future<void> _pushLocationForJob(String jobId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
        'workerLocation': GeoPoint(pos.latitude, pos.longitude),
        'workerLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error writing location for job $jobId: $e');
    }
  }

  Future<void> _startLocationStream(String jobId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
        return;
      }
      if (_locationTimers.containsKey(jobId)) return;

      // Push immediately, then every 5 seconds
      await _pushLocationForJob(jobId);
      _locationTimers[jobId] = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pushLocationForJob(jobId),
      );
    } catch (e) {
      debugPrint('Error starting location timer: $e');
    }
  }

  void _stopLocationStream(String jobId) {
    _locationTimers[jobId]?.cancel();
    _locationTimers.remove(jobId);
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
