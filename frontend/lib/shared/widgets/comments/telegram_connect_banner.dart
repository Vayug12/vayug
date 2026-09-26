import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/providers/telegram_providers.dart';
import 'package:vayug/shared/widgets/interactive_scale_button.dart';

class TelegramConnectBanner extends ConsumerWidget {
  const TelegramConnectBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tgState = ref.watch(creatorTelegramProvider);

    // If already connected or dismissed, do not render
    if (tgState.isConnected || tgState.isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing4,
        vertical: AppSpacing.spacing2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.spacing3,
        vertical: AppSpacing.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF229ED9).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Color(0xFF229ED9),
              size: 16,
            ),
          ),
          SizedBox(width: AppSpacing.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Telegram Alerts',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Get instant comment notifications',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.spacing2),
          InteractiveScaleButton(
            onTap: tgState.isConnecting
                ? null
                : () async {
                    await ref.read(creatorTelegramProvider.notifier).connect();
                  },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.spacing3,
                vertical: AppSpacing.spacing1,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: tgState.isConnecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Connect',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(width: AppSpacing.spacing1),
          InteractiveScaleButton(
            onTap: () {
              ref.read(creatorTelegramProvider.notifier).dismissBanner();
            },
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.spacing1),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
