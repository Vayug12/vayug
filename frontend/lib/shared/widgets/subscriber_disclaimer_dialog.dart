import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';
import 'package:vayug/shared/widgets/apple_alert_dialog.dart';

/// Clean, Apple HIG-compliant consent dialog shown before a user subscribes.
/// Informs the user that the creator may connect off-platform.
///
/// Built on top of [AppleAlertDialog] for consistent aesthetics across the app.
class SubscriberDisclaimerDialog extends StatefulWidget {
  const SubscriberDisclaimerDialog({super.key});

  /// Displays the dialog. Returns:
  /// - `null` if user cancelled.
  /// - `bool` indicating whether "Don't ask again" was checked when confirmed.
  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.overlayDark.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) =>
          const SubscriberDisclaimerDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutCubic.transform(anim1.value);
        return Transform.scale(
          scale: 0.92 + (0.08 * curvedValue),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SubscriberDisclaimerDialog> createState() =>
      _SubscriberDisclaimerDialogState();
}

class _SubscriberDisclaimerDialogState
    extends State<SubscriberDisclaimerDialog> {
  bool _dontAskAgain = true;

  @override
  Widget build(BuildContext context) {
    return AppleAlertDialog(
      icon: Icon(
        Icons.mail_outline_rounded,
        color: AppColors.primary,
        size: 20.r,
      ),
      iconContainerColor: AppColors.primary.withValues(alpha: 0.12),
      title: 'Creator Updates',
      message:
          'By subscribing, you agree that this creator may share updates, newsletters, or connect with you outside the platform.',
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _dontAskAgain = !_dontAskAgain);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 17.r,
                height: 17.r,
                decoration: BoxDecoration(
                  color: _dontAskAgain ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: _dontAskAgain
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    width: 1.2,
                  ),
                ),
                child: _dontAskAgain
                    ? Icon(
                        Icons.check_rounded,
                        size: 12.r,
                        color: AppColors.white,
                      )
                    : null,
              ),
              SizedBox(width: 8.w),
              Text(
                "Don't ask again",
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5.sp,
                  fontWeight: AppTypography.weightRegular,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppleDialogAction(
          text: 'Cancel',
          isCancelAction: true,
          onPressed: () {
            Navigator.of(context).pop(null);
          },
        ),
        AppleDialogAction(
          text: 'Subscribe',
          isDefaultAction: true,
          onPressed: () {
            Navigator.of(context).pop(_dontAskAgain);
          },
        ),
      ],
    );
  }
}
