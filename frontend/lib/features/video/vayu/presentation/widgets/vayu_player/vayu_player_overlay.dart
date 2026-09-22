import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/features/video/vayu/presentation/widgets/vayu_player/vayu_player_layout.dart';
import 'package:vayug/shared/widgets/interactive_scale_button.dart';

class VayuPlayerOverlay extends StatelessWidget {
  final VideoPlayerController? controller;
  final ValueNotifier<bool> showControlsVN;
  final ValueNotifier<bool> isControlsLockedVN;
  final ValueNotifier<bool> isSeekingBufferingVN;
  final bool isPortrait;
  final bool isFullScreenManual;
  final VoidCallback onTogglePlay;
  final VoidCallback onMoreOptions;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback? onToggleFullScreen;

  const VayuPlayerOverlay({
    super.key,
    required this.controller,
    required this.showControlsVN,
    required this.isControlsLockedVN,
    required this.isSeekingBufferingVN,
    required this.isPortrait,
    required this.isFullScreenManual,
    required this.onTogglePlay,
    required this.onMoreOptions,
    required this.onNext,
    required this.onPrevious,
    this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) return const SizedBox.shrink();

    final isFullScreen = !isPortrait || isFullScreenManual;
    final utilityControlSize =
        VayuPlayerLayout.utilityControlSize(isPortrait: isPortrait);
    final utilityIconSize =
        VayuPlayerLayout.utilityIconSize(isPortrait: isPortrait);
    final primaryControlSize =
        VayuPlayerLayout.primaryControlSize(isPortrait: isPortrait);
    final primaryIconSize =
        VayuPlayerLayout.primaryIconSize(isPortrait: isPortrait);
    final playerInsets = VayuPlayerLayout.playerInsets(
      context,
      isFullScreen: isFullScreen,
    );
    // The top menu and bottom utilities share the same safe-area-aware rail.
    final double topOffset =
        isFullScreen ? playerInsets.top : AppSpacing.spacing2;
    return ValueListenableBuilder<bool>(
      valueListenable: showControlsVN,
      builder: (context, showControls, _) {
        return AnimatedOpacity(
          opacity: showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showControls,
            child: Stack(
              children: [
                // Top rail — Back button in landscape mode (^ up arrow)
                if (!isPortrait && onToggleFullScreen != null)
                  Positioned(
                    top: topOffset,
                    left: playerInsets.left,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isControlsLockedVN,
                      builder: (context, isLocked, _) {
                        if (isLocked) return const SizedBox.shrink();
                        return _circleButton(
                          onTap: onToggleFullScreen!,
                          size: utilityControlSize,
                          icon: Icons.keyboard_arrow_up_rounded,
                          iconSize: utilityIconSize + 2,
                        );
                      },
                    ),
                  ),

                // Top rail — single more-options control
                Positioned(
                  top: topOffset,
                  right: playerInsets.right,
                  child: _circleButton(
                    onTap: onMoreOptions,
                    size: utilityControlSize,
                    icon: Icons.more_vert_rounded,
                    iconSize: utilityIconSize,
                  ),
                ),

                // Center controls — symmetrical previous · play/pause · next.
                // Apple HIG discrete pills with subtle border and spring feedback.
                ValueListenableBuilder<bool>(
                  valueListenable: isControlsLockedVN,
                  builder: (context, isLocked, _) {
                    if (isLocked) return const SizedBox.shrink();
                    return Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPortrait) ...[
                            _circleButton(
                              onTap: onPrevious,
                              size: VayuPlayerLayout
                                  .landscapeTransportControlSize,
                              icon: Icons.skip_previous_rounded,
                              iconSize:
                                  VayuPlayerLayout.landscapeTransportIconSize,
                            ),
                            SizedBox(width: VayuPlayerLayout.transportGap),
                          ],
                          ValueListenableBuilder<bool>(
                            valueListenable: isSeekingBufferingVN,
                            builder: (context, isSeekingBuffering, _) {
                              return ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller!,
                                builder: (context, value, _) {
                                  final bool isBuffering = isSeekingBuffering ||
                                      value.isBuffering ||
                                      !value.isInitialized;

                                  // When buffering or seeking, VayuFeedItem renders the
                                  // center spinner directly without any background container
                                  // (YouTube style). Reserve this space so landscape
                                  // transport controls do not shift and play/pause is disabled.
                                  if (isBuffering) {
                                    return SizedBox.square(
                                      dimension: primaryControlSize,
                                    );
                                  }

                                  return InteractiveScaleButton(
                                    onTap: onTogglePlay,
                                    scaleDownFactor: 0.94,
                                    child: Container(
                                      width: primaryControlSize,
                                      height: primaryControlSize,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.42),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: VayuPlayerLayout.pillBorderColor,
                                          width: VayuPlayerLayout.pillBorderWidth,
                                        ),
                                      ),
                                      child: Transform.translate(
                                        offset: Offset(
                                          value.isPlaying ? 0 : 1.5,
                                          0,
                                        ),
                                        child: Icon(
                                          value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: primaryIconSize,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          if (!isPortrait) ...[
                            SizedBox(width: VayuPlayerLayout.transportGap),
                            _circleButton(
                              onTap: onNext,
                              size: VayuPlayerLayout
                                  .landscapeTransportControlSize,
                              icon: Icons.skip_next_rounded,
                              iconSize:
                                  VayuPlayerLayout.landscapeTransportIconSize,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _circleButton({
    required VoidCallback onTap,
    required double size,
    required IconData icon,
    required double iconSize,
  }) {
    return InteractiveScaleButton(
      onTap: onTap,
      scaleDownFactor: 0.94,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: VayuPlayerLayout.minTouchTarget,
          minHeight: VayuPlayerLayout.minTouchTarget,
        ),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: VayuPlayerLayout.pillBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: VayuPlayerLayout.pillBorderColor,
                width: VayuPlayerLayout.pillBorderWidth,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
