import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new review
  Future<bool> createReview(ReviewModel review) async {
    try {
      // Check if review already exists for this job
      QuerySnapshot existingReviews = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('jobId', isEqualTo: review.jobId)
          .where('customerId', isEqualTo: review.customerId)
          .get();

      if (existingReviews.docs.isNotEmpty) {
        throw Exception('Review already exists for this job');
      }

      // Create the review
      await _firestore
          .collection(AppConstants.reviewsCollection)
          .add(review.toFirestore());

      // Update job to mark as reviewed
      await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(review.jobId)
          .update({'hasReview': true});

      return true;
    } catch (e) {
      print("Error creating review: $e");
      return false;
    }
  }

  // Get reviews for a worker
  Future<List<ReviewModel>> getWorkerReviews(String workerId, {int? limit}) async {
    try {
      Query query = _firestore
          .collection(AppConstants.reviewsCollection)
          .where('workerId', isEqualTo: workerId)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      QuerySnapshot querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error getting worker reviews: $e");
      return [];
    }
  }

  // Get review by job ID
  Future<ReviewModel?> getReviewByJobId(String jobId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return ReviewModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print("Error getting review by job ID: $e");
      return null;
    }
  }

  // Get reviews for a customer
  Future<List<ReviewModel>> getCustomerReviews(String customerId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error getting customer reviews: $e");
      return [];
    }
  }

  // Update a review
  Future<bool> updateReview(ReviewModel review) async {
    try {
      await _firestore
          .collection(AppConstants.reviewsCollection)
          .doc(review.id)
          .update(review.copyWith(updatedAt: DateTime.now()).toFirestore());
      return true;
    } catch (e) {
      print("Error updating review: $e");
      return false;
    }
  }

  // Delete a review
  Future<bool> deleteReview(String reviewId, String jobId) async {
    try {
      // Delete the review
      await _firestore
          .collection(AppConstants.reviewsCollection)
          .doc(reviewId)
          .delete();

      // Update job to mark as not reviewed
      await _firestore
          .collection(AppConstants.jobsCollection)
          .doc(jobId)
          .update({'hasReview': false});

      return true;
    } catch (e) {
      print("Error deleting review: $e");
      return false;
    }
  }

  // Get review statistics for a worker
  Future<Map<String, dynamic>> getWorkerReviewStats(String workerId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(AppConstants.reviewsCollection)
          .where('workerId', isEqualTo: workerId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      List<ReviewModel> reviews = querySnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      int totalReviews = reviews.length;
      double totalRating = reviews.fold(0.0, (sum, review) => sum + review.rating);
      double averageRating = totalRating / totalReviews;

      Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (ReviewModel review in reviews) {
        ratingDistribution[review.rating] = (ratingDistribution[review.rating] ?? 0) + 1;
      }

      return {
        'totalReviews': totalReviews,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      print("Error getting worker review stats: $e");
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }

  // Get reviews with customer info
  Future<List<Map<String, dynamic>>> getWorkerReviewsWithCustomerInfo(String workerId) async {
    try {
      List<ReviewModel> reviews = await getWorkerReviews(workerId);
      List<Map<String, dynamic>> reviewsWithCustomerInfo = [];

      for (ReviewModel review in reviews) {
        DocumentSnapshot customerDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(review.customerId)
            .get();

        UserModel? customer = customerDoc.exists ? UserModel.fromFirestore(customerDoc) : null;

        reviewsWithCustomerInfo.add({
          'review': review,
          'customer': customer,
        });
      }

      return reviewsWithCustomerInfo;
    } catch (e) {
      print("Error getting reviews with customer info: $e");
      return [];
    }
  }
}