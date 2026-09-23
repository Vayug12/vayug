import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:like_button/like_button.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Core design tokens
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';

// Core providers & interfaces
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/core/providers/navigation_providers.dart';
import 'package:vayug/core/providers/user_data_providers.dart';
import 'package:vayug/core/interfaces/i_dubbing_service.dart';
import 'package:vayug/core/interfaces/i_quiz_engine.dart';

// Feature models & services
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/core/data/services/video_service.dart';
import 'package:vayug/features/video/core/data/services/picture_in_picture_service.dart';
import 'package:vayug/features/video/core/data/services/video_view_tracker.dart';
import 'package:vayug/features/video/core/data/services/video_cache_proxy_service.dart';
import 'package:vayug/features/video/core/presentation/managers/main_controller.dart';
import 'package:vayug/features/video/core/presentation/managers/video_controller_manager.dart';
import 'package:vayug/features/video/core/presentation/managers/shared_video_controller_pool.dart';
import 'package:vayug/features/video/core/presentation/widgets/quiz_overlay.dart';
import 'package:vayug/features/video/paid/data/services/paid_video_service.dart';
import 'package:vayug/features/video/paid/presentation/widgets/paid_video_player_guard.dart';
import 'package:vayug/features/video/dubbing/data/models/dubbing_models.dart';
import 'package:vayug/features/video/dubbing/data/services/on_device_dubbing_service.dart';
import 'package:vayug/features/video/quiz/data/services/standard_quiz_engine.dart';
import 'package:vayug/features/video/feed/presentation/widgets/video_feed_skeleton.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/features/auth/presentation/controllers/auth_flow.dart';
import 'package:vayug/features/ads/domain/i_ad_service.dart';
import 'package:vayug/features/ads/data/services/active_ads_service.dart';
import 'package:vayug/features/ads/data/services/ad_refresh_notifier.dart';
import 'package:vayug/features/ads/data/services/ad_impression_service.dart';
import 'package:vayug/features/ads/presentation/widgets/carousel_ad_widget.dart';
import 'package:vayug/features/profile/core/data/services/background_profile_preloader.dart';
import 'package:vayug/features/profile/core/data/services/profile_preloader.dart';
import 'package:vayug/features/profile/core/presentation/screens/profile_screen.dart';
import 'package:vayug/features/onboarding/presentation/managers/app_initialization_manager.dart';

// Shared widgets & utilities
import 'package:vayug/shared/di/dependency_injection.dart';
import 'package:vayug/shared/constants/app_constants.dart';
import 'package:vayug/shared/managers/carousel_ad_manager.dart';
import 'package:vayug/shared/services/connectivity_service.dart';
import 'package:vayug/shared/services/local_gallery_service.dart';
import 'package:vayug/shared/services/deep_link_playback_gate.dart';
import 'package:vayug/shared/services/deep_link_service.dart';
import 'package:vayug/shared/services/playback_coordinator.dart';
import 'package:vayug/shared/navigation/app_route_observer.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/utils/feed_page_alignment.dart';
import 'package:vayug/shared/utils/page_scroll_physics.dart';
import 'package:vayug/shared/utils/url_utils.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';
import 'package:vayug/shared/widgets/report_dialog_widget.dart';
import 'package:vayug/shared/widgets/share_options_sheet.dart';
import 'package:vayug/shared/widgets/links_bottom_sheet.dart';
import 'package:vayug/shared/widgets/feed_visit_now_button.dart';
import 'package:vayug/shared/widgets/tab_scope.dart';
import 'package:vayug/shared/widgets/auth_sign_in_prompt.dart';
import 'package:vayug/shared/widgets/subscribe_button_widget.dart';
import 'package:vayug/shared/widgets/episode_grid_widget.dart';
import 'package:vayug/features/video/edit/presentation/screens/edit_video_details.dart';

// Sub-widgets
import 'video_feed_advanced/widgets/video_aspect_surface.dart';
import 'video_feed_advanced/widgets/banner_ad_section.dart';
import 'video_feed_advanced/widgets/heart_animation.dart';
import 'video_feed_advanced/widgets/throttled_progress_bar.dart';
import 'video_feed_advanced/widgets/feed_signin_overlay.dart';
import 'video_feed_advanced/widgets/feed_pip_player.dart';
import 'video_feed_advanced/widgets/feed_language_selector_sheet.dart';
import 'video_feed_advanced/widgets/feed_error_state.dart';
import 'video_feed_advanced/widgets/feed_empty_state.dart';
import 'video_feed_advanced/widgets/video_horizontal_pager.dart';
import 'video_feed_advanced/widgets/pause_pop_ad_overlay.dart';

// Modular part extensions
part 'video_feed_advanced/video_feed_advanced_state_fields.dart';
part 'video_feed_advanced/video_feed_advanced_playback.dart';
part 'video_feed_advanced/video_feed_advanced_persistence.dart';
part 'video_feed_advanced/video_feed_advanced_initialization.dart';
part 'video_feed_advanced/video_feed_advanced_data.dart';
part 'video_feed_advanced/video_feed_advanced_preload.dart';
part 'video_feed_advanced/video_feed_advanced_pip.dart';
part 'video_feed_advanced/video_feed_advanced_actions.dart';
part 'video_feed_advanced/video_feed_advanced_dubbing.dart';
part 'video_feed_advanced/video_feed_advanced_recovery.dart';
part 'video_feed_advanced/video_feed_advanced_diagnostics.dart';
part 'video_feed_advanced/video_feed_advanced_ui.dart';

class VideoFeedAdvanced extends ConsumerStatefulWidget {
  final int? initialIndex;
  final List<VideoModel>? initialVideos;
  final String? initialVideoId;
  final String? videoType;
  final bool isMainYugTab;
  final int? parentTabIndex;
  final int? startAtSeconds;
  final int? endAtSeconds;
  final IDubbingService? dubbingService;
  final IAdService? adService;
  final IQuizEngine? quizEngine;

  const VideoFeedAdvanced({
    Key? key,
    this.initialIndex,
    this.initialVideos,
    this.initialVideoId,
    this.videoType,
    this.isMainYugTab = false,
    this.parentTabIndex,
    this.startAtSeconds,
    this.endAtSeconds,
    this.dubbingService,
    this.adService,
    this.quizEngine,
  }) : super(key: key);

  @override
  ConsumerState<VideoFeedAdvanced> createState() => _VideoFeedAdvancedState();
}

class _VideoFeedAdvancedState extends ConsumerState<VideoFeedAdvanced>
    with
        WidgetsBindingObserver,
        RouteAware,
        AutomaticKeepAliveClientMixin,
        VideoFeedStateFieldsMixin {
  final Map<String, bool> _likeInProgress = {};
  Timer? _pageChangeDebounceTimer;

  // PictureInPicture State
  final PictureInPictureService _pictureInPictureService =
      PictureInPictureService.instance;
  late final String _pictureInPictureOwnerId = 'yug-${identityHashCode(this)}';
  final GlobalKey _pictureInPictureSourceKey = GlobalKey();
  StreamSubscription<PictureInPictureModeEvent>?
      _pictureInPictureModeSubscription;
  StreamSubscription<PictureInPicturePlaybackEvent>?
      _pictureInPicturePlaybackSubscription;
  StreamSubscription<String>? _pictureInPicturePreparationSubscription;
  bool _isPictureInPictureSupported = false;
  bool _isInPictureInPicture = false;
  bool? _lastPictureInPicturePlayingState;
  double? _lastPictureInPictureAspectRatio;
  List<double>? _lastPictureInPictureSourceRect;
  String? _lastSyncedPictureInPictureVideoId;
  String? _pictureInPictureVideoId;

  @override
  bool get wantKeepAlive => true;

  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _playbackCoordinator.setRouteActive(_playbackSession, true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialVideos == null &&
          widget.initialIndex == null &&
          widget.initialVideoId == null &&
          mounted) {
        final mainController = ref.read(mainControllerProvider);
        final savedIndex = await mainController.getLastViewedVideoIndex(0);
        if (savedIndex > 0 && mounted) {
          AppLogger.log('🚀 VideoFeed: Resuming at video index $savedIndex (Main Feed)');
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedIndex);
          }
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);

    if (!_openedFromProfile) {
      _videoControllerManager.registerOnRoutePopped(() {
        if (mounted && !_openedFromProfile) {
          _validateAndRestoreControllers();
        }
      });
    }

    _initializeServices();
    _checkDeviceCapabilities();
    unawaited(_initializePictureInPicture());

    if (_openedFromProfile || _openedFromDeepLink) {
      _isScreenVisible = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route != null && route != _playbackRoute) {
      if (_playbackRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _playbackRoute = route;
      appRouteObserver.subscribe(this, route);
    }

    _mainController = ref.watch(mainControllerProvider);
    _tabScopeIndex = TabScope.maybeOf(context);
    _playbackCoordinator.bindSessionToTab(_playbackSession, _feedTabIndex);
  }

  @override
  void onPlaybackActivated() => _resumeCurrentVideo();

  @override
  void onPlaybackDeactivated() => _pauseCurrentVideo();

  void _resumeCurrentVideo() {
    if (!mounted) return;
    if (!_playbackCoordinator.isActiveSurface(_playbackSession)) return;
    _validateAndRestoreControllers();
    _tryAutoplayCurrent();
  }

  void _pauseCurrentVideo() {
    if (_currentIndex < _videos.length) {
      final video = _videos[_currentIndex];
      _viewTracker.stopViewTracking(video.id);
      final controller = _controllerPool[video.id];
      if (controller != null) {
        try {
          if (SharedVideoControllerPool().isControllerDisposed(controller)) {
            _controllerPool.remove(video.id);
            _controllerStates.remove(video.id);
          } else if (controller.value.isInitialized) {
            controller.pause();
            _controllerStates[video.id] = false;
            _ensureWakelockForVisibility();
            AppLogger.log('⏸️ VideoFeedAdvanced: Paused current video at index $_currentIndex');
          }
        } catch (e) {
          _controllerPool.remove(video.id);
          _controllerStates.remove(video.id);
          AppLogger.log('⚠️ VideoFeedAdvanced: Error pausing current video: $e');
        }
      }
    }

    _playbackCoordinator.pause(_playbackSession);
  }

  void _pauseAllPooledVideos() {
    _pauseCurrentVideo();

    for (final entry in _controllerPool.entries.toList()) {
      try {
        if (SharedVideoControllerPool().isControllerDisposed(entry.value)) {
          continue;
        }
        if (entry.value.value.isInitialized && entry.value.value.isPlaying) {
          entry.value.pause();
          _controllerStates[entry.key] = false;
        }
      } catch (_) {}
    }
  }

  void _pauseAllVideosOnTabSwitch() {
    AppLogger.log('🔇 VideoFeedAdvanced: Pausing all videos for tab switch');
    _pauseAllPooledVideos();
    _isScreenVisible = false;
    _ensureWakelockForVisibility();
  }

  void _pauseOtherLocalVideos(String activeId) {
    for (final entry in _controllerPool.entries.toList()) {
      if (entry.key != activeId) {
        try {
          if (entry.value.value.isPlaying) {
            entry.value.pause();
            _controllerStates[entry.key] = false;
          }
        } catch (_) {}
      }
    }
    _ensureWakelockForVisibility();
  }

  ValueNotifier<T> _getOrCreateNotifier<T>(
    Map<String, ValueNotifier<T>> map,
    String key,
    T initialValue,
  ) {
    if (map.containsKey(key)) {
      return map[key]!;
    } else {
      final notifier = ValueNotifier<T>(initialValue);
      map[key] = notifier;
      return notifier;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        // Transient state (gesture start, notification shade, PiP handover) — do NOT pause
        break;
      case AppLifecycleState.paused:
        if (_isInPictureInPicture ||
            _pictureInPictureService.isPiPActive ||
            (_isPictureInPictureSupported &&
                _pictureInPictureService.isOwnerAutoEnterEligible(_pictureInPictureOwnerId))) {
          _keepYugPlaybackActiveInPictureInPicture();
          break;
        }
        _playbackCoordinator.setAppLifecycle(false);
        _handleAppMovedToBackground(state);
        break;
      case AppLifecycleState.resumed:
        _playbackCoordinator.setAppLifecycle(true);
        _videoControllerManager.onAppResumed();
        _retryBannerAdsNow(resetAttempts: true);
        _ensureWakelockForVisibility();
        _lifecyclePaused = false;
        _lastPausedAt = null;

        _restoreBackgroundStateIfAny().then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final bool isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
            if (!isCurrentRoute) {
              AppLogger.log('⏸️ Resume skipped: route is not current (obscured).');
              return;
            }

            if (_lifecyclePaused) {
              AppLogger.log('⏸️ Resume detected but autoplay blocked until user interaction.');
              return;
            }

            final mainController = _mainController;
            if (mainController != null &&
                (mainController.isMediaPickerActive ||
                    mainController.recentlyReturnedFromPicker)) {
              return;
            }
            _tryAutoplayCurrent();
          });
        });
        break;
      case AppLifecycleState.detached:
        _videoControllerManager.disposeAllControllers();
        _videoControllerManager.onAppDetached();
        _ensureWakelockForVisibility();
        break;
      case AppLifecycleState.hidden:
        if (_isInPictureInPicture || _pictureInPictureService.isPiPActive) {
          _keepYugPlaybackActiveInPictureInPicture();
          break;
        }
        _handleAppMovedToBackground(state);
        break;
    }
  }

  void _handleAppMovedToBackground(AppLifecycleState state) {
    _pauseAllVideosOnTabSwitch();
    _videoControllerManager.pauseAllVideos();
    _videoControllerManager.onAppPaused();
    SharedVideoControllerPool().pauseAllControllers();
    _lifecyclePaused = true;
    _pendingAutoplayAfterLogin = false;
    _ensureWakelockForVisibility();
    AppLogger.log(
      '📱 VideoFeedAdvanced: Lifecycle state $state triggered background handling; current video buffering initiated.',
    );
  }

  void _tryAutoplayCurrent() {
    if (_videos.isEmpty || _isLoading) return;
    if (!_shouldAutoplayForContext('tryAutoplayCurrent')) return;
    _autoAdvancedForIndex.remove(_currentIndex);

    final video = _videos[_currentIndex];
    final controller = _controllerPool[video.id];

    if (controller != null) {
      final sharedPool = SharedVideoControllerPool();
      if (sharedPool.isControllerDisposed(controller)) {
        _controllerPool.remove(video.id);
        _controllerStates.remove(video.id);
      } else {
        try {
          if (!controller.value.isInitialized) {
            throw StateError('not initialized');
          }

          if (controller.value.isPlaying) return;

          if (_userPaused[video.id] == true) return;

          try {
            controller.setVolume(1.0);
          } catch (_) {}
          if (!_shouldAutoplayForContext('autoplay current immediate')) return;
          _pauseOtherLocalVideos(_videos[_currentIndex].id);
          _maybeApplyInitialStartSeek(video.id, controller).then((_) {
            if (!mounted) return;
            _playWithPolicy(controller, 'feed autoplay immediate');
            _ensureWakelockForVisibility();
            _controllerStates[video.id] = true;
            _userPaused[video.id] = false;
            _pendingAutoplayAfterLogin = false;
          });

          if (_currentIndex < _videos.length) {
            final currentVideo = _videos[_currentIndex];
            _viewTracker.startViewTracking(
              currentVideo.id,
              videoUploaderId: currentVideo.uploader.id,
              videoHash: currentVideo.videoHash,
            );
          }
          return;
        } catch (e) {
          _controllerPool.remove(video.id);
          _controllerStates.remove(video.id);
        }
      }
    }

    final indexToPlay = _currentIndex;
    final videoToPlay = _videos[indexToPlay];
    _preloadVideo(indexToPlay).then((_) {
      if (mounted &&
          _currentIndex == indexToPlay &&
          _controllerPool.containsKey(videoToPlay.id)) {
        final pController = _controllerPool[videoToPlay.id];
        if (pController != null && pController.value.isInitialized) {
          if (_userPaused[videoToPlay.id] == true) {
            AppLogger.log(
              '⏸️ Autoplay suppressed after preload: user has manually paused video at index $indexToPlay',
            );
            return;
          }
          if (!_shouldAutoplayForContext('autoplay current after preload')) return;

          try {
            pController.setVolume(1.0);
          } catch (_) {}
          _pauseOtherLocalVideos(_videos[indexToPlay].id);
          _playWithPolicy(pController, 'feed autoplay after preload');
          _ensureWakelockForVisibility();
          _controllerStates[videoToPlay.id] = true;
          _userPaused[videoToPlay.id] = false;
          _pendingAutoplayAfterLogin = false;

          if (indexToPlay < _videos.length) {
            final currentVideo = _videos[indexToPlay];
            _viewTracker.startViewTracking(
              currentVideo.id,
              videoUploaderId: currentVideo.uploader.id,
              videoHash: currentVideo.videoHash,
            );
          }
        }
      }
    });
  }

  void _handleVisibilityChange(bool isVisible) {
    if (_isScreenVisible != isVisible) {
      _isScreenVisible = isVisible;

      if (isVisible) {
        if (_currentIndex < _videos.length) {
          final video = _videos[_currentIndex];
          final controller = _controllerPool[video.id];
          if (controller != null) {
            final sharedPool = SharedVideoControllerPool();
            if (sharedPool.isControllerDisposed(controller)) {
              _controllerPool.remove(video.id);
              _controllerStates.remove(video.id);
            }
          }
        }

        _pauseAllPooledVideos();
        _ensureWakelockForVisibility();
        _tryAutoplayCurrent();
        _profilePreloader.startBackgroundPreloading();
      } else {
        _pauseCurrentVideo();
        videoCacheProxy.cancelAllPrefetchesExcept([]);
        _profilePreloader.stopBackgroundPreloading();
        _ensureWakelockForVisibility();
      }
    }

    if (isVisible) {
      _validateAndRestoreControllers();
    }
  }

  void _enableWakelock() {
    if (_wakelockEnabled) return;
    WakelockPlus.enable();
    _wakelockEnabled = true;
  }

  void _disableWakelock() {
    if (!_wakelockEnabled) return;
    WakelockPlus.disable();
    _wakelockEnabled = false;
  }

  bool _hasActivePlayback() {
    for (final entry in _controllerPool.entries.toList()) {
      final videoId = entry.key;
      final controller = entry.value;
      try {
        final value = controller.value;
        if (value.isInitialized && value.isPlaying) {
          return true;
        }
      } catch (e) {
        _controllerPool.remove(videoId);
        _controllerStates.remove(videoId);
      }
    }
    return SharedVideoControllerPool().hasActivePlayback();
  }

  int? get _feedTabIndex => widget.parentTabIndex ?? _tabScopeIndex;

  bool get _openedFromProfile =>
      !widget.isMainYugTab &&
      widget.initialVideos != null &&
      widget.initialVideos!.isNotEmpty;

  bool get _openedFromDeepLink =>
      widget.initialVideoId != null && widget.initialVideos == null;

  bool _shouldAutoplayForContext(String reason) {
    if (widget.isMainYugTab && DeepLinkPlaybackGate.isActive) {
      final currentVideo = _videos.isNotEmpty && _currentIndex >= 0 && _currentIndex < _videos.length
          ? _videos[_currentIndex]
          : null;
      final isPlayingDeepLinkVideo = currentVideo != null &&
          ((_pinnedDeepLinkVideo != null && _pinnedDeepLinkVideo!.id == currentVideo.id) ||
           (_dynamicDeepLinkVideoId != null && _dynamicDeepLinkVideoId == currentVideo.id));
      if (!isPlayingDeepLinkVideo) {
        AppLogger.log('AUTOPLAY[$reason]: Shared video link is resolving (blocking random video)');
        return false;
      }
    }

    if (!_playbackCoordinator.canPlay(_playbackSession, reason: reason)) {
      return false;
    }

    if (!_allowAutoplay(reason)) {
      AppLogger.log('🚫 AUTOPLAY[$reason]: blocked by app lifecycle');
      return false;
    }

    if (ref.read(googleSignInProvider).isLoading) {
      AppLogger.log('🚫 AUTOPLAY[$reason]: Auth is loading');
      return false;
    }

    if (!_isScreenVisible) {
      AppLogger.log('🚫 AUTOPLAY[$reason]: component hidden (_isScreenVisible=false)');
      return false;
    }

    return true;
  }

  void _scheduleAutoplayAfterLogin() {
    if (!_pendingAutoplayAfterLogin) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_shouldAutoplayForContext('autoplay after login')) {
        AppLogger.log('⏸️ Autoplay deferred (login): Yug tab not active or screen hidden');
        return;
      }

      _pendingAutoplayAfterLogin = false;
      AppLogger.log('🚀 Triggering autoplay after login');
      forcePlayCurrent();
    });
  }

  void _ensureWakelockForVisibility() {
    final bool shouldKeepAwake =
        (_isScreenVisible && !_lifecyclePaused) || _hasActivePlayback();
    if (shouldKeepAwake) {
      _enableWakelock();
    } else {
      _disableWakelock();
    }
  }

  bool _allowAutoplay(String reason) {
    if (_lifecyclePaused) {
      AppLogger.log('⏸️ Autoplay blocked ($reason) due to lifecycle pause.');
      return false;
    }

    if (ref.read(googleSignInProvider).isLoading) {
      return false;
    }

    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      AppLogger.log(
          '⏸️ Autoplay blocked ($reason): System state is ${WidgetsBinding.instance.lifecycleState}');
      return false;
    }
    return true;
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;

    _pauseCurrentVideo();
    _playbackCoordinator.setUserPaused(_playbackSession, false);

    if (index >= 0 && index < _videos.length) {
      ref
          .read(mainControllerProvider)
          .updateCurrentVideoIndex(index, tabIndex: 0);
    }

    setState(() {
      _currentIndex = index;
      _activeQuizVN.value = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncPictureInPictureState());
    });

    if (index >= 0 && index < _videos.length) {
      final currentVid = _videos[index];
      SharedVideoControllerPool()
          .pinVideo(currentVid.id, sessionId: _playbackSession.id);
      if (currentVid.isPaidVideo) {
        PaidVideoService.instance.checkAccess(currentVid.id);
      }
    }

    _pageChangeDebounceTimer?.cancel();
    _pageChangeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && index == _currentIndex) {
        _handlePageChange(index);
      }
    });

    _preloadVideo(index);

    final currentTime = DateTime.now();
    final scrollDelta =
        currentTime.difference(_lastPageChangeTime).inMilliseconds;
    _lastPageChangeTime = currentTime;
    _wasLastScrollFast = scrollDelta < 300;

    _cancelIrrelevantPreloads(index);
  }

  Set<String> _keepAliveVideoIds(int start, int end) {
    final ids = <String>{};
    for (int i = start; i <= end; i++) {
      if (i >= 0 && i < _videos.length) {
        ids.add(_videos[i].id);
      }
    }
    return ids;
  }

  void _cancelIrrelevantPreloads(int currentIndex) {
    _preloadDebounceTimers.forEach((videoId, timer) {
      bool isRelevant = false;
      for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
        if (i >= 0 && i < _videos.length && _videos[i].id == videoId) {
          isRelevant = true;
          break;
        }
      }
      if (!isRelevant) {
        timer.cancel();
      }
    });

    _loadingVideos.removeWhere((videoId) {
      bool isRelevant = false;
      for (int i = currentIndex - 1; i <= currentIndex + 1; i++) {
        if (i >= 0 && i < _videos.length && _videos[i].id == videoId) {
          isRelevant = true;
          break;
        }
      }
      return !isRelevant;
    });

    SharedVideoControllerPool()
        .retainOnly(_keepAliveVideoIds(currentIndex - 1, currentIndex + 1));
  }

  void _handlePageChange(int index) {
    if (!mounted || index != _currentIndex) return;

    AppLogger.log('📱 Page changed to index $index. Triggering SNAP autoplay...');
    _tryAutoplayCurrent();
    _preloadNearbyVideos();
    _markCurrentVideoAsSeen();
  }

  void _togglePlayPause(int index) {
    Vibration.vibrate(duration: 50, amplitude: 128);
    if (index >= _videos.length) return;
    final video = _videos[index];
    final String videoId = video.id;

    if (_togglingVideos.contains(videoId)) {
      AppLogger.log('⚠️ _togglePlayPause: Already toggling video $videoId, ignoring duplicate tap');
      return;
    }
    final controller = _controllerPool[video.id];
    if (controller == null || !controller.value.isInitialized) {
      AppLogger.log('⚠️ _togglePlayPause: Controller not available for index $index, preloading...');

      _preloadVideo(index).then((_) {
        if (!mounted) return;
        final c = _controllerPool[videoId];
        if (c != null && c.value.isInitialized) {
          try {
            _pauseOtherLocalVideos(videoId);
            _autoAdvancedForIndex.remove(index);
            _playWithPolicy(c, 'feed tap after preload');
            _controllerStates[videoId] = true;
            _userPaused[videoId] = false;
            _userPausedVN[videoId]?.value = false;

            AppLogger.log('▶️ Successfully played video at index $index after preload');

            if (index < _videos.length) {
              final currentVideo = _videos[index];
              _viewTracker.startViewTracking(
                currentVideo.id,
                videoUploaderId: currentVideo.uploader.id,
              );
            }
          } catch (e) {
            AppLogger.log('❌ Error playing video after preload at index $index: $e');
          }
        }
      }).catchError((e) {
        AppLogger.log('❌ Error preloading video for play/pause at index $index: $e');
      });
      return;
    }

    _togglingVideos.add(videoId);
    final isCurrentlyPlaying = controller.value.isPlaying;

    if (isCurrentlyPlaying) {
      try {
        _controllerStates[videoId] = false;
        _userPaused[videoId] = true;
        _userPausedVN[videoId]?.value = true;
        _playbackCoordinator.setUserPaused(_playbackSession, true);

        controller.pause();
        _ensureWakelockForVisibility();

        AppLogger.log('⏸️ Successfully paused video at index $index');

        if (widget.videoType == 'yog') {
          _showPauseAd(index);
        }

        if (index < _videos.length) {
          final currentVideo = _videos[index];
          _viewTracker.stopViewTracking(currentVideo.id);
        }
      } catch (e) {
        AppLogger.log('❌ Error pausing video at index $index: $e');
        _togglingVideos.remove(videoId);
        return;
      }
    } else {
      try {
        _pauseOtherLocalVideos(videoId);

        _controllerStates[videoId] = true;
        _userPaused[videoId] = false;
        _userPausedVN[videoId]?.value = false;
        _playbackCoordinator.setUserPaused(_playbackSession, false);
        _cinemaModeVN.value = false;
        _hidePauseAdOverlay(videoId: videoId);

        _lifecyclePaused = false;
        _autoAdvancedForIndex.remove(index);
        _playWithPolicy(controller, 'feed tap play');
        _ensureWakelockForVisibility();

        AppLogger.log('▶️ Successfully played video at index $index');

        if (index < _videos.length) {
          final currentVideo = _videos[index];
          _viewTracker.startViewTracking(
            currentVideo.id,
            videoUploaderId: currentVideo.uploader.id,
          );
        }
      } catch (e) {
        AppLogger.log('❌ Error playing video at index $index: $e');
        _togglingVideos.remove(videoId);
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      _togglingVideos.remove(videoId);
    });
  }

  @override
  void didPushNext() {
    _playbackCoordinator.setRouteActive(_playbackSession, false);
    _pauseCurrentVideo();
  }

  @override
  void didPopNext() {
    _playbackCoordinator.setRouteActive(_playbackSession, true);
    _tryAutoplayCurrent();
  }

  @override
  void didPop() {
    _playbackCoordinator.setRouteActive(_playbackSession, false);
    _pauseCurrentVideo();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInPictureInPicture) {
      final controller = _currentPictureInPictureController;
      return FeedPipPlayer(
        controller: controller,
        aspectRatio: controller != null
            ? _pictureInPictureAspectRatio(controller)
            : 9 / 16,
      );
    }

    final authController = ref.watch(googleSignInProvider);
    final isSignedIn = authController.isSignedIn;

    if (isSignedIn != _wasSignedIn) {
      _wasSignedIn = isSignedIn;
      if (isSignedIn) {
        _pendingAutoplayAfterLogin = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleAutoplayAfterLogin();
            _loadActiveAds().catchError((e) {
              AppLogger.log('⚠️ Error reloading ads after login: $e');
            });
          }
        });
      } else {
        _pendingAutoplayAfterLogin = false;
      }
    }

    if (isSignedIn && authController.userData != null) {
      final userId = authController.userData!['googleId'] ??
          authController.userData!['id'];
      if (userId != null && _currentUserId != userId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentUserId = userId;
            });
            AppLogger.log('✅ VideoFeedAdvanced: User ID synced from auth: $userId');
          }
        });
      }
    } else if (!isSignedIn && _currentUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentUserId = null;
          });
          AppLogger.log('✅ VideoFeedAdvanced: User ID cleared (signed out)');
        }
      });
    }

    final mainController = ref.watch(mainControllerProvider);
    final feedTabIndex = _feedTabIndex;
    final isOwnTabActive =
        feedTabIndex == null || mainController.currentIndex == feedTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVisibilityChange(isOwnTabActive);
    });

    Widget buildBody() {
      if (_isLoading && _videos.isEmpty) {
        return const VideoFeedSkeleton();
      }

      if (_videos.isEmpty && _errorMessage != null) {
        return RefreshIndicator(
          onRefresh: refreshVideos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: FeedErrorState(
                errorMessage: _errorMessage != null
                    ? _getUserFriendlyErrorMessage(_errorMessage!)
                    : null,
                isLoadingOrRefreshing: _isLoading || _isRefreshing,
                onRefresh: refreshVideos,
                onTestConnection: _testApiConnection,
              ),
            ),
          ),
        );
      }

      if (_videos.isEmpty) {
        return RefreshIndicator(
          onRefresh: refreshVideos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: FeedEmptyState(
                isLoadingOrRefreshing: _isLoading || _isRefreshing,
                onRefresh: refreshVideos,
              ),
            ),
          ),
        );
      }

      return _buildVideoFeed();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          buildBody(),
          _buildOfflineIndicator(),
          if (_isGoogleSignInInProgress) const FeedSignInOverlay(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pictureInPictureModeSubscription?.cancel();
    _pictureInPicturePlaybackSubscription?.cancel();
    _pictureInPicturePreparationSubscription?.cancel();
    _playbackCoordinator.setPiPActive(_playbackSession, false);
    unawaited(_pictureInPictureService.release(_pictureInPictureOwnerId));
    appRouteObserver.unsubscribe(this);
    _playbackCoordinator.release(_playbackSession);

    if (!_openedFromProfile) {
      _videoControllerManager.unregisterOnRoutePopped();
    }

    WidgetsBinding.instance.removeObserver(this);

    _pageChangeDebounceTimer?.cancel();
    _pageChangeTimer?.cancel();
    _preloadTimer?.cancel();
    _preloadDebounceTimer?.cancel();
    _adRefreshSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _bannerAdRetryTimer?.cancel();
    _poolDisposalSubscription?.cancel();

    for (var s in _dubbingSubscriptions.values) {
      s.cancel();
    }
    for (var timer in _preloadDebounceTimers.values) {
      timer.cancel();
    }
    for (var timer in _bufferingTimers.values) {
      timer.cancel();
    }
    for (var timer in _forceShowOverlayTimers.values) {
      timer.cancel();
    }

    _viewTracker.dispose();
    _profilePreloader.dispose();
    _videoControllerManager.dispose();
    AppLogger.log('🎯 VideoFeedAdvanced: Disposed Trackers and Managers');

    final sharedPool = SharedVideoControllerPool();
    final bool openedFromProfile = _openedFromProfile;
    int savedControllers = 0;

    sharedPool.pinVideo(null, sessionId: _playbackSession.id);

    final controllersToDispose =
        Map<String, VideoPlayerController>.from(_controllerPool);

    controllersToDispose.forEach((videoId, controller) {
      try {
        sharedPool.removeListener(videoId);

        if (openedFromProfile) {
          if (sharedPool.isPooled(videoId)) {
            sharedPool.disposeController(videoId);
          } else {
            try {
              if (controller.value.isInitialized) {
                if (controller.value.isPlaying) {
                  controller.pause();
                }
                controller.setVolume(0.0);
              }
              controller.dispose();
            } catch (e) {
              AppLogger.log('⚠️ VideoFeedAdvanced: Error disposing unpooled controller: $e');
            }
          }
        } else {
          if (controller.value.isInitialized && controller.value.isPlaying) {
            controller.pause();
            _controllerStates[videoId] = false;
          }
          sharedPool.addController(videoId, controller, skipDisposeOld: true);
          savedControllers++;
        }
      } catch (e) {
        AppLogger.log('⚠️ Error saving controller for video $videoId: $e');
        try {
          controller.dispose();
        } catch (_) {}
      }
    });

    AppLogger.log('💾 VideoFeedAdvanced: Saved $savedControllers controllers to shared pool');

    if (savedControllers > 2) {
      sharedPool.disposeControllersForMemoryManagement();
    }

    _controllerPool.clear();
    _controllerStates.clear();
    _isBuffering.clear();
    _bufferingListeners.clear();
    _videoEndListeners.clear();
    _errorListeners.clear();
    _quizListeners.clear();
    _wasPlayingBeforeNavigation.clear();
    _loadingVideos.clear();
    _initializingVideos.clear();
    _preloadRetryCount.clear();
    _preloadedVideos.clear();

    for (final notifier in _showHeartAnimation.values) {
      notifier.dispose();
    }
    _showHeartAnimation.clear();

    for (final notifier in _currentHorizontalPage.values) {
      notifier.dispose();
    }
    _currentHorizontalPage.clear();

    for (final notifier in _isBufferingVN.values) {
      notifier.dispose();
    }
    _isBufferingVN.clear();

    for (final notifier in _userPausedVN.values) {
      notifier.dispose();
    }
    _userPausedVN.clear();

    for (final notifier in _forceShowOverlayVN.values) {
      notifier.dispose();
    }
    _forceShowOverlayVN.clear();

    _cinemaModeVN.dispose();

    for (final notifier in _showPauseAdOverlayPerVideoVN.values) {
      notifier.dispose();
    }
    _showPauseAdOverlayPerVideoVN.clear();

    for (final notifier in _bannerAdDismissedPerVideoVN.values) {
      notifier.dispose();
    }
    _bannerAdDismissedPerVideoVN.clear();
    _dismissedPauseAdVideoIds.clear();

    _pageController.dispose();

    for (final controller in _horizontalControllers.values) {
      controller.dispose();
    }
    _horizontalControllers.clear();

    _disableWakelock();
    super.dispose();
  }
}
