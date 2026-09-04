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

/// حسابي — خلفية Gradient + أقسام منظمة + هيدر ثابت (RTL كامل).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            stops: const [0.0, 0.35, 0.6],
          ),
        ),
        child: Column(children: [
          // هيدر ثابت لا يتحرك
          _ProfileHeader(loggedIn: loggedIn),

          // المحتوى القابل للتمرير
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.s16),

                  // بطاقة المستخدم
                  _UserInfoCard(
                    loggedIn: loggedIn,
                    isVendor: isVendor,
                    email: email,
                    profile: profile,
                  ),

                  // تنبيه التوثيق
                  if (loggedIn && !isVendor) ...[
                    const SizedBox(height: AppSpacing.s12),
                    _KycBanner(profile: profile),
                  ],

                  // أزرار الدخول للزوار
                  if (!loggedIn) ...[
                    const SizedBox(height: AppSpacing.s16),
                    _GradientButton(
                      label: 'تسجيل الدخول',
                      icon: Icons.login_rounded,
                      onTap: () => _push(context, const LoginScreen()),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _OutlineButton(
                      label: 'أنشئ محفظة جديدة',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _push(context, const WalletRegisterScreen()),
                    ),
                  ],

                  if (loggedIn) ...[
                    const SizedBox(height: AppSpacing.s20),

                    // ── قسم: توثيق الحساب ──
                    _SectionCard(
                      title: 'توثيق الحساب',
                      children: [
                        _MenuTile(
                          icon: Icons.badge_outlined,
                          title: 'الملفي الشخصي والتوثيق',
                          onTap: () => _push(
                            context,
                            isVendor ? const RegisterScreen() : const ProfileDetailsScreen(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: معلومات الحساب ──
                    _SectionCard(
                      title: 'معلومات الحساب',
                      children: [
                        _MenuTile(
                          icon: Icons.person_outline_rounded,
                          title: 'البيانات الشخصية',
                          onTap: () => _push(context, const AccountInfoScreen()),
                        ),
                        if (!isVendor) ...[
                          _Divider(),
                          _MenuTile(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'تفاصيل المحفظة',
                            onTap: () => _push(context, const TransfersScreen()),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: إعدادات الأمان ──
                    _SectionCard(
                      title: 'إعدادات الأمان',
                      children: [
                        _MenuTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'تغيير رمز الـ PIN',
                          onTap: () => _push(context, const SecurityScreen()),
                        ),
                        _Divider(),
                        _MenuTile(
                          icon: Icons.security_outlined,
                          title: 'الأمان وحماية الحساب',
                          onTap: () => _push(context, const SecurityScreen()),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: الأجهزة المرتبطة ──
                    _SectionCard(
                      title: 'الاجهزة المرتبطة',
                      children: [
                        _MenuTile(
                          icon: Icons.devices_outlined,
                          title: 'ادارة الاجهزة',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: الاعدادات ──
                    _SectionCard(
                      title: 'الاعدادات',
                      children: [
                        _MenuTile(
                          icon: Icons.language_outlined,
                          title: 'اللغة',
                          trailing: 'العربية',
                          onTap: () {},
                        ),
                        _Divider(),
                        _MenuTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'المظهر',
                          trailing: 'فاتح',
                          onTap: () {},
                        ),
                        _Divider(),
                        _MenuTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'الاشعارات',
                          onTap: () => _push(context, const NotificationsScreen()),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: المفضلة ──
                    _SectionCard(
                      title: 'المفضلة',
                      children: [
                        _MenuTile(
                          icon: Icons.favorite_border,
                          title: 'قائمة المفضلة',
                          onTap: () => _push(context, const FavoritesScreen()),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── قسم: حجوزاتي ──
                    if (!isVendor)
                      _SectionCard(
                        title: 'حجوزاتي',
                        children: [
                          _MenuTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'حجوزاتي',
                            onTap: () => _push(context, const MyBookingsScreen()),
                          ),
                          _Divider(),
                          _MenuTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'سجل عمليات المحفظة',
                            onTap: () => _push(context, const TransfersScreen()),
                          ),
                        ],
                      ),

                    if (isVendor) ...[
                      const SizedBox(height: AppSpacing.s16),
                      _SectionCard(
                        title: 'التجارة',
                        children: [
                          _MenuTile(
                            icon: Icons.storefront_rounded,
                            title: 'متجري (حساب تجاري)',
                            onTap: () => _push(context, const MyVendorScreen()),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: AppSpacing.s16),
                    _SectionCard(
                      title: 'العام',
                      children: [
                        _MenuTile(
                          icon: Icons.favorite_border,
                          title: 'المفضلة',
                          onTap: () => _push(context, const FavoritesScreen()),
                        ),
                      ],
                    ),
                  ],

                  // خروج
                  if (loggedIn) ...[
                    const SizedBox(height: AppSpacing.s24),
                    _LogoutButton(
                      onTap: () async {
                        ref.read(sessionTokenProvider.notifier).state = null;
                        await SessionService.saveToken(null);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل الخروج'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ─────────────────────── الهيدر الثابت ───────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = loggedIn ? ref.watch(_unreadProvider).valueOrNull ?? 0 : 0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            // جرس يسار + شارة العداد
            Stack(clipBehavior: Clip.none, children: [
              IconButton(
                tooltip: 'الاشعارات',
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
                      color: const Color(0xFFE53935),
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
            // إعدادات يمين
            IconButton(
              tooltip: 'الاعدادات',
              onPressed: !loggedIn
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
              icon: const Icon(Icons.settings_outlined, size: 26, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────── بطاقة المستخدم ───────────────────────

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
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

  /// تنسيق رقم الحساب: مسافة بين كل 4 أرقام
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

    return Column(children: [
      // أفاتار دائري كبير
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: Text(
              !loggedIn ? '؟' : _initials(name.isNotEmpty ? name : email),
              style: AppText.headingL(Colors.white),
            ),
          ),
        ),
        if (loggedIn && !isVendor)
          Positioned(
            left: -2,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: kyc == 'APPROVED'
                    ? const Color(0xFF4CAF50)
                    : kyc == 'REJECTED'
                        ? const Color(0xFFE53935)
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

      // رقم الحساب مع نسخ — مسافة بين كل 4 أرقام
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
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppText.caption(isVendor ? Colors.white : Colors.white.withOpacity(0.9)),
          ),
        ),
        if (!isVendor)
          Text(
            kyc == 'APPROVED' ? 'موثق' : kyc == 'REJECTED' ? 'التوثيق مرفوض' : 'قيد المراجعة',
            style: AppText.caption(Colors.white.withOpacity(0.7)),
          ),
      ],
    );
  }
}

// ─────────────────────── بطاقة قسم ───────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            title,
            style: AppText.bodyM(const Color(0xFF4A6B6F)),
          ),
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
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── عنصر قائمة ───────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, this.trailing, required this.onTap});
  final IconData icon;
  final String title;
  final String? trailing;
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
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52);
  }
}

// ─────────────────────── تنبيه التوثيق ───────────────────────

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
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (rejected ? const Color(0xFFE53935) : const Color(0xFFFFA726)).withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
          size: 20,
          color: rejected ? const Color(0xFFE53935) : const Color(0xFFFFA726),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            rejected
                ? (note.isNotEmpty ? 'تم رفض التوثيق: $note' : 'تم رفض التوثيق — راجع الدعم')
                : 'حسابك قيد مراجعة التوثيق — المحفظة تتفعل بعد الموافقة',
            style: AppText.bodyM(rejected ? const Color(0xFFE53935) : const Color(0xFF0A2E33)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────── أزرار مساعدة ───────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.icon, required this.onTap});
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

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.icon, required this.onTap});
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE53935)),
              const SizedBox(width: 8),
              Text('تسجيل الخروج', style: AppText.button(const Color(0xFFE53935))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Providers ───────────────────────

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

// ─────────────────────── شاشات فرعية ───────────────────────

/// تفاصيل الملف الشخصي والتوثيق — قراءة فقط.
class ProfileDetailsScreen extends ConsumerWidget {
  const ProfileDetailsScreen({super.key});

  static String _maskNationalId(String v) {
    if (v.length != 11) return v;
    return '${v.substring(0, 2)}*******${v.substring(9)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final me = ref.watch(_meProvider).valueOrNull ?? const {};
    final email = '${me['email'] ?? ''}';
    final p = ((me['profile'] as Map?)?.cast<String, dynamic>()) ?? const {};
    final kyc = '${p['kycStatus'] ?? ''}';
    final rows = [
      ('الاسم الثلاثي', '${p['fullName'] ?? ''}'),
      ('اسم الأب', '${p['fatherName'] ?? ''}'),
      ('اسم الأم', '${p['motherName'] ?? ''}'),
      ('الرقم الوطني', _maskNationalId('${p['nationalId'] ?? ''}')),
      ('الموبايل', '${p['phone'] ?? ''}'),
      ('البريد', email),
      ('المحافظة', '${p['governorate'] ?? ''}'),
      ('المدينة', '${p['city'] ?? ''}'),
      ('رقم الحساب', _UserInfoCard.formatAccount('${p['walletAccountId'] ?? ''}')),
    ];
    final visible = rows.where((e) => e.$2.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('الملفي الشخصي والتوثيق')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Text('حالة التوثيق:', style: AppText.bodyM(c.textSecondary)),
              const SizedBox(width: 8),
              Text(
                kyc == 'APPROVED' ? 'موثق' : kyc == 'REJECTED' ? 'مرفوض' : 'قيد المراجعة',
                style: AppText.bodyL(kyc == 'APPROVED' ? c.success : kyc == 'REJECTED' ? c.error : c.warning),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s12),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(children: [
              for (var i = 0; i < visible.length; i++) ...[
                ListTile(
                  title: Text(visible[i].$1, style: AppText.caption(c.textSecondary)),
                  subtitle: Text(
                    visible[i].$2,
                    style: AppText.bodyL(c.textPrimary),
                    textDirection: RegExp(r'^[0-9+]').hasMatch(visible[i].$2) ? TextDirection.ltr : null,
                  ),
                ),
                if (i < visible.length - 1) Divider(height: 1, color: c.border, indent: 16),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

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
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('الأمان وتغيير رمز الـ PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('رمز الحماية يُستخدم لتأكيد عمليات المحفظة.', style: AppText.bodyM(c.textSecondary)),
          const SizedBox(height: AppSpacing.s4),
          Text('إن لم تكن قد عيّنت رمزاً من قبل، اترك حقل الحالي فارغاً.', style: AppText.caption(c.textMuted)),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _current,
            keyboardType: TextInputType.number,
            obscureText: _o1,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'رمز الحماية الحالي (اختياري أول مرة)',
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_o1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _o1 = !_o1),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: _o2,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'الرمز الجديد (4 أو 6 أرقام)',
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_o2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _o2 = !_o2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _confirm,
            keyboardType: TextInputType.number,
            obscureText: _o3,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'تأكيد الرمز الجديد',
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_o3 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _o3 = !_o3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ الرمز الجديد'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
        ]),
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
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('متجري')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.storefront_rounded, size: 64, color: c.primary),
            const SizedBox(height: AppSpacing.s16),
            Text('لوحة البائع الكاملة', style: AppText.headingM(c.textPrimary)),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'أدر متجرك وخدماتك وحجوزاتك من لوحة البائع على الويب، أو أضف متجرك إن لم يكن لديك بعد.',
              style: AppText.bodyM(c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RegisterVendorScreen())),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('إضافة متجري'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RegisterVendorScreen extends ConsumerStatefulWidget {
  const _RegisterVendorScreen();

  @override
  ConsumerState<_RegisterVendorScreen> createState() => _RegisterVendorScreenState();
}

class _RegisterVendorScreenState extends ConsumerState<_RegisterVendorScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  String? _categoryId;
  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>> _cats = const [];

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      final d = await ref.read(apiClientProvider).get('/categories');
      if (mounted) setState(() => _cats = (d as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_categoryId == null || _name.value.text.trim().isEmpty) {
      setState(() => _error = 'اختر التصنيف وأدخل اسم المتجر');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/vendors', body: {
        'name': _name.value.text.trim(),
        'categoryId': _categoryId,
        'description': _desc.value.text.trim(),
        'phone': _phone.value.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء متجرك — بانتظار موافقة الإدارة'), duration: Duration(seconds: 2)),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('إضافة متجري')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'اسم المتجر *')),
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<String>(
            value: _categoryId,
            hint: const Text('التصنيف *'),
            items: _cats.map((cat) => DropdownMenuItem(
              value: cat['id'] as String,
              child: Text((cat['nameAr'] ?? '') as String),
            )).toList(),
            onChanged: (v) => setState(() => _categoryId = v),
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'وصف المتجر')),
          const SizedBox(height: AppSpacing.s12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'رقم الهاتف')),
          const SizedBox(height: AppSpacing.s20),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('إنشاء المتجر'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}
