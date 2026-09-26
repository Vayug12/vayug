import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vayug/features/video/core/data/services/video_service.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/features/profile/core/presentation/screens/saved_shorts_screen.dart';
import 'package:vayug/features/profile/core/presentation/screens/saved_long_videos_screen.dart';
import 'package:vayug/features/video/core/presentation/screens/video_screen.dart';
import 'package:vayug/features/video/vayu/presentation/screens/vayu_long_form_player_screen.dart';
import 'package:vayug/features/video/core/presentation/managers/shared_video_controller_pool.dart';
import 'package:vayug/shared/utils/format_utils.dart';

class SavedVideosScreen extends StatefulWidget {
  const SavedVideosScreen({super.key});

  @override
  State<SavedVideosScreen> createState() => _SavedVideosScreenState();
}

class _SavedVideosScreenState extends State<SavedVideosScreen> {
  final VideoService _videoService = VideoService();
  List<VideoModel> _savedVideos = [];
  bool _isLoading = true;
  String? _error;

  // Filter Chip: 0: All, 1: Shorts (Yug), 2: Videos (Vayu)
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedVideos();
  }

  Future<void> _loadSavedVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await _videoService.getSavedVideos();
      if (mounted) {
        setState(() {
          _savedVideos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ SavedVideosScreen: Error loading videos: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<VideoModel> get _yugVideos => _savedVideos
      .where((v) => v.videoType.toLowerCase() != 'vayu')
      .toList();

  List<VideoModel> get _vayuVideos => _savedVideos
      .where((v) => v.videoType.toLowerCase() == 'vayu')
      .toList();

  void _navigateToShortsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedShortsScreen(
          initialVideos: _yugVideos,
          onVideosUpdated: _loadSavedVideos,
        ),
      ),
    ).then((_) => _loadSavedVideos());
  }

  void _navigateToLongVideosScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedLongVideosScreen(
          initialVideos: _vayuVideos,
          onVideosUpdated: _loadSavedVideos,
        ),
      ),
    ).then((_) => _loadSavedVideos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSavedVideos,
          color: AppColors.primary,
          backgroundColor: AppColors.surfacePrimary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top AppBar (Image 1 style)
              SliverAppBar(
                title: const Text(
                  'Saved Videos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                backgroundColor: AppColors.backgroundPrimary,
                floating: true,
                snap: true,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                    onPressed: _loadSavedVideos,
                  ),
                ],
              ),

              // Filter Chips Row (Recent/All, Shorts, Long Videos)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 0),
                      const SizedBox(width: 8),
                      _buildFilterChip('Shorts (Yug)', 1),
                      const SizedBox(width: 8),
                      _buildFilterChip('Videos (Vayu)', 2),
                    ],
                  ),
                ),
              ),

              // Loading / Error / Content
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
                        AppButton(
                          onPressed: _loadSavedVideos,
                          label: 'Retry',
                          variant: AppButtonVariant.primary,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_savedVideos.isEmpty)
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
                            Icons.bookmark_outline_rounded,
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
                          'Videos and shorts you bookmark will appear here.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._buildCollectionSections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCollectionSections() {
    final showShorts = _selectedFilterIndex == 0 || _selectedFilterIndex == 1;
    final showVayu = _selectedFilterIndex == 0 || _selectedFilterIndex == 2;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              // 1. Saved Shorts (Yug) Collection Tile (Image 1)
              if (showShorts)
                _buildCollectionItem(
                  title: 'Saved Shorts',
                  subtitle: '${_yugVideos.length} ${_yugVideos.length == 1 ? "video" : "videos"} • Private',
                  stackedThumbnail: _buildShortsStackedThumbnail(),
                  onTap: _navigateToShortsScreen,
                ),

              if (showShorts && showVayu)
                const SizedBox(height: 16),

              // 2. Saved Long Videos (Vayu) Collection Tile (Image 1)
              if (showVayu)
                _buildCollectionItem(
                  title: 'Saved Videos',
                  subtitle: '${_vayuVideos.length} ${_vayuVideos.length == 1 ? "video" : "videos"} • Private',
                  stackedThumbnail: _buildVayuStackedThumbnail(),
                  onTap: _navigateToLongVideosScreen,
                ),
            ],
          ),
        ),
      ),

      // Recent Saved Videos preview header and list (when "All" is active)
      if (_selectedFilterIndex == 0 && _savedVideos.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              'Recently Saved',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = _savedVideos[index];
              return _buildRecentVideoTile(video);
            },
            childCount: _savedVideos.length > 5 ? 5 : _savedVideos.length,
          ),
        ),
      ],

      const SliverToBoxAdapter(
        child: SizedBox(height: 32),
      ),
    ];
  }

  /// Builds a YouTube-style playlist/collection row with stacked thumbnail
  Widget _buildCollectionItem({
    required String title,
    required String subtitle,
    required Widget stackedThumbnail,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Stacked Card Thumbnail
            stackedThumbnail,
            const SizedBox(width: 16),

            // Title & Subtitle Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing 3-dots Menu
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the stacked card thumbnail for Saved Shorts (Yug)
  Widget _buildShortsStackedThumbnail() {
    const stackLayerColor = Color(0xFF3B2F2A); // YouTube brown tint back layer

    return SizedBox(
      width: 134,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Back stacked layer (peeking out from top)
          Positioned(
            top: 0,
            child: Container(
              width: 118,
              height: 10,
              decoration: const BoxDecoration(
                color: stackLayerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
          ),

          // Main front card
          Positioned(
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 134,
                height: 72,
                color: const Color(0xFF261D19),
                child: _yugVideos.isNotEmpty
                    ? Row(
                        children: [
                          // Left 65%: vertical thumbnail preview(s)
                          Expanded(
                            flex: 65,
                            child: _yugVideos.length > 1
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _buildMiniThumb(_yugVideos[0].thumbnailUrl),
                                      ),
                                      const SizedBox(width: 1),
                                      Expanded(
                                        child: _buildMiniThumb(_yugVideos[1].thumbnailUrl),
                                      ),
                                    ],
                                  )
                                : _buildMiniThumb(_yugVideos[0].thumbnailUrl),
                          ),

                          // Right 35%: Dark container with Shorts (Yug) badge
                          Expanded(
                            flex: 35,
                            child: Container(
                              color: const Color(0xFF3A2B24),
                              child: const Center(
                                child: Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: AppColors.textTertiary,
                          size: 32,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the stacked card thumbnail for Saved Videos (Vayu)
  Widget _buildVayuStackedThumbnail() {
    const stackLayerColor = Color(0xFF382E2B); // YouTube brown tint back layer

    return SizedBox(
      width: 134,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Back stacked layer (peeking out from top)
          Positioned(
            top: 0,
            child: Container(
              width: 118,
              height: 10,
              decoration: const BoxDecoration(
                color: stackLayerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
          ),

          // Main front card
          Positioned(
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 134,
                height: 72,
                color: const Color(0xFF261D19),
                child: _vayuVideos.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildMiniThumb(_vayuVideos.first.thumbnailUrl),
                          // Subtle dark right panel with play icon like YouTube
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: 48,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: const Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          color: AppColors.textTertiary,
                          size: 32,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniThumb(String url) {
    if (url.isEmpty) {
      return Container(
        color: AppColors.surfacePrimary,
        child: const Icon(Icons.movie_outlined, color: AppColors.textTertiary, size: 20),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.surfacePrimary),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surfacePrimary,
        child: const Icon(Icons.movie_outlined, color: AppColors.textTertiary, size: 20),
      ),
    );
  }

  /// Compact tile for recently saved items
  Widget _buildRecentVideoTile(VideoModel video) {
    final isVayu = video.videoType.toLowerCase() == 'vayu';

    return InkWell(
      onTap: () {
        final sharedPool = SharedVideoControllerPool();
        sharedPool.pauseAllControllers();

        if (isVayu) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VayuLongFormPlayerScreen(
                video: video,
                relatedVideos: _vayuVideos,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoScreen(
                initialVideos: _yugVideos,
                initialVideoId: video.id,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            SizedBox(
              width: isVayu ? 104 : 64,
              height: 58,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMiniThumb(video.thumbnailUrl),
                    if (isVayu && video.duration.inSeconds > 0)
                      Positioned(
                        bottom: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            FormatUtils.formatDuration(video.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
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

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.videoName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${isVayu ? "Vayu" : "Yug"} • ${FormatUtils.formatViews(video.views)} views',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
