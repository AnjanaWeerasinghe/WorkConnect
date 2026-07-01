import 'package:cloud_firestore/cloud_firestore.dart';

class BidModel {
  final String id;
  final String jobId;
  final String workerId;
  final String workerName;
  final double amount;
  final String? message;
  final String status; // 'pending', 'accepted', 'withdrawn'
  final DateTime createdAt;

  BidModel({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.amount,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory BidModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BidModel(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? 'Worker',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      message: data['message'] as String?,
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'workerId': workerId,
      'workerName': workerName,
      'amount': amount,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
