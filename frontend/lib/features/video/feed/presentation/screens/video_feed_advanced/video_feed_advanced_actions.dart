part of '../video_feed_advanced.dart';

extension _VideoFeedActions on _VideoFeedAdvancedState {
  /// Show heart animation and trigger like logic on double-tap
  Future<void> _handleDoubleTapLike(VideoModel video) async {
    _showHeartAnimation[video.id] ??= ValueNotifier<bool>(false);
    _showHeartAnimation[video.id]!.value = true;

    Future.delayed(const Duration(milliseconds: 1000), () {
      _showHeartAnimation[video.id]?.value = false;
    });

    _forceShowOverlayVN[video.id] ??= ValueNotifier<bool>(false);
    _forceShowOverlayVN[video.id]!.value = true;
    _forceShowOverlayTimers[video.id]?.cancel();
    _forceShowOverlayTimers[video.id] = Timer(const Duration(seconds: 2), () {
      _forceShowOverlayVN[video.id]?.value = false;
    });

    final isLikedNotifier = _isLikedVN.putIfAbsent(
      video.id,
      () => ValueNotifier<bool>(video.isLiked),
    );

    if (isLikedNotifier.value) {
      AppLogger.log(
        '🔴 DoubleTap Like: Video already liked by current user – showing animation only (count unchanged)',
      );
      return;
    }

    await _handleLike(video);
  }

  /// Handle like button press with optimistic update and backend sync
  Future<void> _handleLike(VideoModel video) async {
    ValueNotifier<bool> getLikedNotifier() {
      return _isLikedVN.putIfAbsent(
        video.id,
        () => ValueNotifier<bool>(video.isLiked),
      );
    }

    ValueNotifier<int> getCountNotifier() {
      return _likeCountVN.putIfAbsent(
        video.id,
        () => ValueNotifier<int>(video.likes),
      );
    }

    if (_likeInProgress[video.id] == true) return;

    final authController = ref.read(googleSignInProvider);
    if (!authController.isSignedIn) {
      final signedIn = await _triggerSignInOptions();
      if (!signedIn) return;
    }

    final likedVN = getLikedNotifier();
    final countVN = getCountNotifier();

    final wasLiked = likedVN.value;
    final originalLikes = countVN.value;

    likedVN.value = !wasLiked;
    countVN.value = wasLiked
        ? (originalLikes - 1).clamp(0, double.infinity).toInt()
        : originalLikes + 1;

    video.isLiked = !wasLiked;
    video.likes = countVN.value;

    try {
      _likeInProgress[video.id] = true;
      VideoModel updatedVideo = await _videoService.toggleLike(video.id);

      video.likes = updatedVideo.likes;
      video.isLiked = updatedVideo.isLiked;

      countVN.value = updatedVideo.likes;
      likedVN.value = updatedVideo.isLiked;

      _recordVideoLikePersistence(video.id, updatedVideo.isLiked);
    } catch (e) {
      AppLogger.log('❌ Error handling like: $e');

      likedVN.value = wasLiked;
      countVN.value = originalLikes;

      video.isLiked = wasLiked;
      video.likes = originalLikes;

      _recordVideoLikePersistence(video.id, wasLiked);

      String errorMessage = 'Failed to like video';
      final errorString = e.toString();
      if (errorString.contains('sign in') ||
          errorString.contains('authenticated')) {
        errorMessage = 'Please sign in again to like videos';
        Future.delayed(
          const Duration(milliseconds: 500),
          _triggerSignInOptions,
        );
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      _likeInProgress[video.id] = false;
    }
  }

  /// Trigger Google Sign-In account picker popup
  Future<bool> _triggerSignInOptions() async {
    if (_isGoogleSignInInProgress) return false;

    try {
      final authController = ref.read(googleSignInProvider);
      if (authController.isSignedIn) return true;
      if (mounted) {
        safeSetState(() => _isGoogleSignInInProgress = true);
        VayuSnackBar.showInfo(
          context,
          'Opening Google sign-in...',
          duration: const Duration(seconds: 2),
        );
      }

      final result = await AuthFlow.signIn(
        context,
        ref,
        onSuccess: () async {
          AppLogger.log('✅ Sign-in successful after like/comment action');
          final user = ref.read(googleSignInProvider).userData;
          final userId =
              (user?['googleId'] ?? user?['id'] ?? user?['_id'])?.toString();
          if (userId != null && userId.isNotEmpty && mounted) {
            safeSetState(() => _currentUserId = userId);
          }
        },
      );
      return result.isSuccess;
    } catch (e) {
      AppLogger.log('❌ Error triggering sign-in: $e');
      _showSnackBar('Failed to sign in. Please try again.', isError: true);
      return false;
    } finally {
      if (mounted) {
        safeSetState(() => _isGoogleSignInInProgress = false);
      }
    }
  }

  /// Share options sheet
  Future<void> _handleShare(VideoModel video) async {
    try {
      final index = _videos.indexWhere((v) => v.id == video.id);
      ShareOptionsSheet.show(
        context,
        video: video,
        controller: index != -1 ? _getController(index) : null,
      );
    } catch (e) {
      AppLogger.log('❌ Error showing share options: $e');
      _showSnackBar('Failed to share video', isError: true);
    }
  }

  /// Visit now button handler
  Future<void> _handleVisitNow(VideoModel video) async {
    final validLinks = video.validLinks;
    if (validLinks.length > 1) {
      LinksBottomSheet.show(
        context,
        title: video.videoName,
        links: validLinks.map((l) => l.toLinkItemData()).toList(),
        source: 'vayug',
        medium: 'video_feed',
        campaign: 'creator_visit',
      );
      return;
    }

    final singleUrl = validLinks.isNotEmpty
        ? validLinks.first.url
        : (video.link?.trim() ?? '');
    if (singleUrl.isEmpty) {
      _showSnackBar('No link available for this video', isError: true);
      return;
    }
    await _launchExternalUrl(singleUrl);
  }

  /// Launch external URL in browser
  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final enrichedUrl = UrlUtils.enrichUrl(
        urlString,
        medium: 'video_feed',
        campaign: 'creator_visit',
      );

      final Uri? uri = Uri.tryParse(enrichedUrl);
      if (uri == null) {
        _showSnackBar('This link format is invalid and cannot be opened.', isError: true);
        return;
      }

      if (!await canLaunchUrl(uri)) {
        final scheme = uri.scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          _showSnackBar('This link type is not supported.', isError: true);
        } else {
          _showSnackBar(
            'No browser found to open this link. Please check if a browser app is installed.',
            isError: true,
          );
        }
        return;
      }

      _showSnackBar('Opening link...', isError: false);
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        _showSnackBar(
          'Could not open link. The website may be down or temporarily unavailable.',
          isError: true,
        );
      }
    } catch (e) {
      AppLogger.log('❌ Error opening link: $e');
      _showSnackBar('An unexpected error occurred while opening the link.', isError: true);
    }
  }

  /// Show snackbar helper
  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      VayuSnackBar.showError(context, message);
    } else {
      VayuSnackBar.showInfo(context, message, duration: const Duration(seconds: 2));
    }
  }

  /// Follow/unfollow toggle
  Future<void> _handleFollow(VideoModel video) async {
    if (_currentUserId == null) return;
    if (video.uploader.id == _currentUserId) return;

    try {
      final userProviderRef = ref.read(userProvider);
      final trimmedUploaderId = video.uploader.id.trim();

      if (trimmedUploaderId.isEmpty || trimmedUploaderId == 'unknown') {
        AppLogger.log('⚠️ Cannot follow: Invalid uploader ID');
        return;
      }

      final success = await userProviderRef.toggleFollow(trimmedUploaderId);
      if (!success) {
        AppLogger.log('❌ Failed to toggle follow for $trimmedUploaderId');
      }
    } catch (e) {
      AppLogger.log('❌ Error in _handleFollow: $e');
    }
  }

  /// Navigate to creator profile
  void _navigateToCreatorProfile(VideoModel video) {
    final candidateIds = <String>[
      if (video.uploader.googleId != null) video.uploader.googleId!.trim(),
      if (video.uploader.id.isNotEmpty) video.uploader.id.trim(),
    ]
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id.toLowerCase() != 'unknown')
        .toList();

    final targetUserId = candidateIds.isNotEmpty ? candidateIds.first : '';

    if (targetUserId.isEmpty) {
      _showSnackBar('User profile not available', isError: true);
      return;
    }

    _pauseVideosForProfileNavigation();
    ProfilePreloader().preloadProfileOnTap(targetUserId);

    Navigator.push(
      context,
      MaterialPageRoute(
        settings:
            RouteSettings(name: 'profile', arguments: {'userId': targetUserId}),
        builder: (context) => ProfileScreen(userId: targetUserId),
      ),
    ).catchError((error) {
      AppLogger.log('❌ Error navigating to profile: $error');
      _showSnackBar('Failed to open profile', isError: true);
      return null;
    });
  }

  /// Open report dialog
  void _openReportDialog(String videoId) {
    if (videoId.isEmpty) return;
    VayuBottomSheet.show(
      context: context,
      title: 'Report Content',
      icon: Icons.report_problem_outlined,
      child: ReportDialogWidget(targetType: 'video', targetId: videoId),
    );
  }
}
