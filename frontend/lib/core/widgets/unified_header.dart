import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../session/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../core/network/api_client.dart';

/// هيدر دبرني — مطابق للصورة: جرس يسار 16px + شعار يمين 16px منعزل، بلا نص، بلا خط تحت الرئيسية
class UnifiedHeader extends ConsumerStatefulWidget {
  const UnifiedHeader({super.key, this.trailing, this.showDivider = true});
  final Widget? trailing;
  final bool showDivider;
  @override
  ConsumerState<UnifiedHeader> createState() => _UnifiedHeaderState();
}

class _UnifiedHeaderState extends ConsumerState<UnifiedHeader> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _shineCtrl;
  late Animation<double> _shineAnim;

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _shineAnim = Tween<double>(begin: -1.2, end: 1.2).animate(CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut));
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      _shineCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(seconds: 1), () { if (mounted) _shineCtrl.forward(from: 0); });
  }

  @override
  void dispose() {
    _timer.cancel();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
          // جرس يسار 16px — منعزل
          if (widget.trailing != null) widget.trailing! else _HeaderBell(c: c),
          const Spacer(),
          // شعار يمين 16px — دائري زجاجي صغير مع لمعان كل 6ث
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.primary.withOpacity(0.10),
                  border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
                  boxShadow: [BoxShadow(color: c.primary.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _shineAnim,
                      builder: (_, __) {
                        return Transform.translate(
                          offset: Offset(_shineAnim.value * 40, 0),
                          child: Container(
                            width: 18, height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.transparent, Colors.white.withOpacity(0.45), Colors.transparent],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Image.asset('assets/images/dabirni.png', width: 24, height: 24, fit: BoxFit.contain),
                  ],
                ),
              ),
            ),
          ),
          ]),
        ),
        if (widget.showDivider) ...[
          const SizedBox(height: 8),
          Container(height: 2, width: 56, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0AAEBF), Color(0xFF00C8D6)]), borderRadius: BorderRadius.circular(2))),
        ],
      ]),
    );
  }
}

class _HeaderBell extends ConsumerWidget {
  const _HeaderBell({required this.c});
  final AppColors c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(sessionTokenProvider);
    final unreadAsync = ref.watch(_headerUnreadProvider(token));
    final unread = unreadAsync.valueOrNull ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 43, height: 43, child: Center(child: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, color: c.textPrimary, size: 21))),
        ),
      ),
      if (unread > 0)
        Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)), constraints: const BoxConstraints(minWidth: 16), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center))),
    ]);
  }
}

final _headerUnreadProvider = FutureProvider.autoDispose.family<int, String?>((ref, token) async {
  if (token == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    return d is int ? d : (d is num ? d.toInt() : 0);
  } catch (_) { return 0; }
});

/// شريط عنوان موحّد بارتفاع 52 مثل شريط البحث بالرئيسية
class UnifiedTitleBar extends StatelessWidget {
  const UnifiedTitleBar({super.key, required this.title, this.icon});
  final String title;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, size: 20, color: c.primary), const SizedBox(width: AppSpacing.s8)],
        Text(title, style: AppText.headingS(c.textPrimary)),
      ]),
    );
  }
}
