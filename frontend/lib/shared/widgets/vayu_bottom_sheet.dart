import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/elevation.dart';
import 'package:vayug/core/design/radius.dart';
import 'package:vayug/core/design/typography.dart';

class VayuBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final bool showHandle;
  final bool showCloseButton;
  final EdgeInsetsGeometry? padding;
  final List<Widget>? actions;
  final ScrollController? scrollController;
  final double? height;
  final double? maxWidth;
  final Widget Function(BuildContext context, ScrollController? scrollController)? builder;

  const VayuBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.showHandle = true,
    this.showCloseButton = true,
    this.padding,
    this.actions,
    this.scrollController,
    this.height,
    this.maxWidth,
    this.builder,
  });

  /// Static helper to show the bottom sheet with consistent styling.
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? child,
    Widget Function(BuildContext context, ScrollController? scrollController)? builder,
    String? title,
    IconData? icon,
    Color? iconColor,
    bool showHandle = true,
    bool showCloseButton = true,
    bool isScrollControlled = true,
    EdgeInsetsGeometry? padding,
    List<Widget>? actions,
    double initialChildSize = 0.5,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    bool useDraggable = false,
    double? height,
    double? maxWidth,
  }) {
    assert(child != null || builder != null, 'Either child or builder must be provided');
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayDark.withValues(alpha: 0.6),
      builder: (context) {
        if (useDraggable) {
          return DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            expand: false,
            builder: (context, scrollController) => VayuBottomSheet(
              title: title,
              icon: icon,
              iconColor: iconColor,
              showHandle: showHandle,
              showCloseButton: showCloseButton,
              padding: padding,
              actions: actions,
              scrollController: scrollController,
              height: height,
              maxWidth: maxWidth,
              builder: builder,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        }
        return VayuBottomSheet(
          title: title,
          icon: icon,
          iconColor: iconColor,
          showHandle: showHandle,
          showCloseButton: showCloseButton,
          padding: padding,
          actions: actions,
          height: height,
          maxWidth: maxWidth,
          builder: builder,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final effectiveMaxWidth = maxWidth ?? (isLandscape ? 420.0 : null);
    final isFloating = isLandscape && effectiveMaxWidth != null;

    Widget content = ClipRRect(
      borderRadius: isFloating 
        ? AppRadius.borderRadiusSheetFloating 
        : AppRadius.borderRadiusSheet,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: effectiveMaxWidth != null ? BoxConstraints(maxWidth: effectiveMaxWidth) : null,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(alpha: 0.82),
            borderRadius: isFloating 
              ? AppRadius.borderRadiusSheetFloating 
              : AppRadius.borderRadiusSheet,
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
            boxShadow: AppElevation.sheetShadow,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHandle)
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                
                // Header. A titleless sheet still gets one when it has actions,
                // so a corner control has somewhere to sit.
                if (title != null || (actions?.isNotEmpty ?? false))
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        isLandscape ? 16 : 20,
                        showHandle ? 0 : (isLandscape ? 6 : 20),
                        isLandscape ? 12 : 16,
                        isLandscape ? 4 : 12),
                    child: Row(
                      children: [
                        if (title != null) ...[
                          if (icon != null) ...[
                            Icon(icon, color: iconColor ?? AppColors.primary, size: isLandscape ? 18 : 22),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              title!,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                fontSize: isLandscape ? 14.0 : null,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (actions != null) ...actions!,
                        if (showCloseButton)
                          Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.close, color: AppColors.textSecondary, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
                // Main Content
                Flexible(
                  child: builder != null 
                    ? builder!(context, scrollController)
                    : SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: padding ?? (isLandscape ? const EdgeInsets.fromLTRB(16, 0, 16, 10) : const EdgeInsets.fromLTRB(16, 0, 16, 20)),
                      child: child,
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isFloating) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: isLandscape ? 8 : 16),
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: content,
    );
  }
}
