import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/shared/widgets/interactive_scale_button.dart';

class CommentItemWidget extends StatelessWidget {
  final CommentModel comment;
  final bool isOwner;
  final VoidCallback onLike;
  final VoidCallback? onDelete;
  final VoidCallback? onUserTap;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.isOwner = false,
    required this.onLike,
    this.onDelete,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing4,
        vertical: AppSpacing.spacing2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: onUserTap,
            child: _buildAvatar(),
          ),
          SizedBox(width: AppSpacing.spacing3),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username & Time
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: onUserTap,
                        child: Text(
                          comment.user.name,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.spacing2),
                    Text(
                      comment.formattedTime,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.spacing1),

                // Comment Text
                Text(
                  comment.content,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.spacing2),

          // Action column (Like & Delete)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveScaleButton(
                onTap: onLike,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.spacing1),
                  child: Icon(
                    comment.isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                    size: 18,
                    color: comment.isLiked ? AppColors.error : AppColors.textTertiary,
                  ),
                ),
              ),
              if (comment.likes > 0)
                Text(
                  comment.formattedLikes,
                  style: AppTypography.labelSmall.copyWith(
                    color: comment.isLiked ? AppColors.error : AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (isOwner && onDelete != null) ...[
                SizedBox(height: AppSpacing.spacing1),
                InteractiveScaleButton(
                  onTap: onDelete,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.spacing1),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    const size = 34.0;
    if (comment.user.profilePic.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: comment.user.profilePic,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildFallbackAvatar(size),
          errorWidget: (_, __, ___) => _buildFallbackAvatar(size),
        ),
      );
    }
    return _buildFallbackAvatar(size);
  }

  Widget _buildFallbackAvatar(double size) {
    final initial = comment.user.name.isNotEmpty
        ? comment.user.name[0].toUpperCase()
        : 'U';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfacePrimary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
