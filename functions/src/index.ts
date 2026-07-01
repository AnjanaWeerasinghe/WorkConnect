import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import corsLib from "cors";
import Stripe from "stripe";

admin.initializeApp();
const db = admin.firestore();

// Allow requests from any origin (Flutter web dev server + deployed hosting)
const cors = corsLib({ origin: true });

const stripe = new Stripe(
  process.env.STRIPE_SECRET_KEY!,
  { apiVersion: "2023-10-16" }
);

// Helper: wrap an async handler with the cors middleware.
function withCors(
  handler: (req: functions.https.Request, res: functions.Response) => Promise<void>
): functions.HttpsFunction {
  return functions.https.onRequest((req, res) => {
    cors(req, res, () => handler(req, res).catch((err) => {
      console.error(err);
      res.status(500).json({ error: (err as Error).message });
    }));
  });
}

// ── confirmPayment ──────────────────────────────────────────────────────────
// Called by the Flutter web card dialog after creating a PaymentMethod.
// Requires Firebase Blaze plan (outbound network calls).
export const confirmPayment = withCors(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { clientSecret, paymentMethodId } = req.body as {
    clientSecret: string;
    paymentMethodId: string;
  };

  if (!clientSecret || !paymentMethodId) {
    res.status(400).json({ error: "clientSecret and paymentMethodId are required" });
    return;
  }

  const paymentIntentId = clientSecret.split("_secret_")[0];

  const intent = await stripe.paymentIntents.confirm(paymentIntentId, {
    payment_method: paymentMethodId,
  });

  res.status(200).json({
    success: intent.status === "succeeded",
    status:  intent.status,
  });
});

// ── createPaymentIntent ─────────────────────────────────────────────────────
// Creates a PaymentIntent and returns the clientSecret.
// Requires Firebase Blaze plan (outbound network calls).
// Deploy: firebase deploy --only functions
export const createPaymentIntent = withCors(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { amount, currency = "usd", jobId, customerId } = req.body as {
    amount: number;
    currency?: string;
    jobId: string;
    customerId: string;
  };

  if (!amount || amount <= 0) {
    res.status(400).json({ error: "Invalid amount" });
    return;
  }

  const paymentIntent = await stripe.paymentIntents.create({
    amount,
    currency,
    automatic_payment_methods: { enabled: true },
    metadata: { jobId, customerId },
  });

  res.status(200).json({ clientSecret: paymentIntent.client_secret });
});

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