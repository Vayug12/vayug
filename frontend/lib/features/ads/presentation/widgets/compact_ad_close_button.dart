import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';

/// A compact, minimal close ('X') button designed specifically for ads.
/// Follows the design system in `design.md`:
/// - Minimalist aesthetic without heavy shadows or neon colors
/// - Subtle dark surface with crisp, clean icon
/// - Generous touch target with a compact visual footprint
class CompactAdCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final String tooltip;

  const CompactAdCloseButton({
    Key? key,
    required this.onTap,
    this.size = 20.0,
    this.iconSize = 12.0,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.tooltip = 'Close ad',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4.0), // Expands tap target
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ?? AppColors.surfacePrimary.withValues(alpha: 0.85),
              border: Border.all(
                color: borderColor ?? AppColors.borderPrimary.withValues(alpha: 0.6),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.close_rounded,
                size: iconSize,
                color: iconColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
