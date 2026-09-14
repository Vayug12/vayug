import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/paid/data/services/paid_video_service.dart';
import 'package:vayug/features/video/paid/presentation/widgets/paid_video_badge.dart';
import 'package:vayug/features/video/paid/presentation/widgets/paid_video_paywall_overlay.dart';

/// **PaidVideoPlayerGuard**
///
/// Wraps video player surfaces to enforce preview cutoff and paywall overlay
/// for monetized videos.
/// - Unlocked or free videos render normally.
/// - Creators bypass paywall on their own videos.
/// - When playback position hits preview cutoff (e.g. 20%), playback is paused
///   and [PaidVideoPaywallOverlay] is displayed.
class PaidVideoPlayerGuard extends StatefulWidget {
  final VideoModel video;
  final VideoPlayerController? controller;
  final bool isCreator;
  final Widget child;

  const PaidVideoPlayerGuard({
    super.key,
    required this.video,
    required this.controller,
    this.isCreator = false,
    required this.child,
  });

  @override
  State<PaidVideoPlayerGuard> createState() => _PaidVideoPlayerGuardState();
}

class _PaidVideoPlayerGuardState extends State<PaidVideoPlayerGuard> {
  bool _showPaywall = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAccess();
    widget.controller?.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(PaidVideoPlayerGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerTick);
      widget.controller?.addListener(_onControllerTick);
    }
    if (oldWidget.video.id != widget.video.id) {
      _showPaywall = false;
      _checkInitialAccess();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerTick);
    super.dispose();
  }

  void _checkInitialAccess() {
    if (!widget.video.isPaidVideo || widget.isCreator) {
      _isUnlocked = true;
      return;
    }

    if (PaidVideoService.instance.isLocallyUnlocked(widget.video.id)) {
      _isUnlocked = true;
      return;
    }

    PaidVideoService.instance.checkAccess(widget.video.id).then((unlocked) {
      if (mounted && unlocked) {
        setState(() {
          _isUnlocked = true;
          _showPaywall = false;
        });
      }
    });
  }

  void _onControllerTick() {
    if (!widget.video.isPaidVideo || widget.isCreator || _isUnlocked) return;
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final durationMs = controller.value.duration.inMilliseconds;
    final positionMs = controller.value.position.inMilliseconds;
    final previewPct = widget.video.paidAccess?.previewPercentage ?? 20.0;
    final cutoffMs = (durationMs * (previewPct / 100.0)).round();

    if (durationMs > 0 && positionMs >= cutoffMs) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
      if (!_showPaywall) {
        setState(() {
          _showPaywall = true;
        });
      }
    }
  }

  void _handleUnlocked() {
    PaidVideoService.instance.markLocallyUnlocked(widget.video.id);
    setState(() {
      _isUnlocked = true;
      _showPaywall = false;
    });
    widget.controller?.play();
  }

  void _handleReplayPreview() {
    setState(() {
      _showPaywall = false;
    });
    widget.controller?.seekTo(Duration.zero);
    widget.controller?.play();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.video.isPaidVideo) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,

        // Top Badge (hidden while paywall is active)
        if (!_showPaywall)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: PaidVideoBadge(
              video: widget.video,
            ),
          ),

        // Paywall Overlay
        if (_showPaywall)
          PaidVideoPaywallOverlay(
            video: widget.video,
            onUnlocked: _handleUnlocked,
            onReplayPreview: _handleReplayPreview,
          ),
      ],
    );
  }
}
