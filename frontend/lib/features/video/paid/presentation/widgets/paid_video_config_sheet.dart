import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/features/video/paid/domain/models/paid_video_config.dart';
import 'package:vayug/features/video/paid/domain/utils/paid_video_tier_helper.dart';
import 'package:vayug/shared/widgets/app_button.dart';

class PaidVideoConfigSheet extends StatefulWidget {
  final PaidVideoConfig initialConfig;
  final double videoDurationInSeconds;
  final ValueChanged<PaidVideoConfig> onSave;

  const PaidVideoConfigSheet({
    super.key,
    required this.initialConfig,
    this.videoDurationInSeconds = 0.0,
    required this.onSave,
  });

  static Future<PaidVideoConfig?> show(
    BuildContext context, {
    required PaidVideoConfig initialConfig,
    double videoDurationInSeconds = 0.0,
  }) {
    return showModalBottomSheet<PaidVideoConfig>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusSheet,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PaidVideoConfigSheet(
          initialConfig: initialConfig,
          videoDurationInSeconds: videoDurationInSeconds,
          onSave: (config) => Navigator.pop(ctx, config),
        ),
      ),
    );
  }

  @override
  State<PaidVideoConfigSheet> createState() => _PaidVideoConfigSheetState();
}

class _PaidVideoConfigSheetState extends State<PaidVideoConfigSheet> {
  late int _previewPercentage;
  late PaidVideoTier _activeTier;

  @override
  void initState() {
    super.initState();
    _previewPercentage = widget.initialConfig.previewPercentage;
    final initialPrice = widget.initialConfig.creatorTargetPrice > 0
        ? widget.initialConfig.creatorTargetPrice
        : 19.0;
    _activeTier = PaidVideoTierHelper.snapToNearestTier(initialPrice);
  }

  void _save() {
    final config = PaidVideoConfig(
      isPaid: true,
      previewPercentage: _previewPercentage,
      priceTier: _activeTier.productId,
      priceAmount: _activeTier.price,
      creatorTargetPrice: _activeTier.price,
    );
    widget.onSave(config);
  }

  @override
  Widget build(BuildContext context) {
    final previewSeconds = widget.videoDurationInSeconds > 0
        ? ((widget.videoDurationInSeconds * (_previewPercentage / 100)).round())
        : 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space24,
          vertical: AppSpacing.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.vSpace16,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid Video',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  splashRadius: 22,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTargetApple,
                    minHeight: AppSpacing.minTouchTargetApple,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            AppSpacing.vSpace16,

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Price', style: AppTypography.labelLarge),
                    AppSpacing.vSpace8,
                    Row(
                      children: PaidVideoTierHelper.supportedTiers.map((tier) {
                        final isSelected = _activeTier.productId == tier.productId;
                        final tierBadge = tier.price == 199.0
                            ? 'Premium'
                            : (tier.price == 49.0 ? 'Standard' : 'Basic');

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _activeTier = tier;
                                });
                              },
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.space24,
                                  horizontal: AppSpacing.space8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.borderPrimary,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tier.label,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tierBadge,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textTertiary,
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    AppSpacing.vSpace12,

                    Container(
                      padding: AppSpacing.edgeInsetsAll12,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.borderPrimary),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          AppSpacing.hSpace8,
                          Expanded(
                            child: Text(
                              'Viewer pays ${_activeTier.label} · Your 80% share: ~₹${_activeTier.estimatedCreatorShare.toStringAsFixed(2)} / unlock',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vSpace24,

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Free Preview', style: AppTypography.labelLarge),
                        Text(
                          '$_previewPercentage% ${previewSeconds > 0 ? '($previewSeconds s)' : ''}',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vSpace8,
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.borderPrimary,
                        thumbColor: AppColors.primary,
                      ),
                      child: Slider(
                        value: _previewPercentage.toDouble(),
                        min: 10,
                        max: 50,
                        divisions: 8,
                        onChanged: (val) {
                          setState(() => _previewPercentage = val.round());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.vSpace16,

            AppButton(
              onPressed: _save,
              label: 'Save Settings',
              variant: AppButtonVariant.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
