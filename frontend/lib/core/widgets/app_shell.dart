import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

/// Bottom Navigation — 5 تبويبات معتمدة من IA: الرئيسية/استكشف/حجوزاتي/طلباتي/حسابي
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.currentIndex, required this.onTap});

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: widget.onTap,
        backgroundColor: c.surface,
        indicatorColor: c.primary.withOpacity(0.12),
        height: 68,
        destinations: [
          _dest(c, 0, Icons.home_outlined, Icons.home, 'الرئيسية'),
          _dest(c, 1, Icons.search_outlined, Icons.search, 'استكشف'),
          _dest(c, 2, Icons.event_note_outlined, Icons.event_note, 'حجوزاتي'),
          _dest(c, 3, Icons.shopping_bag_outlined, Icons.shopping_bag, 'طلباتي'),
          _dest(c, 4, Icons.person_outline, Icons.person, 'حسابي'),
        ],
      ),
    );
  }

  NavigationDestination _dest(AppColors c, int i, IconData out, IconData sel, String label) {
    final active = widget.currentIndex == i;
    return NavigationDestination(
      icon: Icon(out, size: 24, color: active ? c.primary : c.textMuted),
      selectedIcon: Icon(sel, size: 24, color: c.primary),
      label: label,
    );
  }
}
