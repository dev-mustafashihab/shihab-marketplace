import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// OfferCarousel — بطاقات العروض بلمسة Accent مقتصدة (خلفية 10% فقط).
class OfferCarousel extends StatelessWidget {
  const OfferCarousel({super.key, required this.offers});

  final List<(String, String, IconData)> offers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s12),
        itemBuilder: (context, i) {
          final (title, discount, icon) = offers[i];
          return _OfferCard(title: title, discount: discount, icon: icon);
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.title, required this.discount, required this.icon});

  final String title;
  final String discount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: c.accent.withOpacity( 0.10),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: c.accent.withOpacity( 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: c.accent),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: AppText.headingS(c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.s4),
                Text(discount, style: AppText.bodyM(c.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_left, size: 22, color: c.textMuted),
        ],
      ),
    );
  }
}
