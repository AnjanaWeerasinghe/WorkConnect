import 'package:flutter/material.dart';
import '../../../../data/models/worker_registration_model.dart';
import '../../../../data/repositories/worker_registration_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WorkerRegistrationRepository _registrationRepo = WorkerRegistrationRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.admin,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Admin Panel',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            ),
            onPressed: () async => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.admin,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.admin,
          indicatorWeight: 2.5,
          dividerColor: AppColors.border,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistrationList(WorkerApprovalStatus.pending),
          _buildRegistrationList(WorkerApprovalStatus.approved),
          _buildRegistrationList(WorkerApprovalStatus.rejected),
        ],
      ),
    );
  }

  Widget _buildRegistrationList(WorkerApprovalStatus status) {
    return StreamBuilder<List<WorkerRegistrationModel>>(
      stream: _registrationRepo.getAllRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }
        if (snapshot.hasError) {
          return WcEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load',
            subtitle: 'Could not load registrations. Please try again.',
            action: WcPrimaryButton(
              label: 'Retry',
              onPressed: () => setState(() {}),
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = all.where((r) => r.status == status).toList();

        if (filtered.isEmpty) {
          return WcEmptyState(
            icon: _emptyIcon(status),
            title: _emptyTitle(status),
            subtitle: _emptySubtitle(status),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildRegistrationCard(filtered[index]),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: WcCard(
            hasShadow: false,
            borderColor: AppColors.borderLight,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const WcSkeleton(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(22))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        WcSkeleton(width: 120, height: 14),
                        SizedBox(height: 8),
                        WcSkeleton(width: 180, height: 12),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                const WcSkeleton(width: double.infinity, height: 12),
                const SizedBox(height: 6),
                const WcSkeleton(width: 200, height: 12),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildRegistrationCard(WorkerRegistrationModel reg) {
    final isPending = reg.status == WorkerApprovalStatus.pending;

    return WcCard(
      onTap: () => _showDetailDialog(reg),
      borderColor: isPending ? AppColors.border : AppColors.borderLight,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _roleColor(reg.status).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _roleColor(reg.status).withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    reg.name.isNotEmpty ? reg.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: _roleColor(reg.status),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reg.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(reg.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              WcStatusBadge(label: _statusLabel(reg.status), color: _roleColor(reg.status)),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.work_outline_rounded, label: reg.serviceCategory),
              _InfoChip(icon: Icons.timeline_rounded, label: '${reg.experience} exp'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reg.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),

          // Rejection reason
          if (reg.status == WorkerApprovalStatus.rejected && reg.rejectionReason != null) ...[
            const SizedBox(height: 12),
            WcNotice(
              message: 'Rejection reason: ${reg.rejectionReason}',
              color: AppColors.error,
              icon: Icons.info_outline_rounded,
            ),
          ],

          // Action buttons (pending only)
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: WcOutlinedButton(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    borderColor: AppColors.error,
                    textColor: AppColors.error,
                    onPressed: () => _showRejectDialog(reg),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WcPrimaryButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    backgroundColor: AppColors.success,
                    onPressed: () => _approveWorker(reg),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Detail Dialog ─────────────────────────────────────────────────────────

  void _showDetailDialog(WorkerRegistrationModel reg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _roleColor(reg.status).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _roleColor(reg.status).withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                reg.name.isNotEmpty ? reg.name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _roleColor(reg.status)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(reg.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('Email',      reg.email),
                _DetailRow('Phone',      reg.phone),
                _DetailRow('Category',   reg.serviceCategory),
                _DetailRow('Experience', reg.experience),
                _DetailRow('Area',       reg.address),
                const Divider(height: 20),
                const Text('About',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(reg.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
                const Divider(height: 20),
                _DetailRow('Submitted',
                    '${reg.createdAt.day}/${reg.createdAt.month}/${reg.createdAt.year}'),
                if (reg.reviewedAt != null)
                  _DetailRow('Reviewed',
                      '${reg.reviewedAt!.day}/${reg.reviewedAt!.month}/${reg.reviewedAt!.year}'),

                // ── Documents ──────────────────────────────────────────
                if (reg.idProofUrl != null || reg.certificateUrl != null) ...[
                  const Divider(height: 20),
                  const Text('VERIFICATION DOCUMENTS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 1.2, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: [
                      if (reg.idProofUrl != null)
                        _DocThumbnail(
                          label: 'Government ID',
                          url: reg.idProofUrl!,
                          onTap: () => _viewDocument(context, 'Government ID', reg.idProofUrl!),
                        ),
                      if (reg.certificateUrl != null)
                        _DocThumbnail(
                          label: 'Certificate',
                          url: reg.certificateUrl!,
                          onTap: () => _viewDocument(context, 'Certificate', reg.certificateUrl!),
                        ),
                    ],
                  ),
                ] else ...[
                  const Divider(height: 20),
                  WcNotice(
                    message: 'No verification documents were uploaded.',
                    color: AppColors.textMuted,
                    icon: Icons.document_scanner_outlined,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (reg.status == WorkerApprovalStatus.pending) ...[
            WcOutlinedButton(
              label: 'Reject',
              borderColor: AppColors.error,
              textColor: AppColors.error,
              onPressed: () {
                Navigator.pop(context);
                _showRejectDialog(reg);
              },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
            const SizedBox(width: 4),
            WcPrimaryButton(
              label: 'Approve',
              backgroundColor: AppColors.success,
              onPressed: () {
                Navigator.pop(context);
                _approveWorker(reg);
              },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          ],
        ],
      ),
    );
  }

  void _viewDocument(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (_) => _ImageViewerDialog(title: title, url: url),
    );
  }

  // ── Approve / Reject ──────────────────────────────────────────────────────

  Future<void> _approveWorker(WorkerRegistrationModel reg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Worker'),
        content: Text('Approve ${reg.name} and grant platform access?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          WcPrimaryButton(
            label: 'Approve',
            backgroundColor: AppColors.success,
            onPressed: () => Navigator.pop(context, true),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final success = await _registrationRepo.approveWorkerRegistration(
        registrationId: reg.id, adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '${reg.name} has been approved' : 'Failed to approve worker'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ));
      }
    }
  }

  void _showRejectDialog(WorkerRegistrationModel reg) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejecting ${reg.name}:',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          WcPrimaryButton(
            label: 'Reject',
            backgroundColor: AppColors.error,
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }
              // Capture messenger before popping / awaiting to avoid
              // using BuildContext across an async gap.
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
              final success = await _registrationRepo.rejectWorkerRegistration(
                registrationId: reg.id,
                adminId: adminId,
                reason: reasonController.text.trim(),
              );
              messenger.showSnackBar(SnackBar(
                content: Text(success ? 'Registration rejected' : 'Failed to reject'),
                backgroundColor: success ? AppColors.warning : AppColors.error,
              ));
            },
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _roleColor(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:  return AppColors.warning;
      case WorkerApprovalStatus.approved: return AppColors.success;
      case WorkerApprovalStatus.rejected: return AppColors.error;
    }
  }

  String _statusLabel(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:  return 'Pending';
      case WorkerApprovalStatus.approved: return 'Approved';
      case WorkerApprovalStatus.rejected: return 'Rejected';
    }
  }

  IconData _emptyIcon(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:  return Icons.inbox_outlined;
      case WorkerApprovalStatus.approved: return Icons.check_circle_outline_rounded;
      case WorkerApprovalStatus.rejected: return Icons.cancel_outlined;
    }
  }

  String _emptyTitle(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:  return 'No pending applications';
      case WorkerApprovalStatus.approved: return 'No approved workers yet';
      case WorkerApprovalStatus.rejected: return 'No rejected applications';
    }
  }

  String _emptySubtitle(WorkerApprovalStatus status) {
    switch (status) {
      case WorkerApprovalStatus.pending:  return 'New worker sign-ups will appear here for review.';
      case WorkerApprovalStatus.approved: return 'Approved workers will be listed here.';
      case WorkerApprovalStatus.rejected: return 'Rejected applications will appear here.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info chip — small tag inside registration cards
// ─────────────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail row — label + value in dialog
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document thumbnail — tappable image preview in the detail dialog
// ─────────────────────────────────────────────────────────────────────────────
class _DocThumbnail extends StatelessWidget {
  final String       label;
  final String       url;
  final VoidCallback onTap;

  const _DocThumbnail({required this.label, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  width: 120, height: 90,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 120, height: 90,
                          color: AppColors.surfaceAlt,
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          ),
                        ),
                  errorBuilder: (context, error, _) => Container(
                    width: 120, height: 90,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted, size: 32),
                  ),
                ),
              ),
              // Overlay: magnify icon
              Positioned(
                right: 6, bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.zoom_in_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.admin.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.admin.withValues(alpha: 0.25), width: 1),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.admin, letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ImageViewerDialog extends StatelessWidget {
  final String title;
  final String url;

  const _ImageViewerDialog({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        height: 260,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                errorBuilder: (context, error, _) => Container(
                  height: 200,
                  color: AppColors.surfaceAlt,
                  child: const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_outlined,
                          color: AppColors.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('Could not load image',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
