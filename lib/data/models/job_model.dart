import 'package:cloud_firestore/cloud_firestore.dart';

class JobModel {
  final String id;
  final String customerId;
  final String? workerId;
  final String serviceType;
  final String description;
  final GeoPoint location;
  final String address;
  final String status; // requested, accepted, in_progress, completed, cancelled
  final double? agreedPrice;
  final List<String> imageUrls;
  final bool hasReview;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  JobModel({
    required this.id,
    required this.customerId,
    this.workerId,
    required this.serviceType,
    required this.description,
    required this.location,
    required this.address,
    required this.status,
    this.agreedPrice,
    required this.imageUrls,
    required this.hasReview,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      workerId: data['workerId'],
      serviceType: data['serviceType'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] as GeoPoint,
      address: data['address'] ?? '',
      status: data['status'] ?? 'requested',
      agreedPrice: data['agreedPrice']?.toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      hasReview: data['hasReview'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null ? (data['acceptedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'workerId': workerId,
      'serviceType': serviceType,
      'description': description,
      'location': location,
      'address': address,
      'status': status,
      'agreedPrice': agreedPrice,
      'imageUrls': imageUrls,
      'hasReview': hasReview,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JobModel copyWith({
    String? id,
    String? customerId,
    String? workerId,
    String? serviceType,
    String? description,
    GeoPoint? location,
    String? address,
    String? status,
    double? agreedPrice,
    List<String>? imageUrls,
    bool? hasReview,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      workerId: workerId ?? this.workerId,
      serviceType: serviceType ?? this.serviceType,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      status: status ?? this.status,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      imageUrls: imageUrls ?? this.imageUrls,
      hasReview: hasReview ?? this.hasReview,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}