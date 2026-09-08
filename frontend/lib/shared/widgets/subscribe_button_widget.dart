import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/utils/app_text.dart';

/// Canonical subscribe action used by every creator surface.
///
/// Relationship state stays with the caller; this widget owns the shared
/// visuals, labels, loading behavior, and tap affordance.
class SubscribeButtonWidget extends StatelessWidget {
  final bool isSubscribed;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  const SubscribeButtonWidget({
    super.key,
    required this.isSubscribed,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final label = AppText.get(
      isSubscribed ? 'btn_subscribed' : 'btn_subscribe',
    );

    final button = Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(
            minHeight: 26.r,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 10.r,
            vertical: AppSpacing.spacing1,
          ),
          decoration: BoxDecoration(
            color: isSubscribed
                ? AppColors.backgroundTertiary.withValues(alpha: 0.6)
                : AppColors.backgroundSecondary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSubscribed ? Colors.white12 : Colors.white24,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.white,
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: AppTypography.weightSemiBold,
                    fontSize: 11.5.sp,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
