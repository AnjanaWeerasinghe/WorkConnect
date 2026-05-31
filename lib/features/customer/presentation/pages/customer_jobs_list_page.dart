import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/job_model.dart';

enum CustomerJobsScope {
  all,
  pending,
  completed,
  history,
}

class CustomerJobsListPage extends StatelessWidget {
  final String title;
  final String customerId;
  final CustomerJobsScope scope;

  const CustomerJobsListPage({super.key, required this.title, required this.customerId, required this.scope});

  Future<void> _cancelJob(BuildContext context, String jobId) async {
    try {
      await FirebaseFirestore.instance.collection(AppConstants.jobsCollection).doc(jobId).update({
        'status': AppConstants.jobStatusCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job request cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final base = firestore.collection(AppConstants.jobsCollection).where('customerId', isEqualTo: customerId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: base.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading jobs\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final jobs = snapshot.data?.docs.map((d) => JobModel.fromFirestore(d)).where(_matchesScope).toList() ?? [];
          if (jobs.isEmpty) return Center(child: Text('No jobs found'));

          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: jobs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final job = jobs[i];
              final statusColor = _colorForStatus(job.status);
              final canCancel = job.status == AppConstants.jobStatusRequested || job.status == AppConstants.jobStatusAccepted || job.status == AppConstants.jobStatusInProgress;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(job.serviceType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)), child: Text(_labelForStatus(job.status), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 8),
                  Text(job.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(job.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (job.agreedPrice != null) Text('\$${job.agreedPrice!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(_formatJobTime(job.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ]),
                  if (canCancel)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Cancel job request'),
                                content: const Text('Do you want to cancel this job request?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );

                            if (ok == true) {
                              await _cancelJob(context, job.id);
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel Request'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                    ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  bool _matchesScope(JobModel job) {
    switch (scope) {
      case CustomerJobsScope.pending:
        return job.status == AppConstants.jobStatusRequested || job.status == AppConstants.jobStatusAccepted || job.status == AppConstants.jobStatusInProgress;
      case CustomerJobsScope.completed:
        return job.status == AppConstants.jobStatusCompleted;
      case CustomerJobsScope.history:
        return job.status == AppConstants.jobStatusCompleted || job.status == AppConstants.jobStatusCancelled;
      case CustomerJobsScope.all:
      default:
        return true;
    }
  }

  Color _colorForStatus(String status) {
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

  String _labelForStatus(String status) {
    switch (status) {
      case AppConstants.jobStatusAccepted:
        return 'Accepted';
      case AppConstants.jobStatusInProgress:
        return 'In Progress';
      case AppConstants.jobStatusCompleted:
        return 'Completed';
      case AppConstants.jobStatusRequested:
      default:
        return 'Requested';
    }
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
}
