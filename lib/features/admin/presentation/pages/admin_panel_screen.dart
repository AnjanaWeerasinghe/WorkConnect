import 'package:flutter/material.dart';
import '../../../../data/models/worker_registration_model.dart';
import '../../../../data/repositories/worker_registration_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WorkerRegistrationRepository _registrationRepo = WorkerRegistrationRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Rejected', icon: Icon(Icons.cancel)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistrationList(WorkerApprovalStatus.pending),
          _buildRegistrationList(WorkerApprovalStatus.approved),
          _buildRegistrationList(WorkerApprovalStatus.rejected),
        ],
      ),
    );
  }

  Widget _buildRegistrationList(WorkerApprovalStatus status) {
    return StreamBuilder<List<WorkerRegistrationModel>>(
      stream: _registrationRepo.getAllRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allRegistrations = snapshot.data ?? [];
        final filteredRegistrations = allRegistrations
            .where((reg) => reg.status == status)
            .toList();

        if (filteredRegistrations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyIcon(status),
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  _getEmptyMessage(status),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredRegistrations.length,
          itemBuilder: (context, index) {
            final registration = filteredRegistrations[index];
            return _buildRegistrationCard(registration);
          },
        );
      },
    );
  }

  IconData _getEmptyIcon(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:
        return Icons.inbox;
      case WorkerApprovalStatus.approved:
        return Icons.check_circle_outline;
      case WorkerApprovalStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  String _getEmptyMessage(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:
        return 'No pending registrations';
      case WorkerApprovalStatus.approved:
        return 'No approved workers yet';
      case WorkerApprovalStatus.rejected:
        return 'No rejected registrations';
    }
  }

  Widget _buildRegistrationCard(WorkerRegistrationModel registration) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDetailDialog(registration),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      registration.name.isNotEmpty 
                          ? registration.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          registration.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          registration.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(registration.status),
                ],
              ),
              Divider(height: 24),
              Row(
                children: [
                  _buildInfoChip(Icons.work, registration.serviceCategory),
                  SizedBox(width: 8),
                  _buildInfoChip(Icons.timeline, '${registration.experience} exp'),
                ],
              ),
              SizedBox(height: 8),
              Text(
                registration.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
              if (registration.status == WorkerApprovalStatus.pending) ...[
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(registration),
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _approveWorker(registration),
                      icon: Icon(Icons.check, size: 18),
                      label: Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
              if (registration.status == WorkerApprovalStatus.rejected &&
                  registration.rejectionReason != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reason: ${registration.rejectionReason}',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(WorkerApprovalStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case WorkerApprovalStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case WorkerApprovalStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case WorkerApprovalStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(WorkerRegistrationModel registration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Worker Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', registration.name),
              _buildDetailRow('Email', registration.email),
              _buildDetailRow('Phone', registration.phone),
              _buildDetailRow('Category', registration.serviceCategory),
              _buildDetailRow('Experience', registration.experience),
              _buildDetailRow('Address', registration.address),
              Divider(),
              Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(registration.description),
              Divider(),
              _buildDetailRow(
                'Submitted',
                '${registration.createdAt.day}/${registration.createdAt.month}/${registration.createdAt.year}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveWorker(WorkerRegistrationModel registration) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Worker?'),
        content: Text('Are you sure you want to approve ${registration.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final success = await _registrationRepo.approveWorkerRegistration(
        registrationId: registration.id,
        adminId: adminId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '${registration.name} has been approved!'
                : 'Failed to approve worker'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(WorkerRegistrationModel registration) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Worker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason for rejecting ${registration.name}:'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }

              Navigator.pop(context);

              final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
              final success = await _registrationRepo.rejectWorkerRegistration(
                registrationId: registration.id,
                adminId: adminId,
                reason: reasonController.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Registration rejected'
                        : 'Failed to reject registration'),
                    backgroundColor: success ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }
}
