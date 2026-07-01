import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../pages/home_page.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to Firebase Auth so navigation updates automatically when the session changes.
    final authRepository = AuthRepository();

    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        // Show a loading state while Firebase is resolving the current session.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // Fall back to the login screen if the auth stream errors out.
        if (snapshot.hasError) {
          return const LoginScreen(); // Fallback to login on error
        }

        // Signed-in users go straight to the home page.
        if (snapshot.hasData && snapshot.data != null) {
          return HomePage();
        }

        // No session means we stay on the authentication screen.
        return const LoginScreen();
      },
    );
  }
}