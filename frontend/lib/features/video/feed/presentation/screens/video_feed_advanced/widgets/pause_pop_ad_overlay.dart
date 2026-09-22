import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/features/ads/presentation/widgets/compact_ad_close_button.dart';

/// Modular widget for the pause pop-up ad in the video feed.
/// Renders a circular ad thumbnail with smooth entrance animation
/// and a compact, minimal close ('X') button.
class PausePopAdOverlay extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final double left;
  final double size;

  const PausePopAdOverlay({
    Key? key,
    required this.imageUrl,
    required this.onTap,
    required this.onDismiss,
    this.left = 40.0,
    this.size = 70.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.backgroundPrimary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          memCacheWidth: (size * 2).toInt(),
                          maxWidthDiskCache: (size * 2).toInt(),
                          errorWidget: (context, url, error) {
                            return Container(
                              color: AppColors.borderPrimary,
                              child: const Icon(
                                Icons.ad_units,
                                color: AppColors.white,
                                size: 28,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Compact close button positioned neatly at top-right
                  Positioned(
                    top: -6,
                    right: -6,
                    child: CompactAdCloseButton(
                      size: 20,
                      iconSize: 12,
                      backgroundColor: AppColors.surfacePrimary.withValues(alpha: 0.9),
                      borderColor: AppColors.white.withValues(alpha: 0.6),
                      iconColor: AppColors.white,
                      tooltip: 'Hide ad for this video',
                      onTap: onDismiss,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
