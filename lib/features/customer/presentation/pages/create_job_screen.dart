import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/job_model.dart';
import '../../../../data/models/location_model.dart';
import '../../../../shared/widgets/wc_components.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Service category metadata
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kServiceMeta = <String, _ServiceMeta>{
  'Plumber':          _ServiceMeta(Icons.plumbing_rounded,            Color(0xFF2563EB), 'Pipes, leaks, fixtures'),
  'Electrician':      _ServiceMeta(Icons.electrical_services_rounded, Color(0xFFD97706), 'Wiring, panels, outlets'),
  'Mechanic':         _ServiceMeta(Icons.build_rounded,               Color(0xFF6B7280), 'Vehicle & engine work'),
  'Technician':       _ServiceMeta(Icons.computer_rounded,            Color(0xFF7C3AED), 'Electronics, devices'),
  'Carpenter':        _ServiceMeta(Icons.handyman_rounded,            Color(0xFF92400E), 'Furniture, woodwork'),
  'Painter':          _ServiceMeta(Icons.format_paint_rounded,        Color(0xFFDB2777), 'Interior & exterior'),
  'Cleaner':          _ServiceMeta(Icons.cleaning_services_rounded,   Color(0xFF16A34A), 'Home & office cleaning'),
  'Gardener':         _ServiceMeta(Icons.yard_rounded,                Color(0xFF15803D), 'Landscaping, garden'),
  'AC Repair':        _ServiceMeta(Icons.ac_unit_rounded,             Color(0xFF0284C7), 'Air conditioning, HVAC'),
  'Appliance Repair': _ServiceMeta(Icons.kitchen_rounded,             Color(0xFFDC2626), 'Washing machines, fridges'),
};

class _ServiceMeta {
  final IconData icon;
  final Color    color;
  final String   description;
  const _ServiceMeta(this.icon, this.color, this.description);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// CreateJobScreen â€” 4-step wizard for posting a job
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class CreateJobScreen extends StatefulWidget {
  final String        customerId;
  final LocationModel? initialLocation;
  final String?       presetService;

  const CreateJobScreen({
    super.key,
    required this.customerId,
    this.initialLocation,
    this.presetService,
  });

  /// Convenience navigator â€” returns true if a job was posted.
  static Future<bool> show(
    BuildContext context, {
    required String customerId,
    LocationModel? initialLocation,
    String? presetService,
  }) async {
    return await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateJobScreen(
              customerId:      customerId,
              initialLocation: initialLocation,
              presetService:   presetService,
            ),
          ),
        ) ??
        false;
  }

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen>
    with SingleTickerProviderStateMixin {
  // â”€â”€ Controllers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _step2FormKey      = GlobalKey<FormState>();
  final _descController    = TextEditingController();
  final _addressController = TextEditingController();

  // â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _firestore       = FirebaseFirestore.instance;
  final _locationService = LocationService();

  int              _step             = 0;
  String           _selectedService  = '';
  LocationModel?   _selectedLocation;
  bool             _isLoadingLoc     = false;
  bool             _isSubmitting     = false;

  late final AnimationController _anim;
  late       Animation<double>   _fade;

  static const _totalSteps = 4;
  static const _maxDescLen  = 600;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    // Pre-fill from parent
    _selectedService  = widget.presetService ?? AppConstants.serviceCategories.first;
    _selectedLocation = widget.initialLocation;
    if (widget.initialLocation?.address != null) {
      _addressController.text = widget.initialLocation!.address!;
    }
    if (widget.presetService != null) {
      // Skip directly to step 1 if service is pre-selected
      _step = 1;
    }

    _descController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _anim.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _nextStep() {
    if (_step == 0 && _selectedService.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service type')),
      );
      return;
    }
    if (_step == 1 && !(_step2FormKey.currentState?.validate() ?? false)) return;
    if (_step == 2 && _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a location for this job')),
      );
      return;
    }

    _anim.reverse().then((_) {
      setState(() => _step++);
      _anim.forward();
    });
  }

  void _prevStep() {
    _anim.reverse().then((_) {
      setState(() => _step--);
      _anim.forward();
    });
  }

  // â”€â”€ Location helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLoc = true);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _selectedLocation = result.data;
        _addressController.text = result.data!.address ?? '';
      });
    }
    setState(() => _isLoadingLoc = false);
  }

  Future<void> _pickOnMap() async {
    final picked = await LocationPickerScreen.pickLocation(
      context,
      initialLocation: _selectedLocation,
      title: 'Select Job Location',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedLocation = picked;
      if (picked.address != null && picked.address!.isNotEmpty) {
        _addressController.text = picked.address!;
      }
    });
  }

  // â”€â”€ Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _submit() async {
    if (_selectedLocation == null) return;
    setState(() => _isSubmitting = true);

    try {
      // Use address from text field, or fall back to coordinates already stored
      final finalAddress = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : (_selectedLocation!.address ?? '');

      final job = JobModel(
        id: '',
        customerId:  widget.customerId,
        workerId:    null,
        serviceType: _selectedService,
        description: _descController.text.trim(),
        location:    GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        address:     finalAddress,
        status:      AppConstants.jobStatusRequested,
        agreedPrice: null,
        imageUrls:   const [],
        hasReview:   false,
        createdAt:   DateTime.now(),
        acceptedAt:  null,
        completedAt: null,
        updatedAt:   DateTime.now(),
      );

      await _firestore.collection(AppConstants.jobsCollection).add(job.toFirestore());

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
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
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep)
            : null,
        title: const Text('Post a Job'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          _JobWizardProgress(step: _step, total: _totalSteps),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ][_step],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  // â”€â”€ Step 0: Service Selection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JobStepHeader(step: 1, total: _totalSteps, title: 'What do you need?', subtitle: 'Select the type of service required'),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
          ),
          itemCount: AppConstants.serviceCategories.length,
          itemBuilder: (_, i) {
            final cat  = AppConstants.serviceCategories[i];
            final meta = _kServiceMeta[cat];
            final sel  = cat == _selectedService;
            final color = meta?.color ?? AppColors.primary;
            return GestureDetector(
              onTap: () => setState(() => _selectedService = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? color.withValues(alpha: 0.07) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? color : AppColors.borderLight, width: sel ? 2 : 1.5),
                  boxShadow: sel
                      ? [BoxShadow(color: color.withValues(alpha: 0.2), offset: const Offset(3, 3), blurRadius: 0)]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(meta?.icon ?? Icons.work_rounded, size: 20, color: sel ? color : AppColors.textSecondary),
                      const Spacer(),
                      if (sel) Icon(Icons.check_circle_rounded, size: 16, color: color),
                    ]),
                    const SizedBox(height: 8),
                    Text(cat, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? color : AppColors.textPrimary)),
                    if (meta?.description != null)
                      Text(meta!.description, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // â”€â”€ Step 1: Job Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep1() {
    final charCount = _descController.text.length;
    final nearLimit = charCount > _maxDescLen - 60;
    final meta = _kServiceMeta[_selectedService];

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JobStepHeader(step: 2, total: _totalSteps, title: 'Describe the Job', subtitle: 'Help workers understand exactly what you need'),
          const SizedBox(height: 20),

          // Selected service chip
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: meta.color.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(meta.icon, size: 16, color: meta.color),
                  const SizedBox(width: 8),
                  Text(_selectedService, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: meta.color)),
                ]),
              ),
            ),

          // Description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Job Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('$charCount / $_maxDescLen',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: nearLimit ? AppColors.error : AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Be specific â€” good descriptions attract better workers faster',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descController,
            maxLines: 5,
            maxLength: _maxDescLen,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: const InputDecoration(
              hintText: 'e.g. My kitchen tap is dripping constantly. The sink is under the window. I need it fixed today if possible.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please describe the job';
              if (v.trim().length < 15) return 'Please add more detail (at least 15 characters)';
              return null;
            },
          ),

        ],
      ),
    );
  }

  // â”€â”€ Step 2: Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JobStepHeader(step: 3, total: _totalSteps, title: 'Where is the job?', subtitle: 'Set the location so workers know where to go'),
        const SizedBox(height: 24),

        // Current location display
        WcCard(
          hasShadow: false,
          borderColor: _selectedLocation != null ? AppColors.success.withValues(alpha: 0.5) : AppColors.borderLight,
          backgroundColor: _selectedLocation != null ? AppColors.successLight : AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _selectedLocation != null ? AppColors.success.withValues(alpha: 0.15) : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedLocation != null ? AppColors.success.withValues(alpha: 0.4) : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: _selectedLocation != null ? AppColors.success : AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLocation != null ? 'Location Set' : 'No location set',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _selectedLocation != null ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _selectedLocation!.address ??
                            '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                            '${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Location actions
        Row(
          children: [
            Expanded(
              child: WcOutlinedButton(
                label: _isLoadingLoc ? 'Detecting...' : 'Use My Location',
                icon: Icons.my_location_rounded,
                borderColor: AppColors.info,
                textColor: AppColors.info,
                onPressed: _isLoadingLoc ? null : _useCurrentLocation,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: WcPrimaryButton(
                label: 'Pick on Map',
                icon: Icons.map_outlined,
                onPressed: _pickOnMap,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Manual address entry
        const Text('Or type an address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          maxLines: 2,
          onChanged: (_) {
            // Update the display without changing coordinates
            setState(() {});
          },
          decoration: const InputDecoration(
            labelText: 'Street address or area',
            prefixIcon: Icon(Icons.place_outlined),
            hintText: 'e.g. 12 Main Street, Colombo 07',
            alignLabelWithHint: true,
          ),
        ),

        if (_selectedLocation == null) ...[
          const SizedBox(height: 16),
          WcNotice(
            message: 'A location is required so workers can navigate to you. Use GPS or pick a point on the map.',
            color: AppColors.warning,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }

  // â”€â”€ Step 3: Review & Post â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep3() {
    final meta = _kServiceMeta[_selectedService];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JobStepHeader(
            step: 4, total: _totalSteps,
            title: 'Review & Post',
            subtitle: 'Check everything before posting your job'),
        const SizedBox(height: 24),

        // Service highlight
        WcCard(
          backgroundColor: (meta?.color ?? AppColors.primary).withValues(alpha: 0.07),
          borderColor: (meta?.color ?? AppColors.primary).withValues(alpha: 0.4),
          hasShadow: false,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (meta?.color ?? AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (meta?.color ?? AppColors.primary).withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(meta?.icon ?? Icons.work_rounded,
                  color: meta?.color ?? AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedService,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
              const Text('Worker will set the price on acceptance',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]),
        ),

        const SizedBox(height: 12),

        // Description
        WcCard(
          hasShadow: false,
          borderColor: AppColors.borderLight,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('JOB DESCRIPTION',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(_descController.text.trim(),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
          ]),
        ),

        const SizedBox(height: 12),

        // Location
        WcCard(
          hasShadow: false,
          borderColor: AppColors.borderLight,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.location_on_rounded, color: AppColors.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedLocation?.address ??
                    (_selectedLocation != null
                        ? '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                          '${_selectedLocation!.longitude.toStringAsFixed(5)}'
                        : 'No location'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ]),
        ),


        const SizedBox(height: 20),

        WcNotice(
          message:
              'Your request will be visible to qualified workers nearby. '
              'The worker will set a price when accepting the job.',
          color: AppColors.info,
          icon: Icons.info_outline_rounded,
        ),

        const SizedBox(height: 28),

        WcPrimaryButton(
          label: 'Post Job Request',
          icon: Icons.send_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ],
    );
  }

  // â”€â”€ Bottom nav bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNav() {
    if (_step == _totalSteps - 1) return const SizedBox.shrink();
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
              label: _step == _totalSteps - 2 ? 'Review Job' : 'Continue',
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
// Progress bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _JobWizardProgress extends StatelessWidget {
  final int step;
  final int total;
  static const _labels = ['Service', 'Details', 'Location', 'Review'];

  const _JobWizardProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: List.generate(total, (i) {
          final done   = i < step;
          final active = i == step;
          final color  = done || active ? AppColors.primary : AppColors.borderLight;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : (active ? AppColors.primaryLight : AppColors.surfaceAlt),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800,
                                    color: active ? AppColors.primary : AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
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
class _JobStepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String subtitle;

  const _JobStepHeader({required this.step, required this.total, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP $step OF $total',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                letterSpacing: 1.5, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }
}
