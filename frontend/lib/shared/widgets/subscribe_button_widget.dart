import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
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

  /// Optional color overrides for profile-specific styling.
  /// When null, falls back to default dark theme colors.
  final Color? activeBackgroundColor;
  final Color? activeTextColor;
  final Color? activeBorderColor;
  final Color? inactiveBackgroundColor;
  final Color? inactiveTextColor;
  final Color? inactiveBorderColor;
  final double? height;

  const SubscribeButtonWidget({
    super.key,
    required this.isSubscribed,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.activeBackgroundColor,
    this.activeTextColor,
    this.activeBorderColor,
    this.inactiveBackgroundColor,
    this.inactiveTextColor,
    this.inactiveBorderColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final label = AppText.get(
      isSubscribed ? 'btn_subscribed' : 'btn_subscribe',
    );

    // Resolve colors: use overrides when provided, else default dark theme
    final bgColor = isSubscribed
        ? (inactiveBackgroundColor ?? AppColors.backgroundTertiary.withValues(alpha: 0.6))
        : (activeBackgroundColor ?? AppColors.backgroundSecondary.withValues(alpha: 0.85));
    final textColor = isSubscribed
        ? (inactiveTextColor ?? AppColors.white)
        : (activeTextColor ?? AppColors.white);
    final borderColor = isSubscribed
        ? (inactiveBorderColor ?? Colors.white12)
        : (activeBorderColor ?? Colors.white24);

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
          height: height,
          constraints: height == null ? BoxConstraints(minHeight: 26.r) : null,
          padding: EdgeInsets.symmetric(
            horizontal: 8.r,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: borderColor,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: textColor,
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: textColor,
                    fontWeight: AppTypography.weightBold,
                    fontSize: 14.5.sp,
                    letterSpacing: 0.1,
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
