import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

typedef CategoryTap = void Function();

/// CategoryRow — التصنيفات أفقياً، أيقونة دائرية 64 + تسمية.
class CategoryRow extends StatelessWidget {
  const CategoryRow({super.key, required this.items});

  final List<(String, IconData)> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s16),
        itemBuilder: (context, i) {
          final (label, icon) = items[i];
          return _CategoryItem(label: label, icon: icon, onTap: () {});
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final CategoryTap onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.primary.withOpacity( 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: c.primary),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              label,
              style: AppText.caption(c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
