import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// StatusBadge — ألوان الحالات الموحدة عبر التطبيق.
enum BookingStatus { pending, confirmed, cancelled, completed, expired, rejected }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, String label) = switch (status) {
      BookingStatus.pending => (c.warning.withOpacity( 0.14), c.warning, 'قيد الانتظار'),
      BookingStatus.confirmed => (c.success.withOpacity( 0.14), c.success, 'مؤكد'),
      BookingStatus.cancelled => (c.error.withOpacity( 0.12), c.error, 'ملغى'),
      BookingStatus.completed => (c.textMuted.withOpacity( 0.14), c.textSecondary, 'مكتمل'),
      BookingStatus.expired => (c.border, c.textMuted, 'منتهي'),
      BookingStatus.rejected => (c.error.withOpacity( 0.12), c.error, 'مرفوض'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12, vertical: AppSpacing.s4 + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Text(label, style: AppText.caption(fg)),
    );
  }
}
