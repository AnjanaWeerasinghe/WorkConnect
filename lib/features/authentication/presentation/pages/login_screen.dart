import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';
import '../../../worker/presentation/pages/worker_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = AppConstants.customerRole;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('LoginScreen: Submit called, isLoginMode: $_isLoginMode');

    if (!_formKey.currentState!.validate()) {
      debugPrint('LoginScreen: Form validation failed');
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authRepository = context.read<AuthRepository>();

      if (_isLoginMode) {
        debugPrint('LoginScreen: Attempting login for ${_emailController.text.trim()}');
        await authRepository.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        debugPrint('LoginScreen: Login successful');
      } else {
        if (_selectedRole == AppConstants.workerRole) {
          debugPrint('LoginScreen: Redirecting to worker registration form');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkerRegistrationScreen(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                  name: _nameController.text.trim(),
                  phone: _phoneController.text.trim(),
                ),
              ),
            );
          }
        } else {
          debugPrint('LoginScreen: Attempting $_selectedRole registration for ${_emailController.text.trim()}');
          await authRepository.registerWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            role: _selectedRole,
          );
        }
      }
      debugPrint('LoginScreen: Authentication successful');
    } catch (e) {
      debugPrint('LoginScreen: Authentication failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // ── Brand ──────────────────────────────────────────
                _BrandHeader(),

                const SizedBox(height: 40),

                // ── Mode toggle ────────────────────────────────────
                _ModeToggle(
                  isLoginMode: _isLoginMode,
                  onToggle: (login) => setState(() => _isLoginMode = login),
                ),

                const SizedBox(height: 28),

                // ── Register-only fields ───────────────────────────
                if (!_isLoginMode) ...[
                  _buildField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter your phone number' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildRoleDropdown(),
                  const SizedBox(height: 14),
                ],

                // ── Email ──────────────────────────────────────────
                _buildField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Password ───────────────────────────────────────
                _buildPasswordField(),

                const SizedBox(height: 28),

                // ── Submit ─────────────────────────────────────────
                WcPrimaryButton(
                  label: _isLoginMode ? 'Sign In' : 'Create Account',
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),

                const SizedBox(height: 14),

                // ── Forgot Password ────────────────────────────────
                if (_isLoginMode)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset feature coming soon.'),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool autocorrect = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter your password';
        if (v.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'Account Type',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: const [
        DropdownMenuItem(value: AppConstants.customerRole, child: Text('Customer')),
        DropdownMenuItem(value: AppConstants.workerRole,   child: Text('Worker')),
        DropdownMenuItem(value: AppConstants.adminRole,    child: Text('Admin')),
      ],
      onChanged: (v) => setState(() => _selectedRole = v!),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand Header
// ─────────────────────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo mark
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'WorkConnect',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'On-demand home services marketplace',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Toggle (Login / Register)
// ─────────────────────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final bool isLoginMode;
  final ValueChanged<bool> onToggle;

  const _ModeToggle({required this.isLoginMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          _Tab(label: 'Sign In',      selected: isLoginMode,  onTap: () => onToggle(true)),
          _Tab(label: 'Create Account', selected: !isLoginMode, onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: AppColors.border, width: 1.5)
                : null,
            boxShadow: selected
                ? [const BoxShadow(color: AppColors.shadow, offset: Offset(2, 2), blurRadius: 0)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.textInverse : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
