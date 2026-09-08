import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/services/story_share_service.dart';
import 'package:vayug/shared/widgets/vayu_bottom_sheet.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';
import 'package:vayug/features/profile/core/presentation/widgets/referral_story_card.dart';

class ReferralShareBottomSheet extends StatefulWidget {
  final String creatorName;
  final String? profilePicUrl;
  final String? referralCode;
  final String playStoreUrl;
  final String shareMessage;
  final int invitedCount;

  const ReferralShareBottomSheet({
    super.key,
    required this.creatorName,
    this.profilePicUrl,
    this.referralCode,
    required this.playStoreUrl,
    required this.shareMessage,
    required this.invitedCount,
  });

  static Future<void> show({
    required BuildContext context,
    required String creatorName,
    String? profilePicUrl,
    String? referralCode,
    required String playStoreUrl,
    required String shareMessage,
    required int invitedCount,
  }) {
    return VayuBottomSheet.show(
      context: context,
      isScrollControlled: true,
      showHandle: true,
      showCloseButton: true,
      title: 'Share Creator Card',
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      child: ReferralShareBottomSheet(
        creatorName: creatorName,
        profilePicUrl: profilePicUrl,
        referralCode: referralCode,
        playStoreUrl: playStoreUrl,
        shareMessage: shareMessage,
        invitedCount: invitedCount,
      ),
    );
  }

  @override
  State<ReferralShareBottomSheet> createState() =>
      _ReferralShareBottomSheetState();
}

class _ReferralShareBottomSheetState extends State<ReferralShareBottomSheet> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isExporting = false;

  Future<File?> _captureCard() async {
    return await StoryShareService.captureCardToPng(_cardBoundaryKey);
  }

  Future<void> _shareToWhatsApp() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      HapticFeedback.lightImpact();
      final file = await _captureCard();
      await StoryShareService.shareToWhatsAppStatus(
        imageFile: file,
        message: widget.shareMessage,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } catch (e) {
      if (mounted) {
        VayuSnackBar.showError(context, 'Unable to share to WhatsApp');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareToInstagram() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      HapticFeedback.lightImpact();
      final file = await _captureCard();
      await StoryShareService.shareToInstagramStory(
        imageFile: file,
        message: widget.shareMessage,
        playStoreUrl: widget.playStoreUrl,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    } catch (e) {
      if (mounted) {
        VayuSnackBar.showError(context, 'Unable to share to Instagram');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareNative() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      HapticFeedback.lightImpact();
      final file = await _captureCard();
      await StoryShareService.shareGeneral(
        imageFile: file,
        message: widget.shareMessage,
      );
    } catch (e) {
      if (mounted) {
        VayuSnackBar.showError(context, 'Unable to open share menu');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _copyLinkAndCode() async {
    HapticFeedback.mediumImpact();
    final copyText =
        '${widget.shareMessage}\n\nInstall Link: ${widget.playStoreUrl}';
    await Clipboard.setData(ClipboardData(text: copyText));
    if (mounted) {
      VayuSnackBar.showSuccess(
        context,
        'Copied to clipboard',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Status Text (Show invite progress if not yet unlocked)
        if (widget.invitedCount < 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Share with 2 friends to unlock billing setup (${widget.invitedCount}/2)',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),

        // 2. Share Options (Positioned at TOP of sheet, Apple secondary style)
        if (_isExporting)
          const SizedBox(
            height: 96,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Generating card...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _buildShareButton(
                  icon: HugeIcons.strokeRoundedWhatsapp,
                  label: 'WhatsApp',
                  onTap: _shareToWhatsApp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShareButton(
                  icon: HugeIcons.strokeRoundedInstagram,
                  label: 'Instagram',
                  onTap: _shareToInstagram,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildShareButton(
                  icon: HugeIcons.strokeRoundedCopy01,
                  label: 'Copy link',
                  onTap: _copyLinkAndCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShareButton(
                  icon: HugeIcons.strokeRoundedShare01,
                  label: 'More',
                  onTap: _shareNative,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 18),

        // 3. Story Card Preview (Placed BELOW all share options with responsive sizing)
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final cardWidth = availableWidth.clamp(260.0, 310.0);
            final cardHeight = (cardWidth * 1.62).clamp(440.0, 490.0);

            return Center(
              child: RepaintBoundary(
                key: _cardBoundaryKey,
                child: ReferralStoryCard(
                  creatorName: widget.creatorName,
                  profilePicUrl: widget.profilePicUrl,
                  referralCode: widget.referralCode,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShareButton({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfacePrimary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: icon,
                color: AppColors.textPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
