import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// AppButton — الأزرار الموحدة. ارتفاع 52، tokens فقط.
/// variants: primary / secondary / ghost / destructive
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.icon,
  }) : assert(!(loading && onPressed != null) || true);

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;

    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_fg(c)),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.s8),
        ],
        Text(label, style: AppText.button(_fg(c))),
      ],
    );

    switch (variant) {
      case AppButtonVariant.primary:
        child = ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? c.primary : c.border,
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        child = OutlinedButton(onPressed: enabled ? onPressed : null, child: child);
      case AppButtonVariant.ghost:
        child = TextButton(onPressed: enabled ? onPressed : null, child: child);
      case AppButtonVariant.destructive:
        child = ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.error,
            foregroundColor: c.surface,
          ),
          child: child,
        );
    }

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }

  Color _fg(AppColors c) {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return c.surface;
      case AppButtonVariant.destructive:
        return c.surface;
    }
  }
}

enum AppButtonVariant { primary, secondary, ghost, destructive }
