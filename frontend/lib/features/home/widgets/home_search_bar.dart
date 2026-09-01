import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// HomeSearchBar — ينقل لشاشة البحث (لا بحث فعلي هنا).
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.m),
      onTap: () {
        // TODO(Phase-2): Navigator إلى SearchScreen
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 22, color: c.textMuted),
            const SizedBox(width: AppSpacing.s12),
            Text('ابحث عن خدمة...', style: AppText.bodyM(c.textMuted)),
          ],
        ),
      ),
    );
  }
}
