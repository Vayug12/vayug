import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

enum SearchTab { all, creators, videos, shorts }

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

  @override
  Future<UnifiedSearchResult> searchUnified(String query, {int limit = 20}) =>
      _impl.searchUnified(query, limit: limit);
}

// -----------------------------------------------------------------------------

class _SearchDiscoveryScreenState extends State<SearchDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final ISearchService _searchService = widget.searchService;

  String _query = '';
  bool _isSearching = false;
  bool _showResults = false;
  SearchTab _selectedTab = SearchTab.all;

  List<UserModel> _resultCreators = [];
  List<VideoModel> _creatorVideos = [];
  List<VideoModel> _otherVideos = [];
  List<String> _recentSearches = [];

  static const String _recentSearchesKey = 'vayu_recent_searches_v2';

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Motivation', 'icon': Icons.bolt_rounded},
    {'title': 'Startup', 'icon': Icons.lightbulb_outline_rounded},
    {'title': 'Finance', 'icon': Icons.account_balance_wallet_outlined},
    {'title': 'Technology', 'icon': Icons.devices_other_rounded},
    {'title': 'Education', 'icon': Icons.school_outlined},
    {'title': 'Lifestyle', 'icon': Icons.self_improvement_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      if (mounted) {
        setState(() => _recentSearches = list);
      }
    } catch (e) {
      AppLogger.log('⚠️ SearchDiscovery: Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    try {
      final updated = [
        query,
        ..._recentSearches.where((s) => s.toLowerCase() != query.toLowerCase()),
      ].take(10).toList();

      if (mounted) {
        setState(() => _recentSearches = updated);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, updated);
    } catch (e) {
      AppLogger.log('⚠️ SearchDiscovery: Error saving recent search: $e');
    }
  }

  Future<void> _removeRecentSearch(String item) async {
    try {
      final updated = _recentSearches.where((s) => s != item).toList();
      if (mounted) {
        setState(() => _recentSearches = updated);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, updated);
    } catch (e) {
      AppLogger.log('⚠️ SearchDiscovery: Error removing recent search: $e');
    }
  }

  Future<void> _clearAllRecentSearches() async {
    try {
      if (mounted) {
        setState(() => _recentSearches = []);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      AppLogger.log('⚠️ SearchDiscovery: Error clearing recent searches: $e');
    }
  }

  /// Updates local text state only — no live auto-suggestions on typing.
  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      if (value.trim().isEmpty) {
        _showResults = false;
        _resultCreators = [];
        _creatorVideos = [];
        _otherVideos = [];
      }
    });
  }

  /// Triggers unified search query only upon explicit user submission.
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
      _selectedTab = SearchTab.all;
    });

    _saveRecentSearch(q);

    try {
      final result = await _searchService.searchUnified(q);

      if (mounted) {
        setState(() {
          _resultCreators = result.creators;
          _creatorVideos = result.creatorVideos;
          _otherVideos = result.videos;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ SearchDiscovery: Error performing unified search: $e');
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
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: false,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _performSearch(),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search creators, videos...',
          hintStyle:
              AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          prefixIcon: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _performSearch(),
            child: const Icon(Icons.search_rounded,
                color: AppColors.textTertiary, size: 20),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_showResults) {
      return _buildDiscoveryView();
    }
    return _buildResultsView();
  }

  // ---------------------------------------------------------------------------
  // Pre-Search State (Recent Searches + Explore Topics)
  // ---------------------------------------------------------------------------

  Widget _buildDiscoveryView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Recent Searches (Whitespace separation, no dividers)
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT SEARCHES',
                style: AppTypography.labelSmall.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              GestureDetector(
                onTap: _clearAllRecentSearches,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Clear',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((item) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    onTap: () {
                      _searchController.text = item;
                      _performSearch(item);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded,
                              size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          Text(
                            item,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _removeRecentSearch(item),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded,
                                  size: 14, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],

        // 2. Curated Categories (Apple-style squircles)
        Text(
          'EXPLORE TOPICS',
          style: AppTypography.labelSmall.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
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
                _performSearch(cat['title']);
              },
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Results State (Filter Tabs + Intent-Aware Shelves)
  // ---------------------------------------------------------------------------

  Widget _buildResultsView() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final hasAnyResult = _resultCreators.isNotEmpty ||
        _creatorVideos.isNotEmpty ||
        _otherVideos.isNotEmpty;

    if (!hasAnyResult) {
      return _buildNoResults();
    }

    return Column(
      children: [
        // Filter Tabs Bar (No dividers — clean whitespace)
        _buildFilterTabs(),
        const SizedBox(height: 12),
        Expanded(
          child: _buildSelectedTabContent(),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'tab': SearchTab.all, 'label': 'All'},
      {'tab': SearchTab.creators, 'label': 'Creators'},
      {'tab': SearchTab.videos, 'label': 'Videos'},
      {'tab': SearchTab.shorts, 'label': 'Shorts'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((t) {
          final tab = t['tab'] as SearchTab;
          final label = t['label'] as String;
          final isSelected = _selectedTab == tab;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = tab);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case SearchTab.all:
        return _buildAllTab();
      case SearchTab.creators:
        return _buildCreatorsTab();
      case SearchTab.videos:
        return _buildVideosTab();
      case SearchTab.shorts:
        return _buildShortsTab();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 1: All
  // ---------------------------------------------------------------------------

  Widget _buildAllTab() {
    final allCombinedVideos = [..._creatorVideos, ..._otherVideos];

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 48),
      children: [
        // 1. Creator Profile Card (Top priority when creator matches)
        if (_resultCreators.isNotEmpty) ...[
          _buildCreatorCard(_resultCreators.first),
          const SizedBox(height: 24),
        ],

        // 2. Creator's Own Videos ("Uploads by [Creator]")
        if (_creatorVideos.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Uploads by ${_resultCreators.isNotEmpty ? _resultCreators.first.name : 'Creator'}',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildVideoList(_creatorVideos, allCombinedVideos),
          const SizedBox(height: 28),
        ],

        // 3. Other Relevant Matching Videos (From general topics / other creators)
        if (_otherVideos.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _resultCreators.isNotEmpty ? 'Related Videos' : 'Videos',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildVideoList(_otherVideos, allCombinedVideos),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Creators
  // ---------------------------------------------------------------------------

  Widget _buildCreatorsTab() {
    if (_resultCreators.isEmpty) {
      return _buildNoResults(customMessage: 'No creators found for "$_query"');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _resultCreators.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCreatorCard(_resultCreators[index]);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Videos (Long Form)
  // ---------------------------------------------------------------------------

  Widget _buildVideosTab() {
    final allVideos = [..._creatorVideos, ..._otherVideos];
    final vayuVideos = allVideos.where((v) => v.videoType == 'vayu').toList();

    if (vayuVideos.isEmpty) {
      return _buildNoResults(customMessage: 'No long videos found for "$_query"');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: vayuVideos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final video = vayuVideos[index];
        return VayuVideoCard(
          video: video,
          onTap: () => _navigateToVideo(video, allVideos),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Shorts (Short Form)
  // ---------------------------------------------------------------------------

  Widget _buildShortsTab() {
    final allVideos = [..._creatorVideos, ..._otherVideos];
    final shorts = allVideos.where((v) => v.videoType != 'vayu').toList();

    if (shorts.isEmpty) {
      return _buildNoResults(customMessage: 'No videos found for "$_query"');
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemCount: shorts.length,
      itemBuilder: (context, index) {
        final video = shorts[index];
        return _buildYouTubeShortCard(video, allVideos);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets: Video Lists & Cards (Strict Apple Squircle Design)
  // ---------------------------------------------------------------------------

  Widget _buildVideoList(List<VideoModel> videos, List<VideoModel> allVideos) {
    final vayu = videos.where((v) => v.videoType == 'vayu').toList();
    final yog = videos.where((v) => v.videoType != 'vayu').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vayu.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vayu.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final video = vayu[index];
              return VayuVideoCard(
                video: video,
                onTap: () => _navigateToVideo(video, allVideos),
              );
            },
          ),
          if (yog.isNotEmpty) const SizedBox(height: 20),
        ],
        if (yog.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemCount: yog.length,
              itemBuilder: (context, index) {
                final video = yog[index];
                return _buildYouTubeShortCard(video, allVideos);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreatorCard(UserModel user) {
    final hasProfession =
        user.professionLabel != null && user.professionLabel!.trim().isNotEmpty;
    final handle = hasProfession
        ? user.professionLabel!.trim()
        : '@${user.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surfacePrimary,
                  backgroundImage: user.profilePic.isNotEmpty
                      ? CachedNetworkImageProvider(user.profilePic)
                      : null,
                  child: user.profilePic.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 32, color: AppColors.textTertiary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        handle,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${FormatUtils.formatViews(user.followersCount)} followers • ${user.videos.length} videos',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      FollowButtonWidget(
                        uploaderId: user.id,
                        uploaderName: user.name,
                        height: 32,
                        activeBackgroundColor: Colors.white,
                        activeTextColor: Colors.black,
                        inactiveBackgroundColor: AppColors.primary,
                        inactiveTextColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeShortCard(VideoModel video, List<VideoModel> allVideos) {
    return GestureDetector(
      onTap: () => _navigateToVideo(video, allVideos),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.image),
        child: Container(
          color: AppColors.backgroundSecondary,
          child: Stack(
            fit: StackFit.expand,
            children: [
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
                height: 100,
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

              // Subscriber-only badge
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
                      borderRadius: BorderRadius.circular(AppRadius.button),
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

              // Title and views
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.videoName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${FormatUtils.formatViews(video.views)} views',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white70,
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
            video: video,
            relatedVideos: all,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoScreen(
            initialVideos: all,
            initialVideoId: video.id,
          ),
        ),
      );
    }
  }

  Widget _buildNoResults({String? customMessage}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              customMessage ?? 'No results found for "$_query"',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
