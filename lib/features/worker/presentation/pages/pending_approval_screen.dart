import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/worker_registration_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/wc_components.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: WcEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Not signed in',
            action: WcOutlinedButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ),
        ),
      );
    }

    // ── Live stream: auto-updates when admin changes status ────────────────
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('worker_registrations')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        WorkerRegistrationModel? reg;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          reg = WorkerRegistrationModel.fromFirestore(snapshot.data!.docs.first);
        }

        final isRejected = reg?.status == WorkerApprovalStatus.rejected;
        final isApproved = reg?.status == WorkerApprovalStatus.approved;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // ── Status illustration ──────────────────────────────────
                  _StatusIllustration(
                    isRejected: isRejected,
                    isApproved: isApproved,
                  ),

                  const SizedBox(height: 28),

                  // ── Application timeline ─────────────────────────────────
                  if (reg != null)
                    _ApplicationTimeline(
                      reg: reg,
                      isRejected: isRejected,
                      isApproved: isApproved,
                    ),

                  const SizedBox(height: 20),

                  // ── Rejection notice ─────────────────────────────────────
                  if (isRejected && reg?.rejectionReason != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: WcCard(
                        borderColor: AppColors.error,
                        backgroundColor: AppColors.errorLight,
                        hasShadow: false,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.feedback_outlined, color: AppColors.error, size: 16),
                                SizedBox(width: 6),
                                Text('Reason for Rejection',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reg!.rejectionReason!,
                              style: const TextStyle(fontSize: 13, color: AppColors.error, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Application details ──────────────────────────────────
                  if (reg != null)
                    _ApplicationDetails(reg: reg),

                  const SizedBox(height: 20),

                  // ── What happens next ────────────────────────────────────
                  if (!isRejected && !isApproved)
                    _WhatHappensNext(),

                  const SizedBox(height: 32),

                  // ── Actions ──────────────────────────────────────────────
                  if (isRejected) ...[
                    WcPrimaryButton(
                      label: 'Start New Application',
                      icon: Icons.refresh_rounded,
                      width: double.infinity,
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    const SizedBox(height: 12),
                  ],

                  WcOutlinedButton(
                    label: 'Sign Out',
                    icon: Icons.logout_rounded,
                    width: double.infinity,
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status illustration
// ─────────────────────────────────────────────────────────────────────────────
class _StatusIllustration extends StatelessWidget {
  final bool isRejected;
  final bool isApproved;

  const _StatusIllustration({required this.isRejected, required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (isApproved) {
      color    = AppColors.success;
      icon     = Icons.verified_rounded;
      title    = 'Application Approved';
      subtitle = 'Your account will be activated shortly.';
    } else if (isRejected) {
      color    = AppColors.error;
      icon     = Icons.cancel_rounded;
      title    = 'Application Rejected';
      subtitle = 'Please review the reason below and re-apply.';
    } else {
      color    = AppColors.warning;
      icon     = Icons.pending_actions_rounded;
      title    = 'Under Review';
      subtitle = 'Your application is being reviewed by our team.';
    }

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), offset: const Offset(4, 4), blurRadius: 0)],
          ),
          child: Icon(icon, size: 44, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w900,
            color: AppColors.textPrimary, letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Application timeline — 3 stages
// ─────────────────────────────────────────────────────────────────────────────
class _ApplicationTimeline extends StatelessWidget {
  final WorkerRegistrationModel reg;
  final bool isRejected;
  final bool isApproved;

  const _ApplicationTimeline({
    required this.reg,
    required this.isRejected,
    required this.isApproved,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(
        icon: Icons.send_rounded,
        label: 'Submitted',
        date: '${reg.createdAt.day}/${reg.createdAt.month}/${reg.createdAt.year}',
        state: _TimelineState.done,
        color: AppColors.success,
      ),
      _TimelineStep(
        icon: Icons.rate_review_outlined,
        label: 'Under Review',
        date: isRejected || isApproved ? 'Reviewed' : 'In progress',
        state: isRejected || isApproved ? _TimelineState.done : _TimelineState.active,
        color: AppColors.info,
      ),
      _TimelineStep(
        icon: isRejected
            ? Icons.cancel_rounded
            : (isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded),
        label: isRejected ? 'Rejected' : (isApproved ? 'Approved' : 'Decision'),
        date: isRejected ? 'See reason below' : (isApproved ? 'Account activated' : 'Pending'),
        state: isRejected
            ? _TimelineState.rejected
            : (isApproved ? _TimelineState.done : _TimelineState.pending),
        color: isRejected ? AppColors.error : (isApproved ? AppColors.success : AppColors.borderLight),
      ),
    ];

    return WcCard(
      hasShadow: false,
      borderColor: AppColors.borderLight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Application Status',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return _TimelineRow(step: step, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

enum _TimelineState { done, active, pending, rejected }

class _TimelineStep {
  final IconData icon;
  final String label;
  final String date;
  final _TimelineState state;
  final Color color;

  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.date,
    required this.state,
    required this.color,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDone     = step.state == _TimelineState.done;
    final isActive   = step.state == _TimelineState.active;
    final isRejected = step.state == _TimelineState.rejected;
    final color      = step.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot + connector
        Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (isDone || isRejected)
                    ? color
                    : (isActive ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDone || isRejected || isActive) ? color : AppColors.borderLight,
                  width: isActive ? 2 : 1.5,
                ),
              ),
              child: Icon(step.icon, size: 16,
                  color: (isDone || isRejected) ? Colors.white : (isActive ? color : AppColors.textMuted)),
            ),
            if (!isLast)
              Container(
                width: 2, height: 32,
                color: isDone ? color.withValues(alpha: 0.4) : AppColors.borderLight,
              ),
          ],
        ),
        const SizedBox(width: 14),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: (isDone || isActive || isRejected) ? FontWeight.w700 : FontWeight.w500,
                        color: (isDone || isActive || isRejected) ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color, width: 1),
                        ),
                        child: Text('NOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(step.date, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsible application details
// ─────────────────────────────────────────────────────────────────────────────
class _ApplicationDetails extends StatefulWidget {
  final WorkerRegistrationModel reg;
  const _ApplicationDetails({required this.reg});

  @override
  State<_ApplicationDetails> createState() => _ApplicationDetailsState();
}

class _ApplicationDetailsState extends State<_ApplicationDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return WcCard(
      hasShadow: false,
      borderColor: AppColors.borderLight,
      child: Column(
        children: [
          // Header toggle
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Your Application',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 14),
                  _DetailLine('Name',         widget.reg.name),
                  _DetailLine('Email',        widget.reg.email),
                  _DetailLine('Phone',        widget.reg.phone),
                  _DetailLine('Category',     widget.reg.serviceCategory),
                  _DetailLine('Experience',   widget.reg.experience),
                  _DetailLine('Service Area', widget.reg.address),
                  const SizedBox(height: 10),
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('About',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppColors.textMuted, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Text(widget.reg.description,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.55)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// What happens next — shown while pending
// ─────────────────────────────────────────────────────────────────────────────
class _WhatHappensNext extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Admin reviews your application',            Icons.manage_search_rounded),
      ('Background & credentials are verified',     Icons.verified_user_outlined),
      ('You receive approval and sign-in access',   Icons.login_rounded),
      ('Start accepting jobs on the platform',      Icons.work_outline_rounded),
    ];

    return WcCard(
      hasShadow: false,
      borderColor: AppColors.info.withValues(alpha: 0.3),
      backgroundColor: AppColors.infoLight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.info, size: 16),
              SizedBox(width: 6),
              Text('What happens next?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Icon(s.$2, size: 14, color: AppColors.info),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.$1,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              children: const [
                Icon(Icons.schedule_rounded, size: 14, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text('This page updates automatically — no need to refresh.',
                      style: TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
