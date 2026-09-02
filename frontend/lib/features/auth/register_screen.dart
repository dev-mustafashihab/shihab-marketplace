import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// شاشة إنشاء حساب — customer فقط (البائع له مسار خاص من الويب).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
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
        'role': 'CUSTOMER',
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
              helperText: '8 أحرف على الأقل مع حرف كبير وصغير ورقم ورمز',
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إنشاء الحساب'),
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
