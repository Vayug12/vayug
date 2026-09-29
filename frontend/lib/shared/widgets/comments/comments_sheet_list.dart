import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/providers/comment_providers.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/comments/comment_item_widget.dart';
import 'package:vayug/shared/widgets/comments/comments_empty_state.dart';
import 'package:vayug/shared/widgets/comments/comments_sheet_header.dart';
import 'package:vayug/shared/widgets/comments/telegram_connect_banner.dart';

class CommentsSheetList extends ConsumerWidget {
  final String videoId;
  final VideoCommentsState state;
  final String? currentUserId;
  final bool isVideoOwner;
  final ScrollController scrollController;

  const CommentsSheetList({
    super.key,
    required this.videoId,
    required this.state,
    required this.currentUserId,
    required this.isVideoOwner,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoCommentsProvider(videoId).notifier);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.extentAfter < 200 &&
            notification.metrics.pixels > 0) {
          notifier.loadMoreComments();
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfacePrimary,
        onRefresh: () => notifier.loadComments(isRefresh: true),
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: CommentsSheetHeader(
                  totalComments: state.totalComments,
                  isVideoOwner: isVideoOwner),
            ),
            if (isVideoOwner)
              const SliverToBoxAdapter(child: TelegramConnectBanner()),
            if (state.comments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildPlaceholder(ref),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final comment = state.comments[index];
                    final canDelete = isVideoOwner ||
                        (currentUserId != null &&
                            currentUserId!.isNotEmpty &&
                            [
                              comment.user.id,
                              comment.user.googleId,
                              comment.user.mongoId
                            ].contains(currentUserId));
                    return CommentItemWidget(
                      key: ValueKey(comment.id),
                      comment: comment,
                      isOwner: canDelete,
                      onLike: () => notifier.toggleLike(comment.id),
                      onDelete: canDelete
                          ? () => notifier.deleteComment(comment.id)
                          : null,
                    );
                  },
                  childCount: state.comments.length,
                  findChildIndexCallback: (key) {
                    final index = state.comments
                        .indexWhere((comment) => ValueKey(comment.id) == key);
                    return index < 0 ? null : index;
                  },
                ),
              ),
            if (state.isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.spacing4),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(WidgetRef ref) {
    if (state.isLoading) {
      return const Center(
          child: SizedBox.square(
              dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (state.error != null) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                AppText.get('comments_load_error',
                    fallback: 'Could not load comments'),
                style: AppTypography.labelLarge,
                textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.spacing2),
            Text(
                AppText.get('comments_retry_hint',
                    fallback: 'Check your connection and try again.'),
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center),
            TextButton(
              onPressed: () => ref
                  .read(videoCommentsProvider(videoId).notifier)
                  .loadComments(isRefresh: true),
              child: Text(AppText.get('btn_retry')),
            ),
          ],
        ),
      );
    }
    return const CommentsEmptyState();
  }
}
