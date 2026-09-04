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

/// حسابي — الملف الشخصي والمحفظة بتصميم نظيف (RTL كامل).
///
/// * ترويسة: جرس الإشعارات مع شارة غير المقروء + أيقونة الأمان.
/// * بطاقة المستخدم: أفاتار بالأحرف الأولى + شارة التوثيق + الاسم الثلاثي
///   + رقم الحساب (4-4-4-4) مع نسخ + شارة نوع الحساب.
/// * بطاقة خيارات واحدة: التوثيق، حجوزاتي، سجل المحفظة، المفضلة، الأمان وPIN.
/// * خروج Outline أحمر مع مسافة أمان من الشريط السفلي.
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
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.s12,
            AppSpacing.screenH,
            32, // مسافة أمان من الشريط السفلي وزر QR
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(loggedIn: loggedIn),
              const SizedBox(height: AppSpacing.s12),
              _UserInfoCard(
                loggedIn: loggedIn,
                isVendor: isVendor,
                email: email,
                profile: profile,
              ),
              if (loggedIn && !isVendor) ...[
                const SizedBox(height: AppSpacing.s12),
                _KycBanner(profile: profile),
              ],
              if (!loggedIn) ...[
                const SizedBox(height: AppSpacing.s12),
                ElevatedButton.icon(
                  onPressed: () => _push(context, const LoginScreen()),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('تسجيل الدخول'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: AppSpacing.s8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _push(context, const WalletRegisterScreen()),
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 20),
                  label: const Text('أنشئ محفظة جديدة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary.withOpacity(0.4)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              if (loggedIn)
                _MenuCard(isVendor: isVendor)
              else
                const _MenuCard(isVendor: false, guest: true),
              if (loggedIn) ...[
                const SizedBox(height: AppSpacing.s16),
                OutlinedButton.icon(
                  onPressed: () async {
                    ref.read(sessionTokenProvider.notifier).state = null;
                    await SessionService.saveToken(null);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم تسجيل الخروج'),
                            duration: Duration(seconds: 1)),
                      );
                    }
                  },
                  icon: Icon(Icons.logout_rounded, size: 20, color: c.error),
                  label: Text('تسجيل الخروج',
                      style: TextStyle(color: c.error)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(color: c.error.withOpacity(0.4)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// الترويسة: جرس مع شارة + إعدادات (الأمان) — بلا UnifiedHeader هنا حسب التصميم.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unread = loggedIn
        ? ref.watch(_unreadProvider).valueOrNull ?? 0
        : 0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        // جرس يسار مع شارة العداد
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: !loggedIn
                ? null
                : () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()))
                    .then((_) => ref.invalidate(_unreadProvider)),
            icon: Icon(Icons.notifications_none_rounded,
                size: 26, color: c.textPrimary),
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: c.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.background, width: 1.5),
                ),
                child: Center(
                  child: Text(unread > 99 ? '99+' : '$unread',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
        const Spacer(),
        Text('حسابي', style: AppText.headingM(c.textPrimary)),
        const Spacer(),
        // أيقونة الأمان يمين
        IconButton(
          tooltip: 'الأمان',
          onPressed: !loggedIn
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SecurityScreen())),
          icon: Icon(Icons.settings_outlined, size: 26, color: c.textPrimary),
        ),
      ]),
    );
  }
}

/// بطاقة المستخدم: أفاتار + شارة توثيق + الاسم + رقم الحساب + نوع الحساب.
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
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  static String formatAccount(String raw) {
    final d = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (d.length != 16) return raw;
    return '${d.substring(0, 4)}-${d.substring(4, 8)}-${d.substring(8, 12)}-${d.substring(12)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = '${profile['fullName'] ?? ''}'.trim();
    final phone = '${profile['phone'] ?? ''}';
    final kyc = '${profile['kycStatus'] ?? ''}';
    final accId = '${profile['walletAccountId'] ?? ''}';
    final premium = profile['isPremium'] == true;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        // أفاتار مربع الحواف + شارة التوثيق
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: (isVendor ? c.accent : c.primary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                !loggedIn ? '؟' : _initials(name.isNotEmpty ? name : email),
                style: AppText.headingM(
                    isVendor ? c.accent : c.primary),
              ),
            ),
          ),
          if (loggedIn && !isVendor)
            Positioned(
              left: -4,
              bottom: -4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kyc == 'APPROVED'
                      ? c.success
                      : kyc == 'REJECTED'
                          ? c.error
                          : c.warning,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: Icon(
                  kyc == 'APPROVED'
                      ? Icons.check_rounded
                      : kyc == 'REJECTED'
                          ? Icons.close_rounded
                          : Icons.hourglass_top_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ]),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            !loggedIn
                ? 'زائر'
                : name.isNotEmpty
                    ? name
                    : (email.isEmpty ? 'حسابي' : email),
            style: AppText.headingS(c.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (loggedIn && !isVendor && accId.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: accId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم نسخ رقم الحساب'),
                      duration: Duration(seconds: 1)),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatAccount(accId),
                    textDirection: TextDirection.ltr,
                    style: AppText.en(c.textSecondary,
                        size: 13, weight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 14, color: c.textMuted),
              ]),
            )
          else if (phone.isNotEmpty)
            Text(phone,
                textDirection: TextDirection.ltr,
                style: AppText.caption(c.textSecondary)),
          const SizedBox(height: 6),
          if (loggedIn)
            _AccountBadge(
                isVendor: isVendor, premium: premium, kyc: kyc),
        ])),
      ]),
    );
  }
}

/// شارة نوع الحساب: تجاري / مميز / عادي (+ حالة التوثيق نصاً للعادي).
class _AccountBadge extends StatelessWidget {
  const _AccountBadge(
      {required this.isVendor, required this.premium, required this.kyc});
  final bool isVendor;
  final bool premium;
  final String kyc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final String label;
    final Color color;
    if (isVendor) {
      label = 'حساب تجاري';
      color = c.accent;
    } else if (premium) {
      label = 'حساب مميز';
      color = c.warning;
    } else {
      label = 'حساب عادي';
      color = c.primary;
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(label, style: AppText.caption(color)),
        ),
        if (!isVendor)
          Text(
            kyc == 'APPROVED'
                ? 'موثق'
                : kyc == 'REJECTED'
                    ? 'التوثيق مرفوض'
                    : 'قيد المراجعة',
            style: AppText.caption(c.textMuted),
          ),
      ],
    );
  }
}

/// بطاقة خيارات واحدة بفواصل خفيفة — بلا تكرار.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.isVendor, this.guest = false});
  final bool isVendor;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <_MenuRow>[
      if (!guest) ...[
        _MenuRow(
          icon: Icons.badge_outlined,
          title: 'الملف الشخصي والتوثيق',
          onTap: () => ProfileScreen._push(
              context,
              isVendor
                  ? const RegisterScreen()
                  : const ProfileDetailsScreen()),
        ),
        if (!isVendor)
          _MenuRow(
            icon: Icons.calendar_month_outlined,
            title: 'حجوزاتي',
            onTap: () =>
                ProfileScreen._push(context, const MyBookingsScreen()),
          ),
        if (!isVendor)
          _MenuRow(
            icon: Icons.receipt_long_outlined,
            title: 'سجل عمليات المحفظة',
            onTap: () =>
                ProfileScreen._push(context, const TransfersScreen()),
          ),
      ],
      _MenuRow(
        icon: Icons.favorite_border,
        title: 'المفضلة',
        onTap: () => ProfileScreen._push(context, const FavoritesScreen()),
      ),
      if (!guest)
        _MenuRow(
          icon: Icons.lock_outline_rounded,
          title: 'الأمان وتغيير رمز الـ PIN',
          onTap: () =>
              ProfileScreen._push(context, const SecurityScreen()),
        ),
      if (isVendor)
        _MenuRow(
          icon: Icons.storefront_rounded,
          title: 'متجري (حساب تجاري)',
          onTap: () =>
              ProfileScreen._push(context, const MyVendorScreen()),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1)
            Divider(height: 1, color: c.border, indent: 56),
        ],
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon, color: c.primary),
      title: Text(title, style: AppText.bodyL(c.textPrimary)),
      trailing: Icon(Icons.chevron_left_rounded, color: c.textMuted),
      onTap: onTap,
    );
  }
}

/// تنبيه حالة التوثيق (قيد المراجعة / مرفوض مع السبب).
class _KycBanner extends StatelessWidget {
  const _KycBanner({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = '${profile['kycStatus'] ?? ''}';
    if (status == 'APPROVED' || status.isEmpty) {
      return const SizedBox.shrink();
    }
    final rejected = status == 'REJECTED';
    final note = '${profile['kycNote'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: (rejected ? c.error : c.warning).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: (rejected ? c.error : c.warning).withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
          size: 20,
          color: rejected ? c.error : c.warning,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            rejected
                ? (note.isNotEmpty
                    ? 'تم رفض التوثيق: $note'
                    : 'تم رفض التوثيق — راجع الدعم')
                : 'حسابك قيد مراجعة التوثيق — المحفظة تتفعل بعد الموافقة',
            style: AppText.bodyM(rejected ? c.error : c.textPrimary),
          ),
        ),
      ]),
    );
  }
}

/// تفاصيل الملف الشخصي والتوثيق — قراءة فقط (الرقم الوطني مقنّع).
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
      ('رقم الحساب',
          _UserInfoCard.formatAccount('${p['walletAccountId'] ?? ''}')),
    ];
    final visible = rows.where((e) => e.$2.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('الملف الشخصي والتوثيق')),
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
                kyc == 'APPROVED'
                    ? 'موثق'
                    : kyc == 'REJECTED'
                        ? 'مرفوض'
                        : 'قيد المراجعة',
                style: AppText.bodyL(kyc == 'APPROVED'
                    ? c.success
                    : kyc == 'REJECTED'
                        ? c.error
                        : c.warning),
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
                  title:
                      Text(visible[i].$1, style: AppText.caption(c.textSecondary)),
                  subtitle: Text(visible[i].$2,
                      style: AppText.bodyL(c.textPrimary),
                      textDirection:
                          RegExp(r'^[0-9+]').hasMatch(visible[i].$2)
                              ? TextDirection.ltr
                              : null),
                ),
                if (i < visible.length - 1)
                  Divider(height: 1, color: c.border, indent: 16),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// الأمان — تغيير رمز حماية المحفظة (POST /customer-wallet/pin).
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
        if (_current.text.trim().isNotEmpty)
          'currentPin': _current.text.trim(),
        'newPin': pin,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير رمز الحماية بنجاح')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message.contains('الحالي')
          ? 'رمز الحماية الحالي غير صحيح'
          : e.message);
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('رمز الحماية يُستخدم لتأكيد عمليات المحفظة.',
                  style: AppText.bodyM(c.textSecondary)),
              const SizedBox(height: AppSpacing.s4),
              Text('إن لم تكن قد عيّنت رمزاً من قبل، اترك حقل الحالي فارغاً.',
                  style: AppText.caption(c.textMuted)),
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
                    icon: Icon(_o1
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
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
                    icon: Icon(_o2
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
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
                    icon: Icon(_o3
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _o3 = !_o3),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ الرمز الجديد'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(_error!,
                    style: AppText.bodyM(c.error), textAlign: TextAlign.center),
              ],
            ]),
      ),
    );
  }
}

/// عدد الإشعارات غير المقروءة — للشارة.
final _unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  if (ref.watch(sessionTokenProvider) == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    if (d is num) return d.toInt();
    if (d is Map) {
      return ((d['unreadCount'] ?? d['count'] ?? 0) as num).toInt();
    }
    return 0;
  } catch (_) {
    return 0;
  }
});

/// بيانات المستخدم الحالي — /users/me/profile.
final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/users/me/profile');
  if (d is Map) return Map<String, dynamic>.from(d);
  return const {};
});

/// شاشة متجري — تحويل الحساب إلى تجاري + فتح متجر (مبسطة).
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
            Text('أدر متجرك وخدماتك وحجوزاتك من لوحة البائع على الويب، أو أضف متجرك إن لم يكن لديك بعد.',
                style: AppText.bodyM(c.textSecondary), textAlign: TextAlign.center),
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

/// نموذج تسجيل متجر جديد (لحساب VENDOR).
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
    _name.dispose(); _desc.dispose(); _phone.dispose();
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'اسم المتجر *'),
          ),
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
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'وصف المتجر'),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'رقم الهاتف'),
          ),
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
