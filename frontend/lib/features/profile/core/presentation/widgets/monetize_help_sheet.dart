import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/onboarding/presentation/widgets/onboarding_video_player.dart';
import 'package:vayug/features/profile/core/presentation/widgets/help_flow_diagram.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

enum HelpSection { faq, guide, video }

/// Monetize & Help Bottom Sheet with compact intrinsic sizing (no bottom void)
/// and direct Telegram support channel integration.
class MonetizeHelpSheet {
  MonetizeHelpSheet._();

  static const String telegramSupportUrl = 'https://t.me/+PxBFVf7oCLFhYjVl';

  static void show(BuildContext context, {bool showFaq = true}) {
    final section = ValueNotifier<HelpSection>(
      showFaq ? HelpSection.faq : HelpSection.guide,
    );

    VayuBottomSheet.show(
      context: context,
      useDraggable: false,
      showCloseButton: false,
      actions: [_HelpSectionToggle(section: section, showFaq: showFaq)],
      child: ValueListenableBuilder<HelpSection>(
        valueListenable: section,
        builder: (context, selected, _) {
          switch (selected) {
            case HelpSection.faq:
              return showFaq
                  ? _buildHelpFAQSection(context)
                  : _buildHelpGuideSection(context);
            case HelpSection.video:
              return _buildHelpVideoSection(context);
            case HelpSection.guide:
              return _buildHelpGuideSection(context);
          }
        },
      ),
    ).whenComplete(section.dispose);
  }

  static Future<void> _openTelegramSupport(BuildContext context) async {
    try {
      final uri = Uri.parse(telegramSupportUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        VayuSnackBar.showError(context, 'Could not open Telegram link.');
      }
    } catch (e) {
      if (context.mounted) {
        VayuSnackBar.showError(context, 'Could not open Telegram: $e');
      }
    }
  }

  static Widget _buildHelpGuideSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HelpFlow(
          title: 'Kamai ka formula',
          steps: [
            FlowStep(Icons.file_upload_outlined, '2 Videos\nUpload'),
            FlowStep(Icons.share_outlined, 'Ya 2 Friends\nKo Share'),
            FlowStep(Icons.lock_open_rounded, 'Billing\nUnlock'),
          ],
        ),
        const SizedBox(height: 24),
        const HelpFlow(
          title: 'Paisa kaise aayega',
          steps: [
            FlowStep(Icons.account_balance_wallet_outlined, 'UPI ID\nDalo'),
            FlowStep(Icons.calendar_month_outlined, '1st Ko\nRewards'),
            FlowStep(Icons.account_balance_outlined, 'Bank\nMein'),
          ],
          note: 'Har mahine automatic',
        ),
        const SizedBox(height: 24),
        AppButton(
          isFullWidth: true,
          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
          onPressed: () => _openTelegramSupport(context),
          label: 'Vayug Support',
          variant: AppButtonVariant.primary,
        ),
      ],
    );
  }

  static Widget _buildHelpVideoSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingVideoPlayer(
          videoUrl: 'https://cdn.snehayog.site/guide_video.mp4',
          autoPlay: true,
        ),
        const SizedBox(height: 24),
        AppButton(
          isFullWidth: true,
          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
          onPressed: () => _openTelegramSupport(context),
          label: 'Vayug Support',
          variant: AppButtonVariant.primary,
        ),
      ],
    );
  }

  static Widget _buildHelpFAQSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFAQItem(
          question: 'Can I watch videos in external players like VLC or MX Player?',
          answer:
              'Yes! While watching long-form videos on Vayug (Android), you can open and stream videos directly in external media players from the video player menu.',
          icon: Icons.open_in_new_rounded,
          color: AppColors.primary,
        ),
        buildFAQItem(
          question: 'What are Guaranteed Ad Impressions?',
          answer:
              'Unlike traditional platforms where ad reach is uncertain, Vayug provides guaranteed ad impressions for advertisers with transparent metrics and clear ROI. Creators earn an 80% revenue split.',
          icon: Icons.verified_outlined,
          color: Colors.teal,
        ),
        buildFAQItem(
          question: 'How do creators earn money on Vayug?',
          answer:
              'Share Vayug with 2 friends or upload 2 videos to unlock Setup Billing. Link your UPI ID in the Account tab to receive monthly payouts from eligible ad impressions.',
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.amber,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              try {
                final uri = Uri.parse('https://snehayog.site/faq.html');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: const Text('Read Full Web FAQs'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          isFullWidth: true,
          onPressed: () => Navigator.pop(context),
          label: 'Samajh Gaya',
          variant: AppButtonVariant.primary,
        ),
      ],
    );
  }

  static Widget buildFAQItem({
    required String question,
    required String answer,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              answer,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSectionToggle extends StatelessWidget {
  const _HelpSectionToggle({
    required this.section,
    this.showFaq = true,
  });

  final ValueNotifier<HelpSection> section;
  final bool showFaq;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HelpSection>(
      valueListenable: section,
      builder: (context, selected, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFaq)
              _buildSegment(
                value: HelpSection.faq,
                selected: selected,
                icon: Icons.help_outline_rounded,
                label: 'FAQ',
              ),
            _buildSegment(
              value: HelpSection.guide,
              selected: selected,
              icon: Icons.article_outlined,
              label: 'Guide',
            ),
            _buildSegment(
              value: HelpSection.video,
              selected: selected,
              icon: Icons.play_arrow_rounded,
              label: 'Video',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required HelpSection value,
    required HelpSection selected,
    required IconData icon,
    required String label,
  }) {
    final isSelected = value == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => section.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.white : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
