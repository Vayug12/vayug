import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/utils/app_text.dart';

class CommentsEmptyState extends StatelessWidget {
  const CommentsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.spacing5,
          vertical: AppSpacing.spacing6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.spacing4),
              decoration: BoxDecoration(
                color: AppColors.surfacePrimary,
                borderRadius: AppRadius.borderRadiusCard,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 28, color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.spacing4),
            Text(AppText.get('comments_empty', fallback: 'No comments yet'),
                style: AppTypography.labelLarge),
            SizedBox(height: AppSpacing.spacing1),
            Text(
                AppText.get('comments_start',
                    fallback: 'Start the conversation'),
                style: AppTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}
