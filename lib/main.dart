import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/review_repository.dart';
import 'features/authentication/presentation/pages/auth_wrapper.dart';
import 'core/database/database_initializer.dart';
import 'core/services/stripe_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Ensure Flutter bindings are ready before Firebase and other services initialize.
  WidgetsFlutterBinding.ensureInitialized();
  // Load Firebase config for the current platform before the app starts.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    // Stripe is optional in some environments, so initialization failure is non-fatal.
    await StripeService.initialize();
  } catch (e) {
    // Stripe.js may not be available in all environments; non-fatal
    debugPrint('Stripe init warning: $e');
  }

  // Force a fresh auth session on startup so the login flow is always explicit.
  await FirebaseAuth.instance.signOut();
  debugPrint('User signed out on app start');

  // Seed required collections in the background so startup does not block.
  DatabaseInitializer.initializeDatabase().then((_) {
    debugPrint('Database initialization completed in background');
  }).catchError((error) {
    debugPrint('Database initialization error (non-critical): $error');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide repositories once so screens can read them without manual wiring.
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<ReviewRepository>(create: (_) => ReviewRepository()),
      ],
      child: MaterialApp(
        title: 'WorkConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthWrapper(),
      ),
    );
  }
}
