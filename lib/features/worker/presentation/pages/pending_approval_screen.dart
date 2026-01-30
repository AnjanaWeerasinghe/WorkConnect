import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/models/worker_registration_model.dart';
import '../../../../data/repositories/worker_registration_repository.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final WorkerRegistrationRepository _registrationRepo = WorkerRegistrationRepository();
  WorkerRegistrationModel? _registration;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistration();
  }

  Future<void> _loadRegistration() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final registration = await _registrationRepo.getWorkerRegistrationByUserId(userId);
      setState(() {
        _registration = registration;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isRejected = _registration?.status == WorkerApprovalStatus.rejected;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isRejected 
                      ? Colors.red.shade50 
                      : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected ? Icons.cancel : Icons.hourglass_top,
                  size: 60,
                  color: isRejected ? Colors.red : Colors.orange,
                ),
              ),

              SizedBox(height: 32),

              // Title
              Text(
                isRejected 
                    ? 'Registration Rejected'
                    : 'Pending Approval',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isRejected ? Colors.red : Colors.orange.shade800,
                ),
              ),

              SizedBox(height: 16),

              // Description
              Text(
                isRejected
                    ? 'Unfortunately, your worker registration was not approved.'
                    : 'Your worker registration is being reviewed by our admin team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              SizedBox(height: 24),

              // Status Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRejected ? Icons.error : Icons.access_time,
                          color: isRejected ? Colors.red : Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Status: ${isRejected ? "Rejected" : "Pending"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isRejected ? Colors.red : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (_registration != null) ...[
                      Divider(height: 24),
                      _buildInfoRow('Name', _registration!.name),
                      _buildInfoRow('Category', _registration!.serviceCategory),
                      _buildInfoRow('Submitted', _formatDate(_registration!.createdAt)),
                    ],
                    if (isRejected && _registration?.rejectionReason != null) ...[
                      Divider(height: 24),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rejection Reason:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _registration!.rejectionReason!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Info Box
              if (!isRejected)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will be notified once your registration is approved. Please check back later.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              Spacer(),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: Icon(Icons.logout),
                  label: Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ),

              if (isRejected) ...[
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Allow re-registration
                      FirebaseAuth.instance.signOut();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Try Registering Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
