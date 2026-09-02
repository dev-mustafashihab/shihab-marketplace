import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// شاشة إنشاء حساب — عادي (عميل) أو تجاري (بائع/محل).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'CUSTOMER';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/auth/register', body: {
        'email': _email.value.text.trim(),
        'password': _password.value.text,
        'role': _role,
      });
      final t = data['accessToken'] as String;
      ref.read(sessionTokenProvider.notifier).state = t;
      await SessionService.saveToken(t);
      if (!mounted) return;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ترجمة أخطاء الخادم لصيغة بشرية عربية.
  String _friendly(ApiException e) {
    final m = e.message;
    if (m.contains('already')) return 'هذا البريد مسجل مسبقاً — سجّل الدخول';
    if (m.contains('at least 8')) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    if (m.contains('valid email')) return 'صيغة البريد غير صحيحة';
    if (m.contains('role')) return 'نوع الحساب غير صالح';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: AppSpacing.s8),
          // اختيار نوع الحساب — بطاقتان واضحتان
          Row(children: [
            Expanded(child: _roleCard(c,
                icon: Icons.person_rounded,
                title: 'حساب عادي',
                subtitle: 'أحجز وأطلب',
                value: 'CUSTOMER')),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: _roleCard(c,
                icon: Icons.storefront_rounded,
                title: 'حساب تجاري',
                subtitle: 'أعرض محلي',
                value: 'VENDOR')),
          ]),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'البريد الإلكتروني'),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'كلمة المرور',
              helperText: '8 أحرف على الأقل',
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_role == 'VENDOR' ? 'إنشاء حساب تجاري' : 'إنشاء الحساب'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
          if (_role == 'VENDOR') ...[
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: c.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.accent.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.accent),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: Text('بعد إنشاء الحساب التجاري أضف متجرك من «حسابي ← متجري» وستظهر خدماتك بعد موافقة الإدارة.',
                    style: AppText.caption(c.textSecondary))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _roleCard(AppColors c, {required IconData icon, required String title, required String subtitle, required String value}) {
    final selected = _role == value;
    return InkWell(
      onTap: () => setState(() => _role = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.08) : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.6 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 30, color: selected ? c.primary : c.textMuted),
          const SizedBox(height: AppSpacing.s8),
          Text(title, style: AppText.bodyL(selected ? c.primary : c.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.caption(c.textMuted)),
        ]),
      ),
    );
  }
}
