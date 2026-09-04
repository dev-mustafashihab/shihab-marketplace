import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Bottom Navigation — مطابق للصورة: 4 أيقونات + QR عائم
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
      backgroundColor: const Color(0xFFDDF1F4),
      body: widget.child,
      floatingActionButton: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF0AAEBF),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF0AAEBF).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(14),
            child: const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedQrCodeScan, color: Colors.white, size: 28)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCDE8EC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _DockDestination(c: c, index: 0, currentIndex: widget.currentIndex, icon: HugeIcons.strokeRoundedHome02, label: 'الرئيسية', onTap: widget.onTap),
                _DockDestination(c: c, index: 1, currentIndex: widget.currentIndex, icon: HugeIcons.strokeRoundedMoneyExchange01, label: 'التحويلات', onTap: widget.onTap),
                const SizedBox(width: 56),
                _DockDestination(c: c, index: 2, currentIndex: widget.currentIndex, icon: HugeIcons.strokeRoundedCreditCard, label: 'الخدمات', onTap: widget.onTap),
                _DockDestination(c: c, index: 3, currentIndex: widget.currentIndex, icon: HugeIcons.strokeRoundedUser, label: 'حسابي', onTap: widget.onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({required this.c, required this.index, required this.currentIndex, required this.icon, required this.label, required this.onTap});
  final AppColors c;
  final int index;
  final int currentIndex;
  final List<List<dynamic>> icon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HugeIcon(icon: icon, color: active ? const Color(0xFF0AAEBF) : const Color(0xFF7FA3A8), size: 26),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.cairo(fontSize: active ? 11 : 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF0AAEBF) : const Color(0xFF7FA3A8)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
