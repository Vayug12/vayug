import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/spacing.dart';
import 'package:vayug/core/design/typography.dart';

/// Clean, Apple HIG-compliant consent dialog shown before a user subscribes.
/// Informs the user that the creator may connect off-platform.
class SubscriberDisclaimerDialog extends StatefulWidget {
  const SubscriberDisclaimerDialog({super.key});

  /// Displays the dialog. Returns:
  /// - `null` if user cancelled.
  /// - `bool` indicating whether "Don't ask again" was checked when confirmed.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SubscriberDisclaimerDialog(),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 14.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Apple squircle icon container
                    Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppRadius.squircle),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.primary,
                        size: 20.r,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Title
                    Text(
                      'Creator Updates',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: AppTypography.weightSemiBold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Clean Apple HIG Description (no extra text)
                    Text(
                      'By subscribing, you agree that this creator may share updates, newsletters, or connect with you outside the platform.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13.5.sp,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // "Don't ask again" row with minimum touch target
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _dontAskAgain = !_dontAskAgain);
                      },
                      child: SizedBox(
                        height: AppSpacing.minTouchTarget,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18.r,
                              height: 18.r,
                              decoration: BoxDecoration(
                                color: _dontAskAgain
                                    ? AppColors.primary
                                    : Colors.transparent,
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
                                      size: 13.r,
                                      color: AppColors.white,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "Don't ask again",
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hairline horizontal divider
              Container(
                height: 0.8,
                color: AppColors.borderSubtle,
              ),

              // Apple HIG horizontal action buttons
              SizedBox(
                height: 44.h,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(null);
                        },
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: AppTypography.weightMedium,
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 0.8,
                      height: 44.h,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(_dontAskAgain);
                        },
                        child: Center(
                          child: Text(
                            'Subscribe',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: AppTypography.weightSemiBold,
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
