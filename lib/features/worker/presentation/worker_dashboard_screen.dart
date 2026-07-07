import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/worker_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wc_components.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

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
        final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(user.uid).get();
        if (userDoc.exists) {
          _userProfile = UserModel.fromFirestore(userDoc);
          final workerQuery = await _firestore
              .collection(AppConstants.workersCollection)
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (workerQuery.docs.isNotEmpty) {
            _workerProfile = WorkerModel.fromFirestore(workerQuery.docs.first);
            _isOnline = _workerProfile!.isOnline;
          } else {
            await _createWorkerProfile(user.uid);
          }
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading worker profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createWorkerProfile(String userId) async {
    try {
      final newWorker = WorkerModel(
        id: '', userId: userId, skills: [], bio: '', hourlyRate: 0.0,
        isOnline: false, certificationImages: [], isVerified: false,
        totalJobs: 0, avgRating: 0.0, ratingCount: 0,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final docRef = await _firestore.collection(AppConstants.workersCollection).add(newWorker.toFirestore());
      _workerProfile = newWorker.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error creating worker profile: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_workerProfile == null) return;
    try {
      final newStatus = !_isOnline;
      await _firestore.collection(AppConstants.workersCollection).doc(_workerProfile!.id).update({
        'isOnline': newStatus, 'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _isOnline = newStatus;
        _workerProfile = _workerProfile!.copyWith(isOnline: newStatus);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'You are now online' : 'You are now offline'),
          backgroundColor: newStatus ? AppColors.success : AppColors.textSecondary,
        ),
      );
    } catch (e) {
      debugPrint('Error updating online status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating status'), backgroundColor: AppColors.error),
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
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        await _firestore.collection(AppConstants.workersCollection).doc(_workerProfile!.id).update({
          'location': GeoPoint(position.latitude, position.longitude),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated'), backgroundColor: AppColors.success),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating location'), backgroundColor: AppColors.error),
      );
    }
  }

  List<String> _parseSkills(String input) =>
      input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _saveProfileUpdates({
    required String skillsInput,
    required String bio,
    required String address,
    required String hourlyRateInput,
  }) async {
    if (_workerProfile == null) return;
    final skills = _parseSkills(skillsInput);
    final hourlyRate = double.tryParse(hourlyRateInput.trim());
    if (skills.isEmpty) throw Exception('Please add at least one skill');
    if (bio.trim().isEmpty) throw Exception('Please add a bio');
    if (hourlyRate == null || hourlyRate < 0) throw Exception('Please enter a valid hourly rate');

    final updated = _workerProfile!.copyWith(
      skills: skills,
      bio: bio.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
      hourlyRate: hourlyRate,
      updatedAt: DateTime.now(),
    );
    await _firestore
        .collection(AppConstants.workersCollection)
        .doc(_workerProfile!.id)
        .set(updated.toFirestore(), SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _workerProfile = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_workerProfile == null || _userProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Worker Dashboard')),
        body: const WcEmptyState(icon: Icons.error_outline_rounded, title: 'Error loading profile'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.successLight : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isOnline ? AppColors.success : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _isOnline ? AppColors.success : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _isOnline ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile card ───────────────────────────────────────────
            WcCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: _userProfile!.profileImageUrl != null
                            ? ClipOval(child: Image.network(_userProfile!.profileImageUrl!, fit: BoxFit.cover))
                            : const Icon(Icons.person_rounded, color: AppColors.primary, size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(_userProfile!.name,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                                ),
                                if (_workerProfile!.isVerified)
                                  WcStatusBadge(label: 'Verified', color: AppColors.info),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(_userProfile!.email,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            RatingDisplay(rating: _workerProfile!.avgRating, reviewCount: _workerProfile!.ratingCount, starSize: 16),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                WcStatusBadge(label: _isOnline ? 'Online' : 'Offline', color: _isOnline ? AppColors.success : AppColors.textMuted),
                                WcStatusBadge(label: '${_workerProfile!.totalJobs} jobs', color: AppColors.primary),
                                WcStatusBadge(label: '\$${_workerProfile!.hourlyRate.toStringAsFixed(0)}/hr', color: AppColors.info),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Profile details grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile Details',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ProfileTile(icon: Icons.phone_outlined, label: 'Phone',
                                value: _userProfile!.phone.isNotEmpty ? _userProfile!.phone : 'Not set'),
                            _ProfileTile(icon: Icons.location_on_outlined, label: 'Service Area',
                                value: _workerProfile!.address?.isNotEmpty == true ? _workerProfile!.address! : 'Not set'),
                            _ProfileTile(icon: Icons.workspace_premium_outlined, label: 'Certifications',
                                value: '${_workerProfile!.certificationImages.length}'),
                            _ProfileTile(icon: Icons.calendar_today_outlined, label: 'Joined',
                                value: _formatDate(_userProfile!.createdAt)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Skills
                  const Text('Skills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  _workerProfile!.skills.isEmpty
                      ? const Text('No skills added yet', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _workerProfile!.skills.map((skill) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Text(skill, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          )).toList(),
                        ),

                  const SizedBox(height: 16),

                  // Bio
                  const Text('About Me', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: Text(
                      _workerProfile!.bio.isEmpty ? 'No bio added yet' : _workerProfile!.bio,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _workerProfile!.bio.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: WcOutlinedButton(
                          label: _isOnline ? 'Go Offline' : 'Go Online',
                          icon: _isOnline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          borderColor: _isOnline ? AppColors.textSecondary : AppColors.success,
                          textColor: _isOnline ? AppColors.textSecondary : AppColors.success,
                          onPressed: _toggleOnlineStatus,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: WcPrimaryButton(
                          label: 'Update Location',
                          icon: Icons.my_location_rounded,
                          onPressed: _updateLocation,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Stats row ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: WcStatCard(
                    label: 'Jobs Completed',
                    value: '${_workerProfile!.totalJobs}',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WcStatCard(
                    label: 'Hourly Rate',
                    value: '\$${_workerProfile!.hourlyRate.toStringAsFixed(0)}',
                    icon: Icons.attach_money_rounded,
                    accentColor: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Profile completion prompt ──────────────────────────────
            if (_workerProfile!.skills.isEmpty || _workerProfile!.bio.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: WcNotice(
                  message: 'Complete your profile by adding skills and a bio to attract more customers.',
                  color: AppColors.warning,
                  icon: Icons.info_outline_rounded,
                ),
              ),

            // ── Edit button ────────────────────────────────────────────
            WcPrimaryButton(
              label: 'Edit Profile',
              icon: Icons.edit_rounded,
              width: double.infinity,
              onPressed: _showEditProfileDialog,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showEditProfileDialog() {
    if (_workerProfile == null) return;
    final skillsCtrl = TextEditingController(text: _workerProfile!.skills.join(', '));
    final bioCtrl = TextEditingController(text: _workerProfile!.bio);
    final addrCtrl = TextEditingController(text: _workerProfile!.address ?? '');
    final rateCtrl = TextEditingController(text: _workerProfile!.hourlyRate.toStringAsFixed(0));
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (isSaving) return;
            // Capture navigator/messenger before any async gap.
            final nav = Navigator.of(dialogContext);
            final messenger = ScaffoldMessenger.of(context);
            setDialogState(() => isSaving = true);
            try {
              await _saveProfileUpdates(
                skillsInput: skillsCtrl.text,
                bio: bioCtrl.text,
                address: addrCtrl.text,
                hourlyRateInput: rateCtrl.text,
              );
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
              );
            } finally {
              if (mounted) setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: skillsCtrl, decoration: const InputDecoration(labelText: 'Skills', hintText: 'Plumbing, Wiring, Repairs')),
                  const SizedBox(height: 12),
                  TextField(controller: bioCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell customers about your experience')),
                  const SizedBox(height: 12),
                  TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hourly Rate', prefixText: '\$', hintText: '25')),
                  const SizedBox(height: 12),
                  TextField(controller: addrCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Address / Service Area', hintText: 'City, neighborhood, or service area')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              WcPrimaryButton(
                label: 'Save',
                isLoading: isSaving,
                onPressed: isSaving ? null : save,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile info tile
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 80) / 2,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
