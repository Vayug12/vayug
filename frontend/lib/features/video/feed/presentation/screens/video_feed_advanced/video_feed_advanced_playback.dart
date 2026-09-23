part of '../video_feed_advanced.dart';

extension _VideoFeedPlayback on _VideoFeedAdvancedState {
  void _playWithPolicy(VideoPlayerController controller, String reason) {
    if (_playbackCoordinator.claimForPlay(
      _playbackSession,
      controller,
      reason: reason,
    )) {
      unawaited(controller.play());
    }
  }

  void _reprimeWindowIfNeeded() {
    final int start = _currentIndex;
    final int end = (_currentIndex + _decoderPrimeBudget - 1).clamp(
      0,
      _videos.length - 1,
    );

    if (_primedStartIndex == start) return;

    _controllerPool.forEach((videoId, controller) {
      // Find index of this videoId
      int? idx;
      try {
        idx = _videos.indexWhere((v) => v.id == videoId);
      } catch (_) {}

      if (idx == null || idx < start || idx > end) {
        try {
          if (SharedVideoControllerPool().isControllerDisposed(controller)) {
            _controllerPool.remove(videoId);
            _controllerStates.remove(videoId);
            return;
          }
          final value = controller.value;
          if (value.isInitialized) {
            controller.pause();
            _controllerStates[videoId] = false;
          }
        } catch (e) {
          _controllerPool.remove(videoId);
          _controllerStates.remove(videoId);
        }
      }
    });

    _primedStartIndex = start;
  }

  /// Seeks the shared video to the `t` timestamp from a deep link before its
  /// first play. Runs at most once and only for the deep-linked video.
  Future<void> _maybeApplyInitialStartSeek(
      String videoId, VideoPlayerController controller) async {
    final startSeconds =
        _dynamicDeepLinkStartAtSeconds ?? widget.startAtSeconds;
    if (startSeconds == null ||
        startSeconds <= 0 ||
        _hasAppliedInitialStartSeek) {
      return;
    }
    final targetVideoId =
        _dynamicDeepLinkVideoId ?? widget.initialVideoId ?? (_pinnedDeepLinkVideo?.id);
    if (targetVideoId != null && videoId != targetVideoId) {
      return;
    }

    var target = Duration(seconds: startSeconds);
    final duration = controller.value.duration;
    if (duration > Duration.zero && target >= duration) {
      target = duration - const Duration(milliseconds: 500);
    }
    try {
      await controller.seekTo(target);
      _hasAppliedInitialStartSeek = true;
      AppLogger.log(
          '⏩ VideoFeedAdvanced: Applied shared-link start position ${target.inSeconds}s for $videoId');
    } catch (e) {
      AppLogger.log('⚠️ VideoFeedAdvanced: Initial seek failed for $videoId: $e');
    }
  }

  Future<void> playDeepLinkVideo(
    VideoModel video, {
    int? startAtSeconds,
    int? endAtSeconds,
  }) async {
    AppLogger.log('🔗 VideoFeedAdvanced: playDeepLinkVideo for ${video.id}');
    _pinnedDeepLinkVideo = video;
    _dynamicDeepLinkVideoId = video.id;
    _dynamicDeepLinkStartAtSeconds = startAtSeconds;
    _dynamicDeepLinkEndAtSeconds = endAtSeconds;
    _hasAppliedInitialStartSeek = false;
    _hasShownSectionEndToast = false;

    // Pause current playing video
    _pauseCurrentVideo();

    // Check if video is already at index 0
    final existingIndex = _videos.indexWhere((v) => v.id == video.id);
    if (existingIndex != -1) {
      if (existingIndex != 0) {
        final existing = _videos.removeAt(existingIndex);
        _videos.insert(0, existing);
      }
    } else {
      _videos.insert(0, video);
    }

    safeSetState(() {
      _currentIndex = 0;
      _activeQuizVN.value = null;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    SharedVideoControllerPool()
        .pinVideo(video.id, sessionId: _playbackSession.id);

    // Preload controller for index 0 and seek to start position before force play
    await _preloadVideo(0);
    final controller = _controllerPool[video.id];
    if (controller != null && controller.value.isInitialized) {
      await _maybeApplyInitialStartSeek(video.id, controller);
    }
    forcePlayCurrent();
  }

  void forcePlayCurrent() {
    if (_videos.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _videos.length) {
      return;
    }

    final video = _videos[_currentIndex];
    final videoId = video.id;
    final controller = _controllerPool[videoId];

    bool isInitializedSafe = false;
    if (controller != null) {
      try {
        if (!SharedVideoControllerPool().isControllerDisposed(controller)) {
          isInitializedSafe = controller.value.isInitialized;
        } else {
           _controllerPool.remove(videoId);
           _controllerStates.remove(videoId);
        }
      } catch (_) {
        _controllerPool.remove(videoId);
        _controllerStates.remove(videoId);
      }
    }

    if (controller != null && isInitializedSafe) {
      if (!_shouldAutoplayForContext('forcePlayCurrent')) return;
      _pauseOtherLocalVideos(videoId);
      _lifecyclePaused = false;
      _maybeApplyInitialStartSeek(videoId, controller).then((_) {
        if (!mounted) return;
        _playWithPolicy(controller, 'feed force play');
        
        safeSetState(() {
          _controllerStates[videoId] = true;
          _userPaused[videoId] = false; // **Ensure user paused is reset**
          _getOrCreateNotifier<bool>(_userPausedVN, videoId, false);
        });
        
        _ensureWakelockForVisibility();
      });
      return;
    }

    _preloadVideo(_currentIndex).then((_) {
      if (!mounted) return;
      final c = _controllerPool[videoId];
      bool cInit = false;
      if (c != null) {
        try {
          cInit = c.value.isInitialized;
        } catch (_) {
          _controllerPool.remove(videoId);
          _controllerStates.remove(videoId);
        }
      }
      if (c != null && cInit) {
        if (!_shouldAutoplayForContext('forcePlayCurrent preload')) return;
        _pauseOtherLocalVideos(videoId);
        _lifecyclePaused = false;
        _maybeApplyInitialStartSeek(videoId, c).then((_) {
          if (!mounted) return;
          _playWithPolicy(c, 'feed force play after preload');
          
          safeSetState(() {
            _controllerStates[videoId] = true;
            _userPaused[videoId] = false;
            _getOrCreateNotifier<bool>(_userPausedVN, videoId, false);
          });
          
          _ensureWakelockForVisibility();
        });
      }
    });
  }

  // _pauseCurrentVideo / _pauseOtherLocalVideos / _pauseAllVideosOnTabSwitch used
  // to be duplicated here. A class member always shadows an extension member,
  // so these copies never ran — including their coordinator calls. The single
  // implementations now live in _VideoFeedAdvancedState.
}
