import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_registration_model.dart';
import '../../core/constants/app_constants.dart';

class WorkerRegistrationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'worker_registrations';

  /// Submit a new worker registration for approval
  Future<WorkerRegistrationModel?> submitWorkerRegistration({
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String serviceCategory,
    required String experience,
    required String description,
    required String address,
    String? idProofUrl,
    String? certificateUrl,
  }) async {
    try {
      final registration = WorkerRegistrationModel(
        id: '',
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        serviceCategory: serviceCategory,
        experience: experience,
        description: description,
        address: address,
        idProofUrl: idProofUrl,
        certificateUrl: certificateUrl,
        status: WorkerApprovalStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(_collection)
          .add(registration.toFirestore());

      print('Worker registration submitted: ${docRef.id}');
      return registration.copyWith(id: docRef.id);
    } catch (e) {
      print('Error submitting worker registration: $e');
      rethrow;
    }
  }

  /// Get worker registration by user ID
  Future<WorkerRegistrationModel?> getWorkerRegistrationByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return WorkerRegistrationModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting worker registration: $e');
      return null;
    }
  }

  /// Get all pending worker registrations (for admin)
  Stream<List<WorkerRegistrationModel>> getPendingRegistrations() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkerRegistrationModel.fromFirestore(doc))
            .toList());
  }

  /// Get all worker registrations (for admin)
  Stream<List<WorkerRegistrationModel>> getAllRegistrations() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkerRegistrationModel.fromFirestore(doc))
            .toList());
  }

  /// Approve a worker registration
  Future<bool> approveWorkerRegistration({
    required String registrationId,
    required String adminId,
  }) async {
    try {
      // Get the registration
      final regDoc = await _firestore.collection(_collection).doc(registrationId).get();
      if (!regDoc.exists) {
        print('Registration not found');
        return false;
      }

      final registration = WorkerRegistrationModel.fromFirestore(regDoc);

      // Update registration status
      await _firestore.collection(_collection).doc(registrationId).update({
        'status': 'approved',
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'updatedAt': Timestamp.now(),
      });

      // Update user role to worker in users collection
      await _firestore.collection(AppConstants.usersCollection).doc(registration.userId).update({
        'role': AppConstants.workerRole,
        'isApproved': true,
        'updatedAt': Timestamp.now(),
      });

      // Create worker profile in workers collection
      await _firestore.collection(AppConstants.workersCollection).doc(registration.userId).set({
        'userId': registration.userId,
        'name': registration.name,
        'email': registration.email,
        'phone': registration.phone,
        'serviceCategory': registration.serviceCategory,
        'experience': registration.experience,
        'description': registration.description,
        'address': registration.address,
        'rating': 0.0,
        'totalReviews': 0,
        'isAvailable': true,
        'isApproved': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      print('Worker approved: ${registration.name}');
      return true;
    } catch (e) {
      print('Error approving worker: $e');
      return false;
    }
  }

  /// Reject a worker registration
  Future<bool> rejectWorkerRegistration({
    required String registrationId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _firestore.collection(_collection).doc(registrationId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': adminId,
        'updatedAt': Timestamp.now(),
      });

      print('Worker registration rejected');
      return true;
    } catch (e) {
      print('Error rejecting worker registration: $e');
      return false;
    }
  }

  /// Check if user has pending registration
  Future<bool> hasPendingRegistration(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pending registration: $e');
      return false;
    }
  }

  /// Get registration status for a user
  Future<WorkerApprovalStatus?> getRegistrationStatus(String userId) async {
    try {
      final registration = await getWorkerRegistrationByUserId(userId);
      return registration?.status;
    } catch (e) {
      print('Error getting registration status: $e');
      return null;
    }
  }
}
