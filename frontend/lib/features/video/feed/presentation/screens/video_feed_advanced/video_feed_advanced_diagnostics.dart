part of '../video_feed_advanced.dart';

extension _VideoFeedDiagnostics on _VideoFeedAdvancedState {
  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    if (ConnectivityService.isNetworkError(error)) {
      return ConnectivityService.getNetworkErrorMessage(error);
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('device_key_changed') ||
        errorString.contains('device_key_missing')) {
      return 'This device cannot decrypt this video. Please use the original device or contact support.';
    }
    if (errorString.contains('authentication_required') ||
        errorString.contains('please sign in again') ||
        errorString.contains('please sign in to watch this encrypted video')) {
      return 'Please sign in to watch this encrypted video.';
    }
    if (errorString.contains('access_denied')) {
      return 'You do not have access to this encrypted video.';
    }

    if (errorString.contains('decoding error') ||
        errorString.contains('e2ee') ||
        errorString.contains('decrypt') ||
        errorString.contains('symmetric key') ||
        errorString.contains('video-key')) {
      return "You can't access this video. It is End-to-End Encrypted (E2EE).";
    }

    if (errorString.contains('e2ee_error') ||
        (errorString.contains('source') && errorString.contains('error'))) {
      return 'Secure video is still loading. Please wait a moment and try again.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please check your internet connection.';
    } else if (errorString.contains('404')) {
      return 'Videos not found';
    } else if (errorString.contains('500')) {
      return 'Server error. Please try again later.';
    } else if (errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Authentication required. Please sign in again.';
    } else if (errorString.contains('403')) {
      return 'Access denied. You may not have permission for this action.';
    } else {
      return 'Unable to load videos. Please try again.';
    }
  }

  /// Test if the API is reachable
  Future<void> _testApiConnection() async {
    try {
      AppLogger.log('🔍 VideoFeedAdvanced: Testing API connection...');

      if (mounted) {
        VayuSnackBar.showInfo(
          context,
          'Testing connection...',
          duration: const Duration(seconds: 2),
        );
      }

      await _videoService.getVideos(page: 1, limit: 1);

      if (mounted) {
        VayuSnackBar.showSuccess(
          context,
          'Connection successful!',
          duration: const Duration(seconds: 2),
        );

        safeSetState(() {
          _errorMessage = null;
        });
        await refreshVideos();
      }
    } catch (e) {
      AppLogger.log('❌ VideoFeedAdvanced: API connection test failed: $e');

      if (mounted) {
        VayuSnackBar.showError(
          context,
          'Connection failed: ${_getUserFriendlyErrorMessage(e)}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Comprehensive cache information
  Map<String, dynamic> _getDetailedCacheInfo() {
    return {
      'videoControllerPool': {
        'totalControllers': _controllerPool.length,
        'controllerKeys': _controllerPool.keys.toList(),
        'controllerStates': _controllerStates,
        'preloadedVideos': _preloadedVideos.toList(),
        'loadingVideos': _loadingVideos.toList(),
      },
      'cacheStatistics': {
        'cacheHits': _cacheHits,
        'cacheMisses': _cacheMisses,
        'preloadHits': _preloadHits,
        'totalRequests': _totalRequests,
        'hitRate': _totalRequests > 0
            ? (_cacheHits / _totalRequests * 100).toStringAsFixed(2)
            : '0.00',
      },
      'smartCacheManager': {},
      'videoLoadingStatus': {
        'currentIndex': _currentIndex,
        'totalVideos': _videos.length,
        'maxPoolSize': _maxPoolSize,
        'isLoading': _isLoading,
        'isScreenVisible': _isScreenVisible,
      },
      'memoryUsage': {
        'controllerPoolSize': _controllerPool.length,
        'preloadedVideosCount': _preloadedVideos.length,
        'loadingVideosCount': _loadingVideos.length,
      },
    };
  }

  /// Print cache info for debugging
  void _printDetailedCacheInfo() {
    final info = _getDetailedCacheInfo();

    final poolInfo = info['videoControllerPool'] as Map<String, dynamic>;
    poolInfo.forEach((key, value) {
      AppLogger.log('   $key: $value');
    });

    AppLogger.log('📈 Cache Statistics:');
    final statsInfo = info['cacheStatistics'] as Map<String, dynamic>;
    statsInfo.forEach((key, value) {
      AppLogger.log('   $key: $value');
    });

    AppLogger.log('🎥 Video Loading Status:');
    final loadingInfo = info['videoLoadingStatus'] as Map<String, dynamic>;
    loadingInfo.forEach((key, value) {
      AppLogger.log('   $key: $value');
    });

    AppLogger.log('💾 Memory Usage:');
    final memoryInfo = info['memoryUsage'] as Map<String, dynamic>;
    memoryInfo.forEach((key, value) {
      AppLogger.log('   $key: $value');
    });
  }

  void checkCacheStatus() {
    AppLogger.log('🔍 Manual Cache Status Check Triggered');
    _printDetailedCacheInfo();
  }

  Map<String, dynamic> getCacheSummary() {
    return {
      'totalVideos': _videos.length,
      'preloadedVideos': _preloadedVideos.length,
      'loadingVideos': _loadingVideos.length,
      'controllerPoolSize': _controllerPool.length,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': _totalRequests > 0
          ? (_cacheHits / _totalRequests * 100).toStringAsFixed(2)
          : '0.00',
      'currentIndex': _currentIndex,
      'isLoading': _isLoading,
    };
  }
}
