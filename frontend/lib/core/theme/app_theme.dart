import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Theme builder — Light جاهز الآن، Dark معمّر بنفس الـ tokens (تفعيل لاحقاً).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c == AppColors.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: [c],
      colorScheme: base.colorScheme.copyWith(
        primary: c.primary,
        secondary: c.accent,
        error: c.error,
        surface: c.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: AppText.headingS(c.textPrimary),
      ),
      cardTheme: CardTheme(
        color: c.surface,
        elevation: AppElevation.card,
        shadowColor: Colors.black.withOpacity( 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: c.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: c.error),
        ),
        hintStyle: AppText.bodyM(c.textMuted),
        labelStyle: AppText.bodyM(c.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.surface,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size(64, 52),
          textStyle: AppText.button(c.surface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
          elevation: AppElevation.none,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? c.primaryPressed : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: c.primary),
          textStyle: AppText.button(c.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: AppText.button(c.primary),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          side: BorderSide(color: c.border),
        ),
        labelStyle: AppText.bodyM(c.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: AppText.bodyM(c.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
      ),
    );
  }
}
