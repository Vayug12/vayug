import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/app_button.dart';

/// Error state screen shown when initial feed fetch fails.
class FeedErrorState extends StatelessWidget {
  final String? errorMessage;
  final bool isLoadingOrRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onTestConnection;

  const FeedErrorState({
    Key? key,
    required this.errorMessage,
    required this.isLoadingOrRefreshing,
    required this.onRefresh,
    required this.onTestConnection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          AppSpacing.vSpace16,
          Text(
            'Failed to load videos',
            style: TextStyle(
              color: AppColors.white,
              fontSize: AppTypography.fontSizeXL,
              fontWeight: AppTypography.weightBold,
            ),
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            AppSpacing.vSpace8,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.spacing8),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.fontSizeSM,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          AppSpacing.vSpace24,
          AppButton(
            label: isLoadingOrRefreshing ? 'Refreshing...' : 'Try Again',
            onPressed: isLoadingOrRefreshing ? null : onRefresh,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.medium,
            isLoading: isLoadingOrRefreshing,
          ),
          AppSpacing.vSpace12,
          AppButton(
            label: 'Test Connection',
            onPressed: isLoadingOrRefreshing ? null : onTestConnection,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
          ),
        ],
      ),
    );
  }
}
