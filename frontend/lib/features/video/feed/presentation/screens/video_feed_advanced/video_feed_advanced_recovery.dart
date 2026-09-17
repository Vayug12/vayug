part of '../video_feed_advanced.dart';

extension _VideoFeedRecovery on _VideoFeedAdvancedState {
  /// Validate and restore disposed controllers in local pool
  void _validateAndRestoreControllers() {
    if (_videos.isEmpty) return;

    final sharedPool = SharedVideoControllerPool();
    final List<int> indicesToRestore = [];

    final indicesToCheck = {
      _currentIndex,
      if (_currentIndex + 1 < _videos.length) _currentIndex + 1,
      if (_currentIndex - 1 >= 0) _currentIndex - 1
    };

    for (final index in indicesToCheck) {
      final video = _videos[index];
      bool needsRestore = false;

      if (_controllerPool.containsKey(video.id)) {
        final controller = _controllerPool[video.id];
        if (sharedPool.isControllerDisposed(controller)) {
          AppLogger.log(
              '⚠️ VideoFeedAdvanced: Controller for ${video.id} is DISPOSED (local). Marking for restore.');
          _controllerPool.remove(video.id);
          _controllerStates.remove(video.id);
          _preloadedVideos.remove(video.id);
          needsRestore = true;
        }
      } else {
        final sharedController = sharedPool.getController(video.id);
        if (sharedController != null &&
            !sharedPool.isControllerDisposed(sharedController)) {
          AppLogger.log(
              '♻️ VideoFeedAdvanced: Adopting valid controller from shared pool for ${video.id}');
          _controllerPool[video.id] = sharedController;
          _controllerStates[video.id] = false;
          _preloadedVideos.add(video.id);

          _attachEndListenerIfNeeded(sharedController, index);
          _attachBufferingListenerIfNeeded(sharedController, index);
        } else {
          if (index == _currentIndex) {
            needsRestore = true;
          }
        }
      }

      if (needsRestore) {
        indicesToRestore.add(index);
      }
    }

    for (final index in indicesToRestore) {
      if (index == _currentIndex) {
        AppLogger.log(
            '🔄 VideoFeedAdvanced: Restoring controller for index $index (Current Video)');
      }

      _preloadVideo(index).then((_) {
        if (mounted && index == _currentIndex && _isScreenVisible) {
          _tryAutoplayCurrent();
        }
      });
    }
  }

  /// Handle automatic recovery when a child widget detects a disposed controller
  void _handleControllerInvalid(int index) {
    if (!mounted || index < 0 || index >= _videos.length) return;

    final video = _videos[index];
    final videoId = video.id;

    AppLogger.log(
        '🩹 SELF-HEAL: Detected disposed controller for $videoId at index $index. Re-initializing...');

    _controllerPool.remove(videoId);
    _controllerStates.remove(videoId);
    _preloadedVideos.remove(videoId);

    safeSetState(() {});

    _preloadVideo(index).then((_) {
      if (mounted) {
        AppLogger.log('✅ SELF-HEAL: Controller restored for $videoId');
        safeSetState(() {});
      }
    });
  }

  /// Pause videos before navigating away to prevent background audio
  void _pauseVideosForProfileNavigation() {
    try {
      AppLogger.log(
          '⏸️ VideoFeedAdvanced: Pausing current video before navigation');

      final video = _videos[_currentIndex];
      _controllerStates[video.id] = false;
      _pauseCurrentVideo();
    } catch (e) {
      AppLogger.log('⚠️ VideoFeedAdvanced: Error pausing current video: $e');
    }

    try {
      SharedVideoControllerPool().pauseAllControllers();
    } catch (e) {
      AppLogger.log(
          '⚠️ VideoFeedAdvanced: Error pausing SharedVideoControllerPool: $e');
    }

    try {
      _videoControllerManager.pauseAllVideosOnTabChange();
    } catch (e) {
      AppLogger.log(
          '⚠️ VideoFeedAdvanced: Error pausing VideoControllerManager: $e');
    }
  }

  /// Get or adopt controller with atomic validation
  VideoPlayerController? _getController(int index) {
    if (index >= _videos.length) return null;

    final videoId = _videos[index].id;
    final sharedPool = SharedVideoControllerPool();

    VideoPlayerController? controller = _controllerPool[videoId];
    if (controller != null) {
      if (!sharedPool.isControllerValid(controller)) {
        AppLogger.log(
            '⚠️ VideoFeed: Local controller for $videoId is STALE. Evicting.');
        _controllerPool.remove(videoId);
        _controllerStates.remove(videoId);
        _preloadedVideos.remove(videoId);
        _lastAccessedLocal.remove(videoId);
        controller = null;
      } else {
        _lastAccessedLocal[videoId] = DateTime.now();
        return controller;
      }
    }

    controller = sharedPool.getControllerForInstantPlay(videoId);
    if (!sharedPool.isControllerValid(controller)) {
      controller = sharedPool.getController(videoId);
    }

    if (sharedPool.isControllerValid(controller)) {
      AppLogger.log(
          '⚡ VideoFeed: Adopting controller for $videoId from global pool');
      _controllerPool[videoId] = controller!;
      _controllerStates[videoId] = false;
      _preloadedVideos.add(videoId);
      _lastAccessedLocal[videoId] = DateTime.now();
      return controller;
    }

    return null;
  }

  /// Atomic safety helper for getting a valid controller
  VideoPlayerController? _getValidController(int index) {
    if (index < 0 || index >= _videos.length) return null;
    final videoId = _videos[index].id;
    final controller = _controllerPool[videoId];

    if (controller == null) return null;

    final sharedPool = SharedVideoControllerPool();
    if (!sharedPool.isControllerValid(controller)) {
      AppLogger.log(
          '⚠️ VideoFeed: Detected stale local reference for video $videoId. Evicting local entry.');
      _controllerPool.remove(videoId);
      _controllerStates.remove(videoId);
      _preloadedVideos.remove(videoId);
      _lastAccessedLocal.remove(videoId);
      return null;
    }

    return controller;
  }

  /// Seek controller to position from gestures
  void _seekToPosition(VideoPlayerController controller, dynamic details) {
    if (!controller.value.isInitialized) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final screenWidth = _screenWidth ?? MediaQuery.of(context).size.width;
    double seekPosition = (localPosition.dx / screenWidth).clamp(0.0, 1.0);

    final currentVid = _currentIndex < _videos.length ? _videos[_currentIndex] : null;
    if (currentVid != null && currentVid.isPaidVideo) {
      final bool isCreator = _currentUserId != null &&
          (currentVid.uploader.id == _currentUserId ||
              currentVid.uploader.googleId == _currentUserId);
      if (!isCreator && !PaidVideoService.instance.isLocallyUnlocked(currentVid.id)) {
        final maxPercent = (currentVid.paidAccess?.previewPercentage ?? 20.0) / 100.0;
        if (seekPosition > maxPercent) {
          seekPosition = maxPercent;
        }
      }
    }

    final duration = controller.value.duration;
    final newPosition = duration * seekPosition;
    controller.seekTo(newPosition);
  }

  void _attachBufferingListenerIfNeeded(
    VideoPlayerController controller,
    int index,
  ) {
    final videoId = _videos[index].id;
    final existing = _bufferingListeners[videoId];
    if (existing != null) {
      SharedVideoControllerPool().detachListener(videoId, existing);
    }
    void listener() {
      if (!mounted) return;
      final bool next =
          controller.value.isInitialized && controller.value.isBuffering;
      final bool current = _isBuffering[videoId] ?? false;
      if (current != next) {
        _isBuffering[videoId] = next;
        (_isBufferingVN[videoId] ??= ValueNotifier<bool>(false)).value = next;
      }
    }

    SharedVideoControllerPool().attachListener(videoId, listener);
    _bufferingListeners[videoId] = listener;
  }

  void _applyLoopingBehavior(VideoPlayerController controller) {
    controller.setLooping(!_autoScrollEnabled);
  }
}
