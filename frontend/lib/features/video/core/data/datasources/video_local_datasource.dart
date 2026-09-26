import 'package:vayug/features/video/core/data/models/video_model.dart';

class VideoLocalDataSource {
  // Hive removed as per optimization plan (network-first Redis-backed architecture)

  /// Save Video Feed to Cache (No-op)
  Future<void> cacheVideoFeed(List<VideoModel> videos, String type) async {
    // No-op: Caching disabled to improve performance
  }

  /// Get Cached Video Feed (Always returns null to force network fetch)
  Future<List<VideoModel>?> getCachedVideoFeed(String type) async {
    return null;
  }

  /// Delete Cache (No-op)
  Future<void> clearCache() async {
    // No-op
  }
}


