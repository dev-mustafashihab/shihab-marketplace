import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
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
            decoration: const InputDecoration(hintText: 'كلمة المرور'),
          ),
          const SizedBox(height: AppSpacing.s20),
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
        ]),
      ),
    );
  }
}
