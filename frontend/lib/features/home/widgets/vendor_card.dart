import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// VendorCard — صورة 4:3، اسم، تقييم، «من $X»، مسافة. عرض ثابت 240 للكاروسيل.
class VendorCard extends StatelessWidget {
  const VendorCard({super.key, required this.vendor});

  final (String, double, String, double) vendor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (name, rating, fromPrice, distanceKm) = vendor;

    return Container(
      width: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: c.border),
      ),
      child: InkWell(
        onTap: () {
          // TODO(Phase-2): Navigator إلى VendorDetailsScreen
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero placeholder (Phase 2: CachedNetworkImage)
            Container(
              height: 120,
              color: c.primary.withOpacity( 0.10),
              child: Center(
                child: Icon(Icons.storefront_outlined, size: 36, color: c.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: AppText.headingS(c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Icon(Icons.star, size: 14, color: c.accent),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1),
                          style: AppText.caption(c.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(fromPrice,
                            style: AppText.price(c.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Spacer(),
                      Icon(Icons.place_outlined, size: 14, color: c.textMuted),
                      const SizedBox(width: 2),
                      Text('${distanceKm.toStringAsFixed(1)} كم',
                          style: AppText.caption(c.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
