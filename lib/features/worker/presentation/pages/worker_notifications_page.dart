import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter tabs
// ─────────────────────────────────────────────────────────────────────────────
enum _NotifFilter { all, newJobs, active, done }

extension _NotifFilterExt on _NotifFilter {
  String get label {
    switch (this) {
      case _NotifFilter.all:     return 'All';
      case _NotifFilter.newJobs: return 'New Jobs';
      case _NotifFilter.active:  return 'Active';
      case _NotifFilter.done:    return 'Done';
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifFilter.all:     return Icons.notifications_outlined;
      case _NotifFilter.newJobs: return Icons.fiber_new_rounded;
      case _NotifFilter.active:  return Icons.directions_car_outlined;
      case _NotifFilter.done:    return Icons.check_circle_outline_rounded;
    }
  }

  bool matches(String status) {
    switch (this) {
      case _NotifFilter.all:     return true;
      case _NotifFilter.newJobs: return status == AppConstants.jobStatusRequested;
      case _NotifFilter.active:  return status == AppConstants.jobStatusAccepted ||
                                        status == AppConstants.jobStatusInProgress;
      case _NotifFilter.done:    return status == AppConstants.jobStatusCompleted ||
                                        status == AppConstants.jobStatusCancelled;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WorkerNotificationsPage
// ─────────────────────────────────────────────────────────────────────────────
class WorkerNotificationsPage extends StatefulWidget {
  final UserModel worker;
  const WorkerNotificationsPage({super.key, required this.worker});

  @override
  State<WorkerNotificationsPage> createState() => _WorkerNotificationsPageState();
}

class _WorkerNotificationsPageState extends State<WorkerNotificationsPage> {
  _NotifFilter _filter = _NotifFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Filter tabs ─────────────────────────────────────────────
          _FilterBar(
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          Container(height: 1, color: AppColors.borderLight),

          // ── Notification list ───────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.jobsCollection)
                  .where('workerId', isEqualTo: widget.worker.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeleton();
                }

                if (snapshot.hasError) {
                  return WcEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load',
                    subtitle: 'Could not fetch notifications.',
                  );
                }

                final allJobs = snapshot.data?.docs
                        .map((d) => JobModel.fromFirestore(d))
                        .toList() ??
                    [];

                allJobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                final filtered = allJobs.where((j) => _filter.matches(j.status)).toList();

                if (filtered.isEmpty) {
                  return WcEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: _filter == _NotifFilter.all
                        ? 'No notifications yet'
                        : 'No ${_filter.label.toLowerCase()} notifications',
                    subtitle: 'Job updates will appear here in real time.',
                  );
                }

                // Group by date
                final groups = _groupByDate(filtered);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final group = groups[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),
                          child: Row(
                            children: [
                              Text(
                                group.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Container(height: 1, color: AppColors.borderLight)),
                              const SizedBox(width: 10),
                              WcStatusBadge(
                                label: '${group.jobs.length}',
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        // Notification cards
                        ...group.jobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotificationCard(job: job),
                        )),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WcCard(
            hasShadow: false,
            borderColor: AppColors.borderLight,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WcSkeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(10))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      WcSkeleton(width: 140, height: 13),
                      SizedBox(height: 8),
                      WcSkeleton(width: double.infinity, height: 11),
                      SizedBox(height: 5),
                      WcSkeleton(width: 100, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<JobModel> jobs) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));

    final Map<String, List<JobModel>> map = {};

    for (final job in jobs) {
      final d = DateTime(job.updatedAt.year, job.updatedAt.month, job.updatedAt.day);
      final String key;
      if (d == today) {
        key = 'TODAY';
      } else if (d == yest) {
        key = 'YESTERDAY';
      } else {
        key = 'EARLIER';
      }
      (map[key] ??= []).add(job);
    }

    final result = <_DateGroup>[];
    for (final k in ['TODAY', 'YESTERDAY', 'EARLIER']) {
      if (map.containsKey(k)) result.add(_DateGroup(label: k, jobs: map[k]!));
    }
    return result;
  }
}

class _DateGroup {
  final String label;
  final List<JobModel> jobs;
  const _DateGroup({required this.label, required this.jobs});
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final _NotifFilter selected;
  final ValueChanged<_NotifFilter> onSelect;

  const _FilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _NotifFilter.values.map((f) {
          final isSelected = f == selected;
          final color = _filterColor(f);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderLight,
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.25), offset: const Offset(2, 2), blurRadius: 0)]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.icon, size: 14,
                        color: isSelected ? color : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _filterColor(_NotifFilter f) {
    switch (f) {
      case _NotifFilter.all:     return AppColors.primary;
      case _NotifFilter.newJobs: return AppColors.primary;
      case _NotifFilter.active:  return AppColors.worker;
      case _NotifFilter.done:    return AppColors.admin;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final JobModel job;
  const _NotificationCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(job.status);
    final statusIcon  = _statusIcon(job.status);
    final statusTitle = _statusTitle(job.status);
    final isNew       = job.status == AppConstants.jobStatusRequested;
    final timeLabel   = _formatTime(job.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left:   BorderSide(color: statusColor, width: 3),
          top:    BorderSide(color: AppColors.borderLight, width: 1),
          right:  BorderSide(color: AppColors.borderLight, width: 1),
          bottom: BorderSide(color: AppColors.borderLight, width: 1),
        ),
        boxShadow: isNew
            ? [BoxShadow(color: statusColor.withValues(alpha: 0.12), offset: const Offset(2, 2), blurRadius: 0)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          statusTitle,
                          style: TextStyle(
                            fontWeight: isNew ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isNew)
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 1.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.work_outline_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.serviceType,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.address,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Price + time row
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (job.agreedPrice != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(
                            '\$${job.agreedPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(timeLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case AppConstants.jobStatusRequested:   return AppColors.primary;
      case AppConstants.jobStatusAccepted:    return AppColors.worker;
      case AppConstants.jobStatusInProgress:  return AppColors.info;
      case AppConstants.jobStatusCompleted:   return AppColors.admin;
      case AppConstants.jobStatusCancelled:   return AppColors.error;
      default:                                return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case AppConstants.jobStatusRequested:   return Icons.notifications_active_rounded;
      case AppConstants.jobStatusAccepted:    return Icons.check_circle_outline_rounded;
      case AppConstants.jobStatusInProgress:  return Icons.directions_car_rounded;
      case AppConstants.jobStatusCompleted:   return Icons.verified_rounded;
      case AppConstants.jobStatusCancelled:   return Icons.cancel_outlined;
      default:                                return Icons.notifications_outlined;
    }
  }

  String _statusTitle(String s) {
    switch (s) {
      case AppConstants.jobStatusRequested:   return 'New Job Request';
      case AppConstants.jobStatusAccepted:    return 'Job Accepted';
      case AppConstants.jobStatusInProgress:  return 'Job In Progress';
      case AppConstants.jobStatusCompleted:   return 'Job Completed';
      case AppConstants.jobStatusCancelled:   return 'Job Cancelled';
      default:                                return 'Job Update';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
