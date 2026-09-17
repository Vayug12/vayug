import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';

/// Bottom sheet widget allowing users to select or request dubbed audio tracks.
class FeedLanguageSelectorSheet extends StatelessWidget {
  final VideoModel video;
  final String selectedLanguage;
  final void Function(VideoModel video, String langCode) onSelectLanguage;
  final void Function(VideoModel video, String langCode) onStartDub;

  const FeedLanguageSelectorSheet({
    Key? key,
    required this.video,
    required this.selectedLanguage,
    required this.onSelectLanguage,
    required this.onStartDub,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required VideoModel video,
    required String selectedLanguage,
    required void Function(VideoModel video, String langCode) onSelectLanguage,
    required void Function(VideoModel video, String langCode) onStartDub,
  }) {
    return VayuBottomSheet.show<void>(
      context: context,
      title: 'Listen in',
      icon: Icons.volume_up_rounded,
      iconColor: AppColors.primary,
      child: FeedLanguageSelectorSheet(
        video: video,
        selectedLanguage: selectedLanguage,
        onSelectLanguage: onSelectLanguage,
        onStartDub: onStartDub,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasEnglishDub = video.dubbedUrls?.containsKey('english') ?? false;
    final hasHindiDub = video.dubbedUrls?.containsKey('hindi') ?? false;
    final String detectedSource =
        hasEnglishDub ? 'Hindi' : (hasHindiDub ? 'English' : 'Original');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose the audio language for this video.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTypography.fontSizeSM,
            height: 1.35,
          ),
        ),
        AppSpacing.vSpace16,
        _buildOption(
          context: context,
          title: '$detectedSource (Original)',
          langCode: 'default',
          badge: 'Original',
          icon: Icons.graphic_eq_rounded,
        ),
        AppSpacing.vSpace8,
        _buildOption(
          context: context,
          title: 'English',
          langCode: 'english',
          badge: hasEnglishDub ? 'Dubbed' : null,
          available: hasEnglishDub,
          icon: Icons.translate_rounded,
        ),
        AppSpacing.vSpace8,
        _buildOption(
          context: context,
          title: 'Hindi',
          langCode: 'hindi',
          badge: hasHindiDub ? 'Dubbed' : null,
          available: hasHindiDub,
          icon: Icons.translate_rounded,
        ),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String title,
    required String langCode,
    String? badge,
    bool available = true,
    IconData icon = Icons.volume_up_rounded,
  }) {
    final bool isSelected = selectedLanguage == langCode;
    final bool canStartDub = langCode != 'default' && !available;
    final String actionLabel = isSelected
        ? 'Playing now'
        : available
            ? 'Switch audio'
            : 'Dub audio';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (canStartDub) {
          onStartDub(video, langCode);
        } else {
          onSelectLanguage(video, langCode);
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.spacing4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.backgroundSecondary.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.white,
                size: 18,
              ),
            ),
            AppSpacing.hSpace12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: AppTypography.fontSizeBase,
                            fontWeight: isSelected
                                ? AppTypography.weightSemiBold
                                : AppTypography.weightMedium,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        AppSpacing.hSpace8,
                        _buildBadge(badge),
                      ],
                    ],
                  ),
                  AppSpacing.vSpace4,
                  Text(
                    actionLabel,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: AppTypography.fontSizeXS,
                      fontWeight: AppTypography.weightMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : canStartDub
                      ? Icons.auto_awesome_rounded
                      : Icons.chevron_right_rounded,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing2,
        vertical: AppSpacing.spacing1,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: AppTypography.fontSizeXS,
          fontWeight: AppTypography.weightSemiBold,
        ),
      ),
    );
  }
}
