import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/core/providers/telegram_providers.dart';
import 'package:vayug/shared/utils/app_text.dart';
import 'package:vayug/shared/widgets/comments/telegram_connect_banner.dart';

class CommentsSheetHeader extends ConsumerWidget {
  final int totalComments;
  final bool isVideoOwner;

  const CommentsSheetHeader({
    super.key,
    required this.totalComments,
    required this.isVideoOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telegram = isVideoOwner ? ref.watch(creatorTelegramProvider) : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.spacing5, AppSpacing.spacing3,
          AppSpacing.spacing5, AppSpacing.spacing2),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.45),
              borderRadius: AppRadius.borderRadiusPill,
            ),
          ),
          SizedBox(height: AppSpacing.spacing3),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.spacing2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(AppText.get('comments_title', fallback: 'Comments'),
                        style: AppTypography.headlineLarge
                            .copyWith(letterSpacing: -0.5)),
                    if (totalComments > 0)
                      Text('$totalComments',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Keep a way to connect after dismissing the suggestion.
              if (telegram != null &&
                  telegram.canOfferConnection &&
                  telegram.isDismissed)
                IconButton(
                  tooltip: AppText.get('telegram_connect',
                      fallback: 'Connect Telegram'),
                  onPressed: telegram.isConnecting
                      ? null
                      : () => connectCommentAlerts(context, ref),
                  icon: const Icon(Icons.send_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
              IconButton(
                tooltip: AppText.get('btn_close'),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfacePrimary,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
