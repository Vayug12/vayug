import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/features/video/paid/data/services/paid_video_purchase_service.dart';
import 'package:vayug/shared/widgets/app_button.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

class PaidVideoPaywallOverlay extends StatefulWidget {
  final VideoModel video;
  final VoidCallback onUnlocked;
  final VoidCallback onReplayPreview;

  const PaidVideoPaywallOverlay({
    super.key,
    required this.video,
    required this.onUnlocked,
    required this.onReplayPreview,
  });

  @override
  State<PaidVideoPaywallOverlay> createState() => _PaidVideoPaywallOverlayState();
}

class _PaidVideoPaywallOverlayState extends State<PaidVideoPaywallOverlay> {
  bool _isPurchasing = false;

  Future<void> _handleUnlock() async {
    final paid = widget.video.paidAccess;
    if (paid == null) return;

    setState(() => _isPurchasing = true);

    try {
      final result = await PaidVideoPurchaseService.instance.purchaseVideo(
        videoId: widget.video.id,
        priceTierId: paid.priceTier ?? 'paid_video_tier_19',
      );

      if (!mounted) return;

      if (result.outcome == PaidVideoPurchaseOutcome.success) {
        VayuSnackBar.showSuccess(context, result.message);
        widget.onUnlocked();
      } else if (result.outcome == PaidVideoPurchaseOutcome.cancelled) {
        // User cancelled, no error snackbar needed
      } else {
        VayuSnackBar.showError(context, result.message);
      }
    } catch (e) {
      if (mounted) {
        VayuSnackBar.showError(context, 'Unlock failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.video.paidAccess;
    final priceLabel = '₹${(paid?.priceAmount ?? 19).toInt()}';

    return Positioned.fill(
      child: Container(
        color: AppColors.backgroundPrimary.withValues(alpha: 0.94),
        padding: AppSpacing.edgeInsetsAll24,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: AppSpacing.edgeInsetsAll24,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.borderPrimary,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppSpacing.vSpace16,
                  Text(
                    'Paid Video',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vSpace4,
                  Text(
                    'Watch full video for $priceLabel',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vSpace24,
                  AppButton(
                    onPressed: _isPurchasing ? null : _handleUnlock,
                    isLoading: _isPurchasing,
                    label: 'Unlock • $priceLabel',
                    variant: AppButtonVariant.primary,
                    isFullWidth: true,
                  ),
                  AppSpacing.vSpace8,
                  AppButton(
                    onPressed: _isPurchasing ? null : widget.onReplayPreview,
                    label: 'Watch Preview',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
