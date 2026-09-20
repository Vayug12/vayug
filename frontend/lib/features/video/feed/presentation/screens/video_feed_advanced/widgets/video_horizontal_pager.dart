import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/features/profile/core/presentation/screens/profile_screen.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/utils/page_scroll_physics.dart';

/// Modular horizontal pager for a single video item in the Yug feed.
///
/// Layout:
/// - Swipe Right (finger left-to-right) -> Creator's Profile (TikTok style).
/// - Center -> Video Player.
/// - Swipe Left (finger right-to-left) -> Carousel Ad (if available).
///
/// Performance:
/// - Profile screen is loaded strictly ON-DEMAND when the user begins swiping,
///   keeping vertical feed scrolling at 60 FPS without background preloading.
class VideoHorizontalPager extends StatefulWidget {
  final VideoModel video;
  final Widget videoPage;
  final bool hasCarouselAd;
  final Widget? carouselAdPage;
  final bool isActive;
  final VoidCallback? onVideoVisible;
  final VoidCallback? onVideoHidden;
  final ValueChanged<bool>? onSubpageActiveChanged;

  const VideoHorizontalPager({
    super.key,
    required this.video,
    required this.videoPage,
    this.hasCarouselAd = false,
    this.carouselAdPage,
    required this.isActive,
    this.onVideoVisible,
    this.onVideoHidden,
    this.onSubpageActiveChanged,
  });

  @override
  State<VideoHorizontalPager> createState() => _VideoHorizontalPagerState();
}

class _VideoHorizontalPagerState extends State<VideoHorizontalPager> {
  late final PageController _pageController;
  late final String? _creatorId;
  late final bool _hasValidCreator;

  // Dynamic page layout
  late final int _adPageIndex;
  late final int _videoPageIndex;
  late final int _profilePageIndex;
  late final int _pageCount;

  int _currentPageIndex = 0;
  bool _hasStartedSwipingToProfile = false;

  @override
  void initState() {
    super.initState();
    _creatorId = _resolveCreatorId(widget.video);
    _hasValidCreator = _creatorId != null && _creatorId.isNotEmpty;

    // Calculate dynamic page layout
    // Order: [Profile (if available), Video, Carousel Ad (if available)]
    //
    // Case 1: Has Valid Creator + Has Carousel Ad -> [0: Profile, 1: Video, 2: Ad]
    // Case 2: Has Valid Creator only              -> [0: Profile, 1: Video]
    // Case 3: Has Carousel Ad only               -> [0: Video, 1: Ad]
    // Case 4: Neither                            -> [0: Video]
    if (_hasValidCreator) {
      _profilePageIndex = 0;
      _videoPageIndex = 1;
      _currentPageIndex = 1;
      if (widget.hasCarouselAd && widget.carouselAdPage != null) {
        _adPageIndex = 2;
        _pageCount = 3;
      } else {
        _adPageIndex = -1;
        _pageCount = 2;
      }
    } else {
      _profilePageIndex = -1;
      _videoPageIndex = 0;
      _currentPageIndex = 0;
      if (widget.hasCarouselAd && widget.carouselAdPage != null) {
        _adPageIndex = 1;
        _pageCount = 2;
      } else {
        _adPageIndex = -1;
        _pageCount = 1;
      }
    }

    _pageController = PageController(initialPage: _currentPageIndex);
    _pageController.addListener(_handleScrollProgress);
  }

  String? _resolveCreatorId(VideoModel video) {
    final candidateIds = <String>[
      if (video.uploader.googleId != null) video.uploader.googleId!.trim(),
      if (video.uploader.id.isNotEmpty) video.uploader.id.trim(),
    ]
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id.toLowerCase() != 'unknown')
        .toList();

    return candidateIds.isNotEmpty ? candidateIds.first : null;
  }

  void _handleScrollProgress() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _currentPageIndex.toDouble();

    // On-demand profile loading: as soon as the user starts swiping towards
    // the profile page, mount the ProfileScreen widget so it renders seamlessly.
    if (_profilePageIndex != -1 && !_hasStartedSwipingToProfile) {
      if (_profilePageIndex < _videoPageIndex) {
        if (page < _videoPageIndex - 0.01) {
          setState(() {
            _hasStartedSwipingToProfile = true;
          });
        }
      } else {
        if (page > _videoPageIndex + 0.01) {
          setState(() {
            _hasStartedSwipingToProfile = true;
          });
        }
      }
    }
  }

  void _animateToVideo() {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      _videoPageIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    _currentPageIndex = page;
    final bool isVideoPage = page == _videoPageIndex;

    // Notify parent to lock/unlock outer vertical feed
    widget.onSubpageActiveChanged?.call(!isVideoPage);

    if (isVideoPage) {
      if (widget.isActive) {
        widget.onVideoVisible?.call();
      }
    } else {
      // Swiped away to profile or ad -> pause video playback
      widget.onVideoHidden?.call();

      // Ensure profile is mounted if user arrived on profile page
      if (page == _profilePageIndex && !_hasStartedSwipingToProfile) {
        setState(() {
          _hasStartedSwipingToProfile = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleScrollProgress);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildProfilePage() {
    if (!_hasStartedSwipingToProfile || !_hasValidCreator) {
      return Container(
        color: AppColors.backgroundPrimary,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _animateToVideo();
        }
      },
      child: ProfileScreen(
        key: ValueKey('feed_profile_${widget.video.id}_$_creatorId'),
        userId: _creatorId,
        isEmbeddedInFeed: true,
        onBackPressed: _animateToVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount == 1) {
      // No horizontal swipe needed
      return widget.videoPage;
    }

    final List<Widget> pages = [];
    if (_profilePageIndex != -1) {
      pages.add(_buildProfilePage());
    }
    pages.add(widget.videoPage);
    if (_adPageIndex != -1) {
      pages.add(widget.carouselAdPage ?? const SizedBox.shrink());
    }

    return Container(
      key: ValueKey('h_pager_${widget.video.id}'),
      width: double.infinity,
      height: double.infinity,
      color: AppColors.backgroundPrimary,
      child: PopScope(
        canPop: _currentPageIndex == _videoPageIndex,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _animateToVideo();
          }
        },
        child: PageView(
          controller: _pageController,
          physics: const AppleHorizontalPageScrollPhysics(),
          scrollDirection: Axis.horizontal,
          onPageChanged: _onPageChanged,
          children: pages,
        ),
      ),
    );
  }
}
