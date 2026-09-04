import 'package:flutter/material.dart';

/// Design tokens — الألوان. المصدر الوحيد للحقيقة: docs/design/DESIGN_SYSTEM.md
/// لا يُسمح بكتابة Hex داخل أي Widget.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryPressed,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
  });

  final Color primary;
  final Color primaryPressed;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color border;

  static const light = AppColors(
    primary: Color(0xFF0AAEBF),
    primaryPressed: Color(0xFF088E9C),
    accent: Color(0xFF00C8D6),
    background: Color(0xFFF2FBFC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0A2E33),
    textSecondary: Color(0xFF4A6B6F),
    textMuted: Color(0xFF8AA9AD),
    success: Color(0xFF0AAEBF),
    warning: Color(0xFFB26A00),
    error: Color(0xFFC0392B),
    border: Color(0xFFD6EAF0),
  );

  static const dark = AppColors(
    primary: Color(0xFF0ABAC1),
    primaryPressed: Color(0xFF0898A1),
    accent: Color(0xFF2EE0F0),
    background: Color(0xFF07181B),
    surface: Color(0xFF0E2A2E),
    textPrimary: Color(0xFFE6F7F8),
    textSecondary: Color(0xFF9AC8CC),
    textMuted: Color(0xFF6B9AA0),
    success: Color(0xFF0ABAC1),
    warning: Color(0xFFE0A24A),
    error: Color(0xFFE57368),
    border: Color(0xFF1A3A3E),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryPressed,
    Color? accent,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? border,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
