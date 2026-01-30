import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final double itemSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool allowHalfRating;
  final bool ignoreGestures;
  final Function(double)? onRatingUpdate;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.itemSize = 20.0,
    this.activeColor,
    this.inactiveColor,
    this.allowHalfRating = true,
    this.ignoreGestures = true,
    this.onRatingUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: allowHalfRating,
      ignoreGestures: ignoreGestures,
      itemCount: 5,
      itemSize: itemSize,
      itemBuilder: (context, _) => Icon(
        Icons.star,
        color: activeColor ?? Colors.amber,
      ),
      onRatingUpdate: onRatingUpdate ?? (rating) {},
      unratedColor: inactiveColor ?? Colors.grey[300],
    );
  }
}

class RatingDisplay extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double starSize;
  final TextStyle? textStyle;
  final MainAxisAlignment mainAxisAlignment;
  final bool showReviewCount;

  const RatingDisplay({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.starSize = 16.0,
    this.textStyle,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.showReviewCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        StarRatingWidget(
          rating: rating,
          itemSize: starSize,
          ignoreGestures: true,
        ),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: textStyle ?? 
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        if (showReviewCount) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: textStyle?.copyWith(color: Colors.grey[600]) ?? 
                Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ],
    );
  }
}

class RatingInput extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final String? title;
  final double starSize;

  const RatingInput({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.title,
    this.starSize = 40.0,
  });

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: RatingBar.builder(
            initialRating: _currentRating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: widget.starSize,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _currentRating = rating;
              });
              widget.onRatingChanged(rating);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getRatingText(_currentRating),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: _getRatingColor(_currentRating),
            ),
          ),
        ),
      ],
    );
  }

  String _getRatingText(double rating) {
    switch (rating.round()) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Rate your experience';
    }
  }

  Color _getRatingColor(double rating) {
    switch (rating.round()) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}