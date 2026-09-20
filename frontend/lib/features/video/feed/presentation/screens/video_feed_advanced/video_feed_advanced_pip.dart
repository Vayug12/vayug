part of '../video_feed_advanced.dart';

extension _VideoFeedPiP on _VideoFeedAdvancedState {
  Future<void> _initializePictureInPicture() async {
    _pictureInPictureModeSubscription =
        _pictureInPictureService.modeChanges.listen((event) {
      if (event.ownerId == _pictureInPictureOwnerId) {
        _onPictureInPictureModeChanged(event.isActive);
      }
    });
    _pictureInPicturePlaybackSubscription =
        _pictureInPictureService.playbackRequests.listen((event) {
      if (event.ownerId == _pictureInPictureOwnerId) {
        unawaited(_onPictureInPicturePlaybackRequested(event.shouldPlay));
      }
    });
    _pictureInPicturePreparationSubscription =
        _pictureInPictureService.preparationRequests.listen((ownerId) {
      if (ownerId == _pictureInPictureOwnerId) {
        _prepareYugPictureInPictureSurface();
      }
    });
    final isSupported = await _pictureInPictureService.initialize();
    if (!mounted) return;
    safeSetState(() => _isPictureInPictureSupported = isSupported);
    if (isSupported) unawaited(_syncPictureInPictureState(force: true));
  }

  void _prepareYugPictureInPictureSurface() {
    if (!mounted || _isInPictureInPicture) return;
    _capturePictureInPictureVideoId();
    _dismissOpenModalsAndOverlays();
    safeSetState(() => _isInPictureInPicture = true);
    _keepYugPlaybackActiveInPictureInPicture();
  }

  void _dismissOpenModalsAndOverlays() {
    // 1. Pop any open modal bottom sheet, dialog, or overlay routes
    try {
      final rootNav = Navigator.of(context, rootNavigator: true);
      while (rootNav.canPop()) {
        rootNav.pop();
      }
    } catch (_) {}
    try {
      final localNav = Navigator.of(context);
      while (localNav.canPop()) {
        localNav.pop();
      }
    } catch (_) {}

    // 2. Clear snackbars
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (_) {}

    // 3. Reset ephemeral in-feed overlays (quiz, banner ads, long-press ads)
    try {
      _activeQuizVN.value = null;
      _cinemaModeVN.value = false;
      _bannerAdsVN.value = const [];
    } catch (_) {}
  }

  void _capturePictureInPictureVideoId() {
    if (_currentIndex < 0 || _currentIndex >= _videos.length) return;
    _pictureInPictureVideoId = _videos[_currentIndex].id;
  }

  /// Puts the viewport back on the video picture-in-picture was showing.
  void _restoreYugPageAfterPictureInPicture() {
    final videoId = _pictureInPictureVideoId;
    _pictureInPictureVideoId = null;
    if (videoId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isInPictureInPicture) return;
      final index = FeedPageAlignment.indexOfVideoId(_videos, videoId);
      if (index == -1) return;
      if (index != _currentIndex) _onPageChanged(index);
      FeedPageAlignment.jumpToIndex(_pageController, index);
    });
  }

  void _keepYugPlaybackActiveInPictureInPicture() {
    _lifecyclePaused = false;
    _isScreenVisible = true;
    _playbackCoordinator.setPiPActive(_playbackSession, true);
    _playbackCoordinator.setAppLifecycle(true);
  }

  void _onPictureInPictureModeChanged(bool isActive) {
    if (!mounted) return;
    safeSetState(() => _isInPictureInPicture = isActive);
    if (isActive) {
      _capturePictureInPictureVideoId();
      _dismissOpenModalsAndOverlays();
      _keepYugPlaybackActiveInPictureInPicture();
      _tryAutoplayCurrent();
      return;
    }

    _playbackCoordinator.setPiPActive(_playbackSession, false);
    _restoreYugPageAfterPictureInPicture();

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState == AppLifecycleState.resumed) {
      _lifecyclePaused = false;
      _playbackCoordinator.setAppLifecycle(true);
      _tryAutoplayCurrent();
    } else {
      _playbackCoordinator.setAppLifecycle(false);
      _handleAppMovedToBackground(lifecycleState ?? AppLifecycleState.paused);
    }
  }

  Future<void> _onPictureInPicturePlaybackRequested(bool shouldPlay) async {
    final controller = _currentPictureInPictureController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _videos.isEmpty) {
      return;
    }
    final videoId = _videos[_currentIndex].id;
    _userPaused[videoId] = !shouldPlay;
    _userPausedVN[videoId]?.value = !shouldPlay;
    _controllerStates[videoId] = shouldPlay;
    _playbackCoordinator.setUserPaused(_playbackSession, !shouldPlay);
    if (shouldPlay) {
      _keepYugPlaybackActiveInPictureInPicture();
      _pauseOtherLocalVideos(videoId);
      if (_playbackCoordinator.claimForPlay(_playbackSession, controller,
          reason: 'Yug PiP play')) {
        await controller.play();
      }
    } else {
      await controller.pause();
    }
    await _syncPictureInPictureState(force: true);
  }

  VideoPlayerController? get _currentPictureInPictureController {
    if (_videos.isEmpty || _currentIndex < 0 || _currentIndex >= _videos.length) {
      return null;
    }
    return _controllerPool[_videos[_currentIndex].id];
  }

  Future<void> _syncPictureInPictureState({bool force = false}) async {
    if (!_isPictureInPictureSupported ||
        (!_isScreenVisible && !_isInPictureInPicture)) {
      return;
    }
    final controller = _currentPictureInPictureController;
    final isPlaying =
        controller?.value.isInitialized == true && controller!.value.isPlaying;
    final aspectRatio =
        controller == null ? 9 / 16 : _pictureInPictureAspectRatio(controller);
    final sourceRect = _pictureInPictureSourceRect();
    final currentVideoId =
        (_currentIndex >= 0 && _currentIndex < _videos.length)
            ? _videos[_currentIndex].id
            : null;

    final hasRectChanged =
        !_areRectsEqual(_lastPictureInPictureSourceRect, sourceRect);
    final hasVideoChanged =
        _lastSyncedPictureInPictureVideoId != currentVideoId;

    if (!force &&
        !hasVideoChanged &&
        !hasRectChanged &&
        _lastPictureInPicturePlayingState == isPlaying &&
        _lastPictureInPictureAspectRatio == aspectRatio) {
      return;
    }
    _lastPictureInPicturePlayingState = isPlaying;
    _lastPictureInPictureAspectRatio = aspectRatio;
    _lastPictureInPictureSourceRect = sourceRect;
    _lastSyncedPictureInPictureVideoId = currentVideoId;

    await _pictureInPictureService.update(
      ownerId: _pictureInPictureOwnerId,
      aspectRatio: aspectRatio,
      isPlaying: isPlaying,
      autoEnterEnabled: isPlaying && !_isInPictureInPicture,
      sourceRect: sourceRect,
    );
  }

  bool _areRectsEqual(List<double>? a, List<double>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.5) return false;
    }
    return true;
  }

  double _pictureInPictureAspectRatio(VideoPlayerController controller) {
    final ratio = controller.value.aspectRatio;
    return ratio.isFinite && ratio > 0 ? ratio : 9 / 16;
  }

  List<double>? _pictureInPictureSourceRect() {
    final sourceContext = _pictureInPictureSourceKey.currentContext;
    final renderBox = sourceContext?.findRenderObject();
    if (sourceContext == null || renderBox is! RenderBox || !renderBox.hasSize) {
      return null;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    final pixelRatio = View.of(sourceContext).devicePixelRatio;
    return <double>[
      origin.dx * pixelRatio,
      origin.dy * pixelRatio,
      (origin.dx + renderBox.size.width) * pixelRatio,
      (origin.dy + renderBox.size.height) * pixelRatio,
    ];
  }
}
