import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/worker_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wc_components.dart';

class WorkerListScreen extends StatefulWidget {
  final String? serviceFilter;
  final bool emergencyOnly;

  const WorkerListScreen({
    super.key,
    this.serviceFilter,
    this.emergencyOnly = false,
  });

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  Position? _currentPosition;

  static const Map<String, List<String>> _categoryKeywords = {
    'Plumber':         ['plumber', 'plumbing'],
    'Electrician':     ['electrician', 'electrical', 'wiring'],
    'Mechanic':        ['mechanic', 'mechanical', 'auto', 'vehicle'],
    'Technician':      ['technician', 'technical', 'tech'],
    'Carpenter':       ['carpenter', 'carpentry', 'woodwork'],
    'Painter':         ['painter', 'painting'],
    'Cleaner':         ['cleaner', 'cleaning', 'housekeeping'],
    'Gardener':        ['gardener', 'gardening', 'landscaping'],
    'AC Repair':       ['ac repair', 'air conditioning', 'hvac'],
    'Appliance Repair':['appliance repair', 'appliance', 'repair'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.serviceFilter != null) _selectedCategory = widget.serviceFilter!;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection(AppConstants.workersCollection).get();
      final workers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final worker = WorkerModel.fromFirestore(doc);
        if (!_matchesSelectedCategory(worker)) continue;

        final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(worker.userId).get();
        if (!userDoc.exists) continue;

        final user = UserModel.fromFirestore(userDoc);
        double? distance;
        if (_currentPosition != null && worker.location != null) {
          distance = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            worker.location!.latitude, worker.location!.longitude,
          ) / 1000;
        }
        workers.add({'worker': worker, 'user': user, 'distance': distance});
      }

      workers.sort((a, b) {
        if (a['distance'] != null && b['distance'] != null) {
          return (a['distance'] as double).compareTo(b['distance'] as double);
        }
        return (b['worker'] as WorkerModel).avgRating
            .compareTo((a['worker'] as WorkerModel).avgRating);
      });

      if (mounted) setState(() { _workers = workers; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading workers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _matchesSelectedCategory(WorkerModel worker) {
    if (_selectedCategory == 'All') return true;
    final selected = _selectedCategory.toLowerCase();
    final keywords = <String>{
      selected,
      ...?_categoryKeywords[_selectedCategory]?.map((v) => v.toLowerCase()),
    };
    final haystack = [worker.skills.join(' '), worker.bio, worker.address ?? '']
        .join(' ')
        .toLowerCase();
    return keywords.any(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find Workers'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Category filter chips ────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: AppConstants.serviceCategories.length + 1,
                itemBuilder: (context, index) {
                  final cat = index == 0 ? 'All' : AppConstants.serviceCategories[index - 1];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() { _selectedCategory = cat; _isLoading = true; });
                        _loadWorkers();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppColors.border : AppColors.borderLight,
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [const BoxShadow(color: AppColors.shadow, offset: Offset(2, 2), blurRadius: 0)]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(height: 1, color: AppColors.borderLight),

          // ── Worker list ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _workers.isEmpty
                    ? WcEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No workers found',
                        subtitle: 'Try a different category or check back later.',
                        action: WcOutlinedButton(
                          label: 'Show All',
                          icon: Icons.people_outline_rounded,
                          onPressed: () {
                            setState(() { _selectedCategory = 'All'; _isLoading = true; });
                            _loadWorkers();
                          },
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _workers.length,
                        itemBuilder: (context, index) {
                          final data     = _workers[index];
                          final worker   = data['worker'] as WorkerModel;
                          final user     = data['user']   as UserModel;
                          final distance = data['distance'] as double?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _WorkerCard(
                              worker: worker,
                              user: user,
                              distance: distance,
                              onTap: () => _showWorkerDetails(context, worker, user),
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
          color: AppColors.surface,
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Header
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
                          child: user.profileImageUrl != null
                              ? ClipOval(child: Image.network(user.profileImageUrl!, fit: BoxFit.cover))
                              : const Icon(Icons.person_rounded, color: AppColors.primary, size: 36),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                              const SizedBox(height: 6),
                              RatingDisplay(rating: worker.avgRating, reviewCount: worker.ratingCount, starSize: 16),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('\$${worker.hourlyRate.toStringAsFixed(0)}/hr',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  const SizedBox(width: 10),
                                  WcStatusBadge(
                                    label: worker.isOnline ? 'Online' : 'Offline',
                                    color: worker.isOnline ? AppColors.success : AppColors.textMuted,
                                    filled: worker.isOnline,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Container(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // Skills
                    const Text('Skills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: worker.skills.map((skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Text(skill, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      )).toList(),
                    ),

                    if (worker.bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(worker.bio, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                    ],

                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: WcStatCard(
                            label: 'Jobs Completed',
                            value: '${worker.totalJobs}',
                            icon: Icons.check_circle_outline_rounded,
                            accentColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: WcStatCard(
                            label: 'Avg Rating',
                            value: worker.avgRating.toStringAsFixed(1),
                            icon: Icons.star_outline_rounded,
                            accentColor: AppColors.rating,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    WcPrimaryButton(
                      label: 'Contact Worker',
                      icon: Icons.message_outlined,
                      width: double.infinity,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact feature coming soon.')),
                        );
                      },
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker card
// ─────────────────────────────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final UserModel user;
  final double? distance;
  final VoidCallback onTap;

  const _WorkerCard({
    required this.worker,
    required this.user,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WcCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: user.profileImageUrl != null
                ? ClipOval(child: Image.network(user.profileImageUrl!, fit: BoxFit.cover))
                : const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  worker.skills.take(2).join(', '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RatingDisplay(rating: worker.avgRating, reviewCount: worker.ratingCount, starSize: 14),
                    if (distance != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text('${distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
                if (worker.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(worker.bio,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),

          // Rate + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${worker.hourlyRate.toStringAsFixed(0)}/hr',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 6),
              WcStatusBadge(
                label: worker.isOnline ? 'Online' : 'Offline',
                color: worker.isOnline ? AppColors.success : AppColors.textMuted,
                filled: worker.isOnline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
