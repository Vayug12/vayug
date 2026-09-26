import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/interfaces/i_comment_service.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/features/video/core/data/services/comment_service.dart';

final commentServiceProvider = Provider<ICommentService>((ref) {
  return CommentServiceImpl();
});

class VideoCommentsState {
  final List<CommentModel> comments;
  final int totalComments;
  final int currentPage;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting;
  final bool hasMore;
  final String? error;

  const VideoCommentsState({
    this.comments = const [],
    this.totalComments = 0,
    this.currentPage = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.hasMore = true,
    this.error,
  });

  VideoCommentsState copyWith({
    List<CommentModel>? comments,
    int? totalComments,
    int? currentPage,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return VideoCommentsState(
      comments: comments ?? this.comments,
      totalComments: totalComments ?? this.totalComments,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VideoCommentsNotifier extends StateNotifier<VideoCommentsState> {
  final ICommentService _commentService;
  final String videoId;

  VideoCommentsNotifier(this._commentService, this.videoId)
      : super(const VideoCommentsState()) {
    loadComments();
  }

  Future<void> loadComments({bool isRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentPage: isRefresh ? 1 : state.currentPage,
    );

    try {
      final result = await _commentService.getComments(
        videoId,
        page: 1,
        limit: 20,
      );

      state = state.copyWith(
        comments: result.comments,
        totalComments: result.totalComments,
        currentPage: 1,
        hasMore: result.hasNextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<void> loadMoreComments() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;

    try {
      final result = await _commentService.getComments(
        videoId,
        page: nextPage,
        limit: 20,
      );

      final existingIds = state.comments.map((c) => c.id).toSet();
      final fresh = result.comments.where((c) => !existingIds.contains(c.id)).toList();

      state = state.copyWith(
        comments: [...state.comments, ...fresh],
        totalComments: result.totalComments,
        currentPage: nextPage,
        hasMore: result.hasNextPage,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> addComment(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final newComment = await _commentService.addComment(videoId, trimmed);

      state = state.copyWith(
        comments: [newComment, ...state.comments],
        totalComments: state.totalComments + 1,
        isSubmitting: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    final originalComments = state.comments;
    final originalCount = state.totalComments;

    // Optimistic removal
    state = state.copyWith(
      comments: state.comments.where((c) => c.id != commentId).toList(),
      totalComments: Math.max(0, state.totalComments - 1),
    );

    try {
      final success = await _commentService.deleteComment(videoId, commentId);
      if (!success) {
        state = state.copyWith(
          comments: originalComments,
          totalComments: originalCount,
        );
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        comments: originalComments,
        totalComments: originalCount,
        error: 'Failed to delete comment',
      );
      return false;
    }
  }

  Future<void> toggleLike(String commentId) async {
    final index = state.comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = state.comments[index];
    final wasLiked = comment.isLiked;
    final newLikes = wasLiked ? Math.max(0, comment.likes - 1) : comment.likes + 1;

    // Optimistic update
    final updatedList = List<CommentModel>.from(state.comments);
    updatedList[index] = comment.copyWith(
      isLiked: !wasLiked,
      likes: newLikes,
    );
    state = state.copyWith(comments: updatedList);

    try {
      final result = await _commentService.toggleLikeComment(videoId, commentId);
      if (mounted) {
        final currentIdx = state.comments.indexWhere((c) => c.id == commentId);
        if (currentIdx != -1) {
          final confirmedList = List<CommentModel>.from(state.comments);
          confirmedList[currentIdx] = confirmedList[currentIdx].copyWith(
            isLiked: result.isLiked,
            likes: result.likes,
          );
          state = state.copyWith(comments: confirmedList);
        }
      }
    } catch (e) {
      // Rollback
      final rollbackList = List<CommentModel>.from(state.comments);
      final rollbackIdx = rollbackList.indexWhere((c) => c.id == commentId);
      if (rollbackIdx != -1) {
        rollbackList[rollbackIdx] = comment;
        state = state.copyWith(comments: rollbackList);
      }
    }
  }
}

class Math {
  static int max(int a, int b) => a > b ? a : b;
}

final videoCommentsProvider = StateNotifierProvider.family<VideoCommentsNotifier, VideoCommentsState, String>(
  (ref, videoId) {
    final service = ref.watch(commentServiceProvider);
    return VideoCommentsNotifier(service, videoId);
  },
);
