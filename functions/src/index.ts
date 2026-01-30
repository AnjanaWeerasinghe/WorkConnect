import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Update worker rating when a review is created
export const updateWorkerRating = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snap, context) => {
    const review = snap.data();
    const workerId = review.workerId;

    try {
      // Get all reviews for this worker
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("workerId", "==", workerId)
        .get();

      if (reviewsSnapshot.empty) {
        console.log("No reviews found for worker:", workerId);
        return;
      }

      // Calculate new average rating
      let totalRating = 0;
      let totalReviews = 0;

      reviewsSnapshot.forEach((doc) => {
        const reviewData = doc.data();
        totalRating += reviewData.rating;
        totalReviews++;
      });

      const newAvgRating = totalRating / totalReviews;

      // Update worker document
      await db.collection("workers").doc(workerId).update({
        avgRating: parseFloat(newAvgRating.toFixed(2)),
        ratingCount: totalReviews,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Updated worker ${workerId} rating: ${newAvgRating.toFixed(2)} (${totalReviews} reviews)`);

      return null;
    } catch (error) {
      console.error("Error updating worker rating:", error);
      throw error;
    }
  });

// Update worker rating when a review is updated
export const updateWorkerRatingOnUpdate = functions.firestore
  .document("reviews/{reviewId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only recalculate if rating changed
    if (beforeData.rating === afterData.rating) {
      return null;
    }

    const workerId = afterData.workerId;

    try {
      // Get all reviews for this worker
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("workerId", "==", workerId)
        .get();

      if (reviewsSnapshot.empty) {
        console.log("No reviews found for worker:", workerId);
        return;
      }

      // Calculate new average rating
      let totalRating = 0;
      let totalReviews = 0;

      reviewsSnapshot.forEach((doc) => {
        const reviewData = doc.data();
        totalRating += reviewData.rating;
        totalReviews++;
      });

      const newAvgRating = totalRating / totalReviews;

      // Update worker document
      await db.collection("workers").doc(workerId).update({
        avgRating: parseFloat(newAvgRating.toFixed(2)),
        ratingCount: totalReviews,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Updated worker ${workerId} rating: ${newAvgRating.toFixed(2)} (${totalReviews} reviews)`);

      return null;
    } catch (error) {
      console.error("Error updating worker rating:", error);
      throw error;
    }
  });

// Update worker rating when a review is deleted
export const updateWorkerRatingOnDelete = functions.firestore
  .document("reviews/{reviewId}")
  .onDelete(async (snap, context) => {
    const review = snap.data();
    const workerId = review.workerId;

    try {
      // Get all remaining reviews for this worker
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("workerId", "==", workerId)
        .get();

      let newAvgRating = 0;
      let totalReviews = 0;

      if (!reviewsSnapshot.empty) {
        let totalRating = 0;

        reviewsSnapshot.forEach((doc) => {
          const reviewData = doc.data();
          totalRating += reviewData.rating;
          totalReviews++;
        });

        newAvgRating = totalRating / totalReviews;
      }

      // Update worker document
      await db.collection("workers").doc(workerId).update({
        avgRating: parseFloat(newAvgRating.toFixed(2)),
        ratingCount: totalReviews,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Updated worker ${workerId} rating after deletion: ${newAvgRating.toFixed(2)} (${totalReviews} reviews)`);

      return null;
    } catch (error) {
      console.error("Error updating worker rating after deletion:", error);
      throw error;
    }
  });

// Prevent duplicate reviews for the same job
export const validateReview = functions.firestore
  .document("reviews/{reviewId}")
  .onWrite(async (change, context) => {
    // Only run on create
    if (!change.after.exists || change.before.exists) {
      return null;
    }

    const review = change.after.data();
    const jobId = review.jobId;
    const customerId = review.customerId;

    try {
      // Check if a review already exists for this job by this customer
      const existingReviewsSnapshot = await db
        .collection("reviews")
        .where("jobId", "==", jobId)
        .where("customerId", "==", customerId)
        .get();

      // If there are multiple reviews for the same job, delete the current one
      if (existingReviewsSnapshot.size > 1) {
        console.log(`Duplicate review detected for job ${jobId}, deleting...`);
        await change.after.ref.delete();
        throw new functions.https.HttpsError(
          "already-exists",
          "A review already exists for this job."
        );
      }

      return null;
    } catch (error) {
      console.error("Error validating review:", error);
      throw error;
    }
  });

// Update job completion stats when job status changes
export const updateJobStats = functions.firestore
  .document("jobs/{jobId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to completed
    if (beforeData.status !== "completed" && afterData.status === "completed") {
      const workerId = afterData.workerId;

      if (!workerId) {
        return null;
      }

      try {
        // Increment worker's completed jobs count
        await db.collection("workers").doc(workerId).update({
          totalJobs: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Incremented total jobs for worker ${workerId}`);

        return null;
      } catch (error) {
        console.error("Error updating job stats:", error);
        throw error;
      }
    }

    return null;
  });

// Clean up orphaned reviews when jobs are deleted
export const cleanupReviewsOnJobDelete = functions.firestore
  .document("jobs/{jobId}")
  .onDelete(async (snap, context) => {
    const jobId = context.params.jobId;

    try {
      // Find and delete all reviews for this job
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("jobId", "==", jobId)
        .get();

      if (reviewsSnapshot.empty) {
        console.log("No reviews to delete for job:", jobId);
        return null;
      }

      const batch = db.batch();
      reviewsSnapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Deleted ${reviewsSnapshot.size} reviews for job ${jobId}`);

      return null;
    } catch (error) {
      console.error("Error cleaning up reviews:", error);
      throw error;
    }
  });