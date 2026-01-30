import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkerApprovalStatus {
  pending,
  approved,
  rejected,
}

class WorkerRegistrationModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String serviceCategory;
  final String experience; // Years of experience
  final String description; // About the worker
  final String address;
  final String? idProofUrl; // Government ID proof
  final String? certificateUrl; // Work certificate/license
  final WorkerApprovalStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin who reviewed

  WorkerRegistrationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.serviceCategory,
    required this.experience,
    required this.description,
    required this.address,
    this.idProofUrl,
    this.certificateUrl,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory WorkerRegistrationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkerRegistrationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      serviceCategory: data['serviceCategory'] ?? '',
      experience: data['experience'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      idProofUrl: data['idProofUrl'],
      certificateUrl: data['certificateUrl'],
      status: _parseStatus(data['status']),
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  static WorkerApprovalStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return WorkerApprovalStatus.approved;
      case 'rejected':
        return WorkerApprovalStatus.rejected;
      default:
        return WorkerApprovalStatus.pending;
    }
  }

  String get statusString {
    switch (status) {
      case WorkerApprovalStatus.approved:
        return 'approved';
      case WorkerApprovalStatus.rejected:
        return 'rejected';
      default:
        return 'pending';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'serviceCategory': serviceCategory,
      'experience': experience,
      'description': description,
      'address': address,
      'idProofUrl': idProofUrl,
      'certificateUrl': certificateUrl,
      'status': statusString,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
    };
  }

  WorkerRegistrationModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? serviceCategory,
    String? experience,
    String? description,
    String? address,
    String? idProofUrl,
    String? certificateUrl,
    WorkerApprovalStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return WorkerRegistrationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      experience: experience ?? this.experience,
      description: description ?? this.description,
      address: address ?? this.address,
      idProofUrl: idProofUrl ?? this.idProofUrl,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}
