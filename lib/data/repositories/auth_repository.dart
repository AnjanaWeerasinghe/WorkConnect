import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Try to get user data from Firestore, but don't fail if Firestore has issues
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists) {
            return UserModel.fromFirestore(userDoc);
          } else {
            // User exists in Firebase Auth but not in Firestore
            // Create a new user document with basic info
            UserModel userModel = UserModel(
              id: userCredential.user!.uid,
              name: userCredential.user!.displayName ?? 'Unknown User',
              email: email,
              phone: userCredential.user!.phoneNumber ?? '',
              role: AppConstants.customerRole, // Default role
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await _firestore
                .collection(AppConstants.usersCollection)
                .doc(userCredential.user!.uid)
                .set(userModel.toFirestore());

            print("Created new user document for existing Firebase Auth user");
            return userModel;
          }
        } catch (firestoreError) {
          // Firestore failed but Firebase Auth succeeded - return basic user model
          print("Firestore error, but auth succeeded: $firestoreError");
          return UserModel(
            id: userCredential.user!.uid,
            name: userCredential.user!.displayName ?? 'User',
            email: email,
            phone: userCredential.user!.phoneNumber ?? '',
            role: AppConstants.customerRole,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      print("Error signing in: $e");
      rethrow; // Rethrow so the UI can handle the error
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user document in Firestore
        UserModel userModel = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        try {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userCredential.user!.uid)
              .set(userModel.toFirestore());
        } catch (firestoreError) {
          // Firestore failed but registration succeeded
          print("Firestore error during registration, but auth succeeded: $firestoreError");
        }

        return userModel;
      }
      return null;
    } catch (e) {
      print("Error registering: $e");
      rethrow; // Rethrow so the UI can handle the error
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      } else {
        // Check if this is the current authenticated user
        User? currentFirebaseUser = _firebaseAuth.currentUser;
        if (currentFirebaseUser != null && currentFirebaseUser.uid == userId) {
          // Create user document for authenticated user who doesn't have Firestore doc
          UserModel userModel = UserModel(
            id: userId,
            name: currentFirebaseUser.displayName ?? 'Unknown User',
            email: currentFirebaseUser.email ?? '',
            phone: currentFirebaseUser.phoneNumber ?? '',
            role: AppConstants.customerRole, // Default role
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .set(userModel.toFirestore());

          print("Created user document for authenticated user: ${userModel.email}");
          return userModel;
        }
      }
      return null;
    } catch (e) {
      print("Error getting user data: $e");
      return null;
    }
  }

  // Update user data
  Future<bool> updateUserData(UserModel userModel) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userModel.id)
          .update(userModel.copyWith(updatedAt: DateTime.now()).toFirestore());
      return true;
    } catch (e) {
      print("Error updating user data: $e");
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print("Error resetting password: $e");
      return false;
    }
  }

  // Update user approval status
  Future<bool> updateUserApprovalStatus(String userId, bool isApproved) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'isApproved': isApproved,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print("Error updating approval status: $e");
      return false;
    }
  }

  // Check if worker is approved
  Future<bool> isWorkerApproved(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isApproved'] == true;
      }
      return false;
    } catch (e) {
      print("Error checking worker approval: $e");
      return false;
    }
  }

  // Get user role
  Future<String?> getUserRole(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] as String?;
      }
      return null;
    } catch (e) {
      print("Error getting user role: $e");
      return null;
    }
  }
}