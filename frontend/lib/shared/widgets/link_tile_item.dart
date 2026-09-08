import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';

/// **LinkTileItem - Linktree-style clean title-only button tile**
///
/// Follows `design.md`: 14px radius, calm dark aesthetic, min 50px height.
/// Displays ONLY the Title/Name prominently. No domain subtitle.
/// Tapping immediately triggers [onTap].
class LinkTileItem extends StatelessWidget {
  final LinkItemData item;
  final VoidCallback onTap;

  const LinkTileItem({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.spacing16,
            vertical: AppSpacing.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
              AppSpacing.hSpace12,
              Expanded(
                child: Text(
                  item.displayTitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.hSpace8,
              const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
