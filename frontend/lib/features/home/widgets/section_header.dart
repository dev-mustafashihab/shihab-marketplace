import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// SectionHeader — عنوان قسم + «عرض الكل» (Progressive Disclosure).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.headingM(c.textPrimary))),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text('عرض الكل', style: AppText.button(c.primary)),
            ),
        ],
      ),
    );
  }
}
