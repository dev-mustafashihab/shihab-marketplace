import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/wallet_register_screen.dart';
import '../bookings/my_bookings_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transfers/transfers_screen.dart';
import 'account_info_screen.dart';

/// حسابي — شاشة موحدة (RTL كامل) مع ترويسة متدرجة، 4 بطاقات مجمّعة،
/// وسجل تمرير ثابت (ScrollController + AutomaticKeepAliveClientMixin).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
    final token = ref.watch(sessionTokenProvider);
    final loggedIn = token != null;
    final meAsync = loggedIn ? ref.watch(_meProvider) : const AsyncValue.data(null);
    final me = meAsync.valueOrNull ?? const {};
    final role = '${me['role'] ?? 'CUSTOMER'}';
    final email = '${me['email'] ?? ''}';
    final profile = (me['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isVendor = role == 'VENDOR';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.primary.withOpacity(0.95),
              c.primary.withOpacity(0.7),
              c.background,
            ],
            stops: const [0.0, 0.35, 0.55],
          ),
        ),
        child: Column(children: [
          // ── ترويسة ثابتة ──
          _ProfileHeader(loggedIn: loggedIn),

          // ── محتوى قابل للتمرير ──
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.s16),

                  // ── بطاقة المستخدم ──
                  _UserCard(
                    loggedIn: loggedIn,
                    isVendor: isVendor,
                    email: email,
                    profile: profile,
                  ),

                  // ── تنبيه التوثيق ──
                  if (loggedIn && !isVendor) ...[
                    const SizedBox(height: AppSpacing.s12),
                    _KycBanner(profile: profile),
                  ],

                  // ── أزرار الزائر ──
                  if (!loggedIn) ...[
                    const SizedBox(height: AppSpacing.s16),
                    _PrimaryButton(
                      label: 'تسجيل الدخول',
                      icon: Icons.login_rounded,
                      onTap: () => _push(const LoginScreen()),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _GhostButton(
                      label: 'أنشئ محفظة جديدة',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _push(const WalletRegisterScreen()),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    _GroupedCard(title: 'العام', children: [
                      _MenuTile(
                        icon: Icons.favorite_border,
                        title: 'المفضلة',
                        onTap: () => _push(const FavoritesScreen()),
                      ),
                    ]),
                  ],

                  // ── البطاقات الأربع المجمّعة ──
                  if (loggedIn) ...[
                    const SizedBox(height: AppSpacing.s20),

                    // ① الحساب والتوثيق
                    _GroupedCard(title: 'الحساب والتوثيق', children: [
                      _MenuTile(
                        icon: Icons.person_outline_rounded,
                        title: 'الملف الشخصي',
                        onTap: () => _push(
                          isVendor ? const RegisterScreen() : const AccountInfoScreen(),
                        ),
                      ),
                      _MenuTile(
                        icon: Icons.verified_outlined,
                        title: 'توثيق الحساب',
                        badge: _kycBadge(profile),
                        onTap: () => _push(const AccountInfoScreen()),
                      ),
                      if (!isVendor)
                        _MenuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'تفاصيل المحفظة',
                          onTap: () => _push(const TransfersScreen()),
                        ),
                    ]),

                    const SizedBox(height: AppSpacing.s16),

                    // ② النشاط والمعاملات
                    _GroupedCard(title: 'النشاط والمعاملات', children: [
                      if (!isVendor) ...[
                        _MenuTile(
                          icon: Icons.calendar_month_outlined,
                          title: 'حجوزاتي',
                          onTap: () => _push(const MyBookingsScreen()),
                        ),
                        _MenuTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'سجل عمليات المحفظة',
                          onTap: () => _push(const TransfersScreen()),
                        ),
                      ],
                      _MenuTile(
                        icon: Icons.favorite_border,
                        title: 'المفضلة',
                        onTap: () => _push(const FavoritesScreen()),
                      ),
                    ]),

                    const SizedBox(height: AppSpacing.s16),

                    // ③ الأمان والوصول
                    _GroupedCard(title: 'الأمان والوصول', children: [
                      _MenuTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'رمز الدخول (PIN)',
                        onTap: () => _push(const SecurityScreen()),
                      ),
                      _MenuTile(
                        icon: Icons.security_outlined,
                        title: 'الأمان والتحقق',
                        onTap: () => _push(const SecurityScreen()),
                      ),
                      _MenuTile(
                        icon: Icons.devices_outlined,
                        title: 'إدارة الأجهزة المرتبطة',
                        onTap: () {},
                      ),
                    ]),

                    const SizedBox(height: AppSpacing.s16),

                    // ④ تفضيلات التطبيق والدعم
                    _GroupedCard(title: 'التفضيلات والدعم', children: [
                      _MenuTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'المظهر',
                        trailing: 'فاتح',
                        onTap: () {},
                      ),
                      _MenuTile(
                        icon: Icons.language_outlined,
                        title: 'اللغة',
                        trailing: 'العربية',
                        onTap: () {},
                      ),
                      _MenuTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'الإشعارات',
                        onTap: () => _push(const NotificationsScreen()),
                      ),
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        title: 'المساعدة والدعم الفني',
                        onTap: () {},
                      ),
                      _MenuTile(
                        icon: Icons.description_outlined,
                        title: 'الشروط وسياسة الخصوصية',
                        onTap: () {},
                      ),
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        title: 'حول التطبيق',
                        trailing: 'v1.0.0',
                        onTap: () {},
                      ),
                    ]),

                    const SizedBox(height: AppSpacing.s32),

                    // ── إجراءات تدميرية ──
                    _DangerButton(
                      label: 'تسجيل الخروج',
                      icon: Icons.logout_rounded,
                      onTap: () => _confirmLogout(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _DangerLink(
                      label: 'حذف الحساب',
                      onTap: () => _confirmDelete(context),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.s24),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── مساعدات التنقل ──

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String? _kycBadge(Map<String, dynamic> p) {
    final s = '${p['kycStatus'] ?? ''}';
    if (s == 'APPROVED') return 'موثق';
    if (s == 'REJECTED') return 'مرفوض';
    if (s.isNotEmpty) return 'قيد المراجعة';
    return null;
  }

  Future<void> _confirmLogout(BuildContext ctx, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && ctx.mounted) {
      ref.read(sessionTokenProvider.notifier).state = null;
      await SessionService.saveToken(null);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الخروج'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب'),
          content: const Text('هذا الإجراء لا رجعة فيه. سيتم حذف جميع بياناتك نهائياً. هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب حذف الحساب')),
      );
    }
  }
}

// ═══════════════════════════════════════════════
//  الترويسة الثابتة
// ═══════════════════════════════════════════════

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = loggedIn ? ref.watch(_unreadProvider).valueOrNull ?? 0 : 0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          // جرس الإشعارات
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              onPressed: !loggedIn
                  ? null
                  : () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                      .then((_) => ref.invalidate(_unreadProvider)),
              icon: const Icon(Icons.notifications_none_rounded, size: 26, color: Colors.white),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5392B),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ]),
          const Spacer(),
          Text('حسابي', style: AppText.headingM(Colors.white)),
          const Spacer(),
          const SizedBox(width: 48), // موازنة
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  بطاقة المستخدم
// ═══════════════════════════════════════════════

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.loggedIn,
    required this.isVendor,
    required this.email,
    required this.profile,
  });

  final bool loggedIn;
  final bool isVendor;
  final String email;
  final Map<String, dynamic> profile;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  static String formatAccount(String raw) {
    final d = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (d.length != 16) return raw;
    return '${d.substring(0, 4)} ${d.substring(4, 8)} ${d.substring(8, 12)} ${d.substring(12)}';
  }

  @override
  Widget build(BuildContext context) {
    final name = '${profile['fullName'] ?? ''}'.trim();
    final phone = '${profile['phone'] ?? ''}';
    final kyc = '${profile['kycStatus'] ?? ''}';
    final accId = '${profile['walletAccountId'] ?? ''}';
    final premium = profile['isPremium'] == true;
    final hasImage = profile['avatarUrl'] != null && '${profile['avatarUrl']}'.isNotEmpty;

    return Column(children: [
      // أفاتار مع أيقونة كاميرا
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: ClipOval(
            child: hasImage
                ? Image.network('${profile['avatarUrl']}', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(name, email))
                : _defaultAvatar(name, email),
          ),
        ),
        // أيقونة كاميرا
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0AAEBF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
          ),
        ),
        // شارة التوثيق
        if (loggedIn && !isVendor)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: kyc == 'APPROVED'
                    ? const Color(0xFF4CAF50)
                    : kyc == 'REJECTED'
                        ? const Color(0xFFE5392B)
                        : const Color(0xFFFFA726),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                kyc == 'APPROVED'
                    ? Icons.check_rounded
                    : kyc == 'REJECTED'
                        ? Icons.close_rounded
                        : Icons.hourglass_top_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
      ]),
      const SizedBox(height: AppSpacing.s12),

      // الاسم
      Text(
        !loggedIn
            ? 'زائر'
            : name.isNotEmpty
                ? name
                : (email.isEmpty ? 'حسابي' : email),
        style: AppText.headingM(Colors.white),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),

      // رقم الحساب
      if (loggedIn && !isVendor && accId.isNotEmpty)
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: accId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم نسخ رقم الحساب'), duration: Duration(seconds: 1)),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                formatAccount(accId),
                textDirection: TextDirection.ltr,
                style: AppText.en(Colors.white.withOpacity(0.9), size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
            ]),
          ),
        )
      else if (phone.isNotEmpty)
        Text(phone, textDirection: TextDirection.ltr, style: AppText.caption(Colors.white.withOpacity(0.8))),

      const SizedBox(height: 8),

      // شارة نوع الحساب
      if (loggedIn) _AccountBadge(isVendor: isVendor, premium: premium, kyc: kyc),
    ]);
  }

  Widget _defaultAvatar(String name, String email) {
    final initials = _initials(name.isNotEmpty ? name : email);
    final showInitials = loggedIn && initials != '?';
    return Center(
      child: showInitials
          ? Text(initials, style: AppText.headingL(Colors.white))
          : const Icon(Icons.person_rounded, size: 40, color: Colors.white),
    );
  }

}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.isVendor, required this.premium, required this.kyc});
  final bool isVendor;
  final bool premium;
  final String kyc;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bgColor;
    if (isVendor) {
      label = 'حساب تجاري';
      bgColor = const Color(0xFFFFA726);
    } else if (premium) {
      label = 'حساب مميز';
      bgColor = const Color(0xFFFFD54F);
    } else {
      label = 'حساب عادي';
      bgColor = Colors.white.withOpacity(0.2);
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: AppText.caption(Colors.white)),
        ),
        if (!isVendor)
          Text(
            kyc == 'APPROVED' ? 'موثق' : kyc == 'REJECTED' ? 'مرفوض' : 'قيد المراجعة',
            style: AppText.caption(Colors.white.withOpacity(0.7)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  البطاقات المجمّعة
// ═══════════════════════════════════════════════

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(title, style: AppText.bodyM(const Color(0xFF4A6B6F))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  عنصر القائمة
// ═══════════════════════════════════════════════

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, this.trailing, this.badge, required this.onTap});
  final IconData icon;
  final String title;
  final String? trailing;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF0AAEBF), size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: AppText.bodyL(const Color(0xFF0A2E33)))),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: TextStyle(fontSize: 11, color: _badgeColor, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
            ],
            if (trailing != null) ...[
              Text(trailing!, style: AppText.bodyM(const Color(0xFF8AA9AD))),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_left_rounded, color: Color(0xFF8AA9AD), size: 22),
          ]),
        ),
      ),
    );
  }

  Color get _badgeColor {
    if (badge == 'موثق') return const Color(0xFF4CAF50);
    if (badge == 'مرفوض') return const Color(0xFFE5392B);
    return const Color(0xFFFFA726);
  }
}

// ═══════════════════════════════════════════════
//  تنبيه التوثيق
// ═══════════════════════════════════════════════

class _KycBanner extends StatelessWidget {
  const _KycBanner({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final status = '${profile['kycStatus'] ?? ''}';
    if (status == 'APPROVED' || status.isEmpty) return const SizedBox.shrink();
    final rejected = status == 'REJECTED';
    final note = '${profile['kycNote'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (rejected ? const Color(0xFFE5392B) : const Color(0xFFFFA726)).withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
          size: 20,
          color: rejected ? const Color(0xFFE5392B) : const Color(0xFFFFA726),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rejected
                ? (note.isNotEmpty ? 'تم رفض التوثيق: $note' : 'تم رفض التوثيق — راجع الدعم')
                : 'حسابك قيد مراجعة التوثيق — المحفظة تتفعل بعد الموافقة',
            style: AppText.bodyM(rejected ? const Color(0xFFE5392B) : const Color(0xFF0A2E33)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
//  الأزرار
// ═══════════════════════════════════════════════

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0AAEBF), Color(0xFF088E9C)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF0AAEBF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: AppText.button(Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: AppText.button(Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5392B).withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: const Color(0xFFE5392B)),
              const SizedBox(width: 8),
              Text(label, style: AppText.button(const Color(0xFFE5392B))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DangerLink extends StatelessWidget {
  const _DangerLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B).withOpacity(0.7)),
        child: Text(label, style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Providers
// ═══════════════════════════════════════════════

final _unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  if (ref.watch(sessionTokenProvider) == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    if (d is num) return d.toInt();
    if (d is Map) return ((d['unreadCount'] ?? d['count'] ?? 0) as num).toInt();
    return 0;
  } catch (_) {
    return 0;
  }
});

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/users/me/profile');
  if (d is Map) return Map<String, dynamic>.from(d);
  return const {};
});

// ═══════════════════════════════════════════════
//  شاشات فرعية (Security, Vendor)
// ═══════════════════════════════════════════════

/// الأمان — تغيير رمز حماية المحفظة.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _o1 = true, _o2 = true, _o3 = true;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text.trim();
    if (!RegExp(r'^\d{4}$|^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'رمز الحماية الجديد يجب أن يكون 4 أو 6 أرقام');
      return;
    }
    if (pin != _confirm.text.trim()) {
      setState(() => _error = 'تأكيد الرمز غير متطابق');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/customer-wallet/pin', body: {
        if (_current.text.trim().isNotEmpty) 'currentPin': _current.text.trim(),
        'newPin': pin,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير رمز الحماية بنجاح')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message.contains('الحالي') ? 'رمز الحماية الحالي غير صحيح' : e.message);
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('الأمان')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('رمز الحماية يُستخدم لتأكيد عمليات المحفظة.', style: AppText.bodyM(c.textSecondary)),
            const SizedBox(height: 4),
            Text('إن لم تكن قد عيّنت رمزاً من قبل، اترك حقل الحالي فارغاً.', style: AppText.caption(c.textMuted)),
            const SizedBox(height: 16),
            _pinField(_current, 'رمز الحماية الحالي (اختياري)', _o1, () => setState(() => _o1 = !_o1)),
            const SizedBox(height: 12),
            _pinField(_pin, 'الرمز الجديد (4 أو 6 أرقام)', _o2, () => setState(() => _o2 = !_o2)),
            const SizedBox(height: 12),
            _pinField(_confirm, 'تأكيد الرمز الجديد', _o3, () => setState(() => _o3 = !_o3)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ الرمز الجديد'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _pinField(TextEditingController ctrl, String hint, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      obscureText: obscure,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: toggle,
        ),
      ),
    );
  }
}

/// شاشة متجري.
class MyVendorScreen extends ConsumerWidget {
  const MyVendorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('متجري')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.storefront_rounded, size: 64, color: c.primary),
              const SizedBox(height: 16),
              Text('لوحة البائع الكاملة', style: AppText.headingM(c.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'أدر متجرك وخدماتك وحجوزاتك من لوحة البائع على الويب.',
                style: AppText.bodyM(c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
