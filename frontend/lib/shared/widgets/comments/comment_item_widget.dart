import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/comments/comment_avatar.dart';
import 'package:vayug/shared/widgets/comments/comment_more_menu.dart';

class CommentItemWidget extends StatefulWidget {
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
  State<CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<CommentItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final isLong = comment.content.length > 130 ||
        '\n'.allMatches(comment.content).length >= 3;
    final name = comment.user.name.startsWith('@')
        ? comment.user.name
        : '@${comment.user.name}';
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing5,
        vertical: AppSpacing.spacing3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onUserTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.square(
              dimension: AppSpacing.minTouchTargetApple,
              child: Align(
                alignment: Alignment.topLeft,
                child: CommentAvatar(
                  imageUrl: comment.user.profilePic,
                  name: comment.user.name,
                  size: 36,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.spacing2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(comment.formattedTime,
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.spacing2),
                Text(
                  comment.content,
                  maxLines: isLong && !_isExpanded ? 3 : null,
                  overflow: isLong && !_isExpanded
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                  style: AppTypography.bodyMedium.copyWith(height: 1.5),
                ),
                if (isLong)
                  TextButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      alignment: Alignment.centerLeft,
                      textStyle: AppTypography.labelMedium,
                    ),
                    child: Text(_isExpanded
                        ? AppText.get('comment_less', fallback: 'Show less')
                        : AppText.get('comment_more', fallback: 'Read more')),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onLike();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: comment.isLiked
                            ? AppColors.primaryLight
                            : AppColors.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        alignment: Alignment.centerLeft,
                        textStyle: AppTypography.labelMedium,
                      ),
                      icon: Icon(
                          comment.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16),
                      label: Text(comment.likes > 0
                          ? comment.formattedLikes
                          : AppText.get('comment_like', fallback: 'Like')),
                    ),
                    const Spacer(),
                    CommentMoreMenu(
                      content: comment.content,
                      onDelete: widget.isOwner ? widget.onDelete : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
