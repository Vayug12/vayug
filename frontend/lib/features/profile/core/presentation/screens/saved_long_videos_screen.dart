import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/core/data/services/video_service.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/utils/format_utils.dart';
import 'package:vayug/features/video/vayu/presentation/screens/vayu_long_form_player_screen.dart';
import 'package:vayug/features/video/core/presentation/managers/shared_video_controller_pool.dart';
import 'package:vayug/shared/services/share_service.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class SavedLongVideosScreen extends StatefulWidget {
  final List<VideoModel>? initialVideos;
  final VoidCallback? onVideosUpdated;

  const SavedLongVideosScreen({
    super.key,
    this.initialVideos,
    this.onVideosUpdated,
  });

  @override
  State<SavedLongVideosScreen> createState() => _SavedLongVideosScreenState();
}

class _SavedLongVideosScreenState extends State<SavedLongVideosScreen> {
  final VideoService _videoService = VideoService();
  final ShareService _shareService = ShareService();

  List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _error;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Sort state
  String _sortOption = 'Date added (newest)';

  @override
  void initState() {
    super.initState();
    if (widget.initialVideos != null) {
      _videos = widget.initialVideos!
          .where((v) => v.videoType.toLowerCase() == 'vayu')
          .toList();
      _isLoading = false;
    } else {
      _loadSavedVideos();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allSaved = await _videoService.getSavedVideos();
      if (mounted) {
        setState(() {
          _videos = allSaved
              .where((v) => v.videoType.toLowerCase() == 'vayu')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ SavedLongVideosScreen: Error loading long videos: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeSavedVideo(VideoModel video) async {
    final index = _videos.indexWhere((v) => v.id == video.id);
    if (index == -1) return;

    final removedVideo = _videos[index];
    setState(() {
      _videos.removeAt(index);
    });
    widget.onVideosUpdated?.call();

    try {
      await _videoService.toggleSave(video.id);
      if (mounted) {
        VayuSnackBar.show(
          context,
          'Removed from saved videos',
          type: VayuSnackBarType.info,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primaryLight,
            onPressed: () async {
              setState(() {
                _videos.insert(index, removedVideo);
              });
              widget.onVideosUpdated?.call();
              await _videoService.toggleSave(video.id);
            },
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ SavedLongVideosScreen: Error removing video: $e');
      if (mounted) {
        setState(() {
          _videos.insert(index, removedVideo);
        });
        widget.onVideosUpdated?.call();
        VayuSnackBar.show(
          context,
          'Failed to remove from saved videos',
          type: VayuSnackBarType.error,
        );
      }
    }
  }

  List<VideoModel> get _displayVideos {
    List<VideoModel> list = List.from(_videos);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((v) {
        final titleMatches = v.videoName.toLowerCase().contains(query);
        final authorMatches = v.uploader.name.toLowerCase().contains(query);
        return titleMatches || authorMatches;
      }).toList();
    }

    if (_sortOption == 'Date added (oldest)') {
      list.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    } else if (_sortOption == 'Most popular') {
      list.sort((a, b) => b.views.compareTo(a.views));
    } else {
      // Default: newest first
      list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    }

    return list;
  }

  void _playVideo(VideoModel video) {
    final sharedPool = SharedVideoControllerPool();
    sharedPool.pauseAllControllers();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VayuLongFormPlayerScreen(
          video: video,
          relatedVideos: _videos,
        ),
      ),
    );
  }

  void _playAll() {
    final list = _displayVideos;
    if (list.isEmpty) return;
    _playVideo(list.first);
  }

  void _shufflePlay() {
    final list = List<VideoModel>.from(_displayVideos);
    if (list.isEmpty) return;
    list.shuffle();
    _playVideo(list.first);
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _displayVideos;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          // YouTube-style Header Area (Image 3)
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C241F), // Rich warm dark brown header like YouTube
                    Color(0xFF1B1917),
                    AppColors.backgroundPrimary,
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Back button, Title, Search, More
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: 'Search saved videos...',
                                      hintStyle: const TextStyle(
                                          color: AppColors.textSecondary),
                                      border: InputBorder.none,
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: AppColors.textSecondary,
                                                  size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _searchQuery = '');
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Saved Videos',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Private • ${_videos.length} ${_videos.length == 1 ? "video" : "videos"}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
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
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.textPrimary),
                            color: AppColors.surfaceElevated,
                            onSelected: (val) {
                              if (val == 'refresh') {
                                _loadSavedVideos();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh,
                                        color: AppColors.textPrimary, size: 18),
                                    SizedBox(width: 8),
                                    Text('Refresh',
                                        style: TextStyle(
                                            color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons Row: [ ▶ Play all ]  ( + )  ( 🔀 )
                      if (_videos.isNotEmpty) ...[
                        Row(
                          children: [
                            // Pill Play All Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _playAll,
                                icon: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.black, size: 24),
                                label: const Text(
                                  'Play all',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Shuffle Circle Button
                            InkWell(
                              onTap: _shufflePlay,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shuffle_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Sort / Filter Row
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              initialValue: _sortOption,
                              color: AppColors.surfaceElevated,
                              onSelected: (val) {
                                setState(() {
                                  _sortOption = val;
                                });
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'Date added (newest)',
                                  child: Text('Date added (newest)',
                                      style: TextStyle(color: AppColors.textPrimary)),
                                ),
                                const PopupMenuItem(
                                  value: 'Date added (oldest)',
                                  child: Text('Date added (oldest)',
                                      style: TextStyle(color: AppColors.textPrimary)),
                                ),
                                const PopupMenuItem(
                                  value: 'Most popular',
                                  child: Text('Most popular',
                                      style: TextStyle(color: AppColors.textPrimary)),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _sortOption,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondary, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body Content
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load saved videos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadSavedVideos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_videos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
                        Icons.video_library_outlined,
                        size: 40,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No saved videos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Long-form (Vayu) videos you save will appear here.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (displayList.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No videos match "$_searchQuery"',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = displayList[index];
                  return _buildVideoRow(video);
                },
                childCount: displayList.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoRow(VideoModel video) {
    return InkWell(
      onTap: () => _playVideo(video),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left 2 drag bars like YouTube (Image 3)
            Container(
              padding: const EdgeInsets.only(top: 24, right: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Video Thumbnail (16:9)
            SizedBox(
              width: 124,
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.surfacePrimary,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: AppColors.textTertiary,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.surfacePrimary,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: AppColors.textTertiary,
                                size: 28,
                              ),
                            ),
                    ),

                    // Duration Badge (bottom-right)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          FormatUtils.formatDuration(video.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Video Details: Title, Creator, Views & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.videoName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.uploader.name.isNotEmpty
                        ? video.uploader.name
                        : 'Creator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '▷ ${FormatUtils.formatViews(video.views)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        FormatUtils.formatTimeAgo(video.uploadedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3-dots Menu Button
            Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                color: AppColors.surfaceElevated,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 150),
                onSelected: (value) {
                  if (value == 'remove') {
                    _removeSavedVideo(video);
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
          ],
        ),
      ),
    );
  }
}
