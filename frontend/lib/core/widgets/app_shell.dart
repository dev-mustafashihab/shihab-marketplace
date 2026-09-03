import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SizedBox(
            height: 72,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _DockDestination(c: c, index: 0, currentIndex: widget.currentIndex, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', onTap: widget.onTap),
                _DockDestination(c: c, index: 1, currentIndex: widget.currentIndex, icon: Icons.search_outlined, activeIcon: Icons.search, label: 'استكشف', onTap: widget.onTap),
                _DockDestination(c: c, index: 2, currentIndex: widget.currentIndex, icon: Icons.event_note_outlined, activeIcon: Icons.event_note, label: 'حجوزاتي', onTap: widget.onTap),
                _DockDestination(c: c, index: 3, currentIndex: widget.currentIndex, icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag, label: 'طلباتي', onTap: widget.onTap),
                _DockDestination(c: c, index: 4, currentIndex: widget.currentIndex, icon: Icons.person_outline, activeIcon: Icons.person, label: 'حسابي', onTap: widget.onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.c,
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final AppColors c;
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4, horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Icon(active ? activeIcon : icon, size: 27, color: active ? c.primary : c.textMuted),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: active ? 12 : 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? c.primary : c.textMuted,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
