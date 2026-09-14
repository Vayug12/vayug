import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';

class PaidVideoBadge extends StatelessWidget {
  final VideoModel video;

  const PaidVideoBadge({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    if (!video.isPaidVideo) return const SizedBox.shrink();

    final paid = video.paidAccess!;
    final priceLabel = '₹${paid.priceAmount.toInt()}';
    final previewLabel = '${paid.previewPercentage}% Preview';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: AppColors.borderPrimary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: AppColors.textPrimary,
          ),
          AppSpacing.hSpace4,
          Text(
            '$priceLabel · $previewLabel',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
