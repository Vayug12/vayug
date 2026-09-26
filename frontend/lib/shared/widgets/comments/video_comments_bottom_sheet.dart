import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/core/providers/comment_providers.dart';
import 'package:vayug/features/auth/presentation/controllers/auth_flow.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/widgets/comments/comment_input_field.dart';
import 'package:vayug/shared/widgets/comments/comment_item_widget.dart';
import 'package:vayug/shared/widgets/comments/comments_empty_state.dart';
import 'package:vayug/shared/widgets/comments/telegram_connect_banner.dart';
import 'package:vayug/shared/widgets/interactive_scale_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class VideoCommentsBottomSheet extends ConsumerStatefulWidget {
  final VideoModel video;
  final ValueChanged<int>? onCommentsCountChanged;

  const VideoCommentsBottomSheet({
    super.key,
    required this.video,
    this.onCommentsCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VideoModel video,
    ValueChanged<int>? onCommentsCountChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoCommentsBottomSheet(
        video: video,
        onCommentsCountChanged: onCommentsCountChanged,
      ),
    );
  }

  @override
  ConsumerState<VideoCommentsBottomSheet> createState() =>
      _VideoCommentsBottomSheetState();
}

class _VideoCommentsBottomSheetState
    extends ConsumerState<VideoCommentsBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(videoCommentsProvider(widget.video.id).notifier).loadMoreComments();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    await AuthFlow.signIn(
      context,
      ref,
      onSuccess: () async {
        if (mounted) {
          VayuSnackBar.showSuccess(context, 'Signed in successfully');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsState = ref.watch(videoCommentsProvider(widget.video.id));
    final authState = ref.watch(googleSignInProvider);
    final currentUserId =
        (authState.userData?['googleId'] ?? authState.userData?['id'] ?? authState.userData?['_id'])?.toString();
    final profilePic = authState.userData?['profilePic']?.toString();
    final isVideoOwner = currentUserId != null &&
        (widget.video.uploader.id == currentUserId ||
            widget.video.uploader.googleId == currentUserId ||
            widget.video.uploader.mongoId == currentUserId);
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.50;

    // Report comments count changes to parent
    if (widget.onCommentsCountChanged != null && commentsState.totalComments != widget.video.commentsCount) {
      widget.onCommentsCountChanged!(commentsState.totalComments);
    }

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SizedBox(
        height: sheetHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.4),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(commentsState.totalComments),
              if (isVideoOwner) const TelegramConnectBanner(),
              Expanded(
                child: _buildBody(commentsState, currentUserId),
              ),
              CommentInputField(
                userProfilePic: profilePic,
                isSignedIn: authState.isSignedIn,
                isSubmitting: commentsState.isSubmitting,
                onSubmit: (text) async {
                  final success = await ref
                       .read(videoCommentsProvider(widget.video.id).notifier)
                       .addComment(text);
                  if (success && mounted) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                onSignInRequired: _handleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalComments) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.spacing4,
        AppSpacing.spacing2,
        AppSpacing.spacing2,
        AppSpacing.spacing2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: AppSpacing.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Comments',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  if (totalComments > 0) ...[
                    SizedBox(width: AppSpacing.spacing2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalComments',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              InteractiveScaleButton(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.spacing1),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(VideoCommentsState state, String? currentUserId) {
    if (state.isLoading && state.comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }

    if (state.error != null && state.comments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.spacing4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.spacing2),
              TextButton(
                onPressed: () => ref
                    .read(videoCommentsProvider(widget.video.id).notifier)
                    .loadComments(isRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.comments.isEmpty) {
      return const CommentsEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfacePrimary,
      onRefresh: () => ref
          .read(videoCommentsProvider(widget.video.id).notifier)
          .loadComments(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(vertical: AppSpacing.spacing2),
        itemCount: state.comments.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.spacing1),
        itemBuilder: (context, index) {
          if (index == state.comments.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }

          final comment = state.comments[index];
          final isOwner = currentUserId != null &&
              (comment.user.id == currentUserId ||
                  comment.user.googleId == currentUserId ||
                  comment.user.mongoId == currentUserId ||
                  widget.video.uploader.id == currentUserId ||
                  widget.video.uploader.googleId == currentUserId);

          return CommentItemWidget(
            comment: comment,
            isOwner: isOwner,
            onLike: () => ref
                .read(videoCommentsProvider(widget.video.id).notifier)
                .toggleLike(comment.id),
            onDelete: isOwner
                ? () => ref
                    .read(videoCommentsProvider(widget.video.id).notifier)
                    .deleteComment(comment.id)
                : null,
          );
        },
      ),
    );
  }
}
