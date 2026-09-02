import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';

/// حسابي — Profile Hub (بروفايل/مفضلة/إشعارات/لغة/دعم).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final loggedIn = ref.watch(apiClientProvider).token != null;
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
          InkWell(
            onTap: loggedIn ? null : () => _go(context, const LoginScreen()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
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
                  Text(loggedIn ? 'حسابي' : 'زائر', style: AppText.headingS(c.textPrimary)),
                  Text(loggedIn ? 'إدارة بياناتك وتفضيلاتك' : 'سجّل الدخول لحسابك',
                      style: AppText.caption(c.textMuted)),
                ]),
                const Spacer(),
                if (!loggedIn) Icon(Icons.chevron_left, color: c.textMuted),
              ]),
            ),
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
                  onTap: () => _onItemTap(context, items[i].$2),
                ),
                if (i < items.length - 1) Divider(height: 1, color: c.border, indent: 56),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _onItemTap(BuildContext context, String label) {
    switch (label) {
      case 'المفضلة':
        _go(context, const FavoritesScreen());
      case 'الإشعارات':
        _go(context, const NotificationsScreen());
      case 'الملف الشخصي':
        _go(context, const LoginScreen());
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذه الخدمة قادمة قريباً'), duration: Duration(seconds: 1)),
        );
    }
  }
}
