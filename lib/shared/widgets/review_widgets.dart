import 'package:flutter/material.dart';
import '../../data/models/review_model.dart';
import '../../data/models/user_model.dart';
import 'star_rating_widget.dart';

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final UserModel? customer;
  final bool showCustomerInfo;

  const ReviewCard({
    super.key,
    required this.review,
    this.customer,
    this.showCustomerInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showCustomerInfo) ...[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange[100],
                    backgroundImage: customer?.profileImageUrl != null
                        ? NetworkImage(customer!.profileImageUrl!)
                        : null,
                    child: customer?.profileImageUrl == null
                        ? const Icon(Icons.person, color: Colors.orange)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer?.name ?? 'Anonymous',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(review.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      _formatDate(review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                StarRatingWidget(
                  rating: review.rating.toDouble(),
                  itemSize: 18,
                  ignoreGestures: true,
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ReviewsList extends StatelessWidget {
  final List<Map<String, dynamic>> reviews; // Contains review and customer data
  final bool isLoading;
  final String? emptyMessage;

  const ReviewsList({
    super.key,
    required this.reviews,
    this.isLoading = false,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No reviews yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final reviewData = reviews[index];
        final review = reviewData['review'] as ReviewModel;
        final customer = reviewData['customer'] as UserModel?;

        return ReviewCard(
          review: review,
          customer: customer,
        );
      },
    );
  }
}

class ReviewStats extends StatelessWidget {
  final Map<String, dynamic> stats;

  const ReviewStats({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final totalReviews = stats['totalReviews'] ?? 0;
    final averageRating = (stats['averageRating'] ?? 0.0) as double;
    final ratingDistribution = stats['ratingDistribution'] as Map<int, int>? ?? 
        {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Overall Rating
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StarRatingWidget(
                        rating: averageRating,
                        itemSize: 24,
                        ignoreGestures: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalReviews reviews',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rating Distribution
                Expanded(
                  flex: 2,
                  child: Column(
                    children: List.generate(5, (index) {
                      final starCount = 5 - index;
                      final count = ratingDistribution[starCount] ?? 0;
                      final percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$starCount'),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 30,
                              child: Text(
                                count.toString(),
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}