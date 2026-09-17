part of '../video_feed_advanced.dart';

extension _VideoFeedDubbing on _VideoFeedAdvancedState {
  void _onAudioDubTap(VideoModel video) async {
    final videoId = video.id;
    final resultVN = _getOrCreateNotifier<DubbingResult>(
      _dubbingResultsVN,
      videoId,
      const DubbingResult(status: DubbingStatus.idle),
    );

    final currentResult = resultVN.value;
    if (!currentResult.isDone && currentResult.status != DubbingStatus.idle) {
      final bool? cancel = await VayuBottomSheet.show<bool>(
        context: context,
        title: 'Dubbing in progress',
        icon: Icons.multitrack_audio_rounded,
        iconColor: AppColors.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_audioLanguageTitle(_dubbingTargetLanguage[videoId] ?? currentResult.language ?? 'hindi')} audio is being prepared.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTypography.fontSizeSM,
                height: 1.35,
              ),
            ),
            AppSpacing.vSpace16,
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: currentResult.progress > 0
                    ? (currentResult.progress / 100).clamp(0.0, 1.0)
                    : null,
                minHeight: 4,
                backgroundColor: AppColors.backgroundSecondary,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.vSpace12,
            Text(
              currentResult.statusLabel,
              style: TextStyle(
                color: AppColors.white,
                fontSize: AppTypography.fontSizeSM,
                fontWeight: AppTypography.weightSemiBold,
              ),
            ),
            AppSpacing.vSpace24,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep Dubbing',
                    onPressed: () => Navigator.pop(context, false),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                  ),
                ),
                AppSpacing.hSpace12,
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context, true),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (cancel == true) {
        _dubbingService.cancelDubbing(video.id, video.videoUrl);
        _dubbingSubscriptions[videoId]?.cancel();
        _dubbingSubscriptions.remove(videoId);
        _dubbingTargetLanguage.remove(videoId);
        resultVN.value = const DubbingResult(status: DubbingStatus.idle);
        if (mounted) VayuSnackBar.showInfo(context, 'Dubbing cancelled.');
      }
      return;
    }

    FeedLanguageSelectorSheet.show(
      context: context,
      video: video,
      selectedLanguage: _selectedAudioLanguage[video.id] ?? 'default',
      onSelectLanguage: _handleAudioLanguageSelection,
      onStartDub: _startAudioDub,
    );
  }

  void _startAudioDub(VideoModel video, String targetLang) {
    final videoId = video.id;
    final resultVN = _getOrCreateNotifier<DubbingResult>(
      _dubbingResultsVN,
      videoId,
      const DubbingResult(status: DubbingStatus.idle),
    );

    _dubbingTargetLanguage[videoId] = targetLang;
    VayuSnackBar.showInfo(
      context,
      'Preparing ${_audioLanguageTitle(targetLang)} audio...',
    );

    final sub = _dubbingService
        .dubVideo(video.id, video.videoUrl, targetLang: targetLang)
        .listen((result) {
      if (!mounted) return;
      resultVN.value = result;

      if (result.status == DubbingStatus.completed) {
        _dubbingTargetLanguage.remove(videoId);
        if (result.dubbedUrl != null) {
          final vIndex = _videos.indexWhere((v) => v.id == videoId);
          if (vIndex != -1) {
            final currentDubbedUrls =
                Map<String, String>.from(_videos[vIndex].dubbedUrls ?? {});
            final String lang = result.language ?? targetLang;
            currentDubbedUrls[lang] = result.dubbedUrl!;
            safeSetState(() {
              _videos[vIndex] =
                  _videos[vIndex].copyWith(dubbedUrls: currentDubbedUrls);

              if (vIndex == _currentIndex && mounted) {
                _selectedAudioLanguage[videoId] = lang;

                if (_controllerPool.containsKey(videoId)) {
                  final ctrl = _controllerPool[videoId];
                  if (ctrl != null) {
                    _controllerPool.remove(videoId);
                    _controllerStates.remove(videoId);
                    _preloadedVideos.remove(videoId);
                    SharedVideoControllerPool().disposeController(videoId);

                    AppLogger.log(
                        '🗑️ VideoFeed: Safely disposed old controller for $videoId during auto-swap');
                  }
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _preloadVideo(vIndex);
                  }
                });
              }
            });
          }
          VayuSnackBar.showSuccess(
            context,
            '${_audioLanguageTitle(targetLang)} audio is ready.',
          );
        }
      } else if (result.status == DubbingStatus.notSuitable) {
        _dubbingTargetLanguage.remove(videoId);
        VayuSnackBar.showInfo(
          context,
          'Audio cannot be dubbed: ${result.reason ?? "No vocal detected"}',
        );
      } else if (result.status == DubbingStatus.failed) {
        _dubbingTargetLanguage.remove(videoId);
        if (mounted && result.error?.contains('Cancelled') != true) {
          VayuSnackBar.showError(
            context,
            'Dubbing failed: ${result.error ?? "Unknown error"}',
          );
        }
      }
    });

    _dubbingSubscriptions[videoId] = sub;
  }

  String _audioLanguageTitle(String langCode) {
    switch (langCode) {
      case 'english':
        return 'English';
      case 'hindi':
        return 'Hindi';
      default:
        return 'Original';
    }
  }

  void _handleAudioLanguageSelection(VideoModel video, String langCode) {
    if (_selectedAudioLanguage[video.id] == langCode) return;

    final String videoId = video.id;
    AppLogger.log('🎙️ Yug Language Switch: [$videoId] -> $langCode');

    safeSetState(() {
      _selectedAudioLanguage[videoId] = langCode;

      if (_controllerPool.containsKey(videoId)) {
        final ctrl = _controllerPool[videoId];
        if (ctrl != null) {
          _controllerPool.remove(videoId);
          _controllerStates.remove(videoId);
          _preloadedVideos.remove(videoId);
          SharedVideoControllerPool().disposeController(videoId);

          AppLogger.log(
              '🗑️ VideoFeed: Disposed old controller for $videoId during manual language switch');
        }
      }

      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _preloadVideo(index);
          }
        });
      }
    });
  }
}
