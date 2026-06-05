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
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await StripeService.initialize();
  } catch (e) {
    // Stripe.js may not be available in all environments; non-fatal
    debugPrint('Stripe init warning: $e');
  }

  // Always sign out user on app start to force login screen
  await FirebaseAuth.instance.signOut();
  debugPrint('User signed out on app start');

  // Initialize database collections in background (non-blocking)
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
