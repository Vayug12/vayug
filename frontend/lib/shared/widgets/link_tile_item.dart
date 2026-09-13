import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';

/// **LinkTileItem - Linktree-style clean title-only button tile**
///
/// Follows `design.md` & `apple.md`:
/// - 14px radius
/// - Calm dark aesthetic
/// - Min 52px height (44x44 touch target compliant)
/// - Smart icon detection for APKs, PDFs, and web links
/// - Tapping immediately triggers [onTap]
class LinkTileItem extends StatelessWidget {
  final LinkItemData item;
  final VoidCallback onTap;

  const LinkTileItem({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  IconData get _leadingIcon {
    final lower = '${item.url} ${item.title}'.toLowerCase();
    if (lower.contains('.apk')) return Icons.android_rounded;
    if (lower.contains('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.contains('.zip')) return Icons.folder_zip_rounded;
    if (lower.contains('.doc') || lower.contains('.txt')) return Icons.description_rounded;
    return Icons.link_rounded;
  }

  IconData get _trailingIcon {
    final lower = '${item.url} ${item.title}'.toLowerCase();
    if (lower.contains('.apk') ||
        lower.contains('.pdf') ||
        lower.contains('.zip') ||
        lower.contains('download')) {
      return Icons.file_download_outlined;
    }
    return Icons.open_in_new_rounded;
  }

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
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.squircle),
                ),
                child: Icon(
                  _leadingIcon,
                  color: AppColors.primaryLight,
                  size: 18,
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
              Icon(
                _trailingIcon,
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
