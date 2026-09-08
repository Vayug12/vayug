import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vayug/core/interfaces/i_auth_service.dart';
import 'package:vayug/core/interfaces/i_video_service.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/managers/smart_cache_manager.dart';

class ProfileVideoManager extends ChangeNotifier {
  final IVideoService _videoService;
  final IAuthService _authService;
  final SmartCacheManager _smartCacheManager;

  ProfileVideoManager({
    required IVideoService videoService,
    required IAuthService authService,
    required SmartCacheManager smartCacheManager,
  })  : _videoService = videoService,
        _authService = authService,
        _smartCacheManager = smartCacheManager;

  // State variables
  List<VideoModel> _userVideos = [];
  bool _isVideosLoading = false;
  bool _isFetchingMore = false;
  bool _hasMoreVideos = true;
  int _totalVideoCount = 0;
  int _currentPage = 1;
  final Set<String> _selectedVideoIds = {};
  bool _needsVideoRefresh = false;
  String? _error;
  bool _hasLoadedVideosSuccessfully = false;
  
  static const int _pageSize = 1000;
  Timer? _processingStatusPoller;
  bool _isProcessingPollInFlight = false;

  bool _isDisposed = false;

  // Getters
  List<VideoModel> get userVideos => _userVideos;
  bool get isVideosLoading => _isVideosLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMoreVideos => _hasMoreVideos;
  int get totalVideoCount => _totalVideoCount;
  Set<String> get selectedVideoIds => _selectedVideoIds;
  bool get needsVideoRefresh => _needsVideoRefresh;
  String? get error => _error;
  bool get hasLoadedVideosSuccessfully => _hasLoadedVideosSuccessfully;

  void setError(String? value) {
    _error = value;
    notifyListenersSafe();
  }

  void notifyListenersSafe() {
    if (_isDisposed) return;
    final scheduler = WidgetsBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (!_isDisposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopProcessingStatusPolling();
    super.dispose();
  }

  Future<void> loadUserVideos(String? userId, {bool forceRefresh = false, bool silent = false, int page = 1}) async {
    if (page == 1) {
      _currentPage = 1;
      _hasMoreVideos = true;
      _needsVideoRefresh = false;
      _error = null;
      // Silent refreshes should keep cached videos visible, but an initial
      // request with no data still needs an explicit loading state.
      if (!silent || _userVideos.isEmpty) {
        _isVideosLoading = true;
        notifyListenersSafe();
      }
    } else {
      _currentPage = page;
    }

    try {
      final loggedInUser = await _authService.getUserData();
      final bool isMyProfile = userId == null || userId == loggedInUser?['id'] || userId == loggedInUser?['googleId'];
      String? targetUserId = isMyProfile ? (loggedInUser?['googleId'] ?? loggedInUser?['id']) : userId;
      
      if (targetUserId == null || targetUserId.isEmpty) return;

      final videos = await _videoService.getUserVideos(targetUserId,
          forceRefresh: forceRefresh, page: page, limit: _pageSize);

      if (page == 1) {
        _hasLoadedVideosSuccessfully = true;
        _error = null;
      }

      if (page == 1) {
        final optimisticVideos = _userVideos.where((v) => v.isOptimistic).toList();
        if (optimisticVideos.isNotEmpty) {
           final serverIds = videos.map((v) => v.id).toSet();
           final stillOptimistic = optimisticVideos.where((v) => !serverIds.contains(v.id)).toList();
           _userVideos = [...stillOptimistic, ...videos];
        } else {
          _userVideos = videos;
        }
      } else {
        _addUniqueVideos(videos);
      }

      _userVideos.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      _hasMoreVideos = videos.length >= _pageSize;
      
      // Sync total count
      _totalVideoCount = _userVideos.isNotEmpty
          ? (_userVideos.first.uploader.totalVideos ?? _userVideos.length)
          : 0;

      if (_userVideos.any(_isVideoStillProcessing)) {
        _startProcessingStatusPolling();
      } else {
        _stopProcessingStatusPolling();
      }
    } catch (e) {
      AppLogger.log('❌ ProfileVideoManager: Error loading videos: $e');
      if (page == 1) _error = 'Failed to load videos.';
    } finally {
      _isFetchingMore = false;
      _isVideosLoading = false;
      notifyListenersSafe();
    }
  }

  bool _isVideoStillProcessing(VideoModel video) {
    return video.isOptimistic || video.processingStatus.toLowerCase() == 'processing' || video.processingStatus.toLowerCase() == 'pending';
  }

  void _addUniqueVideos(List<VideoModel> newVideos) {
    final existingIds = _userVideos.map((v) => v.id).toSet();
    for (var video in newVideos) {
      if (!existingIds.contains(video.id)) {
        _userVideos.add(video);
      }
    }
  }

  void _startProcessingStatusPolling() {
    if (_processingStatusPoller != null || _isDisposed) return;
    _processingStatusPoller = Timer.periodic(const Duration(seconds: 5), (_) => _pollProcessingStatus());
  }

  void _stopProcessingStatusPolling() {
    _processingStatusPoller?.cancel();
    _processingStatusPoller = null;
  }

  Future<void> _pollProcessingStatus() async {
    if (_isProcessingPollInFlight || _isDisposed) return;
    _isProcessingPollInFlight = true;
    try {
      final processingVideos = _userVideos.where(_isVideoStillProcessing).toList();
      if (processingVideos.isEmpty) {
        _stopProcessingStatusPolling();
        return;
      }

      bool hasChanges = false;
      for (var video in processingVideos) {
        final status = await _videoService.getVideoProcessingStatus(video.id);
        if (status != null) {
          // Logic for updating video model with new status...
          // If status changed to completed, hasChanges = true
        }
      }
      if (hasChanges) notifyListenersSafe();
    } catch (e) {
      AppLogger.log('⚠️ ProfileVideoManager: Polling error: $e');
    } finally {
      _isProcessingPollInFlight = false;
    }
  }
  
  void addVideoOptimistically(Map<String, dynamic> videoData) {
    final newVideo = VideoModel.fromJson({...videoData, 'isOptimistic': true});
    _userVideos.insert(0, newVideo);
    _totalVideoCount++;
    _startProcessingStatusPolling();
    notifyListenersSafe();
  }

  void addNewVideo(VideoModel video) {
    _userVideos.insert(0, video);
    notifyListenersSafe();
  }

  bool _isSelecting = false;
  bool get isSelecting => _isSelecting;

  void enterSelectionMode() {
    _isSelecting = true;
    notifyListenersSafe();
  }

  void exitSelectionMode() {
    _isSelecting = false;
    _selectedVideoIds.clear();
    notifyListenersSafe();
  }

  void toggleSelectionMode() {
    _isSelecting = !_isSelecting;
    if (!_isSelecting) _selectedVideoIds.clear();
    notifyListenersSafe();
  }

  void toggleVideoSelection(String videoId) {
    if (_selectedVideoIds.contains(videoId)) {
      _selectedVideoIds.remove(videoId);
    } else {
      _selectedVideoIds.add(videoId);
    }
    notifyListenersSafe();
  }

  void removeVideo(String videoId) {
    _userVideos.removeWhere((v) => v.id == videoId);
    _pruneEpisodesAfterDeletion({videoId});
    if (!_userVideos.any(_isVideoStillProcessing)) _stopProcessingStatusPolling();
    notifyListenersSafe();
  }

  void _pruneEpisodesAfterDeletion(Set<String> deletedIds) {
    for (var i = 0; i < _userVideos.length; i++) {
      final v = _userVideos[i];
      if (v.episodes != null && v.episodes!.isNotEmpty) {
        final filteredEpisodes = v.episodes!
            .where((ep) => !deletedIds.contains((ep['id'] ?? ep['_id'])?.toString()))
            .toList();

        if (filteredEpisodes.length <= 1) {
          // No longer a multi-episode series! Unlink in local state
          _userVideos[i] = v.copyWith(
            clearSeriesId: true,
            clearEpisodes: true,
          );
        } else if (filteredEpisodes.length != v.episodes!.length) {
          _userVideos[i] = v.copyWith(
            episodes: filteredEpisodes,
          );
        }
      }
    }
  }

  Future<bool> deleteSingleVideo(String videoId) async {
    try {
      _isVideosLoading = true;
      notifyListenersSafe();
      final success = await _videoService.deleteVideos([videoId]);
      if (success > 0) {
        removeVideo(videoId);
        _totalVideoCount--;
        await _smartCacheManager.invalidateVideoCache();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.log('❌ ProfileVideoManager: Error deleting video: $e');
      return false;
    } finally {
      _isVideosLoading = false;
      notifyListenersSafe();
    }
  }

  Future<void> deleteSelectedVideos() async {
    if (_selectedVideoIds.isEmpty) return;
    final idsToDelete = Set<String>.from(_selectedVideoIds);
    try {
      final count = await _videoService.deleteVideos(idsToDelete.toList());
      if (count > 0) {
        _userVideos.removeWhere((v) => idsToDelete.contains(v.id));
        _pruneEpisodesAfterDeletion(idsToDelete);
        _selectedVideoIds.clear();
        _totalVideoCount -= count;
        _isSelecting = false;
        await _smartCacheManager.invalidateVideoCache();
      }
    } finally {
      notifyListenersSafe();
    }
  }

  /// Updates a specific video in the list with data returned from EditVideoDetails.
  /// Called when Navigator.pop returns updated video/series data.
  void updateVideoInList(String videoId, Map<String, dynamic> updatedData) {
    final index = _userVideos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    final old = _userVideos[index];
    final bool hasSeriesKey = updatedData.containsKey('seriesId');
    final String? newSeriesId = hasSeriesKey ? updatedData['seriesId'] as String? : old.seriesId;
    final bool shouldClearSeriesId = hasSeriesKey && (newSeriesId == null || newSeriesId.isEmpty);

    final bool hasEpisodesKey = updatedData.containsKey('episodes');
    final rawEpisodes = updatedData['episodes'];
    final List<Map<String, dynamic>>? parsedEpisodes = (rawEpisodes is List)
        ? rawEpisodes.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : null;
    final bool shouldClearEpisodes = hasEpisodesKey && (parsedEpisodes == null || parsedEpisodes.length <= 1);

    _userVideos[index] = old.copyWith(
      videoName: updatedData['videoName'] as String? ?? old.videoName,
      link: updatedData.containsKey('link') ? updatedData['link'] as String? : old.link,
      links: updatedData.containsKey('links') && updatedData['links'] is List<VideoLink>
          ? updatedData['links'] as List<VideoLink>
          : old.links,
      tags: updatedData.containsKey('tags') && updatedData['tags'] is List
          ? (updatedData['tags'] as List).map((e) => e.toString()).toList()
          : old.tags,
      seriesId: shouldClearSeriesId ? null : newSeriesId,
      clearSeriesId: shouldClearSeriesId,
      episodes: shouldClearEpisodes ? null : parsedEpisodes,
      clearEpisodes: shouldClearEpisodes,
    );
    notifyListenersSafe();
  }

  void clearData() {
    _userVideos = [];
    _selectedVideoIds.clear();
    _isVideosLoading = false;
    _isFetchingMore = false;
    _totalVideoCount = 0;
    _currentPage = 1;
    _hasMoreVideos = true;
    _stopProcessingStatusPolling();
  }

}
