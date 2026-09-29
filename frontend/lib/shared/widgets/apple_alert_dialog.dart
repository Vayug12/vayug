import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/typography.dart';

/// Action item for [AppleAlertDialog].
class AppleDialogAction {
  final String text;
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final bool isCancelAction;

  const AppleDialogAction({
    required this.text,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.isCancelAction = false,
  });
}

/// A clean, elegant, compact alert dialog strictly adhering to `apple.md` and Apple HIG:
/// - Translucent frosted glass surface with BackdropFilter (Layered depth)
/// - Continuous curvature squircle (22.r - 24.r)
/// - Hairline dividers (0.6px, subtle 6-8% opacity)
/// - Strict 44pt minimum touch target action buttons
/// - Light tactile haptic feedback on interactions
/// - Single accent color discipline
class AppleAlertDialog extends StatelessWidget {
  final Widget? icon;
  final Color? iconContainerColor;
  final String? title;
  final String? message;
  final Widget? content;
  final List<AppleDialogAction> actions;
  final double? maxWidth;

  const AppleAlertDialog({
    super.key,
    this.icon,
    this.iconContainerColor,
    this.title,
    this.message,
    this.content,
    this.actions = const [],
    this.maxWidth,
  });

  /// Displays the AppleAlertDialog with consistent styling and smooth animations.
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? icon,
    Color? iconContainerColor,
    String? title,
    String? message,
    Widget? content,
    List<AppleDialogAction> actions = const [],
    bool barrierDismissible = true,
    double? maxWidth,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.overlayDark.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) {
        return AppleAlertDialog(
          icon: icon,
          iconContainerColor: iconContainerColor,
          title: title,
          message: message,
          content: content,
          actions: actions,
          maxWidth: maxWidth,
        );
      },
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
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? 286.w;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Body Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Container(
                              width: 38.r,
                              height: 38.r,
                              decoration: BoxDecoration(
                                color: iconContainerColor ??
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    AppRadius.squircle + 2.r),
                              ),
                              alignment: Alignment.center,
                              child: icon,
                            ),
                            SizedBox(height: 12.h),
                          ],
                          if (title != null && title!.isNotEmpty) ...[
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: AppTypography.weightSemiBold,
                                fontSize: 16.5.sp,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                          if (message != null && message!.isNotEmpty) ...[
                            SizedBox(height: title != null ? 7.h : 0),
                            Text(
                              message!,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13.sp,
                                height: 1.38,
                              ),
                            ),
                          ],
                          if (content != null) ...[
                            SizedBox(height: 12.h),
                            content!,
                          ],
                        ],
                      ),
                    ),

                    // Divider before action buttons
                    if (actions.isNotEmpty) ...[
                      Container(
                        height: 0.6,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      _buildActions(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    // 2 actions -> Side by side horizontal layout (Classic Apple alert)
    if (actions.length == 2) {
      return SizedBox(
        height: 44.h,
        child: Row(
          children: [
            Expanded(child: _buildActionButton(context, actions[0])),
            Container(
              width: 0.6,
              height: 44.h,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Expanded(child: _buildActionButton(context, actions[1])),
          ],
        ),
      );
    }

    // 1 or >2 actions -> Vertical stack
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(actions.length, (index) {
        final action = actions[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Container(
                height: 0.6,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            SizedBox(
              height: 44.h,
              width: double.infinity,
              child: _buildActionButton(context, action),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildActionButton(BuildContext context, AppleDialogAction action) {
    Color textColor;
    FontWeight fontWeight;

    if (action.isDestructiveAction) {
      textColor = AppColors.error;
      fontWeight = AppTypography.weightSemiBold;
    } else if (action.isDefaultAction) {
      textColor = AppColors.primary;
      fontWeight = AppTypography.weightSemiBold;
    } else {
      textColor = AppColors.textSecondary;
      fontWeight = AppTypography.weightMedium;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        onTap: () {
          HapticFeedback.lightImpact();
          if (action.onPressed != null) {
            action.onPressed!();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Center(
          child: Text(
            action.text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: 15.sp,
            ),
          ),
        ),
      ),
    );
  }
}
