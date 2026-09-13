import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppRadius {
  AppRadius._();

  // Core Scale (Apple HIG Standard) - Responsive via .r
  static double get none => 0.0;
  static double get xs => 4.0.r;
  static double get sm => 8.0.r;
  static double get md => 14.0.r; // Apple action button & input standard (14px)
  static double get lg => 18.0.r; // Apple card standard (18px)
  static double get xl => 22.0.r; // Apple hero card / dialog standard (22px)
  static double get sheet => 28.0.r; // Apple bottom sheet standard (28px)
  static double get pill => 999.0.r;

  // Semantic Shortcuts (Mapped to Single Source of Truth)
  static double get button => md; // 14px
  static double get input => md; // 14px
  static double get card => lg; // 18px
  static double get cardLarge => xl; // 22px
  static double get dialog => 20.0.r; // 20px
  static double get image => 16.0.r; // 16px
  static double get squircle => 10.0.r; // 10px (Feature chips / icon boxes)

  // Legacy variables aliased for full backward compatibility (Zero duplicate hardcoding)
  static double get radiusNone => none;
  static double get radiusSmall => xs;
  static double get radiusMedium => sm;
  static double get radiusLarge => md;
  static double get radiusXLarge => lg;
  static double get radiusXXLarge => xl;
  static double get radiusFull => pill;

  static double get radiusXS => xs;
  static double get radiusSM => sm;
  static double get radiusMD => md;
  static double get radiusLG => lg;
  static double get radiusXL => xl;
  static double get radiusPill => pill;

  // Pre-defined BorderRadius objects for instant usage - Dynamic getters
  static BorderRadius get borderRadiusXS => BorderRadius.circular(xs);
  static BorderRadius get borderRadiusSM => BorderRadius.circular(sm);
  static BorderRadius get borderRadiusMD => BorderRadius.circular(md);
  static BorderRadius get borderRadiusLG => BorderRadius.circular(lg);
  static BorderRadius get borderRadiusXL => BorderRadius.circular(xl);

  // Semantic BorderRadius Helpers
  static BorderRadius get borderRadiusButton => BorderRadius.circular(button);
  static BorderRadius get borderRadiusInput => BorderRadius.circular(input);
  static BorderRadius get borderRadiusCard => BorderRadius.circular(card);
  static BorderRadius get borderRadiusCardLarge => BorderRadius.circular(cardLarge);
  static BorderRadius get borderRadiusDialog => BorderRadius.circular(dialog);
  static BorderRadius get borderRadiusSheet => BorderRadius.vertical(top: Radius.circular(sheet));
  static BorderRadius get borderRadiusSheetFloating => BorderRadius.circular(sheet);
  static BorderRadius get borderRadiusSquircle => BorderRadius.circular(squircle);
  static BorderRadius get borderRadiusImage => BorderRadius.circular(image);
  static BorderRadius get borderRadiusPill => BorderRadius.circular(pill);
}
