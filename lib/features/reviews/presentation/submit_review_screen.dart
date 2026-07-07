import 'package:flutter/material.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/job_model.dart';
import '../../../data/models/worker_model.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wc_components.dart';

class SubmitReviewScreen extends StatefulWidget {
  final JobModel job;
  final WorkerModel worker;

  const SubmitReviewScreen({super.key, required this.job, required this.worker});

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final review = ReviewModel(
        id: '',
        jobId: widget.job.id,
        workerId: widget.worker.id,
        customerId: widget.job.customerId,
        rating: _rating.round(),
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await ReviewRepository().createReview(review);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted. Thank you!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Failed to submit review');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leave a Review'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Worker card ────────────────────────────────────────────
            WcCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Icon(Icons.engineering_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.worker.skills.join(' · '),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.worker.bio.isNotEmpty ? widget.worker.bio : 'Verified worker',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        RatingDisplay(
                          rating: widget.worker.avgRating,
                          reviewCount: widget.worker.ratingCount,
                          starSize: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Job details ────────────────────────────────────────────
            WcCard(
              hasShadow: false,
              borderColor: AppColors.borderLight,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Job Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  _JobDetailRow(label: 'Service', value: widget.job.serviceType),
                  _JobDetailRow(label: 'Location', value: widget.job.address),
                  _JobDetailRow(label: 'Completed', value: _formatDate(widget.job.completedAt)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Star rating ────────────────────────────────────────────
            WcCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'How would you rate this service?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap a star to set your rating',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  RatingInput(
                    title: '',
                    initialRating: _rating,
                    starSize: 44,
                    onRatingChanged: (r) => setState(() => _rating = r),
                  ),
                  const SizedBox(height: 12),
                  if (_rating > 0)
                    Text(
                      _ratingLabel(_rating.round()),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.rating),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Comment ────────────────────────────────────────────────
            WcCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Additional Comments',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Optional — share specific feedback',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe your experience...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            WcPrimaryButton(
              label: 'Submit Review',
              icon: Icons.rate_review_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitReview,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _ratingLabel(int stars) {
    switch (stars) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _JobDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _JobDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
