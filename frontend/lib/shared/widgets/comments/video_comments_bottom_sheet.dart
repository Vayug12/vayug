import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/core/providers/comment_providers.dart';
import 'package:vayug/features/auth/presentation/controllers/auth_flow.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/comments/comment_input_field.dart';
import 'package:vayug/shared/widgets/comments/comments_sheet_list.dart';
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
      useSafeArea: true,
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
  ScrollController? _activeScrollController;
  int? _reportedCount;

  Future<void> _handleSignIn() async {
    await AuthFlow.signIn(context, ref, onSuccess: () async {
      if (mounted) {
        VayuSnackBar.showSuccess(
            context, AppText.get('profile_sign_in_success'));
      }
    });
  }

  void _reportCount(VideoCommentsState state) {
    if (state.isLoading ||
        state.error != null ||
        state.totalComments == _reportedCount) {
      return;
    }
    _reportedCount = state.totalComments;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCommentsCountChanged?.call(state.totalComments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(videoCommentsProvider(widget.video.id));
    final auth = ref.watch(googleSignInProvider);
    final userId = (auth.userData?['googleId'] ??
            auth.userData?['id'] ??
            auth.userData?['_id'])
        ?.toString();
    final uploader = widget.video.uploader;
    final isVideoOwner = userId != null &&
        userId.isNotEmpty &&
        [uploader.id, uploader.googleId, uploader.mongoId].contains(userId);
    _reportCount(comments);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.65, 0.94],
        builder: (context, scrollController) {
          _activeScrollController = scrollController;
          return Material(
            color: AppColors.backgroundPrimary,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusSheet,
            ),
            child: Column(
              children: [
                Expanded(
                  child: CommentsSheetList(
                    videoId: widget.video.id,
                    state: comments,
                    currentUserId: userId,
                    isVideoOwner: isVideoOwner,
                    scrollController: scrollController,
                  ),
                ),
                CommentInputField(
                  userProfilePic: auth.userData?['profilePic']?.toString(),
                  isSignedIn: auth.isSignedIn,
                  isSubmitting: comments.isSubmitting,
                  onSubmit: (text) async {
                    final success = await ref
                        .read(videoCommentsProvider(widget.video.id).notifier)
                        .addComment(text);
                    if (success &&
                        mounted &&
                        (_activeScrollController?.hasClients ?? false)) {
                      _activeScrollController!.animateTo(0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut);
                    }
                    return success;
                  },
                  onSignInRequired: _handleSignIn,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
