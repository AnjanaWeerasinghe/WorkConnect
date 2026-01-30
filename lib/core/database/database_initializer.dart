import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class DatabaseInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize Firestore collections and ensure they exist
  static Future<void> initializeDatabase() async {
    try {
      print('DatabaseInitializer: Starting database initialization...');
      
      // Check if collections exist by trying to read them
      await _checkAndCreateCollections();
      
      print('DatabaseInitializer: Database initialization completed successfully');
    } catch (e) {
      print('DatabaseInitializer: Error during initialization: $e');
    }
  }

  /// Check and create necessary collections with sample documents
  static Future<void> _checkAndCreateCollections() async {
    try {
      // Check users collection
      QuerySnapshot usersCheck = await _firestore
          .collection(AppConstants.usersCollection)
          .limit(1)
          .get();
      
      if (usersCheck.docs.isEmpty) {
        print('DatabaseInitializer: Users collection is empty, creating sample structure...');
        // Create a placeholder document to initialize the collection
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc('_placeholder')
            .set({
          'isPlaceholder': true,
          'createdAt': FieldValue.serverTimestamp(),
          'note': 'This is a placeholder document to initialize the collection'
        });
      }

      // Check jobs collection
      QuerySnapshot jobsCheck = await _firestore
          .collection(AppConstants.jobsCollection)
          .limit(1)
          .get();
      
      if (jobsCheck.docs.isEmpty) {
        print('DatabaseInitializer: Jobs collection is empty, creating sample structure...');
        await _firestore
            .collection(AppConstants.jobsCollection)
            .doc('_placeholder')
            .set({
          'isPlaceholder': true,
          'createdAt': FieldValue.serverTimestamp(),
          'note': 'This is a placeholder document to initialize the collection'
        });
      }

      // Check reviews collection
      QuerySnapshot reviewsCheck = await _firestore
          .collection(AppConstants.reviewsCollection)
          .limit(1)
          .get();
      
      if (reviewsCheck.docs.isEmpty) {
        print('DatabaseInitializer: Reviews collection is empty, creating sample structure...');
        await _firestore
            .collection(AppConstants.reviewsCollection)
            .doc('_placeholder')
            .set({
          'isPlaceholder': true,
          'createdAt': FieldValue.serverTimestamp(),
          'note': 'This is a placeholder document to initialize the collection'
        });
      }

      print('DatabaseInitializer: All collections checked/created successfully');
    } catch (e) {
      print('DatabaseInitializer: Error checking collections: $e');
      // If there's a permission error, it likely means the database exists
      // but the security rules need to be configured
      if (e.toString().contains('permission-denied')) {
        print('DatabaseInitializer: Permission denied - database exists but needs proper security rules');
      }
    }
  }

  /// Create a test user document (for development purposes)
  static Future<void> createTestUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          'name': 'Test User',
          'email': user.email,
          'phone': '+1234567890',
          'role': AppConstants.customerRole,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        print('DatabaseInitializer: Test user created/updated: ${user.email}');
      }
    } catch (e) {
      print('DatabaseInitializer: Error creating test user: $e');
    }
  }
}