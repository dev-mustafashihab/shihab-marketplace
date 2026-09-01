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
    primary: Color(0xFF0F6B5C),
    primaryPressed: Color(0xFF0B564A),
    accent: Color(0xFFC9A227),
    background: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1B18),
    textSecondary: Color(0xFF5F5B54),
    textMuted: Color(0xFF98938A),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFB26A00),
    error: Color(0xFFC0392B),
    border: Color(0xFFE4E1DA),
  );

  static const dark = AppColors(
    primary: Color(0xFF3D9B8A),
    primaryPressed: Color(0xFF2F7D6F),
    accent: Color(0xFFD9B84A),
    background: Color(0xFF101413),
    surface: Color(0xFF1A201E),
    textPrimary: Color(0xFFF0EFEA),
    textSecondary: Color(0xFFB5B0A6),
    textMuted: Color(0xFF7F7A72),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFE0A24A),
    error: Color(0xFFE57368),
    border: Color(0xFF2A312E),
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
