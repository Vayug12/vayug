import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';

class CommentsEmptyState extends StatelessWidget {
  const CommentsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing4,
          vertical: AppSpacing.spacing6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.spacing4),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(height: AppSpacing.spacing3),
            Text(
              'No comments yet',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.spacing1),
            Text(
              'Start the conversation',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
