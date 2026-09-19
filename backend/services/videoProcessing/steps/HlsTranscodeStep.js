import IBaseStep from '../IBaseStep.js';
import hybridVideoService from '../../uploadServices/hybridVideoService.js';
import Video from '../../../models/Video.js';

/**
 * Pipeline Step: HLS Transcoding
 */
class HlsTranscodeStep extends IBaseStep {
  constructor() {
    super('HlsTranscoding');
  }

  async execute(context) {
    const { videoId, localRawPath, videoName, userId } = context;
    
    let lastUpdate = 0;

    const hlsResult = await hybridVideoService.processVideoToHLS(
      localRawPath,
      videoName,
      userId,
      {
        videoId: videoId,
        checkCancelled: async () => {
          if (context.pipeline) {
            return await context.pipeline.isCancelled(videoId);
          }
          return false;
        },
        onProgress: (percent) => {
          context.progress = percent;
          
          // Throttle DB updates to once every 3 seconds to avoid overloading MongoDB
          const now = Date.now();
          if (now - lastUpdate > 3000) {
            lastUpdate = now;
            Video.findByIdAndUpdate(videoId, { processingProgress: percent })
              .catch(err => console.warn('⚠️ Failed to update progress in DB:', err.message));
          }
        }
      }
    );

    // If cancelled during transcoding, abort immediately
    if (context.pipeline && await context.pipeline.isCancelled(videoId)) {
      throw new Error('VIDEO_PROCESSING_CANCELLED');
    }

    // Save results to context for later steps
    context.hlsResult = hlsResult;

    // Check video document still exists and is not cancelled before marking completed
    const currentVideo = await Video.findById(videoId).select('processingStatus');
    if (!currentVideo || currentVideo.processingStatus === 'cancelled') {
      throw new Error('VIDEO_PROCESSING_CANCELLED');
    }

    // Update video record (Partial)
    await Video.findByIdAndUpdate(videoId, {
      videoUrl: hlsResult.videoUrl,
      hlsPlaylistUrl: hlsResult.hlsPlaylistUrl,
      isHLSEncoded: true,
      duration: hlsResult.duration,
      aspectRatio: hlsResult.aspectRatio,
      processingStatus: 'completed', // Mark completed early so users can watch immediately while AI processes in background
      processingProgress: 100
    });
  }
}

export default HlsTranscodeStep;
