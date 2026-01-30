import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../pages/home_page.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();

    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        // Add timeout for loading state
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

        // Check for errors
        if (snapshot.hasError) {
          return const LoginScreen(); // Fallback to login on error
        }

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return HomePage();
        }

        // No user signed in
        return const LoginScreen();
      },
    );
  }
}