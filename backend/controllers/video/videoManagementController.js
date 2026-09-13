import mongoose from 'mongoose';
import fs from 'fs';
import path from 'path';
import Video from '../../models/Video.js';
import User from '../../models/User.js';
import redisService from '../../services/caching/redisService.js';
import { invalidateCache, VideoCacheKeys } from '../../middleware/cacheMiddleware.js';
import { logger } from '../../middleware/traceMiddleware.js';
import { serializeVideo } from '../../utils/serializers/videoSerializer.js';
import queueService from '../../services/yugFeedServices/queueService.js';
import videoCleanupService from '../../services/uploadServices/videoCleanupService.js';

/**
 * **Update Video Metadata**
 */
export const updateVideo = async (req, res) => {
  try {
    const videoId = req.params.id;
    const googleId = req.user.googleId;
    const { videoName, link, links, tags, seriesId, episodeNumber, quizzes, thumbnailKey } = req.body;

    if (!videoName || videoName.trim() === '') {
      return res.status(400).json({ error: 'Video name is required' });
    }

    const user = await User.findOne({ googleId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const video = await Video.findById(videoId).populate('uploader', 'name profilePic googleId');
    if (!video) {
      logger.warn(req.traceId, 'Video not found for update', { videoId });
      return res.status(404).json({ error: 'Video not found' });
    }

    if (video.uploader._id.toString() !== user._id.toString()) {
      return res.status(403).json({ error: 'Not authorized to update this video' });
    }

    video.videoName = videoName.trim();
    if (links !== undefined) {
      let parsedLinks = [];
      if (Array.isArray(links)) {
        parsedLinks = links.map(l => {
          if (typeof l === 'string' && l.trim()) return { title: '', url: l.trim() };
          if (l && typeof l === 'object' && l.url) return { title: (l.title || '').trim(), url: String(l.url).trim() };
          return null;
        }).filter(Boolean);
      }
      // Clean up any heavy attachment files that were removed from the video
      await videoCleanupService.cleanupOrphanedAttachments(video.links, parsedLinks);

      video.links = parsedLinks;
      video.link = parsedLinks.length > 0 ? parsedLinks[0].url : '';
    } else if (link !== undefined) {
      const newParsed = link.trim() ? [{ title: '', url: link.trim() }] : [];
      await videoCleanupService.cleanupOrphanedAttachments(video.links, newParsed);
      video.link = link.trim();
      video.links = newParsed;
    }
    if (seriesId !== undefined) video.seriesId = seriesId;
    if (episodeNumber !== undefined) video.episodeNumber = parseInt(episodeNumber) || 0;

    if (tags !== undefined) {
      if (Array.isArray(tags)) {
        video.tags = tags.map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
      } else if (typeof tags === 'string') {
        video.tags = tags.split(',').map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
      }
    }
 
    if (quizzes !== undefined && Array.isArray(quizzes)) {
      video.quizzes = quizzes;
    }

    if (thumbnailKey) {
      const { default: cloudflareR2Service } = await import('../../services/uploadServices/cloudflareR2Service.js');
      // If there was an old thumbnail in R2, clean it up to prevent orphaned files
      if (video.thumbnailUrl) {
        const oldKey = videoCleanupService.getR2KeyFromUrl(video.thumbnailUrl);
        if (oldKey && oldKey !== thumbnailKey) {
          cloudflareR2Service.deleteFile(oldKey).catch(() => {});
        }
      }
      video.thumbnailUrl = cloudflareR2Service.getPublicUrl(thumbnailKey);
      logger.info(req.traceId, 'Video thumbnail updated', { videoId, thumbnailKey });
    }

    video.updatedAt = new Date();
    await video.save();
    
    if (redisService.getConnectionStatus()) {
      const keysToInvalidate = [
        'videos:feed:*',
        `videos:user:${googleId}`,
        VideoCacheKeys.all(),
        VideoCacheKeys.single(videoId),
        `video:data:${videoId}`,
        `video:data:v2:${videoId}`,
        'user:feed:*'
      ];

      if (video.seriesId) {
        try {
          const siblings = await Video.find({ seriesId: video.seriesId }).select('_id').lean();
          siblings.forEach(s => {
            keysToInvalidate.push(VideoCacheKeys.single(s._id.toString()));
            keysToInvalidate.push(`video:data:${s._id.toString()}`);
            keysToInvalidate.push(`video:data:v2:${s._id.toString()}`);
          });
        } catch (e) {}
      }

      await invalidateCache(keysToInvalidate);
    }

    const videoObj = video.toObject();
    const transformedVideo = serializeVideo(videoObj, req.apiVersion, user._id.toString(), req.traceId);

    res.json({ 
      success: true, 
      message: 'Video updated successfully',
      video: transformedVideo
    });
  } catch (error) {
    logger.error(req.traceId, 'Error updating video', error, { videoId: req.params.id });
    res.status(500).json({ error: 'Failed to update video' });
  }
};

/**
 * **Update Video Series**
 */
export const updateVideoSeries = async (req, res) => {
  try {
    const videoId = req.params.id;
    const googleId = req.user.googleId;
    const { episodeIds, seriesId } = req.body;

    if (!Array.isArray(episodeIds) || episodeIds.length === 0) {
      return res.status(400).json({ error: 'episodeIds array is required' });
    }

    const user = await User.findOne({ googleId }).select('_id').lean();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const uniqueVideoIds = [...new Set([videoId, ...episodeIds])];
    const videos = await Video.find({ _id: { $in: uniqueVideoIds } });

    if (videos.length === 0) return res.status(404).json({ error: 'Videos not found' });

    for (const v of videos) {
      if (v.uploader.toString() !== user._id.toString()) {
        return res.status(403).json({ error: `Not authorized to update video: ${v._id}` });
      }
    }

    const targetSeriesId = seriesId || `series_${Date.now()}`;

    await Video.updateMany(
      { 
        seriesId: targetSeriesId, 
        uploader: user._id,
        _id: { $nin: uniqueVideoIds } 
      },
      { 
        $set: { 
          seriesId: null, 
          episodeNumber: 0,
          updatedAt: new Date()
        } 
      }
    );

    const bulkOps = episodeIds.map((id, index) => ({
      updateOne: {
        filter: { _id: id },
        update: { 
          $set: { 
            seriesId: targetSeriesId, 
            episodeNumber: index + 1,
            updatedAt: new Date()
          } 
        }
      }
    }));

    if (!episodeIds.includes(videoId)) {
      bulkOps.push({
        updateOne: {
          filter: { _id: videoId },
          update: { 
            $set: { 
              seriesId: targetSeriesId,
              updatedAt: new Date()
            } 
          }
        }
      });
    }

    if (bulkOps.length > 0) await Video.bulkWrite(bulkOps);

    if (redisService.getConnectionStatus()) {
      const keysToInvalidate = [
        'videos:feed:*',
        `videos:user:${googleId}`,
        VideoCacheKeys.all(),
        VideoCacheKeys.single(videoId),
        `video:data:${videoId}`
      ];

      uniqueVideoIds.forEach(id => {
        keysToInvalidate.push(VideoCacheKeys.single(id.toString()));
        keysToInvalidate.push(`video:data:${id.toString()}`);
      });
      
      await invalidateCache(keysToInvalidate);
    }

    let episodes = await Video.find({ 
      seriesId: targetSeriesId, 
      processingStatus: 'completed' 
    })
    .select('_id videoName thumbnailUrl episodeNumber seriesId duration')
    .sort({ episodeNumber: 1 }).lean();

    episodes = episodes.map(ep => ({ ...ep, _id: ep._id.toString() }));

    res.json({
      success: true,
      message: 'Series linked and updated successfully',
      seriesId: targetSeriesId,
      episodes: episodes
    });

  } catch (error) {
    console.error('❌ Error updating video series:', error);
    res.status(500).json({ error: 'Failed to update video series', message: error.message });
  }
};

/**
 * Clean up and cascade series metadata when video(s) belonging to a series are deleted.
 * - If 0 videos remain in the series: nothing to do.
 * - If 1 video remains: automatically unlink it (seriesId = null, episodeNumber = 0).
 * - If 2+ videos remain: re-sequence episodeNumbers (1, 2, 3...).
 * Returns an array of affected sibling video ID strings (for cache invalidation).
 */
const cascadeSeriesCleanup = async (seriesIds) => {
  const affectedSiblingIds = [];
  if (!seriesIds || seriesIds.length === 0) return affectedSiblingIds;

  for (const sId of seriesIds) {
    if (!sId) continue;
    try {
      const remaining = await Video.find({ seriesId: sId })
        .sort({ episodeNumber: 1, createdAt: 1 })
        .select('_id episodeNumber');

      if (remaining.length === 1) {
        const survivor = remaining[0];
        await Video.updateOne(
          { _id: survivor._id },
          { $set: { seriesId: null, episodeNumber: 0, updatedAt: new Date() } }
        );
        affectedSiblingIds.push(survivor._id.toString());
      } else if (remaining.length > 1) {
        const bulkOps = remaining.map((vid, idx) => ({
          updateOne: {
            filter: { _id: vid._id },
            update: { $set: { episodeNumber: idx + 1, updatedAt: new Date() } }
          }
        }));
        await Video.bulkWrite(bulkOps);
        remaining.forEach(v => affectedSiblingIds.push(v._id.toString()));
      }
    } catch (err) {
      console.error(`⚠️ Error cascading series cleanup for seriesId ${sId}:`, err);
    }
  }

  return affectedSiblingIds;
};

/**
 * Video Deletion Controllers
 */
export const deleteVideo = async (req, res) => {
  try {
    const videoId = req.params.id;
    const googleId = req.user.googleId;

    const user = await User.findOne({ googleId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const video = await Video.findById(videoId);
    if (!video) return res.status(404).json({ error: 'Video not found' });

    if (video.uploader.toString() !== user._id.toString()) {
      return res.status(403).json({ error: 'Not authorized to delete this video' });
    }

    const seriesId = video.seriesId;

    // 1. Permanently delete all storage assets (heavy attachment files, APKs, PDFs, video qualities, HLS, thumbnails) and all DB metadata
    await videoCleanupService.deleteVideoCompletely(video, { googleId });

    // 2. Cascade series cleanup if this video was part of a series
    let affectedSiblingIds = [];
    if (seriesId) {
      affectedSiblingIds = await cascadeSeriesCleanup([seriesId]);
    }

    if (redisService.getConnectionStatus() && affectedSiblingIds.length > 0) {
      const cacheKeys = [];
      affectedSiblingIds.forEach(id => {
        cacheKeys.push(VideoCacheKeys.single(id));
        cacheKeys.push(`video:data:${id}`);
      });
      await invalidateCache(cacheKeys);
    }

    res.json({ success: true, message: 'Video and all associated files deleted successfully' });
  } catch (error) {
    console.error('❌ Error deleting video:', error);
    res.status(500).json({ error: 'Failed to delete video' });
  }
};

export const bulkDeleteVideos = async (req, res) => {
  try {
    const { videoIds } = req.body;
    const googleId = req.user.googleId;

    if (!Array.isArray(videoIds) || videoIds.length === 0) {
      return res.status(400).json({ error: 'No video IDs provided' });
    }

    const user = await User.findOne({ googleId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const objectIds = videoIds.map(id => new mongoose.Types.ObjectId(id));

    // Capture all videos to delete with their file links and series info
    const videosToDelete = await Video.find({
      _id: { $in: objectIds },
      uploader: user._id
    });

    const seriesIdsToClean = [...new Set(videosToDelete.map(v => v.seriesId).filter(Boolean))];

    // Permanently delete each video and all associated storage files (APKs, PDFs, video, thumbnail, HLS) & DB metadata
    for (const v of videosToDelete) {
      await videoCleanupService.deleteVideoCompletely(v, { googleId });
    }

    // Cascade series cleanup
    const affectedSiblingIds = await cascadeSeriesCleanup(seriesIdsToClean);

    if (redisService.getConnectionStatus() && affectedSiblingIds.length > 0) {
      const patterns = [];
      for (const id of affectedSiblingIds) {
        patterns.push(VideoCacheKeys.single(id));
        patterns.push(`video:data:${id}`);
      }
      await invalidateCache(patterns);
    }

    res.json({ 
      success: true, 
      message: `Successfully deleted ${videosToDelete.length} videos and all associated files`,
      deletedCount: videosToDelete.length
    });
  } catch (error) {
    console.error('❌ Bulk delete error:', error);
    res.status(500).json({ error: 'Failed to delete videos' });
  }
};

/**
 * Utility & Cleanup Controllers
 */
export const cleanupTempHLS = async (req, res) => {
  try {
    const tempDir = path.join(process.cwd(), 'temp', 'hls');
    if (fs.existsSync(tempDir)) {
      const folders = fs.readdirSync(tempDir);
      let count = 0;
      for (const folder of folders) {
        const folderPath = path.join(tempDir, folder);
        if (fs.statSync(folderPath).isDirectory()) {
          fs.rmSync(folderPath, { recursive: true, force: true });
          count++;
        }
      }
      res.json({ success: true, message: `Cleaned up ${count} temp HLS folders` });
    } else {
      res.json({ success: true, message: 'Temp HLS directory does not exist' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to cleanup temp HLS' });
  }
};

export const cleanupOrphaned = async (req, res) => {
  try {
    const videos = await Video.find({}).select('uploader').lean();
    const videoIds = videos.map(v => v._id);
    const users = await User.find({ videos: { $in: videoIds } });
    
    let updatedCount = 0;
    for (const user of users) {
      const validVideos = user.videos.filter(id => videoIds.some(vid => vid.equals(id)));
      if (validVideos.length !== user.videos.length) {
        user.videos = validVideos;
        await user.save();
        updatedCount++;
      }
    }
    res.json({ success: true, message: `Checked ${users.length} users, updated ${updatedCount}` });
  } catch (error) {
    res.status(500).json({ error: 'Cleanup failed' });
  }
};

export const cleanupBrokenVideos = async (req, res) => {
  try {
    const result = await Video.deleteMany({
      $or: [
        { videoUrl: { $exists: false } },
        { videoUrl: '' },
        { thumbnailUrl: { $exists: false } },
        { thumbnailUrl: '' }
      ],
      processingStatus: 'completed'
    });
    res.json({ success: true, message: `Deleted ${result.deletedCount} broken videos` });
  } catch (error) {
    res.status(500).json({ error: 'Cleanup failed' });
  }
};

export const syncUserVideoArrays = async (req, res) => {
  try {
    const users = await User.find({});
    let totalUpdated = 0;
    for (const user of users) {
      const activeVideos = await Video.find({ uploader: user._id }).select('_id').lean();
      user.videos = activeVideos.map(v => v._id.toString());
      await user.save();
      totalUpdated++;
    }
    res.json({ success: true, updatedUsers: totalUpdated });
  } catch (error) {
    res.status(500).json({ error: 'Sync failed' });
  }
};
