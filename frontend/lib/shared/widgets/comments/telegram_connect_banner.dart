import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/providers/telegram_providers.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/vayu_snackbar.dart';

Future<void> connectCommentAlerts(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();
  final launched = await ref.read(creatorTelegramProvider.notifier).connect();
  if (!launched && context.mounted) {
    VayuSnackBar.showError(
        context,
        AppText.get('telegram_connect_error',
            fallback: 'Could not open Telegram. Please try again.'));
  }
}

class TelegramConnectBanner extends ConsumerStatefulWidget {
  const TelegramConnectBanner({super.key});

  @override
  ConsumerState<TelegramConnectBanner> createState() =>
      _TelegramConnectBannerState();
}

class _TelegramConnectBannerState extends ConsumerState<TelegramConnectBanner> {
  @override
  void initState() {
    super.initState();
    // Revalidate when a creator opens another sheet, as well as on app resume.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(creatorTelegramProvider.notifier).checkStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorTelegramProvider);
    if (!state.showBanner) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.fromLTRB(AppSpacing.spacing5, AppSpacing.spacing2,
          AppSpacing.spacing5, AppSpacing.spacing3),
      padding: EdgeInsets.all(AppSpacing.spacing3),
      decoration: ShapeDecoration(
        color: AppColors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderRadiusSquircle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: AppColors.primaryLight, size: 18),
              ),
              SizedBox(width: AppSpacing.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        AppText.get('telegram_alerts',
                            fallback: 'Telegram alerts'),
                        style: AppTypography.labelLarge),
                    SizedBox(height: AppSpacing.spacing1),
                    Text(
                        AppText.get('telegram_alerts_hint',
                            fallback: 'Get notified when someone comments.'),
                        style: AppTypography.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppText.get('telegram_dismiss',
                    fallback: 'Dismiss Telegram suggestion'),
                constraints:
                    const BoxConstraints.tightFor(width: 44, height: 44),
                padding: EdgeInsets.zero,
                onPressed: () =>
                    ref.read(creatorTelegramProvider.notifier).dismissBanner(),
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.spacing2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: state.isConnecting
                  ? null
                  : () => connectCommentAlerts(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.spacing3),
                textStyle: AppTypography.labelLarge,
              ),
              child: state.isConnecting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(AppText.get('telegram_connect', fallback: 'Connect')),
            ),
          ),
        ],
      ),
    );
  }
}
