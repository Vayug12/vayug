import cron from 'node-cron';
import Video from '../../models/Video.js';
import videoCleanupService from './videoCleanupService.js';

/**
 * Main function to find and permanently delete exclusive/private videos older than 7 days.
 */
export const runCleanup = async () => {
  try {
    console.log('⏰ Starting Exclusive/Private Video 7-Day Auto-Cleanup Job...');
    
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    // Find all subscriber-only videos created more than 7 days ago
    const expiredVideos = await Video.find({
      isSubscriberOnly: true,
      createdAt: { $lt: sevenDaysAgo }
    }).populate('uploader', '_id googleId');
    
    console.log(`🔍 Found ${expiredVideos.length} expired exclusive/private videos.`);
    
    let deletedCount = 0;
    
    for (const video of expiredVideos) {
      const videoId = video._id.toString();
      console.log(`🚨 Processing cleanup for expired private video: "${video.videoName}" (${videoId}) by creator: ${video.uploader?._id}`);
      
      await videoCleanupService.deleteVideoCompletely(video, {
        googleId: video.uploader?.googleId
      });
      
      deletedCount++;
      console.log(`✅ Finished permanent cleanup for video: ${videoId}`);
    }
    
    console.log(`🎉 Exclusive video cleanup job completed. Total videos permanently deleted: ${deletedCount}`);
  } catch (error) {
    console.error('❌ Error in exclusive video cleanup job:', error);
  }
};

// Scheduler setup
let cleanupJob = null;

export const startScheduler = () => {
  if (cleanupJob) {
    console.log('⚠️ Exclusive video cleanup cron is already running');
    return;
  }
  
  // Run daily at midnight (00:00)
  cleanupJob = cron.schedule('0 0 * * *', async () => {
    await runCleanup();
  });
  
  console.log('📅 Exclusive video cleanup cron scheduled to run daily at 00:00');
};

export const stopScheduler = () => {
  if (cleanupJob) {
    cleanupJob.stop();
    cleanupJob = null;
    console.log('⏹️ Exclusive video cleanup cron stopped');
  }
};

export default {
  runCleanup,
  startScheduler,
  stopScheduler
};
