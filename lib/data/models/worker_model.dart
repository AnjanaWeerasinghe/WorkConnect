import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String id;
  final String userId;
  final List<String> skills;
  final String bio;
  final double hourlyRate;
  final bool isOnline;
  final GeoPoint? location;
  final String? address;
  final List<String> certificationImages;
  final bool isVerified;
  final int totalJobs;
  final double avgRating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerModel({
    required this.id,
    required this.userId,
    required this.skills,
    required this.bio,
    required this.hourlyRate,
    required this.isOnline,
    this.location,
    this.address,
    required this.certificationImages,
    required this.isVerified,
    required this.totalJobs,
    required this.avgRating,
    required this.ratingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkerModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      bio: data['bio'] ?? '',
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      isOnline: data['isOnline'] ?? false,
      location: data['location'] as GeoPoint?,
      address: data['address'],
      certificationImages: List<String>.from(data['certificationImages'] ?? []),
      isVerified: data['isVerified'] ?? false,
      totalJobs: data['totalJobs'] ?? 0,
      avgRating: (data['avgRating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'skills': skills,
      'bio': bio,
      'hourlyRate': hourlyRate,
      'isOnline': isOnline,
      'location': location,
      'address': address,
      'certificationImages': certificationImages,
      'isVerified': isVerified,
      'totalJobs': totalJobs,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WorkerModel copyWith({
    String? id,
    String? userId,
    List<String>? skills,
    String? bio,
    double? hourlyRate,
    bool? isOnline,
    GeoPoint? location,
    String? address,
    List<String>? certificationImages,
    bool? isVerified,
    int? totalJobs,
    double? avgRating,
    int? ratingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isOnline: isOnline ?? this.isOnline,
      location: location ?? this.location,
      address: address ?? this.address,
      certificationImages: certificationImages ?? this.certificationImages,
      isVerified: isVerified ?? this.isVerified,
      totalJobs: totalJobs ?? this.totalJobs,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}