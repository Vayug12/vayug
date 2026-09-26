import mongoose from 'mongoose';
import Comment from '../models/Comment.js';
import Video from '../models/Video.js';
import User from '../models/User.js';
import redisService from './caching/redisService.js';
import { invalidateCache, VideoCacheKeys } from '../middleware/cacheMiddleware.js';
import telegramService from './telegramService.js';

class VideoCommentService {
  /**
   * Fetch paginated comments for a video
   */
  async getVideoComments(videoId, { page = 1, limit = 20, requestingUserId = null }) {
    if (!videoId || !mongoose.Types.ObjectId.isValid(videoId)) {
      throw new Error('Invalid video ID');
    }

    const safePage = Math.max(1, parseInt(page, 10) || 1);
    const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (safePage - 1) * safeLimit;

    // Resolve requesting user ObjectId if googleId was passed
    let requestingUserObjectIdStr = null;
    if (requestingUserId) {
      if (mongoose.Types.ObjectId.isValid(requestingUserId)) {
        requestingUserObjectIdStr = requestingUserId.toString();
      } else {
        const user = await User.findOne({ googleId: requestingUserId }).select('_id').lean();
        if (user) {
          requestingUserObjectIdStr = user._id.toString();
        }
      }
    }

    const [comments, totalComments] = await Promise.all([
      Comment.find({
        targetType: 'video',
        targetId: videoId
      })
        .populate('user', 'name profilePic googleId _id')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(safeLimit)
        .lean(),
      Comment.countDocuments({
        targetType: 'video',
        targetId: videoId
      })
    ]);

    const formattedComments = comments.map(comment => {
      const isLiked = requestingUserObjectIdStr && Array.isArray(comment.likedBy)
        ? comment.likedBy.some(id => (id?._id?.toString() || id?.toString()) === requestingUserObjectIdStr)
        : false;

      return {
        _id: comment._id.toString(),
        id: comment._id.toString(),
        content: comment.content,
        targetId: comment.targetId.toString(),
        targetType: comment.targetType,
        likes: comment.likes || 0,
        isLiked: Boolean(isLiked),
        createdAt: comment.createdAt,
        user: {
          _id: comment.user?._id?.toString() || '',
          id: comment.user?.googleId || comment.user?._id?.toString() || '',
          googleId: comment.user?.googleId || '',
          name: comment.user?.name || 'Vayu User',
          profilePic: comment.user?.profilePic || ''
        }
      };
    });

    return {
      comments: formattedComments,
      pagination: {
        currentPage: safePage,
        totalPages: Math.ceil(totalComments / safeLimit),
        totalComments,
        hasNextPage: safePage * safeLimit < totalComments,
        hasPrevPage: safePage > 1
      }
    };
  }

  /**
   * Add a new comment to a video
   */
  async addComment(videoId, userId, content) {
    if (!videoId || !mongoose.Types.ObjectId.isValid(videoId)) {
      throw new Error('Invalid video ID');
    }

    const trimmedContent = (content || '').trim();
    if (!trimmedContent) {
      throw new Error('Comment content cannot be empty');
    }
    if (trimmedContent.length > 500) {
      throw new Error('Comment exceeds maximum length of 500 characters');
    }

    // Resolve user ObjectId
    let userObjectId = userId;
    let userDoc = null;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      userDoc = await User.findOne({ googleId: userId }).select('_id name profilePic googleId');
      if (!userDoc) throw new Error('User not found');
      userObjectId = userDoc._id;
    } else {
      userDoc = await User.findById(userId).select('_id name profilePic googleId');
      if (!userDoc) throw new Error('User not found');
    }

    const video = await Video.findById(videoId).select('_id uploader commentsCount videoName');
    if (!video) {
      throw new Error('Video not found');
    }

    const comment = new Comment({
      content: trimmedContent,
      user: userObjectId,
      targetType: 'video',
      targetId: videoId
    });

    await comment.save();

    // Increment video comments count atomically
    await Video.findByIdAndUpdate(videoId, { $inc: { commentsCount: 1 } });

    // Invalidate cached video details if redis is connected
    if (redisService.getConnectionStatus()) {
      invalidateCache([VideoCacheKeys.single(videoId)]).catch(() => {});
    }

    // Non-blocking Telegram notification to video uploader
    if (video.uploader && video.uploader.toString() !== userDoc._id.toString()) {
      setImmediate(() => {
        telegramService
          .notifyVideoComment({
            uploaderId: video.uploader,
            commenterUser: userDoc,
            videoTitle: video.videoName,
            videoId: video._id.toString(),
            commentContent: trimmedContent
          })
          .catch(() => {});
      });
    }

    return {
      _id: comment._id.toString(),
      id: comment._id.toString(),
      content: comment.content,
      targetId: comment.targetId.toString(),
      targetType: comment.targetType,
      likes: 0,
      isLiked: false,
      createdAt: comment.createdAt,
      user: {
        _id: userDoc._id.toString(),
        id: userDoc.googleId || userDoc._id.toString(),
        googleId: userDoc.googleId || '',
        name: userDoc.name || 'Vayu User',
        profilePic: userDoc.profilePic || ''
      }
    };
  }

  /**
   * Delete a comment (by author, video uploader, or admin)
   */
  async deleteComment(videoId, commentId, userId, userRole = 'user') {
    if (!commentId || !mongoose.Types.ObjectId.isValid(commentId)) {
      throw new Error('Invalid comment ID');
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      throw new Error('Comment not found');
    }

    if (comment.targetType !== 'video' || comment.targetId.toString() !== videoId.toString()) {
      throw new Error('Comment does not belong to this video');
    }

    // Resolve user ObjectId
    let userObjectIdStr = userId.toString();
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      const user = await User.findOne({ googleId: userId }).select('_id').lean();
      if (user) userObjectIdStr = user._id.toString();
    }

    const isCommentAuthor = comment.user.toString() === userObjectIdStr;

    // Check if user is video uploader
    let isVideoUploader = false;
    const video = await Video.findById(videoId).select('uploader commentsCount').lean();
    if (video && video.uploader) {
      isVideoUploader = video.uploader.toString() === userObjectIdStr;
    }

    const isAdmin = userRole === 'admin';

    if (!isCommentAuthor && !isVideoUploader && !isAdmin) {
      throw new Error('Not authorized to delete this comment');
    }

    await Comment.findByIdAndDelete(commentId);

    // Atomically decrement video comments count (minimum 0)
    await Video.findByIdAndUpdate(videoId, [
      {
        $set: {
          commentsCount: {
            $max: [0, { $subtract: ['$commentsCount', 1] }]
          }
        }
      }
    ]);

    if (redisService.getConnectionStatus()) {
      invalidateCache([VideoCacheKeys.single(videoId)]).catch(() => {});
    }

    return true;
  }

  /**
   * Toggle like on a comment
   */
  async toggleCommentLike(commentId, userId) {
    if (!commentId || !mongoose.Types.ObjectId.isValid(commentId)) {
      throw new Error('Invalid comment ID');
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      throw new Error('Comment not found');
    }

    // Resolve user ObjectId
    let userObjectId = userId;
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      const user = await User.findOne({ googleId: userId }).select('_id').lean();
      if (!user) throw new Error('User not found');
      userObjectId = user._id;
    }

    const userObjectIdStr = userObjectId.toString();
    const isLiked = comment.likedBy.some(id => id.toString() === userObjectIdStr);

    if (isLiked) {
      comment.likedBy = comment.likedBy.filter(id => id.toString() !== userObjectIdStr);
      comment.likes = Math.max(0, (comment.likes || 1) - 1);
    } else {
      comment.likedBy.push(userObjectId);
      comment.likes = (comment.likes || 0) + 1;
    }

    await comment.save();

    return {
      isLiked: !isLiked,
      likes: comment.likes,
      commentId: comment._id.toString()
    };
  }
}

export default new VideoCommentService();
