import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/app_button.dart';

/// Empty state screen shown when no videos are returned for the feed.
class FeedEmptyState extends StatelessWidget {
  final bool isLoadingOrRefreshing;
  final VoidCallback onRefresh;

  const FeedEmptyState({
    Key? key,
    required this.isLoadingOrRefreshing,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          AppSpacing.vSpace16,
          Text(
            'No videos available',
            style: TextStyle(
              color: AppColors.white,
              fontSize: AppTypography.fontSizeXL,
              fontWeight: AppTypography.weightBold,
            ),
          ),
          AppSpacing.vSpace8,
          Text(
            'Check back later for new content',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTypography.fontSizeSM,
            ),
          ),
          AppSpacing.vSpace24,
          AppButton(
            label: isLoadingOrRefreshing ? 'Refreshing...' : 'Refresh',
            onPressed: isLoadingOrRefreshing ? null : onRefresh,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.medium,
            isLoading: isLoadingOrRefreshing,
          ),
        ],
      ),
    );
  }
}
