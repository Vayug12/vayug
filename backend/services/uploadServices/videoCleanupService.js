import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import Video from '../../models/Video.js';
import User from '../../models/User.js';
import View from '../../models/View.js';
import WatchHistory from '../../models/WatchHistory.js';
import FeedHistory from '../../models/FeedHistory.js';
import SavedVideo from '../../models/SavedVideo.js';
import Report from '../../models/Report.js';
import EncryptedVideoKey from '../../models/EncryptedVideoKey.js';
import cloudflareR2Service from './cloudflareR2Service.js';
import queueService from '../yugFeedServices/queueService.js';
import redisService from '../caching/redisService.js';
import { invalidateCache, VideoCacheKeys } from '../../middleware/cacheMiddleware.js';

class VideoCleanupService {
  /**
   * Parses a public URL to extract the corresponding Cloudflare R2 storage key.
   * Only matches internal storage keys (resources/, videos/, thumbnails/, hls/, uploads/).
   * Safely ignores external URLs (e.g. google.com, github.com).
   */
  getR2KeyFromUrl(url) {
    if (!url || typeof url !== 'string' || !url.startsWith('http')) return null;

    try {
      const parsedUrl = new URL(url);
      const hostname = parsedUrl.hostname.toLowerCase();
      const pathname = parsedUrl.pathname;

      // Check if URL belongs to SnehaYog CDN, Cloudflare R2, or matches our storage structure
      const isInternalDomain = 
        hostname.includes('snehayog') || 
        hostname.includes('cloudflarestorage.com') ||
        (process.env.CLOUDFLARE_R2_PUBLIC_DOMAIN && hostname.includes(process.env.CLOUDFLARE_R2_PUBLIC_DOMAIN.replace(/^https?:\/\//, '')));

      // Also check pathname prefixes to identify our uploaded resources
      const isStoragePath = /^\/(resources|videos|thumbnails|hls|uploads)\//i.test(pathname);

      if (!isInternalDomain && !isStoragePath) {
        return null; // External website link, DO NOT touch
      }

      let key = decodeURIComponent(pathname);
      if (key.startsWith('/')) {
        key = key.substring(1);
      }
      return key;
    } catch (e) {
      console.warn('⚠️ Failed to parse URL for R2 key:', url, e.message);
      return null;
    }
  }

  /**
   * Check if a URL or path points to a local file in uploads/ and unlinks it.
   */
  async cleanupLocalFile(urlOrPath) {
    if (!urlOrPath || typeof urlOrPath !== 'string') return;

    try {
      let relativePath = null;
      if (urlOrPath.includes('/uploads/resources/')) {
        const parts = urlOrPath.split('/uploads/resources/');
        if (parts[1]) {
          relativePath = path.join('uploads', 'resources', path.basename(parts[1]));
        }
      } else if (urlOrPath.includes('/uploads/temp/')) {
        const parts = urlOrPath.split('/uploads/temp/');
        if (parts[1]) {
          relativePath = path.join('uploads', 'temp', path.basename(parts[1]));
        }
      } else if (urlOrPath.startsWith('uploads/')) {
        relativePath = urlOrPath;
      }

      if (relativePath) {
        const fullPath = path.join(process.cwd(), relativePath);
        if (fs.existsSync(fullPath)) {
          await fsp.unlink(fullPath);
          console.log(`🧹 Cleaned up local file: ${fullPath}`);
        }
      }
    } catch (err) {
      console.warn('⚠️ Error cleaning up local file:', urlOrPath, err.message);
    }
  }

  /**
   * Cleans up a single attachment resource (Cloudflare R2 or local disk).
   */
  async cleanupAttachmentUrl(url) {
    if (!url || typeof url !== 'string') return;

    // 1. Check if on Cloudflare R2
    const r2Key = this.getR2KeyFromUrl(url);
    if (r2Key) {
      try {
        await cloudflareR2Service.deleteFile(r2Key);
        console.log(`🗑️ Deleted attachment from Cloudflare R2: ${r2Key}`);
      } catch (err) {
        console.warn(`⚠️ Failed to delete R2 attachment ${r2Key}:`, err.message);
      }
    }

    // 2. Check if local file fallback
    await this.cleanupLocalFile(url);
  }

  /**
   * Compares previous links with updated links on a video edit.
   * If any heavy attachment (APK, PDF, Notes, etc.) was removed, deletes it immediately
   * from Cloudflare R2 and local disk to avoid orphaned heavy files.
   */
  async cleanupOrphanedAttachments(oldLinks, newLinks) {
    try {
      const getUrls = (links) => {
        if (!links) return [];
        if (Array.isArray(links)) {
          return links.map(l => (typeof l === 'string' ? l : l?.url)).filter(Boolean);
        }
        if (typeof links === 'string' && links.trim()) {
          return [links.trim()];
        }
        return [];
      };

      const oldUrls = getUrls(oldLinks);
      const newUrls = new Set(getUrls(newLinks));

      const orphanedUrls = oldUrls.filter(url => !newUrls.has(url));

      if (orphanedUrls.length > 0) {
        console.log(`🧹 Found ${orphanedUrls.length} orphaned attachment(s) to cleanup`);
        for (const url of orphanedUrls) {
          await this.cleanupAttachmentUrl(url);
        }
      }
    } catch (err) {
      console.error('❌ Error cleaning up orphaned attachments:', err);
    }
  }

  /**
   * Cleans up ALL physical storage assets for a video:
   * 1. Attached heavy files (APKs, PDFs, Notes in video.links and video.link)
   * 2. Video renditions & qualities (video.videoUrl, canonicalMp4Url, qualitiesGenerated)
   * 3. Video thumbnail (video.thumbnailUrl)
   * 4. HLS streams (master playlists and all .ts segments under the folder prefix)
   * 5. Any leftover local temp files
   */
  async cleanupVideoStorageAssets(video) {
    if (!video) return;

    const r2KeysToDelete = new Set();
    const localFilesToDelete = new Set();

    const registerUrl = (url) => {
      if (!url || typeof url !== 'string') return;
      const key = this.getR2KeyFromUrl(url);
      if (key) {
        r2KeysToDelete.add(key);
      }
      if (url.includes('/uploads/')) {
        localFilesToDelete.add(url);
      }
    };

    // 1. Heavy Attachments & Resources (APKs, PDFs, Notes, Docs)
    if (video.links && Array.isArray(video.links)) {
      video.links.forEach(l => {
        const u = typeof l === 'string' ? l : l?.url;
        registerUrl(u);
      });
    }
    if (video.link) {
      registerUrl(video.link);
    }

    // 2. Video renditions
    registerUrl(video.videoUrl);
    registerUrl(video.canonicalMp4Url);
    registerUrl(video.preloadQualityUrl);
    registerUrl(video.lowQualityUrl);
    registerUrl(video.mediumQualityUrl);
    registerUrl(video.highQualityUrl);

    if (video.qualitiesGenerated && Array.isArray(video.qualitiesGenerated)) {
      video.qualitiesGenerated.forEach(q => registerUrl(q?.url));
    }

    // 3. Thumbnail
    registerUrl(video.thumbnailUrl);

    // 4. HLS Variants
    if (video.hlsVariants && Array.isArray(video.hlsVariants)) {
      video.hlsVariants.forEach(v => registerUrl(v?.url));
    }

    // 5. Delete batch R2 keys
    if (r2KeysToDelete.size > 0) {
      console.log(`🗑️ Deleting ${r2KeysToDelete.size} R2 file(s) for video: ${video._id}`);
      await cloudflareR2Service.deleteObjects(Array.from(r2KeysToDelete));
    }

    // 6. Delete entire HLS folder prefixes (all .m3u8 and .ts segments)
    const hlsUrls = [video.hlsMasterPlaylistUrl, video.hlsPlaylistUrl].filter(Boolean);
    for (const hlsUrl of hlsUrls) {
      const r2Key = this.getR2KeyFromUrl(hlsUrl);
      if (r2Key) {
        const lastSlash = r2Key.lastIndexOf('/');
        if (lastSlash !== -1) {
          const prefix = r2Key.substring(0, lastSlash + 1);
          console.log(`🧹 Deleting HLS folder prefix from R2: ${prefix}`);
          await cloudflareR2Service.deletePrefix(prefix);
        }
      }
    }

    // 7. Clean up local files
    for (const localUrl of localFilesToDelete) {
      await this.cleanupLocalFile(localUrl);
    }
  }

  /**
   * Cleans up all database metadata and cross-collection references:
   * - View records
   * - WatchHistory records
   * - FeedHistory records
   * - SavedVideo records
   * - EncryptedVideoKey records
   * - Report records
   * - Pull videoId from User.videos and saved/liked lists
   */
  async cleanupVideoDatabaseMetadata(videoId, uploaderId) {
    if (!videoId) return;

    try {
      await Promise.allSettled([
        View.deleteMany({ video: videoId }),
        WatchHistory.deleteMany({ videoId }),
        FeedHistory.deleteMany({ videoId }),
        SavedVideo.deleteMany({ video: videoId }),
        EncryptedVideoKey.deleteMany({ videoId }),
        Report.deleteMany({ targetType: 'video', targetId: videoId.toString() }),
        uploaderId ? User.findByIdAndUpdate(uploaderId, { $pull: { videos: videoId } }) : Promise.resolve(),
        User.updateMany(
          { $or: [{ savedVideos: videoId }, { likedVideos: videoId }] },
          { $pull: { savedVideos: videoId, likedVideos: videoId } }
        ),
      ]);
      console.log(`🗃️ Cleaned up all database metadata for video: ${videoId}`);
    } catch (err) {
      console.error('❌ Error cleaning up video database metadata:', err);
    }
  }

  /**
   * Invalidates all Redis caches associated with the video and uploader
   */
  async invalidateVideoCache(videoId, googleId, extraSiblingIds = []) {
    if (!redisService.getConnectionStatus()) return;

    try {
      const keys = [
        'videos:feed:*',
        VideoCacheKeys.all(),
        VideoCacheKeys.single(videoId),
        `video:data:${videoId}`,
      ];

      if (googleId) {
        keys.push(`videos:user:${googleId}*`);
        keys.push(`user:feed:${googleId}:*`);
      }

      if (Array.isArray(extraSiblingIds)) {
        extraSiblingIds.forEach(id => {
          keys.push(VideoCacheKeys.single(id));
          keys.push(`video:data:${id}`);
        });
      }

      await invalidateCache(keys);
      console.log(`🧹 Invalidated caches for video: ${videoId}`);
    } catch (err) {
      console.warn('⚠️ Failed to invalidate video cache:', err.message);
    }
  }

  /**
   * Complete cascading video deletion:
   * Deletes all physical storage files (heavy attachments, video, HLS, thumbnails),
   * all database metadata across collections, queue jobs, and the video document itself.
   */
  async deleteVideoCompletely(videoOrId, options = {}) {
    let video = videoOrId;
    if (typeof videoOrId === 'string' || !videoOrId?.videoName) {
      const id = typeof videoOrId === 'string' ? videoOrId : videoOrId?._id;
      if (id) {
        video = await Video.findById(id).populate('uploader', '_id googleId');
      }
    }

    if (!video) {
      console.warn('⚠️ Video not found for deletion');
      return false;
    }

    const videoId = video._id.toString();
    const uploaderId = video.uploader?._id || video.uploader;
    const googleId = options.googleId || video.uploader?.googleId;

    console.log(`🚨 Starting complete deletion for video "${video.videoName}" (${videoId})`);

    // 1. Delete all storage assets (heavy files, APKs, PDFs, videos, thumbnails, HLS)
    await this.cleanupVideoStorageAssets(video);

    // 2. Delete all DB metadata across collections
    await this.cleanupVideoDatabaseMetadata(video._id, uploaderId);

    // 3. Remove queue jobs
    try {
      await queueService.removeVideoJob(videoId);
    } catch (queueErr) {
      console.warn('⚠️ Queue job cleanup failed:', queueErr.message);
    }

    // 3.5 Release daily upload quota if reserved
    try {
      const { releaseUploadSlotForVideo } = await import('./dailyUploadQuotaService.js');
      await releaseUploadSlotForVideo(video);
    } catch (quotaErr) {
      // Non-fatal if video had no quota slot reserved
    }

    // 4. Delete the video document itself from MongoDB
    await Video.findByIdAndDelete(video._id);

    // 5. Invalidate cache
    await this.invalidateVideoCache(videoId, googleId, options.siblingIds || []);

    console.log(`✅ Permanently deleted video and all assets: ${videoId}`);
    return true;
  }
}

export default new VideoCleanupService();
