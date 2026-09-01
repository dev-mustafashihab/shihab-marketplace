import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// EmptyState — بديل إلزامي لـ«No data» المجردة.
/// الصيغة: عنوان + شرح + فعل تالٍ.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.primary.withOpacity( 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: c.primary),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(title, style: AppText.headingS(c.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              style: AppText.bodyM(c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel!,
                    style: AppText.button(c.surface)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
