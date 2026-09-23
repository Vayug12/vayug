import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/feed/presentation/screens/video_feed_advanced.dart';
import 'package:vayug/features/video/core/presentation/managers/video_controller_manager.dart';
import 'package:vayug/shared/services/deep_link_playback_gate.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class VideoScreen extends ConsumerStatefulWidget {
  final int? initialIndex;
  final List<VideoModel>? initialVideos;
  final String? initialVideoId;
  final String? videoType;
  final bool isMainYugTab; // **NEW: Flag to identify the primary Yug feed**
  final int? parentTabIndex; // **NEW: Tab context for autoplay logic**
  final int? startAtSeconds; // Share links: start playback of initialVideoId here
  final int? endAtSeconds; // Share links: pause playback of initialVideoId here

  const VideoScreen({
    Key? key,
    this.initialIndex,
    this.initialVideos,
    this.initialVideoId,
    this.videoType,
    this.isMainYugTab = false,
    this.parentTabIndex,
    this.startAtSeconds,
    this.endAtSeconds,
  }) : super(key: key);

  @override
  ConsumerState<VideoScreen> createState() => VideoScreenState();
}

class VideoScreenState extends ConsumerState<VideoScreen> {
  final GlobalKey _videoFeedKey = GlobalKey();

  VideoModel? _pendingDeepLinkVideo;
  int? _pendingStartAtSeconds;
  int? _pendingEndAtSeconds;

  /// **PUBLIC: Refresh video list after upload**
  Future<void> refreshVideos() async {
    AppLogger.log('🔄 VideoScreen: refreshVideos() called');
    final videoFeedState = _videoFeedKey.currentState;
    if (videoFeedState != null) {
      // Cast to dynamic to access the refreshVideos method
      await (videoFeedState as dynamic).refreshVideos();
      AppLogger.log('✅ VideoScreen: Video refresh completed');
    } else {
      AppLogger.log('❌ VideoScreen: VideoFeedAdvanced state not found');
    }
  }

  /// **PUBLIC: Play a shared deep-linked video dynamically at the top of feed**
  Future<void> playDeepLinkVideo(
    VideoModel video, {
    int? startAtSeconds,
    int? endAtSeconds,
  }) async {
    AppLogger.log('🔗 VideoScreen: playDeepLinkVideo called for ${video.id}');
    final videoFeedState = _videoFeedKey.currentState;
    if (videoFeedState != null) {
      _pendingDeepLinkVideo = null;
      await (videoFeedState as dynamic).playDeepLinkVideo(
        video,
        startAtSeconds: startAtSeconds,
        endAtSeconds: endAtSeconds,
      );
    } else {
      AppLogger.log('⏳ VideoScreen: VideoFeedAdvanced not mounted yet, queueing deep link for ${video.id}');
      _pendingDeepLinkVideo = video;
      _pendingStartAtSeconds = startAtSeconds;
      _pendingEndAtSeconds = endAtSeconds;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingDeepLink());
    }
  }

  void _flushPendingDeepLink() {
    if (_pendingDeepLinkVideo != null && _videoFeedKey.currentState != null) {
      final video = _pendingDeepLinkVideo!;
      final startAt = _pendingStartAtSeconds;
      final endAt = _pendingEndAtSeconds;
      _pendingDeepLinkVideo = null;
      _pendingStartAtSeconds = null;
      _pendingEndAtSeconds = null;
      AppLogger.log('🚀 VideoScreen: Flushing queued deep link for ${video.id}');
      (_videoFeedKey.currentState as dynamic).playDeepLinkVideo(
        video,
        startAtSeconds: startAt,
        endAtSeconds: endAt,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    AppLogger.log('🎬 VideoScreen: Initializing VideoScreen');

    // Background videos are silenced by the coordinator's handover, not from
    // here: this screen used to call forcePauseVideos() after its own feed had
    // already been activated, muting the video it was about to play.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushPendingDeepLink();
      if (DeepLinkPlaybackGate.isActive || _pendingDeepLinkVideo != null) {
        AppLogger.log('🎬 VideoScreen: Suppressing premature forcePlayCurrent - deep link active or pending');
        return;
      }
      final state = _videoFeedKey.currentState;
      if (state != null) {
        try {
          (state as dynamic).forcePlayCurrent();
        } catch (_) {}
      }
    });

    // Some devices need a short delay for the first frame to attach
    Future.delayed(const Duration(milliseconds: 120), () {
      _flushPendingDeepLink();
      if (DeepLinkPlaybackGate.isActive || _pendingDeepLinkVideo != null) {
        AppLogger.log('🎬 VideoScreen: Suppressing delayed forcePlayCurrent - deep link active or pending');
        return;
      }
      final s = _videoFeedKey.currentState;
      if (s != null) {
        try {
          (s as dynamic).forcePlayCurrent();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    AppLogger.log('🗑️ VideoScreen: Disposing VideoScreen');

    // Only this screen's own controllers are silenced here. A blanket pause
    // would also hit the surface underneath, which the coordinator is about to
    // reactivate as this route goes away.
    try {
      VideoControllerManager().forcePauseAllVideosSync();
      AppLogger.log('🔇 VideoScreen: Paused own controllers on dispose');
    } catch (e) {
      AppLogger.log('⚠️ VideoScreen: Error pausing videos on dispose: $e');
    }

    // Clean up the video feed if needed
    final videoFeedState = _videoFeedKey.currentState;
    if (videoFeedState != null) {
      try {
        // The VideoFeedAdvanced dispose method will be called automatically
        AppLogger.log(
            '✅ VideoScreen: VideoFeedAdvanced disposal handled automatically');
      } catch (e) {
        AppLogger.log('⚠️ VideoScreen: Error during disposal: $e');
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **FIXED: Respect passed videoType (e.g. 'vayu') even if initialVideos are present**
    final String videoType = widget.videoType ?? 'yog';

    return VideoFeedAdvanced(
      key: _videoFeedKey,
      initialIndex: widget.initialIndex,
      initialVideos: widget.initialVideos,
      initialVideoId: widget.initialVideoId,
      startAtSeconds: widget.startAtSeconds,
      endAtSeconds: widget.endAtSeconds,
      videoType: videoType,
      isMainYugTab: widget.isMainYugTab,
      // Left null on purpose when the caller did not specify one: the feed
      // reads its tab from the enclosing `TabScope`, which is accurate at any
      // nesting depth. Guessing it from the live tab index used to bind a
      // player to whichever tab happened to be settling when it opened.
      parentTabIndex: widget.parentTabIndex,
    );
  }
}

