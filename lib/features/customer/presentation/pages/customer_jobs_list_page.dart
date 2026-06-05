import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/job_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scope enum (unchanged — keeps all existing call sites working)
// ─────────────────────────────────────────────────────────────────────────────
enum CustomerJobsScope { all, pending, completed, history }

// ─────────────────────────────────────────────────────────────────────────────
// CustomerJobsListPage
// ─────────────────────────────────────────────────────────────────────────────
class CustomerJobsListPage extends StatefulWidget {
  final String            title;
  final String            customerId;
  final CustomerJobsScope scope;

  const CustomerJobsListPage({
    super.key,
    required this.title,
    required this.customerId,
    required this.scope,
  });

  @override
  State<CustomerJobsListPage> createState() => _CustomerJobsListPageState();
}

class _CustomerJobsListPageState extends State<CustomerJobsListPage> {
  // Active secondary filter (within the parent scope)
  _JobFilter _filter = _JobFilter.all;

  // ── Cancel a job ──────────────────────────────────────────────────────────
  Future<void> _cancelJob(BuildContext context, String jobId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this job request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.jobsCollection)
          .doc(jobId)
          .update({
        'status': AppConstants.jobStatusCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job request cancelled'), backgroundColor: AppColors.warning),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection(AppConstants.jobsCollection)
        .where('customerId', isEqualTo: widget.customerId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: base.snapshots(),
        builder: (context, snapshot) {
          // ── Loading ───────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton();
          }

          // ── Error ─────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return WcEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load jobs',
              subtitle: 'Check your connection and try again.',
            );
          }

          // ── Data ──────────────────────────────────────────────────────
          final all = snapshot.data?.docs
                  .map((d) => JobModel.fromFirestore(d))
                  .toList() ??
              [];

          // Apply parent scope first
          final scoped = all.where(_matchesScope).toList();

          // Count badges for the filter bar
          final counts = {
            for (final f in _JobFilter.values)
              f: scoped.where((j) => f.matches(j.status)).length,
          };

          // Apply secondary filter
          final filtered = scoped.where((j) => _filter.matches(j.status)).toList();
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            children: [
              // ── Stats summary ──────────────────────────────────────
              if (scoped.isNotEmpty) _StatsSummary(jobs: scoped),

              // ── Filter bar ─────────────────────────────────────────
              _FilterBar(
                selected:   _filter,
                counts:     counts,
                onSelect:   (f) => setState(() => _filter = f),
              ),
              Container(height: 1, color: AppColors.borderLight),

              // ── List ───────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? WcEmptyState(
                        icon: _emptyIcon(_filter),
                        title: _emptyTitle(_filter),
                        subtitle: 'Jobs matching this filter will appear here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groupByDate(filtered).length,
                        itemBuilder: (context, gi) {
                          final group = _groupByDate(filtered)[gi];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, top: 4),
                                child: Row(children: [
                                  Text(group.label,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2, color: AppColors.textSecondary)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Container(height: 1, color: AppColors.borderLight)),
                                  const SizedBox(width: 10),
                                  WcStatusBadge(label: '${group.jobs.length}', color: AppColors.textSecondary),
                                ]),
                              ),
                              // Job cards
                              ...group.jobs.map((job) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _JobCard(
                                  job: job,
                                  onCancel: () => _cancelJob(context, job.id),
                                ),
                              )),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _matchesScope(JobModel job) {
    switch (widget.scope) {
      case CustomerJobsScope.pending:
        return job.status == AppConstants.jobStatusRequested ||
               job.status == AppConstants.jobStatusAccepted ||
               job.status == AppConstants.jobStatusInProgress;
      case CustomerJobsScope.completed:
        return job.status == AppConstants.jobStatusCompleted;
      case CustomerJobsScope.history:
        return job.status == AppConstants.jobStatusCompleted ||
               job.status == AppConstants.jobStatusCancelled;
      case CustomerJobsScope.all:
        return true;
    }
  }

  List<_DateGroup> _groupByDate(List<JobModel> jobs) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    final week  = today.subtract(const Duration(days: 7));

    final Map<String, List<JobModel>> map = {};
    for (final job in jobs) {
      final d = DateTime(job.createdAt.year, job.createdAt.month, job.createdAt.day);
      final String key;
      if (d == today) {
        key = 'TODAY';
      } else if (d == yest) {
        key = 'YESTERDAY';
      } else if (d.isAfter(week)) {
        key = 'THIS WEEK';
      } else {
        key = 'EARLIER';
      }
      (map[key] ??= []).add(job);
    }

    final result = <_DateGroup>[];
    for (final k in ['TODAY', 'YESTERDAY', 'THIS WEEK', 'EARLIER']) {
      if (map.containsKey(k)) {
        result.add(_DateGroup(label: k, jobs: map[k]!));
      }
    }
    return result;
  }

  IconData _emptyIcon(_JobFilter f) {
    switch (f) {
      case _JobFilter.active:    return Icons.pending_actions_rounded;
      case _JobFilter.completed: return Icons.check_circle_outline_rounded;
      case _JobFilter.cancelled: return Icons.cancel_outlined;
      default:                   return Icons.receipt_long_outlined;
    }
  }

  String _emptyTitle(_JobFilter f) {
    switch (f) {
      case _JobFilter.active:    return 'No active jobs';
      case _JobFilter.completed: return 'No completed jobs';
      case _JobFilter.cancelled: return 'No cancelled jobs';
      default:                   return 'No jobs found';
    }
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WcCard(
            hasShadow: false,
            borderColor: AppColors.borderLight,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              WcSkeleton(width: 120, height: 14),
              SizedBox(height: 10),
              WcSkeleton(width: double.infinity, height: 11),
              SizedBox(height: 6),
              WcSkeleton(width: 200, height: 11),
              SizedBox(height: 14),
              WcSkeleton(width: double.infinity, height: 8),
            ]),
          ),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary filter enum
// ─────────────────────────────────────────────────────────────────────────────
enum _JobFilter { all, active, completed, cancelled }

extension _JobFilterExt on _JobFilter {
  String get label {
    switch (this) {
      case _JobFilter.all:       return 'All';
      case _JobFilter.active:    return 'Active';
      case _JobFilter.completed: return 'Done';
      case _JobFilter.cancelled: return 'Cancelled';
    }
  }

  IconData get icon {
    switch (this) {
      case _JobFilter.all:       return Icons.list_rounded;
      case _JobFilter.active:    return Icons.schedule_rounded;
      case _JobFilter.completed: return Icons.check_circle_outline_rounded;
      case _JobFilter.cancelled: return Icons.cancel_outlined;
    }
  }

  Color get color {
    switch (this) {
      case _JobFilter.all:       return AppColors.primary;
      case _JobFilter.active:    return AppColors.info;
      case _JobFilter.completed: return AppColors.success;
      case _JobFilter.cancelled: return AppColors.error;
    }
  }

  bool matches(String status) {
    switch (this) {
      case _JobFilter.all:       return true;
      case _JobFilter.active:
        return status == AppConstants.jobStatusRequested ||
               status == AppConstants.jobStatusAccepted  ||
               status == AppConstants.jobStatusInProgress;
      case _JobFilter.completed: return status == AppConstants.jobStatusCompleted;
      case _JobFilter.cancelled: return status == AppConstants.jobStatusCancelled;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats summary strip
// ─────────────────────────────────────────────────────────────────────────────
class _StatsSummary extends StatelessWidget {
  final List<JobModel> jobs;
  const _StatsSummary({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final active    = jobs.where((j) => _JobFilter.active.matches(j.status)).length;
    final completed = jobs.where((j) => j.status == AppConstants.jobStatusCompleted).length;
    final total     = jobs.length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _StatPill(value: '$total',     label: 'Total',     color: AppColors.primary),
          const SizedBox(width: 10),
          _StatPill(value: '$active',    label: 'Active',    color: AppColors.info),
          const SizedBox(width: 10),
          _StatPill(value: '$completed', label: 'Completed', color: AppColors.success),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _StatPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final _JobFilter                  selected;
  final Map<_JobFilter, int>        counts;
  final ValueChanged<_JobFilter>    onSelect;

  const _FilterBar({required this.selected, required this.counts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _JobFilter.values.map((f) {
          final isSel = f == selected;
          final color = f.color;
          final count = counts[f] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? color.withValues(alpha: 0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSel ? color : AppColors.borderLight, width: isSel ? 2 : 1.5),
                  boxShadow: isSel
                      ? [BoxShadow(color: color.withValues(alpha: 0.2), offset: const Offset(2, 2), blurRadius: 0)]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.icon, size: 13, color: isSel ? color : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(f.label,
                      style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? color : AppColors.textSecondary)),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSel ? color : AppColors.textMuted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : AppColors.textMuted)),
                    ),
                  ],
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date group model
// ─────────────────────────────────────────────────────────────────────────────
class _DateGroup {
  final String         label;
  final List<JobModel> jobs;
  const _DateGroup({required this.label, required this.jobs});
}

// ─────────────────────────────────────────────────────────────────────────────
// Job card
// ─────────────────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final JobModel     job;
  final VoidCallback onCancel;

  const _JobCard({required this.job, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(job.status);
    final statusLabel = _statusLabel(job.status);
    final isActive    = job.status == AppConstants.jobStatusRequested ||
                        job.status == AppConstants.jobStatusAccepted  ||
                        job.status == AppConstants.jobStatusInProgress;
    final isCompleted = job.status == AppConstants.jobStatusCompleted;
    final isCancelled = job.status == AppConstants.jobStatusCancelled;

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
        boxShadow: isActive
            ? [BoxShadow(color: statusColor.withValues(alpha: 0.1), offset: const Offset(2, 2), blurRadius: 0)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Text(job.serviceType,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              WcStatusBadge(label: statusLabel, color: statusColor, filled: isActive),
            ]),

            const SizedBox(height: 6),

            // ── Location ──────────────────────────────────────────────
            if (job.address.isNotEmpty)
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(job.address,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ]),

            const SizedBox(height: 6),

            // ── Description ───────────────────────────────────────────
            Text(job.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),

            // ── Progress stepper (active only) ────────────────────────
            if (isActive) ...[
              const SizedBox(height: 12),
              _JobProgressStepper(status: job.status),
            ],

            const SizedBox(height: 12),

            // ── Footer row ────────────────────────────────────────────
            Row(children: [
              if (job.agreedPrice != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    '\$${job.agreedPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Payment status chip
              if (isCompleted)
                job.isPaid
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            job.paymentMethod == 'cash' ? Icons.payments_outlined : Icons.credit_card_rounded,
                            size: 12, color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.paymentMethod == 'cash' ? 'Paid — Cash' : 'Paid — Card',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                          ),
                        ]),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Text('Payment pending',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                      ),
              const Spacer(),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(_formatTime(job.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ]),

            // ── Cancel action (active jobs) ───────────────────────────
            if (isActive && !isCancelled) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onCancel,
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                    SizedBox(width: 5),
                    Text('Cancel Request',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case AppConstants.jobStatusRequested:   return AppColors.primary;
      case AppConstants.jobStatusAccepted:    return AppColors.success;
      case AppConstants.jobStatusInProgress:  return AppColors.info;
      case AppConstants.jobStatusCompleted:   return AppColors.admin;
      case AppConstants.jobStatusCancelled:   return AppColors.error;
      default:                                return AppColors.textSecondary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case AppConstants.jobStatusRequested:   return 'Waiting';
      case AppConstants.jobStatusAccepted:    return 'Accepted';
      case AppConstants.jobStatusInProgress:  return 'In Progress';
      case AppConstants.jobStatusCompleted:   return 'Completed';
      case AppConstants.jobStatusCancelled:   return 'Cancelled';
      default:                                return 'Unknown';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact job progress stepper
// ─────────────────────────────────────────────────────────────────────────────
class _JobProgressStepper extends StatelessWidget {
  final String status;

  static const _steps = [
    ('Requested',  Icons.send_rounded,           AppConstants.jobStatusRequested),
    ('Accepted',   Icons.check_circle_outline_rounded, AppConstants.jobStatusAccepted),
    ('On the Way', Icons.directions_car_rounded,  AppConstants.jobStatusInProgress),
    ('Done',       Icons.verified_rounded,        AppConstants.jobStatusCompleted),
  ];

  static const _stepColors = [AppColors.primary, AppColors.success, AppColors.info, AppColors.admin];

  const _JobProgressStepper({required this.status});

  int get _currentIndex {
    switch (status) {
      case AppConstants.jobStatusAccepted:   return 1;
      case AppConstants.jobStatusInProgress: return 2;
      case AppConstants.jobStatusCompleted:  return 3;
      default:                               return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = _currentIndex;
    return Row(
      children: List.generate(_steps.length, (i) {
        final isActive = i <= cur;
        final isLast   = i == _steps.length - 1;
        final color    = isActive ? _stepColors[i] : AppColors.borderLight;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: isActive ? color : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Icon(_steps[i].$2, size: 12,
                        color: isActive ? Colors.white : AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(_steps[i].$1,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? color : AppColors.textMuted,
                      )),
                ]),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 12, height: 1.5,
                    color: i < cur ? _stepColors[i] : AppColors.borderLight,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
