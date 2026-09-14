import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/screens/promotional_links_screen.dart';

/// **AdMultiLinkField - Sub-widget for advertiser multi-link input**
///
/// Clean, modular widget (< 100 lines) following `design.md`.
/// Allows advertiser to add, view, and manage multiple links with custom titles.
class AdMultiLinkField extends StatelessWidget {
  final List<LinkItemData> links;
  final ValueChanged<List<LinkItemData>> onLinksChanged;

  const AdMultiLinkField({
    Key? key,
    required this.links,
    required this.onLinksChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final count = links.length;

    return Container(
      padding: EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderPrimary,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            color: count > 0 ? AppColors.primaryLight : AppColors.textSecondary,
            size: 20,
          ),
          AppSpacing.hSpace12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Additional Destination Links',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vSpace4,
                Text(
                  count > 0
                      ? '$count link${count > 1 ? 's' : ''} configured (multi-link sheet)'
                      : 'Optional: add multiple destination URLs',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hSpace8,
          TextButton(
            onPressed: () {
              PromotionalLinksScreen.push(
                context,
                initialLinks: links,
                onSave: onLinksChanged,
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              count > 0 ? 'Edit ($count)' : '+ Add Links',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
