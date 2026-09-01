import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// LocationBar — الموقع الحالي + فتح تغيير المدينة.
class LocationBar extends StatelessWidget {
  const LocationBar({super.key, required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: c.primary),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(city, style: AppText.headingS(c.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.keyboard_arrow_down, size: 20, color: c.textMuted),
          const Spacer(),
          Badge(
            isLabelVisible: true,
            backgroundColor: c.accent,
            smallSize: 8,
            child: Icon(Icons.notifications_none, size: 26, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
