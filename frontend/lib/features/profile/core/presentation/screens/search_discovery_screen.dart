import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/interfaces/i_search_service.dart';
import 'package:vayug/features/auth/data/usermodel.dart';
import 'package:vayug/features/profile/search/data/models/search_suggestions.dart';
import 'package:vayug/features/profile/search/data/services/search_service_impl.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/profile/core/presentation/widgets/category_tile_widget.dart';
import 'package:vayug/features/profile/core/presentation/screens/profile_screen.dart';
import 'package:vayug/features/video/vayu/presentation/screens/vayu_long_form_player_screen.dart';
import 'package:vayug/features/video/core/presentation/screens/video_screen.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/utils/format_utils.dart';
import 'package:vayug/shared/widgets/follow_button_widget.dart';
import 'package:vayug/shared/widgets/vayu_video_card.dart';

class SearchDiscoveryScreen extends StatefulWidget {
  /// **INJECTION POINT — The "FFmpeg Codec Socket".**
  ///
  /// Pass any [ISearchService] implementation here.
  /// Defaults to [SearchServiceImpl] (HTTP backend) when not provided.
  final ISearchService searchService;

  const SearchDiscoveryScreen({
    Key? key,
    ISearchService? searchService,
  })  : searchService = searchService ?? const _DefaultSearchService(),
        super(key: key);

  @override
  State<SearchDiscoveryScreen> createState() => _SearchDiscoveryScreenState();
}

/// Private const sentinel so `const SearchDiscoveryScreen()` still compiles.
/// Delegates every call to [SearchServiceImpl] which is created lazily on first use.
class _DefaultSearchService implements ISearchService {
  const _DefaultSearchService();

  // Lazy singleton — one instance shared across all default usages.
  static final _impl = SearchServiceImpl();

  @override
  Future<List<VideoModel>> searchVideos(String query, {int limit = 20}) =>
      _impl.searchVideos(query, limit: limit);

  @override
  Future<List<UserModel>> searchCreators(String query, {int limit = 20}) =>
      _impl.searchCreators(query, limit: limit);

  @override
  Future<SearchSuggestions> getSuggestions(String query) =>
      _impl.getSuggestions(query);
}

// -----------------------------------------------------------------------------

class _SearchDiscoveryScreenState extends State<SearchDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Consumed via interface — no concrete class reference here.
  late final ISearchService _searchService = widget.searchService;

  String _query = '';
  bool _isSearching = false;

  bool _showResults = false;
  List<UserModel> _resultCreators = [];
  List<VideoModel> _resultVideos = [];

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Motivation', 'icon': Icons.bolt_rounded},
    {'title': 'Startup', 'icon': Icons.lightbulb_outline_rounded},
    {'title': 'Finance', 'icon': Icons.account_balance_wallet_outlined},
    {'title': 'Technology', 'icon': Icons.devices_other_rounded},
    {'title': 'Education', 'icon': Icons.school_outlined},
    {'title': 'Lifestyle', 'icon': Icons.self_improvement_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Only updates the local text state — NO network requests on typing!
  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      if (value.trim().isEmpty) {
        _showResults = false;
        _resultCreators = [];
        _resultVideos = [];
      }
    });
  }

  /// Triggers network search queries only when the user explicitly hits search.
  Future<void> _performSearch([String? targetQuery]) async {
    final q = (targetQuery ?? _searchController.text).trim();
    if (q.isEmpty) return;

    _searchFocusNode.unfocus();
    setState(() {
      _query = q;
      if (_searchController.text != q) {
        _searchController.text = q;
      }
      _isSearching = true;
      _showResults = true;
    });

    try {
      final creators = await _searchService.searchCreators(q);
      final videos = await _searchService.searchVideos(q);

      if (mounted) {
        setState(() {
          _resultCreators = creators;
          _resultVideos = videos;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ SearchDiscovery: Error performing search: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.backgroundPrimary,
            floating: true,
            snap: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: _buildSearchBar(),
            titleSpacing: 16,
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: false,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _performSearch(),
        style: AppTypography.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search for content, creators...',
          hintStyle:
              AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          prefixIcon: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _performSearch(),
            child: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
          ),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textTertiary, size: 20),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_showResults) {
      if (_query.trim().isNotEmpty) {
        // Shown while typing without triggering network search
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.textTertiary),
              title: Text(
                _query.trim(),
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              ),
              trailing: const Icon(Icons.north_west, color: AppColors.textTertiary, size: 18),
              onTap: () => _performSearch(),
            ),
          ],
        );
      }
      return _buildDiscoveryView();
    }
    return _buildResultsView();
  }

  Widget _buildDiscoveryView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return CategoryTileWidget(
              title: cat['title'],
              icon: cat['icon'],
              onTap: () {
                _searchController.text = cat['title'];
                _onSearchChanged(cat['title']);
                _performSearch(cat['title']);
              },
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_resultCreators.isEmpty && _resultVideos.isEmpty) {
      return _buildNoResults();
    }

    final vayu = _resultVideos.where((v) => v.videoType == 'vayu').toList();
    final yog = _resultVideos.where((v) => v.videoType != 'vayu').toList();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 48),
      children: [
        // 1. YouTube-style Account / Channel Card
        if (_resultCreators.isNotEmpty) ...[
          ..._resultCreators.take(3).map((u) => _buildYouTubeChannelCard(u)),
          if (_resultCreators.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () {
                  // Future: Show all creators screen
                },
                child: const Text('Show more creators'),
              ),
            ),
          const Divider(
            color: Color(0x1FFFFFFF),
            height: 24,
            thickness: 0.8,
            indent: 16,
            endIndent: 16,
          ),
        ],

        // 2. YouTube-style Long Form Videos (stacked vertically like YouTube)
        if (vayu.isNotEmpty) ...[
          _buildYouTubeLongVideosSection(vayu, _resultVideos),
          if (yog.isNotEmpty)
            const Divider(
              color: Color(0x1FFFFFFF),
              height: 32,
              thickness: 0.8,
              indent: 16,
              endIndent: 16,
            ),
        ],

        // 3. YouTube-style Shorts Grid (with title, views, and 2-column layout)
        if (yog.isNotEmpty) ...[
          _buildYouTubeShortsSection(yog, _resultVideos),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // YouTube-Style Account & Video Cards
  // ---------------------------------------------------------------------------

  Widget _buildYouTubeChannelCard(UserModel user) {
    final hasProfession =
        user.professionLabel != null && user.professionLabel!.trim().isNotEmpty;
    final handle = hasProfession
        ? user.professionLabel!.trim()
        : '@${user.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Channel Avatar (YouTube radius 36)
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.backgroundSecondary,
              backgroundImage: user.profilePic.isNotEmpty
                  ? CachedNetworkImageProvider(user.profilePic)
                  : null,
              child: user.profilePic.isEmpty
                  ? const Icon(Icons.person, size: 36, color: AppColors.textTertiary)
                  : null,
            ),
            const SizedBox(width: 16),
            // Channel Details & Subscribe Button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    handle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${FormatUtils.formatViews(user.followersCount)} subscribers • ${user.videos.length} videos',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      user.bio!.trim(),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  FollowButtonWidget(
                    uploaderId: user.id,
                    uploaderName: user.name,
                    height: 32,
                    activeBackgroundColor: Colors.white,
                    activeTextColor: Colors.black,
                    inactiveBackgroundColor: const Color(0xFF272727),
                    inactiveTextColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeLongVideosSection(
      List<VideoModel> vayuVideos, List<VideoModel> allVideos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Videos',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: vayuVideos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final video = vayuVideos[index];
            return VayuVideoCard(
              video: video,
              onTap: () => _navigateToVideo(video, allVideos),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYouTubeShortsSection(
      List<VideoModel> shorts, List<VideoModel> allVideos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Shorts',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shorts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.58, // 9:15.5 aspect ratio for vertical card
            ),
            itemBuilder: (context, index) {
              final video = shorts[index];
              return _buildYouTubeShortCard(video, allVideos);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYouTubeShortCard(VideoModel video, List<VideoModel> allVideos) {
    return GestureDetector(
      onTap: () => _navigateToVideo(video, allVideos),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: AppColors.backgroundSecondary,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              if (video.thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.videocam_outlined,
                        color: AppColors.textTertiary, size: 32),
                  ),
                )
              else
                const Center(
                  child: Icon(Icons.videocam_outlined,
                      color: AppColors.textTertiary, size: 32),
                ),

              // Bottom gradient overlay for legible text
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: Container(
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
                ),
              ),

              // Exclusive subscriber badge if applicable
              if (video.isSubscriberOnly)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 3),
                        Text(
                          'EXCLUSIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Title and views count
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.videoName.isNotEmpty ? video.videoName : 'Short Video',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FormatUtils.formatViews(video.views)} views',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToVideo(VideoModel video, List<VideoModel> all) {
    if (video.videoType == 'vayu') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VayuLongFormPlayerScreen(
                  video: video, relatedVideos: all)));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  VideoScreen(initialVideos: all, initialVideoId: video.id)));
    }
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64,
                color: AppColors.textTertiary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_query"',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
