import videoCommentService from '../../services/videoCommentService.js';

/**
 * GET /api/videos/:id/comments
 */
export const getVideoComments = async (req, res) => {
  try {
    const videoId = req.params.id;
    const { page = 1, limit = 20 } = req.query;
    const requestingUserId = req.user?._id || req.user?.id || req.user?.googleId || null;

    const result = await videoCommentService.getVideoComments(videoId, {
      page,
      limit,
      requestingUserId
    });

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('❌ Error in getVideoComments:', error);
    res.status(error.message === 'Invalid video ID' ? 400 : 500).json({
      success: false,
      error: error.message || 'Failed to fetch comments'
    });
  }
};

/**
 * POST /api/videos/:id/comments
 */
export const addComment = async (req, res) => {
  try {
    const videoId = req.params.id;
    const { content } = req.body;
    const userId = req.user?._id || req.user?.id || req.user?.googleId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const comment = await videoCommentService.addComment(videoId, userId, content);

    res.status(201).json({
      success: true,
      message: 'Comment added successfully',
      comment
    });
  } catch (error) {
    console.error('❌ Error in addComment:', error);
    const isClientError = error.message.includes('Invalid') ||
      error.message.includes('cannot be empty') ||
      error.message.includes('exceeds maximum') ||
      error.message.includes('not found');

    res.status(isClientError ? 400 : 500).json({
      success: false,
      error: error.message || 'Failed to add comment'
    });
  }
};

/**
 * DELETE /api/videos/:id/comments/:commentId
 */
export const deleteComment = async (req, res) => {
  try {
    const { id: videoId, commentId } = req.params;
    const userId = req.user?._id || req.user?.id || req.user?.googleId;
    const userRole = req.user?.role || 'user';

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    await videoCommentService.deleteComment(videoId, commentId, userId, userRole);

    res.json({
      success: true,
      message: 'Comment deleted successfully'
    });
  } catch (error) {
    console.error('❌ Error in deleteComment:', error);
    const status = error.message.includes('Not authorized')
      ? 403
      : error.message.includes('not found')
      ? 404
      : 400;

    res.status(status).json({
      success: false,
      error: error.message || 'Failed to delete comment'
    });
  }
};

/**
 * POST /api/videos/:id/comments/:commentId/like
 */
export const toggleCommentLike = async (req, res) => {
  try {
    const { commentId } = req.params;
    const userId = req.user?._id || req.user?.id || req.user?.googleId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const result = await videoCommentService.toggleCommentLike(commentId, userId);

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('❌ Error in toggleCommentLike:', error);
    res.status(error.message.includes('not found') ? 404 : 500).json({
      success: false,
      error: error.message || 'Failed to toggle comment like'
    });
  }
};
