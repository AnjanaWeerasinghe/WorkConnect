import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/worker_registration_repository.dart';
import '../data/models/user_model.dart';
import '../data/models/worker_registration_model.dart';
import '../features/customer/presentation/pages/customer_landing_page.dart';
import '../features/worker/presentation/pages/worker_landing_page.dart';
import '../features/worker/presentation/pages/pending_approval_screen.dart';
import '../features/admin/presentation/pages/admin_panel_screen.dart';
import '../core/constants/app_constants.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthRepository _authRepository = AuthRepository();
  final WorkerRegistrationRepository _workerRegRepo = WorkerRegistrationRepository();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isWorkerPendingApproval = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _authRepository.getUserData(user.uid);
        
        // Check if user is a worker pending approval
        if (userData?.role == AppConstants.workerRole) {
          final isApproved = await _authRepository.isWorkerApproved(user.uid);
          if (!isApproved) {
            // Check registration status
            final registration = await _workerRegRepo.getWorkerRegistrationByUserId(user.uid);
            if (registration != null && registration.status != WorkerApprovalStatus.approved) {
              setState(() {
                _isWorkerPendingApproval = true;
                _isLoading = false;
              });
              return;
            }
          }
        }
        
        setState(() {
          _currentUser = userData;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading user data: $e');
        // If we can't load user data, create a basic user model from Firebase Auth data
        if (user.email != null) {
          final basicUser = UserModel(
            id: user.uid,
            name: user.displayName ?? 'User',
            email: user.email!,
            phone: user.phoneNumber ?? '',
            role: 'customer', // Default role
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          setState(() {
            _currentUser = basicUser;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
      appBar: AppBar(
        title: Text('WorkConnect'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your workspace...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
    }

    // If no user data, show please login message
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('WorkConnect'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.login,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Please log in to continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Access your personalized workspace',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Route to appropriate landing page based on user role
    
    // Admin users go to admin panel
    if (_currentUser!.role == AppConstants.adminRole) {
      return AdminPanelScreen();
    }
    
    // Workers pending approval see the pending screen
    if (_currentUser!.role == AppConstants.workerRole && _isWorkerPendingApproval) {
      return PendingApprovalScreen();
    }
    
    if (_currentUser!.role == AppConstants.customerRole) {
      return CustomerLandingPage(user: _currentUser!);
    } else if (_currentUser!.role == AppConstants.workerRole) {
      return WorkerLandingPage(user: _currentUser!);
    }

    // Fallback generic homepage (shouldn't happen with proper role assignment)
    return Scaffold(
      appBar: AppBar(
        title: Text('WorkConnect'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to WorkConnect!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('Role: ${_currentUser!.role}'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _signOut,
              child: Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
