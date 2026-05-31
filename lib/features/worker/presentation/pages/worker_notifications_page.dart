import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/user_model.dart';

class WorkerNotificationsPage extends StatelessWidget {
  final UserModel worker;

  const WorkerNotificationsPage({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection(AppConstants.jobsCollection)
            .where('workerId', isEqualTo: worker.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading notifications\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final jobs = snapshot.data?.docs.map((doc) => JobModel.fromFirestore(doc)).toList() ?? [];
          jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final notifications = <_WorkerNotificationItem>[];
          for (final job in jobs) {
            notifications.add(_WorkerNotificationItem(
              title: _titleForStatus(job.status),
              message: '${job.serviceType} · ${job.address}',
              timeLabel: _formatTime(job.updatedAt),
              color: _colorForStatus(job.status),
              icon: _iconForStatus(job.status),
            ));
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New job updates will appear here.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return Container(
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Text(
                                item.timeLabel,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.message,
                            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _titleForStatus(String status) {
    switch (status) {
      case AppConstants.jobStatusRequested:
        return 'New job request';
      case AppConstants.jobStatusAccepted:
        return 'Job accepted';
      case AppConstants.jobStatusInProgress:
        return 'Job in progress';
      case AppConstants.jobStatusCompleted:
        return 'Job completed';
      case AppConstants.jobStatusCancelled:
        return 'Job cancelled';
      default:
        return 'Job update';
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case AppConstants.jobStatusRequested:
        return Colors.orange;
      case AppConstants.jobStatusAccepted:
        return Colors.green;
      case AppConstants.jobStatusInProgress:
        return Colors.blue;
      case AppConstants.jobStatusCompleted:
        return Colors.purple;
      case AppConstants.jobStatusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case AppConstants.jobStatusRequested:
        return Icons.notifications_active_outlined;
      case AppConstants.jobStatusAccepted:
        return Icons.check_circle_outline;
      case AppConstants.jobStatusInProgress:
        return Icons.directions_car_outlined;
      case AppConstants.jobStatusCompleted:
        return Icons.verified_outlined;
      case AppConstants.jobStatusCancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime dateTime) {
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

class _WorkerNotificationItem {
  final String title;
  final String message;
  final String timeLabel;
  final Color color;
  final IconData icon;

  _WorkerNotificationItem({
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.color,
    required this.icon,
  });
}
