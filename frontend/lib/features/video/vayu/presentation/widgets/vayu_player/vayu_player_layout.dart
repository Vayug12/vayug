import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vayug/core/design/spacing.dart';

/// Shared visual geometry for the Vayu player chrome.
///
/// Playback and interaction behavior deliberately stay outside this class. It
/// only keeps the top, centre, bottom and quiz rails on one spacing system.
class VayuPlayerLayout {
  VayuPlayerLayout._();

  static const double portraitUtilityControlSize = 36;
  static const double landscapeUtilityControlSize = 38;
  static const double portraitUtilityIconSize = 21;
  static const double landscapeUtilityIconSize = 22;

  static const double landscapeTransportControlSize = 44;
  static const double landscapeTransportIconSize = 26;
  static const double portraitPrimaryControlSize = 56;
  static const double landscapePrimaryControlSize = 64;
  static const double portraitPrimaryIconSize = 32;
  static const double landscapePrimaryIconSize = 40;

  /// Apple HIG minimum touch target dimension (44x44 pt).
  static const double minTouchTarget = 44;

  /// Apple-style pill container dimensions
  static const double durationPillHeightPortrait = 28;
  static const double durationPillHeightLandscape = 30;
  static const double actionCapsuleHeightPortrait = 36;
  static const double actionCapsuleHeightLandscape = 38;

  /// Apple minimal pill styling tokens (GPU-lightweight)
  static const Color pillBackgroundColor = Color(0x66000000); // 40% black
  static const Color pillBorderColor = Color(0x29FFFFFF); // 16% white
  static const double pillBorderWidth = 0.75;

  /// Keeps the painted control surface dense without changing its outer
  /// layout box or tap position.
  static const double compactIconPadding = 2;

  static double compactSurfaceSize(double iconSize) =>
      iconSize + (compactIconPadding * 2);

  static double utilityControlSize({required bool isPortrait}) =>
      isPortrait ? portraitUtilityControlSize : landscapeUtilityControlSize;

  static double utilityIconSize({required bool isPortrait}) =>
      isPortrait ? portraitUtilityIconSize : landscapeUtilityIconSize;

  static double primaryControlSize({required bool isPortrait}) =>
      isPortrait ? portraitPrimaryControlSize : landscapePrimaryControlSize;

  static double primaryIconSize({required bool isPortrait}) =>
      isPortrait ? portraitPrimaryIconSize : landscapePrimaryIconSize;

  static double get transportGap => AppSpacing.spacing6;

  static double get transportRailWidth =>
      (landscapeTransportControlSize * 2) +
      landscapePrimaryControlSize +
      (transportGap * 2);

  static EdgeInsets playerInsets(
    BuildContext context, {
    required bool isFullScreen,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final padding = MediaQuery.paddingOf(context);
    final left = math.max(viewPadding.left, padding.left);
    final top = math.max(viewPadding.top, padding.top);
    final right = math.max(viewPadding.right, padding.right);
    final bottom = math.max(viewPadding.bottom, padding.bottom);
    final baseInset = isFullScreen ? AppSpacing.spacing6 : AppSpacing.spacing4;

    return EdgeInsets.fromLTRB(
      left + baseInset,
      top + baseInset,
      right + baseInset,
      bottom + baseInset,
    );
  }

  /// Width of the fullscreen landscape quiz lane. Its right edge always stops
  /// before the centred transport rail, leaving one major spacing unit between
  /// the two regions.
  static double landscapeQuizWidth({
    required double viewportWidth,
    required double leftInset,
  }) {
    final transportLeft = (viewportWidth - transportRailWidth) / 2;
    final availableWidth = transportLeft - leftInset - AppSpacing.spacing6;
    return math.max(0, math.min(400, availableWidth));
  }
}
