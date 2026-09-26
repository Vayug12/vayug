import 'package:vayug/features/video/core/data/models/comment_model.dart';

abstract class ICommentService {
  /// Fetches paginated comments for a video
  Future<CommentPageResult> getComments(
    String videoId, {
    int page = 1,
    int limit = 20,
  });

  /// Adds a new comment to a video
  Future<CommentModel> addComment(
    String videoId,
    String content,
  );

  /// Deletes a comment from a video
  Future<bool> deleteComment(
    String videoId,
    String commentId,
  );

  /// Toggles like on a comment
  Future<CommentModel> toggleLikeComment(
    String videoId,
    String commentId,
  );
}
