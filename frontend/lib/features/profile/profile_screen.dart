import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// حسابي — Profile Hub (بروفايل/مفضلة/إشعارات/لغة/دعم) — شاشة ثابتة MVP.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = [
      (Icons.person_outline, 'الملف الشخصي'),
      (Icons.location_on_outlined, 'عناويني'),
      (Icons.favorite_border, 'المفضلة'),
      (Icons.notifications_none, 'الإشعارات'),
      (Icons.language, 'اللغة (العربية)'),
      (Icons.support_agent_outlined, 'الدعم'),
    ];
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border)),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: c.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.person, size: 30, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.s12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('زائر', style: AppText.headingS(c.textPrimary)),
                Text('سجّل الدخول لحسابك', style: AppText.caption(c.textMuted)),
              ]),
            ]),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border)),
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  leading: Icon(items[i].$1, color: c.primary),
                  title: Text(items[i].$2, style: AppText.bodyL(c.textPrimary)),
                  trailing: Icon(Icons.chevron_left, color: c.textMuted),
                  onTap: () {},
                ),
                if (i < items.length - 1) Divider(height: 1, color: c.border, indent: 56),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
