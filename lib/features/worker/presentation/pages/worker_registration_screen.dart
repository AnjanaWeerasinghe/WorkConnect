import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/worker_registration_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Service category metadata (icon + accent color)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kCategoryMeta = <String, _CategoryMeta>{
  'Plumber':          _CategoryMeta(Icons.plumbing_rounded,            Color(0xFF2563EB)),
  'Electrician':      _CategoryMeta(Icons.electrical_services_rounded, Color(0xFFD97706)),
  'Mechanic':         _CategoryMeta(Icons.build_rounded,               Color(0xFF6B7280)),
  'Technician':       _CategoryMeta(Icons.computer_rounded,            Color(0xFF7C3AED)),
  'Carpenter':        _CategoryMeta(Icons.handyman_rounded,            Color(0xFF92400E)),
  'Painter':          _CategoryMeta(Icons.format_paint_rounded,        Color(0xFF7C3AED)),
  'Cleaner':          _CategoryMeta(Icons.cleaning_services_rounded,   Color(0xFF16A34A)),
  'Gardener':         _CategoryMeta(Icons.yard_rounded,                Color(0xFF15803D)),
  'AC Repair':        _CategoryMeta(Icons.ac_unit_rounded,             Color(0xFF0284C7)),
  'Appliance Repair': _CategoryMeta(Icons.kitchen_rounded,             Color(0xFFDC2626)),
};

class _CategoryMeta {
  final IconData icon;
  final Color color;
  const _CategoryMeta(this.icon, this.color);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// WorkerRegistrationScreen â€” 3-step wizard
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class WorkerRegistrationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final String phone;

  const WorkerRegistrationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
  });

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // â”€â”€ Controllers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _experienceController  = TextEditingController();
  final _addressController     = TextEditingController();
  final _descriptionController = TextEditingController();

  // â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final WorkerRegistrationRepository _registrationRepo = WorkerRegistrationRepository();
  final AuthRepository _authRepo = AuthRepository();

  int    _step              = 0;  // 0=Expertise  1=Profile  2=Review
  String _selectedCategory  = AppConstants.serviceCategories.first;
  bool   _isSubmitting      = false;

  late final AnimationController _stepAnim;
  late       Animation<double>   _fadeAnim;

  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut);
    _stepAnim.forward();
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    _experienceController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _nextStep() {
    bool valid = true;
    if (_step == 0) valid = _step1FormKey.currentState?.validate() ?? false;
    if (_step == 1) valid = _step2FormKey.currentState?.validate() ?? false;
    if (!valid) return;

    _stepAnim.reverse().then((_) {
      setState(() => _step++);
      _stepAnim.forward();
    });
  }

  void _prevStep() {
    _stepAnim.reverse().then((_) {
      setState(() => _step--);
      _stepAnim.forward();
    });
  }

  // â”€â”€ Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _submitRegistration() async {
    setState(() => _isSubmitting = true);
    try {
      final user = await _authRepo.registerWithEmail(
        email: widget.email,
        password: widget.password,
        name: widget.name,
        phone: widget.phone,
        role: AppConstants.workerRole,
      );
      if (user == null) throw Exception('Failed to create user account');

      await _authRepo.updateUserApprovalStatus(user.id, false);
      await _registrationRepo.submitWorkerRegistration(
        userId:          user.id,
        name:            widget.name,
        email:           widget.email,
        phone:           widget.phone,
        serviceCategory: _selectedCategory,
        experience:      _experienceController.text.trim(),
        description:     _descriptionController.text.trim(),
        address:         _addressController.text.trim(),
      );
      await FirebaseAuth.instance.signOut();

      if (mounted) _showSuccessDialog();
    } catch (e) {
      debugPrint('Worker registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.successLight, shape: BoxShape.circle,
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Application Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your worker application has been submitted and is now under review.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            WcNotice(
              message: 'You will be able to sign in once an admin approves your application. This typically takes 1–2 business days.',
              color: AppColors.warning,
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
        actions: [
          WcPrimaryButton(
            label: 'Back to Sign In',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              )
            : null,
        title: const Text('Worker Registration'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          _WizardProgressBar(currentStep: _step, totalSteps: _totalSteps),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                ][_step],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // â”€â”€ Step 0: Expertise â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep0() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            stepNumber: 1,
            title: 'Your Expertise',
            subtitle: 'Tell us what type of work you do',
          ),
          const SizedBox(height: 24),

          // Service category grid
          const Text('Service Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          const Text('Select the primary service you offer',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _CategoryGrid(
            categories: AppConstants.serviceCategories,
            selected: _selectedCategory,
            onSelect: (c) => setState(() => _selectedCategory = c),
          ),

          const SizedBox(height: 20),

          // Experience
          TextFormField(
            controller: _experienceController,
            decoration: const InputDecoration(
              labelText: 'Years of Experience',
              prefixIcon: Icon(Icons.timeline_rounded),
              hintText: 'e.g. 5 years',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your experience' : null,
          ),

          const SizedBox(height: 14),

          // Work area
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Service Area / Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'City or neighbourhood where you work',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your service area' : null,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tooltip(
                  message: 'Pick from map',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final loc = await LocationPickerScreen.pickLocation(
                        context,
                        title: 'Pick Your Service Area',
                      );
                      if (loc != null) {
                        final text = loc.formattedAddress;
                        if (text != 'Unknown location') {
                          _addressController.text = text;
                        }
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Step 1: Profile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep1() {
    const maxChars = 500;
    final charCount = _descriptionController.text.length;
    final nearLimit = charCount > maxChars - 50;

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            stepNumber: 2,
            title: 'About You',
            subtitle: 'Help customers understand your background',
          ),
          const SizedBox(height: 24),

          // Account info summary
          WcCard(
            hasShadow: false,
            borderColor: AppColors.borderLight,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'W',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(widget.email,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    WcStatusBadge(label: _selectedCategory, color: AppColors.worker),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('About Yourself',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(
                '$charCount / $maxChars',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: nearLimit ? AppColors.error : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Minimum 20 characters â€” describe your skills, experience, and approach',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 6,
            maxLength: maxChars,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: const InputDecoration(
              hintText: 'e.g. I have 5 years of experience as a licensed electrician. I specialize in residential wiring, fault finding, and panel upgrades...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please describe yourself';
              if (v.trim().length < 20) return 'Please write at least 20 characters';
              return null;
            },
          ),

          const SizedBox(height: 20),

          WcNotice(
            message: 'Your application will be reviewed by our admin team before your account is activated.',
            color: AppColors.info,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  // â”€â”€ Step 3: Review â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep2() {
    final meta = _kCategoryMeta[_selectedCategory];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          stepNumber: 3,
          title: 'Review & Submit',
          subtitle: 'Confirm your details before sending',
        ),
        const SizedBox(height: 24),

        // Category highlight
        WcCard(
          backgroundColor: (meta?.color ?? AppColors.primary).withValues(alpha: 0.06),
          borderColor: (meta?.color ?? AppColors.primary).withValues(alpha: 0.35),
          hasShadow: false,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: (meta?.color ?? AppColors.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (meta?.color ?? AppColors.primary).withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(meta?.icon ?? Icons.work_rounded, color: meta?.color ?? AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedCategory,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                  Text('${_experienceController.text.trim()} experience',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Details card
        WcCard(
          hasShadow: false,
          borderColor: AppColors.borderLight,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ReviewRow(icon: Icons.person_rounded,      label: 'Name',         value: widget.name),
              _ReviewRow(icon: Icons.mail_outline_rounded, label: 'Email',        value: widget.email),
              _ReviewRow(icon: Icons.phone_outlined,       label: 'Phone',        value: widget.phone),
              _ReviewRow(icon: Icons.location_on_outlined, label: 'Service Area', value: _addressController.text.trim()),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Description preview
        WcCard(
          hasShadow: false,
          borderColor: AppColors.borderLight,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About You',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(
                _descriptionController.text.trim(),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.55),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        WcNotice(
          message: 'By submitting, you agree to our platform terms. An admin will review your application within 1–2 business days.',
          color: AppColors.warning,
          icon: Icons.gavel_rounded,
        ),

        const SizedBox(height: 28),

        WcPrimaryButton(
          label: 'Submit Application',
          icon: Icons.send_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitRegistration,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ],
    );
  }

  // â”€â”€ Bottom navigation bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBottomBar() {
    if (_step == _totalSteps - 1) return const SizedBox.shrink(); // Submit is inline on step 2

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            WcOutlinedButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: _prevStep,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: WcPrimaryButton(
              label: _step == _totalSteps - 2 ? 'Review Application' : 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _nextStep,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Wizard progress bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WizardProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  static const _labels = ['Expertise', 'Profile', 'Review'];

  const _WizardProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isDone   = i < currentStep;
          final isActive = i == currentStep;
          final color    = isDone || isActive ? AppColors.primary : AppColors.borderLight;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bar segment
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: isDone ? AppColors.primary : (isActive ? AppColors.primaryLight : AppColors.surfaceAlt),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isActive ? AppColors.primary : AppColors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Step header
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StepHeader extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;

  const _StepHeader({required this.stepNumber, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $stepNumber OF 3',
          style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            letterSpacing: 1.5, color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900,
            color: AppColors.textPrimary, letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Category selection grid
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat      = categories[i];
        final meta     = _kCategoryMeta[cat];
        final isSelected = cat == selected;
        final color    = meta?.color ?? AppColors.primary;

        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.08) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : AppColors.borderLight,
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.25), offset: const Offset(2, 2), blurRadius: 0)]
                  : null,
            ),
            child: Row(
              children: [
                Icon(meta?.icon ?? Icons.work_rounded, size: 18,
                    color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Review row
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'â€”' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Document upload tile

