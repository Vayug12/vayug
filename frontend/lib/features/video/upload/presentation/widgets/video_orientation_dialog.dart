import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';

enum VideoOrientationChoice {
  landscape,
  vertical,
}

/// **VideoOrientationDialog**
///
/// Prompts the creator to choose between Yug (vertical) and Vayu (landscape).
/// Features a minimal horizontal icon layout with "Yug" and "Vayu" labels.
class VideoOrientationDialog extends StatelessWidget {
  final double detectedAspectRatio;

  const VideoOrientationDialog({
    super.key,
    required this.detectedAspectRatio,
  });

  static Future<VideoOrientationChoice?> show(
    BuildContext context, {
    required double detectedAspectRatio,
  }) {
    return showDialog<VideoOrientationChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) => VideoOrientationDialog(
        detectedAspectRatio: detectedAspectRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDetectedLandscape = detectedAspectRatio >= 1.0;

    return Dialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _buildOption(
                context: context,
                choice: VideoOrientationChoice.vertical,
                icon: Icons.stay_current_portrait_rounded,
                label: 'Yug',
                isDetected: !isDetectedLandscape,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildOption(
                context: context,
                choice: VideoOrientationChoice.landscape,
                icon: Icons.stay_current_landscape_rounded,
                label: 'Vayu',
                isDetected: isDetectedLandscape,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required VideoOrientationChoice choice,
    required IconData icon,
    required String label,
    required bool isDetected,
  }) {
    return Material(
      color: isDetected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(choice),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDetected
                  ? AppColors.primary
                  : AppColors.borderSecondary.withValues(alpha: 0.6),
              width: isDetected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isDetected ? AppColors.primary : AppColors.textSecondary,
                size: 38,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: isDetected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
