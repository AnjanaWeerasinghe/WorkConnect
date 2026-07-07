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
      // Sign in with Firebase Auth first, then load the matching Firestore profile.
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Try to get user data from Firestore, but don't fail if Firestore has issues.
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists) {
            // Existing profile found, so return it as-is.
            print("Login successful: Loading existing user data");
            return UserModel.fromFirestore(userDoc);
          } else {
            // Auth succeeded but the profile document is missing, which can happen for legacy users.
            print("User has no Firestore document, creating new one with default role");
            
            UserModel userModel = UserModel(
              id: userCredential.user!.uid,
              name: userCredential.user!.displayName ?? 'Unknown User',
              email: email,
              phone: userCredential.user!.phoneNumber ?? '',
              role: AppConstants.customerRole, // Default role for new users only
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
          // Firestore failed but Firebase Auth succeeded, so return a minimal in-memory profile.
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
      // Create the authentication record first, then persist the app profile in Firestore.
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Build the user document that the rest of the app will read from Firestore.
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
          // Registration still succeeded even if the profile write failed.
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
      // Read the profile document for this user and create a fallback record if it is missing.
      DocumentSnapshot userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      } else {
        // Only auto-create a profile for the user that is actually signed in.
        User? currentFirebaseUser = _firebaseAuth.currentUser;
        if (currentFirebaseUser != null && currentFirebaseUser.uid == userId) {
          // Re-check the document to avoid a race if another flow created it a moment earlier.
          DocumentSnapshot recheckDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .get();
          
          if (recheckDoc.exists) {
            // The profile appeared during the re-check, so use the latest copy.
            return UserModel.fromFirestore(recheckDoc);
          }
          
          // Create a default profile only when the signed-in user has no Firestore document.
          UserModel userModel = UserModel(
            id: userId,
            name: currentFirebaseUser.displayName ?? 'Unknown User',
            email: currentFirebaseUser.email ?? '',
            phone: currentFirebaseUser.phoneNumber ?? '',
            role: AppConstants.customerRole, // Default role ONLY for new users
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Use set without merge because the document is known to be absent.
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
      // Save the latest profile fields and refresh the updated timestamp.
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
      // Delegate password recovery to Firebase Auth.
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
      // Approval is app-specific state, so it is stored in Firestore.
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
      // Read the Firestore flag that controls worker access.
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
      // Role is stored in the user profile document, not in Firebase Auth.
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