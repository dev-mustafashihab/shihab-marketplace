import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../vendors/vendor_details_screen.dart';

/// حسابي — كل الميزات فعالة: جلسة حية، مفضلة، إشعارات، حساب تجاري/عادي، تسجيل خروج.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final token = ref.watch(sessionTokenProvider);
    final loggedIn = token != null;
    final meAsync = loggedIn ? ref.watch(_meProvider) : const AsyncValue.data(null);
    final role = ((meAsync.valueOrNull ?? const {})['role'] ?? 'CUSTOMER') as String;
    final email = ((meAsync.valueOrNull ?? const {})['email'] ?? '') as String;

    final items = [
      (Icons.person_outline, 'الملف الشخصي', _openProfile),
      (Icons.location_on_outlined, 'عناويني', null),
      (Icons.favorite_border, 'المفضلة', (_) => _push(context, const FavoritesScreen())),
      (Icons.notifications_none, 'الإشعارات', (_) => _push(context, const NotificationsScreen())),
      (Icons.storefront_rounded, 'متجري (حساب تجاري)', role == 'VENDOR' ? (_) => _push(context, const _MyVendorScreen()) : null),
      (Icons.support_agent_outlined, 'الدعم', null),
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          // بطاقة الحساب — تنقر للدخول إن زائر، وتعرض البريد/النوع إن مسجل
          InkWell(
            onTap: loggedIn ? null : () => _push(context, const LoginScreen()),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border)),
              child: Row(children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: role == 'VENDOR' ? c.accent.withOpacity(0.15) : c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(role == 'VENDOR' ? Icons.storefront_rounded : Icons.person_rounded,
                      size: 28, color: role == 'VENDOR' ? c.accent : c.primary),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loggedIn ? (email.isEmpty ? 'حسابي' : email) : 'زائر',
                      style: AppText.headingS(c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    !loggedIn
                        ? 'اضغط لتسجيل الدخول'
                        : role == 'VENDOR' ? 'حساب تجاري (بائع)' : 'حساب عادي',
                    style: AppText.caption(role == 'VENDOR' ? c.accent : c.textMuted),
                  ),
                ])),
                if (!loggedIn) Icon(Icons.chevron_left_rounded, color: c.textMuted),
              ]),
            ),
          ),
          if (!loggedIn) ...[
            const SizedBox(height: AppSpacing.s12),
            // إنشاء حساب — عادي أو تجاري
            OutlinedButton.icon(
              onPressed: () => _push(context, const RegisterScreen()),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('إنشاء حساب جديد (عادي أو تجاري)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary.withOpacity(0.4)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          // قائمة الميزات
          Container(
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border)),
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  leading: Icon(items[i].$1, color: c.primary),
                  title: Text(items[i].$2, style: AppText.bodyL(c.textPrimary)),
                  trailing: Icon(Icons.chevron_left_rounded, color: c.textMuted),
                  onTap: () => items[i].$3?.call(context, ref),
                ),
                if (i < items.length - 1) Divider(height: 1, color: c.border, indent: 56),
              ],
            ]),
          ),
          // تسجيل الخروج
          if (loggedIn) ...[
            const SizedBox(height: AppSpacing.s16),
            OutlinedButton.icon(
              onPressed: () async {
                ref.read(sessionTokenProvider.notifier).state = null;
                await SessionService.saveToken(null);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الخروج'), duration: Duration(seconds: 1)),
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
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openProfile(BuildContext context, WidgetRef ref) {
    final token = ref.read(sessionTokenProvider);
    _push(context, token == null ? const LoginScreen() : const RegisterScreen());
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
