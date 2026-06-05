import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/worker_registration_repository.dart';
import '../data/models/user_model.dart';
import '../data/models/worker_registration_model.dart';
import '../features/customer/presentation/pages/customer_landing_page.dart';
import '../features/worker/presentation/pages/worker_landing_page.dart';
import '../features/worker/presentation/pages/pending_approval_screen.dart';
import '../features/admin/presentation/pages/admin_panel_screen.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/wc_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthRepository               _authRepository = AuthRepository();
  final WorkerRegistrationRepository _workerRegRepo  = WorkerRegistrationRepository();

  StreamSubscription<User?>? _authSub;
  UserModel? _currentUser;
  bool       _isLoading              = true;
  bool       _isWorkerPendingApproval = false;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _isLoading              = true;
        _currentUser            = null;
        _isWorkerPendingApproval = false;
      });
      _loadUserData();
    });
    _loadUserData();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _isWorkerPendingApproval = false;
      final userData = await _authRepository.getUserData(user.uid);

      if (userData == null) {
        debugPrint('Warning: user authenticated but no Firestore profile found');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (userData.role == AppConstants.workerRole) {
        final isApproved = await _authRepository.isWorkerApproved(user.uid);
        if (!isApproved) {
          final registration = await _workerRegRepo.getWorkerRegistrationByUserId(user.uid);
          if (registration != null && registration.status != WorkerApprovalStatus.approved) {
            if (mounted) {
              setState(() {
                _currentUser            = userData;
                _isWorkerPendingApproval = true;
                _isLoading              = false;
              });
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentUser = userData;
          _isLoading   = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async => _authRepository.signOut();

  @override
  Widget build(BuildContext context) {
    // ── Loading ───────────────────────────────────────────────────────────
    if (_isLoading) return const _LoadingScreen();

    // ── No profile found ──────────────────────────────────────────────────
    if (_currentUser == null) {
      return _ErrorScreen(
        hasFirebaseUser: FirebaseAuth.instance.currentUser != null,
        onRetry: _loadUserData,
        onSignOut: _signOut,
      );
    }

    // ── Role routing ──────────────────────────────────────────────────────
    if (_currentUser!.role == AppConstants.adminRole) {
      return const AdminPanelScreen();
    }

    if (_currentUser!.role == AppConstants.workerRole && _isWorkerPendingApproval) {
      return const PendingApprovalScreen();
    }

    if (_currentUser!.role == AppConstants.customerRole) {
      return CustomerLandingPage(user: _currentUser!);
    }

    if (_currentUser!.role == AppConstants.workerRole) {
      return WorkerLandingPage(user: _currentUser!);
    }

    // ── Fallback (unknown role) ────────────────────────────────────────────
    return _UnknownRoleScreen(role: _currentUser!.role, onSignOut: _signOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading screen — branded, animated
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo mark
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: 0.94 + 0.06 * _pulse.value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25 + 0.15 * _pulse.value),
                        offset: const Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('WorkConnect',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary, letterSpacing: -0.8)),
            const SizedBox(height: 6),
            const Text('Loading your workspace…',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),

            const SizedBox(height: 28),

            // Skeleton cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(children: const [
                WcSkeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                WcSkeleton(width: double.infinity, height: 12),
                SizedBox(height: 8),
                WcSkeleton(width: 160, height: 12),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error screen
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  final bool         hasFirebaseUser;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ErrorScreen({
    required this.hasFirebaseUser,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.error, width: 2),
                    boxShadow: const [
                      BoxShadow(color: AppColors.error, offset: Offset(3, 3), blurRadius: 0),
                    ],
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                ),

                const SizedBox(height: 20),

                Text(
                  hasFirebaseUser ? 'Profile not found' : 'Please sign in',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  hasFirebaseUser
                      ? 'We could not load your profile. Please try again or sign in afresh.'
                      : 'Sign in to access your personalised workspace.',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                if (hasFirebaseUser) ...[
                  WcPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    width: double.infinity,
                    onPressed: onRetry,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  const SizedBox(height: 12),
                ],

                WcOutlinedButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  width: double.infinity,
                  onPressed: onSignOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unknown role fallback
// ─────────────────────────────────────────────────────────────────────────────
class _UnknownRoleScreen extends StatelessWidget {
  final String       role;
  final VoidCallback onSignOut;

  const _UnknownRoleScreen({required this.role, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WcEmptyState(
                  icon: Icons.help_outline_rounded,
                  title: 'Unknown account type',
                  subtitle: 'Your account role could not be determined. Please sign out and try again.',
                ),
                const SizedBox(height: 20),
                WcOutlinedButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  width: double.infinity,
                  onPressed: onSignOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
