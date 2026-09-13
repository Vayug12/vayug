import 'package:flutter/material.dart';

class AppElevation {
  AppElevation._();

  // Shadow Colors (repeated here if needed, or referenced from Colors, but hardcoding for independence is fine)
  static const Color shadowPrimary = Color(0x0A000000);
  static const Color shadowSecondary = Color(0x0F000000);
  static const Color shadowElevated = Color(0x1A000000);

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: shadowPrimary,
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: shadowSecondary,
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: shadowElevated,
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowXl = [
    BoxShadow(
      color: shadowElevated,
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Apple HIG Soft Ambient & Layered Elevation Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 28,
      offset: Offset(0, -4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 40,
      offset: Offset(0, 12),
      spreadRadius: 0,
    ),
  ];
}
