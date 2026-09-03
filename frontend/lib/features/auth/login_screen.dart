import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'register_screen.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// شاشة تسجيل الدخول — تعيد المستخدم للخلف عند النجاح.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
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
      final data = await api.post('/auth/login', body: {
        'email': _email.value.text.trim(),
        'password': _password.value.text,
      });
      final t = data['accessToken'] as String;
      ref.read(sessionTokenProvider.notifier).state = t;
      await SessionService.saveToken(t);
      final r = data['refreshToken'] as String?;
      if (r != null && r.isNotEmpty) await SessionService.saveRefreshToken(r);
      if (!mounted) return;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، تحقق من اتصالك وأعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ترجمة أخطاء الخادم لصيغة بشرية عربية.
  String _friendly(ApiException e) {
    final m = e.message;
    if (e.status == 401 || m.contains('Invalid credentials')) return 'البريد أو كلمة المرور غير صحيحة';
    if (m.contains('temporarily locked')) return 'الحساب مقفل مؤقتاً — حاول بعد قليل';
    if (e.status == 0 || m.contains('connection')) return 'تعذر الاتصال، تحقق من الإنترنت';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: AppSpacing.s24),
          // شعار التطبيق
          Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.storefront_rounded, size: 38, color: c.primary),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text('سوق المناسبات', style: AppText.headingL(c.textPrimary)),
            const SizedBox(height: AppSpacing.s4),
            Text('كل خدمات مناسباتك بمكان واحد', style: AppText.caption(c.textMuted)),
          ]),
          const SizedBox(height: AppSpacing.s24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _password,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              hintText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تواصل مع الدعم لإعادة تعيين كلمة المرور'), duration: Duration(seconds: 2)));
              },
              child: Text('نسيت كلمة المرور؟', style: AppText.caption(c.primary)),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تسجيل الدخول'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.s24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('ما عندك حساب؟', style: AppText.bodyM(c.textSecondary)),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: Text('أنشئ حساباً', style: AppText.bodyM(c.primary)),
            ),
          ]),
        ]),
      ),
    );
  }
}
