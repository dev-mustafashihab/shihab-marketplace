import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
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
      ref.read(sessionTokenProvider.notifier).state = data['accessToken'] as String;
      if (!mounted) return;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message == 'Registration failed'
          ? 'هذا البريد مسجل مسبقاً' : e.message);
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
