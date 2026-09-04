import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/unified_header.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/wallet_register_screen.dart';
import '../bookings/my_bookings_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transfers/transfers_screen.dart';
import '../wallet/state/customer_wallet_provider.dart';

/// حسابي — مربوط بالشغل السابق: التوثيق (KYC) + المحفظة (رصيد/رقم حساب)
/// + الحجوزات + سجل العمليات، بلا أزرار ميتة.
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
      body: SafeArea(child: Column(children: [
        const UnifiedHeader(),
        const SizedBox(height: AppSpacing.s12),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            _AccountCard(
              loggedIn: loggedIn,
              isVendor: isVendor,
              email: email,
              profile: profile,
            ),
            if (loggedIn && !isVendor) ...[
              const SizedBox(height: AppSpacing.s12),
              _WalletCard(profile: profile),
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
                onPressed: () => _push(context, const WalletRegisterScreen()),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                label: const Text('أنشئ محفظة جديدة'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary.withOpacity(0.4)),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Column(children: [
                if (loggedIn) ...[
                  _MenuRow(
                    icon: Icons.badge_outlined,
                    title: 'الملف الشخصي والتوثيق',
                    onTap: () => _push(
                      context,
                      isVendor ? const RegisterScreen() : const _ProfileDetailsScreen(),
                    ),
                  ),
                  if (!isVendor)
                    _MenuRow(
                      icon: Icons.calendar_month_outlined,
                      title: 'حجوزاتي',
                      onTap: () => _push(context, const MyBookingsScreen()),
                    ),
                  if (!isVendor)
                    _MenuRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'سجل عمليات المحفظة',
                      onTap: () => _push(context, const TransfersScreen()),
                    ),
                ],
                _MenuRow(
                  icon: Icons.favorite_border,
                  title: 'المفضلة',
                  onTap: () => _push(context, const FavoritesScreen()),
                ),
                _MenuRow(
                  icon: Icons.notifications_none,
                  title: 'الإشعارات',
                  onTap: () => _push(context, const NotificationsScreen()),
                ),
                if (isVendor)
                  _MenuRow(
                    icon: Icons.storefront_rounded,
                    title: 'متجري (حساب تجاري)',
                    onTap: () => _push(context, const _MyVendorScreen()),
                  ),
              ]),
            ),
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
                label: Text('تسجيل الخروج', style: TextStyle(color: c.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(color: c.error.withOpacity(0.4)),
                ),
              ),
            ],
          ],
        )),
      ])),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// بطاقة الحساب — الاسم + الهاتف + شارات النوع والتوثيق.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.loggedIn,
    required this.isVendor,
    required this.email,
    required this.profile,
  });

  final bool loggedIn;
  final bool isVendor;
  final String email;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = '${profile['fullName'] ?? ''}'.trim();
    final phone = '${profile['phone'] ?? ''}';
    final kyc = '${profile['kycStatus'] ?? ''}';
    return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: (isVendor ? c.accent : c.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isVendor ? Icons.storefront_rounded : Icons.person_rounded,
              size: 28,
              color: isVendor ? c.accent : c.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (!loggedIn)
                    _Chip(label: 'اضغط دخول من الأسفل', color: c.textMuted)
                  else ...[
                    _Chip(
                      label: isVendor ? 'حساب تجاري' : 'حساب عادي',
                      color: isVendor ? c.accent : c.primary,
                    ),
                    if (!isVendor) _KycChip(status: kyc),
                  ],
                  if (phone.isNotEmpty)
                    Text(phone,
                        textDirection: TextDirection.ltr,
                        style: AppText.caption(c.textSecondary)),
                ]),
              ])),
        ]),
    );
  }
}

/// شارة حالة التوثيق.
class _KycChip extends StatelessWidget {
  const _KycChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    switch (status) {
      case 'APPROVED':
        return _Chip(label: 'موثق', color: c.success);
      case 'REJECTED':
        return _Chip(label: 'مرفوض', color: c.error);
      default:
        return _Chip(label: 'قيد المراجعة', color: c.warning);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: AppText.caption(color)),
    );
  }
}

/// بطاقة المحفظة — الرصيد الحي + رقم الحساب مع نسخ + زر السجل.
class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.profile});
  final Map<String, dynamic> profile;

  static String _formatAccount(String raw) {
    final d = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (d.length != 16) return raw;
    return '${d.substring(0, 4)}-${d.substring(4, 8)}-${d.substring(8, 12)}-${d.substring(12)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final w = ref.watch(customerWalletProvider).valueOrNull;
    final wMap = (w?['wallet'] as Map?)?.cast<String, dynamic>();
    final balance = (wMap?['balance'] as num?)?.toInt() ?? 0;
    final currency = '${wMap?['currency'] ?? 'USD'}';
    final accId = '${profile['walletAccountId'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 20, color: Colors.white),
          const SizedBox(width: 6),
          Text('محفظتي', style: AppText.bodyL(Colors.white)),
          const Spacer(),
          if (accId.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: accId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم نسخ رقم الحساب'),
                      duration: Duration(seconds: 1)),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Text(_formatAccount(accId),
                      textDirection: TextDirection.ltr,
                      style: AppText.en(Colors.white,
                          size: 12, weight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$balance', style: AppText.price(Colors.white).copyWith(fontSize: 30)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(currency, style: AppText.en(Colors.white70, size: 14)),
          ),
          const Spacer(),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransfersScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: c.primary,
              minimumSize: const Size(0, 38),
            ),
            child: const Text('سجل العمليات'),
          ),
        ]),
      ]),
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: (rejected ? c.error : c.warning).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (rejected ? c.error : c.warning).withOpacity(0.3)),
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
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      ListTile(
        leading: Icon(icon, color: c.primary),
        title: Text(title, style: AppText.bodyL(c.textPrimary)),
        trailing: Icon(Icons.chevron_left_rounded, color: c.textMuted),
        onTap: onTap,
      ),
      Divider(height: 1, color: c.border, indent: 56),
    ]);
  }
}

/// تفاصيل الملف الشخصي والتوثيق — قراءة فقط (الرقم الوطني مقنّع).
class _ProfileDetailsScreen extends ConsumerWidget {
  const _ProfileDetailsScreen();

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
    final rows = [
      ('الاسم الثلاثي', '${p['fullName'] ?? ''}'),
      ('اسم الأب', '${p['fatherName'] ?? ''}'),
      ('اسم الأم', '${p['motherName'] ?? ''}'),
      ('الرقم الوطني', _maskNationalId('${p['nationalId'] ?? ''}')),
      ('الموبايل', '${p['phone'] ?? ''}'),
      ('البريد', email),
      ('المحافظة', '${p['governorate'] ?? ''}'),
      ('المدينة', '${p['city'] ?? ''}'),
    ];
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
              _KycChip(status: '${p['kycStatus'] ?? ''}'),
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
              for (final r in rows)
                if (r.$2.isNotEmpty) ...[
                  ListTile(
                    title: Text(r.$1, style: AppText.caption(c.textSecondary)),
                    subtitle: Text(r.$2,
                        style: AppText.bodyL(c.textPrimary),
                        textDirection:
                            RegExp(r'^[0-9+]').hasMatch(r.$2) ? TextDirection.ltr : null),
                  ),
                  if (r != rows.lastWhere((e) => e.$2.isNotEmpty))
                    Divider(height: 1, color: c.border, indent: 16),
                ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// بيانات المستخدم الحالي — /users/me/profile.
final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/users/me/profile');
  if (d is Map) return Map<String, dynamic>.from(d);
  return const {};
});

/// شاشة متجري — تحويل الحساب إلى تجاري + فتح متجر (مبسطة).
class _MyVendorScreen extends ConsumerWidget {
  const _MyVendorScreen();

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
