import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:flutter/material.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/core/presentation/screens/deep_link_video_resolver_screen.dart';
import 'package:vayug/shared/services/deep_link_playback_gate.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// Registered by MainScreen to navigate seamlessly to Yug or Vayu tab
  Future<void> Function(
    VideoModel video, {
    Duration? initialPosition,
    Duration? sectionEnd,
  })? onVideoResolved;

  Future<void> handleResolvedVideo(
    VideoModel video, {
    Duration? initialPosition,
    Duration? sectionEnd,
  }) async {
    if (onVideoResolved != null) {
      await onVideoResolved!(
        video,
        initialPosition: initialPosition,
        sectionEnd: sectionEnd,
      );
    } else {
      AppLogger.log(
        '⚠️ DeepLinkService: onVideoResolved callback not registered',
      );
    }
  }

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  /// Video deep links must not navigate before MainScreen is mounted:
  /// SplashScreen's pushReplacement would destroy any route pushed on top of
  /// it, and on cold start the navigator context may not even exist yet.
  bool _appReady = false;
  Uri? _pendingVideoUri;

  /// Saved params from cold start or incoming deep links
  int? pendingStartAtSeconds;
  int? pendingEndAtSeconds;
  VideoModel? coldStartPreloadedVideo;

  /// Guards against the same link being delivered twice (getInitialLink and
  /// uriLinkStream can both emit the launch link on some platforms).
  Uri? _lastHandledVideoUri;
  DateTime? _lastHandledVideoAt;

  void initialize() {
    _appLinks = AppLinks();
    _checkInitialLink();
    _listenToLinks();
  }

  /// Exposes initial URI for Splash/InitManager during startup
  Future<Uri?> getInitialUri() async {
    try {
      _appLinks = AppLinks();
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        pendingStartAtSeconds = parseTimestampSeconds(uri.queryParameters['t']);
        pendingEndAtSeconds = parseTimestampSeconds(uri.queryParameters['end']);
      }
      return uri;
    } catch (e) {
      AppLogger.log('❌ DeepLinkService: Error getting initial link: $e');
      return null;
    }
  }

  /// Robust helper to extract video ID from URI (reused across app)
  String? extractVideoId(Uri uri) {
    final path = uri.path.toLowerCase();
    final isHttpsVideoLink = path.startsWith('/video/');
    final isCustomSchemeVideoLink = uri.scheme == 'snehayog' &&
        uri.host == 'video' &&
        uri.pathSegments.isNotEmpty;
    if (isHttpsVideoLink || isCustomSchemeVideoLink) {
      final videoId = isCustomSchemeVideoLink
          ? uri.pathSegments.first
          : uri.pathSegments.length >= 2
              ? uri.pathSegments[1]
              : '';
      if (videoId.isNotEmpty) return videoId;
    }
    return null;
  }

  /// Called by MainScreen once the home UI is mounted. Flushes any deep link
  /// that arrived during cold start.
  void markAppReady() {
    if (_appReady) {
      return;
    }
    _appReady = true;
    final pending = _pendingVideoUri;
    _pendingVideoUri = null;
    if (pending != null) {
      AppLogger.log('🔗 DeepLinkService: App ready, processing pending link: $pending');
      _handleUri(pending);
    }
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      AppLogger.log('❌ DeepLinkService: Error getting initial link: $e');
    }
  }

  void _listenToLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (err) {
      AppLogger.log('❌ DeepLinkService: Stream error: $err');
    });
  }

  void _handleUri(Uri uri) {
    AppLogger.log('🔗 DeepLinkService: Handling URI: $uri');
    
    // **FIX: Ignore legal links to prevent circular interception when launching externally**
    final path = uri.path.toLowerCase();
    if (path.contains('/privacy.html') || 
        path.contains('/terms.html') || 
        path.contains('/refund.html') || 
        path.contains('/contact.html') || 
        path.contains('/about.html')) {
      AppLogger.log('🔗 DeepLinkService: Ignoring legal link (should open in browser)');
      return;
    }

    // Check for social success (vayu://auth/social-success?platform=youtube)
    if (path.contains('social-success')) {
      final platform = uri.queryParameters['platform'];
      AppLogger.log('🔗 DeepLinkService: Social connection success for $platform');
      return;
    }

    final videoId = extractVideoId(uri);
    if (videoId != null && videoId.isNotEmpty) {
      final startAt = parseTimestampSeconds(uri.queryParameters['t']);
      final sectionEnd = parseTimestampSeconds(uri.queryParameters['end']);
      pendingStartAtSeconds = startAt;
      pendingEndAtSeconds = sectionEnd;

      if (!_appReady || AuthService.navigatorKey.currentContext == null) {
        // Gate playback even during a cold start, before the home Yug feed
        // gets a chance to initialize.
        DeepLinkPlaybackGate.beginResolution();
        AppLogger.log('🔗 DeepLinkService: App not ready, queueing link: $uri');
        _pendingVideoUri = uri;
        return;
      }

      final now = DateTime.now();
      if (uri == _lastHandledVideoUri &&
          _lastHandledVideoAt != null &&
          now.difference(_lastHandledVideoAt!) < const Duration(seconds: 5)) {
        AppLogger.log('🔗 DeepLinkService: Ignoring duplicate link delivery: $uri');
        return;
      }
      _lastHandledVideoUri = uri;
      _lastHandledVideoAt = now;

      // If coldStartPreloadedVideo is already present and matches, direct handoff without extra resolver modal
      if (coldStartPreloadedVideo != null && coldStartPreloadedVideo!.id == videoId) {
        AppLogger.log('🔗 DeepLinkService: Handing off cold start preloaded video: $videoId');
        final video = coldStartPreloadedVideo!;
        coldStartPreloadedVideo = null;
        handleResolvedVideo(
          video,
          initialPosition: startAt == null ? null : Duration(seconds: startAt),
          sectionEnd: sectionEnd != null && (startAt == null || sectionEnd > startAt)
              ? Duration(seconds: sectionEnd)
              : null,
        );
        DeepLinkPlaybackGate.release();
        return;
      }

      AppLogger.log('🔗 DeepLinkService: Handling deep link for video: $videoId');

      // Smart Routing: Fetch metadata first to decide between Yug and Vayu.
      _routeToVideoSmartly(
        videoId,
        initialPosition: startAt == null ? null : Duration(seconds: startAt),
        sectionEnd: sectionEnd != null && (startAt == null || sectionEnd > startAt)
            ? Duration(seconds: sectionEnd)
            : null,
      );
      return;
    }

    // Check for referral code (?ref=CODE)
    if (uri.queryParameters.containsKey('ref') || uri.path.contains('ref=')) {
      String? refCode = uri.queryParameters['ref'];
      
      // Fallback for weird URL formats
      if (refCode == null || refCode.isEmpty) {
        final pathStr = uri.path;
        if (pathStr.contains('ref=')) {
          final parts = pathStr.split('ref=');
          if (parts.length > 1) {
            final afterRef = parts.last;
            final subParts = afterRef.split('&');
            if (subParts.isNotEmpty) {
              refCode = subParts.first;
            }
          }
        }
      }

      if (refCode != null && refCode.isNotEmpty) {
        _saveReferralCode(refCode);
      }
    }
  }

  int? parseTimestampSeconds(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds != null && seconds >= 0 ? seconds : null;
  }

  void _routeToVideoSmartly(
    String videoId, {
    Duration? initialPosition,
    Duration? sectionEnd,
  }) {
    final context = AuthService.navigatorKey.currentContext;
    if (context == null) return;

    final requestId = DeepLinkPlaybackGate.beginResolution();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/shared_video_resolver'),
        builder: (_) => DeepLinkVideoResolverScreen(
          videoId: videoId,
          requestId: requestId,
          initialPosition: initialPosition,
          sectionEnd: sectionEnd,
        ),
      ),
    );
  }

  Future<void> _saveReferralCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only save if not already signed in (don't overwrite or track for existing users here)
      // Actually, saved referral code is tracked during sign-up in AuthService.
      await prefs.setString('pending_referral_code', code);
      AppLogger.log('🎁 DeepLinkService: Saved referral code: $code');
    } catch (e) {
      AppLogger.log('❌ DeepLinkService: Error saving referral code: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
