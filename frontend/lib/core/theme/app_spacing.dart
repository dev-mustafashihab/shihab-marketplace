import 'package:flutter/material.dart' show Curve, Curves;

/// Spacing tokens — النظام الوحيد المسموح. المصدر: DESIGN_SYSTEM.md §4
/// هوامش الشاشة 16، الأقسام 24، داخل الكارت 16، بين العناصر 8-12.
class AppSpacing {
  AppSpacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// هوامش الشاشة القياسية
  static const double screenH = s16;
}

/// Radius tokens
class AppRadius {
  AppRadius._();

  static const double s = 8; // chips, inputs
  static const double m = 12; // cards
  static const double l = 16; // sheets
  static const double full = 999; // دائري مقصود فقط
}

/// Elevation tokens — لا ظلال ملونة ولا ثقيلة
class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double card = 1; // e1 = 0/1/3
  static const double sheet = 2; // e2 = 0/2/8
}

/// Motion tokens — مقتصد، كل animation له هدف
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration sheet = Duration(milliseconds: 280);

  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
}
