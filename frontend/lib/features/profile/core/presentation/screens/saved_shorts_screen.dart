import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/core/data/services/video_service.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/utils/format_utils.dart';
import 'package:vayug/features/video/core/presentation/screens/video_screen.dart';
import 'package:vayug/features/video/core/presentation/managers/shared_video_controller_pool.dart';
import 'package:vayug/shared/services/share_service.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class SavedShortsScreen extends StatefulWidget {
  final List<VideoModel>? initialVideos;
  final VoidCallback? onVideosUpdated;

  const SavedShortsScreen({
    super.key,
    this.initialVideos,
    this.onVideosUpdated,
  });

  @override
  State<SavedShortsScreen> createState() => _SavedShortsScreenState();
}

class _SavedShortsScreenState extends State<SavedShortsScreen> {
  final VideoService _videoService = VideoService();
  final ShareService _shareService = ShareService();

  List<VideoModel> _shorts = [];
  bool _isLoading = true;
  String? _error;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialVideos != null) {
      _shorts = widget.initialVideos!
          .where((v) => v.videoType.toLowerCase() != 'vayu')
          .toList();
      _isLoading = false;
    } else {
      _loadSavedShorts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedShorts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allSaved = await _videoService.getSavedVideos();
      if (mounted) {
        setState(() {
          _shorts = allSaved
              .where((v) => v.videoType.toLowerCase() != 'vayu')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ SavedShortsScreen: Error loading shorts: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeSavedShort(VideoModel video) async {
    final index = _shorts.indexWhere((v) => v.id == video.id);
    if (index == -1) return;

    final removedVideo = _shorts[index];
    setState(() {
      _shorts.removeAt(index);
    });
    widget.onVideosUpdated?.call();

    try {
      await _videoService.toggleSave(video.id);
      if (mounted) {
        VayuSnackBar.show(
          context,
          'Removed from saved shorts',
          type: VayuSnackBarType.info,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primaryLight,
            onPressed: () async {
              setState(() {
                _shorts.insert(index, removedVideo);
              });
              widget.onVideosUpdated?.call();
              await _videoService.toggleSave(video.id);
            },
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ SavedShortsScreen: Error removing short: $e');
      if (mounted) {
        setState(() {
          _shorts.insert(index, removedVideo);
        });
        widget.onVideosUpdated?.call();
        VayuSnackBar.show(
          context,
          'Failed to remove from saved shorts',
          type: VayuSnackBarType.error,
        );
      }
    }
  }

  List<VideoModel> get _filteredShorts {
    if (_searchQuery.trim().isEmpty) return _shorts;
    final query = _searchQuery.toLowerCase().trim();
    return _shorts.where((v) {
      final nameMatches = v.videoName.toLowerCase().contains(query);
      final uploaderMatches = v.uploader.name.toLowerCase().contains(query);
      return nameMatches || uploaderMatches;
    }).toList();
  }

  void _openShort(VideoModel video) {
    final sharedPool = SharedVideoControllerPool();
    sharedPool.pauseAllControllers();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoScreen(
          initialVideos: _shorts,
          initialVideoId: video.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredShorts;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search saved shorts...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Shorts',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  if (!_isLoading && _shorts.isNotEmpty)
                    Text(
                      '${_shorts.length} ${_shorts.length == 1 ? "video" : "videos"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.surfaceElevated,
            onSelected: (value) {
              if (value == 'refresh') {
                _loadSavedShorts();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppColors.textPrimary, size: 18),
                    SizedBox(width: 8),
                    Text('Refresh', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(displayList),
    );
  }

  Widget _buildBody(List<VideoModel> displayList) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load saved shorts',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadSavedShorts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_shorts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfacePrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No saved shorts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Shorts (Yug) you save will appear here.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (displayList.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Text(
          'No shorts match "$_searchQuery"',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedShorts,
      color: AppColors.primary,
      backgroundColor: AppColors.surfacePrimary,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final video = displayList[index];
          return _buildShortCard(video);
        },
      ),
    );
  }

  Widget _buildShortCard(VideoModel video) {
    return GestureDetector(
      onTap: () => _openShort(video),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Thumbnail
            Container(
              color: AppColors.surfacePrimary,
              child: video.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfacePrimary,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfacePrimary,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.textTertiary,
                          size: 36,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.surfacePrimary,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.textTertiary,
                        size: 36,
                      ),
                    ),
            ),

            // Top-right 3-dots Menu Button
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.transparent,
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  color: AppColors.surfaceElevated,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 150),
                  onSelected: (value) {
                    if (value == 'remove') {
                      _removeSavedShort(video);
                    } else if (value == 'share') {
                      _shareService.shareVideo(video);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: AppColors.textPrimary, size: 18),
                          SizedBox(width: 8),
                          Text('Remove from saved',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined,
                              color: AppColors.textPrimary, size: 18),
                          SizedBox(width: 8),
                          Text('Share',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Gradient Overlay with Real Fields
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.videoName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FormatUtils.formatViews(video.views)} views',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
