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

/// حسابي — تصميم نظيف (خلفية بيضاء/رمادي فاتح)، صناديق مستقلة، RTL كامل.
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Column(children: [
          // ── ترويسة ثابتة ──
          _Header(loggedIn: loggedIn),

          // ── محتوى قابل للتمرير ──
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // ── بطاقة المستخدم ──
                  _UserCard(
                    loggedIn: loggedIn,
                    isVendor: isVendor,
                    email: email,
                    profile: profile,
                  ),

                  // ── تنبيه التوثيق ──
                  if (loggedIn && !isVendor && '${profile['kycStatus'] ?? ''}' == 'PENDING') ...[
                    const SizedBox(height: 12),
                    _KycBanner(profile: profile),
                  ],

                  // ── أزرار الزائر ──
                  if (!loggedIn) ...[
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: 'تسجيل الدخول',
                      icon: Icons.login_rounded,
                      onTap: () => _push(const LoginScreen()),
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(
                      label: 'أنشئ محفظة جديدة',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _push(const WalletRegisterScreen()),
                    ),
                  ],

                  // ── صناديق مستقلة ──
                  if (loggedIn) ...[
                    const SizedBox(height: 20),

                    _StandaloneCard(
                      icon: Icons.person_outline_rounded,
                      title: 'الملف الشخصي',
                      onTap: () => _push(
                        isVendor ? const RegisterScreen() : const AccountInfoScreen(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.verified_outlined,
                      title: 'توثيق الحساب',
                      badge: _kycBadge(profile),
                      onTap: () => _push(const AccountInfoScreen()),
                    ),
                    if (!isVendor) ...[
                      const SizedBox(height: 10),
                      _StandaloneCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'حجوزاتي',
                        onTap: () => _push(const MyBookingsScreen()),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.favorite_border,
                      title: 'المفضلة',
                      onTap: () => _push(const FavoritesScreen()),
                    ),

                    const SizedBox(height: 20),

                    _StandaloneCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'رمز الدخول (PIN)',
                      onTap: () => _push(const SecurityScreen()),
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.security_outlined,
                      title: 'الأمان والتحقق',
                      onTap: () => _push(const SecurityScreen()),
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.devices_outlined,
                      title: 'إدارة الأجهزة',
                      onTap: () {},
                    ),

                    const SizedBox(height: 20),

                    _StandaloneCard(
                      icon: Icons.dark_mode_outlined,
                      title: 'المظهر',
                      trailing: 'فاتح',
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.language_outlined,
                      title: 'اللغة',
                      trailing: 'العربية',
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.help_outline_rounded,
                      title: 'الدعم والمساعدة',
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.description_outlined,
                      title: 'الشروط والخصوصية',
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _StandaloneCard(
                      icon: Icons.info_outline_rounded,
                      title: 'حول التطبيق',
                      trailing: 'v1.0.0',
                      onTap: () {},
                    ),

                    const SizedBox(height: 24),

                    // ── تسجيل الخروج ──
                    _LogoutCard(onTap: () => _confirmLogout(context, ref)),

                    const SizedBox(height: 10),

                    // ── حذف الحساب ──
                    _DeleteAccountCard(onTap: () => _confirmDelete(context)),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE5392B), size: 22),
            SizedBox(width: 8),
            Text('حذف الحساب'),
          ]),
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
//  الترويسة
// ═══════════════════════════════════════════════

class _Header extends ConsumerWidget {
  const _Header({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = loggedIn ? ref.watch(_unreadProvider).valueOrNull ?? 0 : 0;
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              onPressed: !loggedIn
                  ? null
                  : () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                      .then((_) => ref.invalidate(_unreadProvider)),
              icon: const Icon(Icons.notifications_none_rounded, size: 26, color: Color(0xFF1A1A2E)),
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
          Text('حسابي', style: AppText.headingM(const Color(0xFF1A1A2E))),
          const Spacer(),
          const SizedBox(width: 48),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // أفاتار مع كاميرا
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F8),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD6EAF0), width: 2),
            ),
            child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF0AAEBF)),
          ),
          Positioned(
            left: -2,
            bottom: -2,
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
          if (loggedIn && !isVendor)
            Positioned(
              right: -2,
              bottom: -2,
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
        const SizedBox(height: 12),

        Text(
          !loggedIn
              ? 'زائر'
              : name.isNotEmpty
                  ? name
                  : (email.isEmpty ? 'حسابي' : email),
          style: AppText.headingM(const Color(0xFF1A1A2E)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

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
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  formatAccount(accId),
                  textDirection: TextDirection.ltr,
                  style: AppText.en(const Color(0xFF4A6B6F), size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF8AA9AD)),
              ]),
            ),
          )
        else if (phone.isNotEmpty)
          Text(phone, textDirection: TextDirection.ltr, style: AppText.caption(const Color(0xFF8AA9AD))),

        const SizedBox(height: 8),

        if (loggedIn) _AccountBadge(isVendor: isVendor, premium: premium, kyc: kyc),
      ]),
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
    final Color bg, fg;
    if (isVendor) {
      label = 'حساب تجاري';
      bg = const Color(0xFFFFA726).withOpacity(0.1);
      fg = const Color(0xFFFFA726);
    } else if (premium) {
      label = 'حساب مميز';
      bg = const Color(0xFFFFD54F).withOpacity(0.15);
      fg = const Color(0xFFF9A825);
    } else {
      label = 'حساب عادي';
      bg = const Color(0xFF0AAEBF).withOpacity(0.08);
      fg = const Color(0xFF0AAEBF);
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
        ),
        if (!isVendor)
          Text(
            kyc == 'APPROVED' ? 'موثق' : kyc == 'REJECTED' ? 'مرفوض' : 'قيد المراجعة',
            style: AppText.caption(const Color(0xFF8AA9AD)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  صندوق مستقل
// ═══════════════════════════════════════════════

class _StandaloneCard extends StatelessWidget {
  const _StandaloneCard({
    required this.icon,
    required this.title,
    this.trailing,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0AAEBF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF0AAEBF)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: AppText.bodyL(const Color(0xFF1A1A2E)))),
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
              const Icon(Icons.chevron_left_rounded, color: Color(0xFFCCCCCC), size: 22),
            ]),
          ),
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
    final note = '${profile['kycNote'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded, size: 20, color: Color(0xFFFFA726)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'حسابك قيد مراجعة التوثيق — المحفظة تتفعل بعد الموافقة',
            style: AppText.bodyM(const Color(0xFF1A1A2E)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
//  أزرار الزائر
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
        color: const Color(0xFF0AAEBF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF0AAEBF).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6EAF0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: const Color(0xFF0AAEBF)),
              const SizedBox(width: 8),
              Text(label, style: AppText.button(const Color(0xFF0AAEBF))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  إجراءات تدميرية
// ═══════════════════════════════════════════════

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5392B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE5392B)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('تسجيل الخروج', style: AppText.bodyL(const Color(0xFFE5392B)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5392B).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5392B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFE5392B)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('حذف الحساب', style: AppText.bodyL(const Color(0xFFE5392B)))),
              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE5392B)),
            ]),
          ),
        ),
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
//  شاشات فرعية
// ═══════════════════════════════════════════════

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير رمز الحماية بنجاح')));
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
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('الأمان')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('رمز الحماية يُستخدم لتأكيد عمليات المحفظة.', style: AppText.bodyM(c.textSecondary)),
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

class MyVendorScreen extends ConsumerWidget {
  const MyVendorScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('متجري')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_rounded, size: 64, color: Color(0xFF0AAEBF)),
              const SizedBox(height: 16),
              Text('لوحة البائع الكاملة', style: AppText.headingM(const Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Text('أدر متجرك من لوحة البائع على الويب.', style: AppText.bodyM(const Color(0xFF8AA9AD)), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}
