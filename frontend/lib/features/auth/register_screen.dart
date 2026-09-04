import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// شاشة إنشاء حساب — الزبون العادي بمعالج توثيق من 3 خطوات، والتجاري بخطوة واحدة.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

const _governorates = [
  'دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس',
  'إدلب', 'دير الزور', 'الرقة', 'الحسكة', 'درعا', 'السويداء', 'القنيطرة',
];

const _consentText =
    'أقرّ بأن جميع البيانات والمستندات المقدمة صحيحة ومطابقة للواقع، وأتحمل كامل '
    'المسؤولية القانونية عن أي بيانات كاذبة. وأوافق على معالجة بياناتي لغايات تشغيل '
    'الحساب والمحفظة والتحقق من الهوية، وعلى اعتبار سجلات التطبيق الإلكترونية حجة عليّ.';

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;
  String _role = 'CUSTOMER';
  bool _loading = false;
  String? _error;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  DateTime? _birthDate;
  String? _governorate;
  String? _frontPath;
  String? _backPath;
  bool _consent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _nationalId.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    super.dispose();
  }

  int get _maxStep => _role == 'CUSTOMER' ? 2 : 0;

  bool _validAccount() {
    if (!_email.text.trim().contains('@')) {
      setState(() => _error = 'صيغة البريد غير صحيحة');
      return false;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return false;
    }
    return true;
  }

  bool _validPersonal() {
    if (_fullName.text.trim().length < 5) {
      setState(() => _error = 'الاسم الثلاثي مطلوب ومطابق للهوية');
      return false;
    }
    if (!RegExp(r'^\d{11}$').hasMatch(_nationalId.text.trim())) {
      setState(() => _error = 'الرقم الوطني يجب أن يكون 11 رقماً');
      return false;
    }
    if (_birthDate == null || DateTime.now().difference(_birthDate!).inDays < 18 * 365) {
      setState(() => _error = 'التسجيل متاح لمن بلغ 18 سنة فأكثر');
      return false;
    }
    if (!RegExp(r'^09\d{8}$').hasMatch(_phone.text.trim())) {
      setState(() => _error = 'رقم الموبايل يبدأ بـ 09 ومؤلف من 10 أرقام');
      return false;
    }
    if (_governorate == null || _city.text.trim().isEmpty) {
      setState(() => _error = 'المحافظة والمدينة مطلوبتان');
      return false;
    }
    return true;
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0 && !_validAccount()) return;
    if (_step == 1 && !_validPersonal()) return;
    if (_step < _maxStep) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _pickId(bool front) async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (img == null) return;
      setState(() {
        if (front) {
          _frontPath = img.path;
        } else {
          _backPath = img.path;
        }
        _error = null;
      });
    } on PlatformException {
      setState(() => _error = 'تعذر الوصول إلى الصور');
    }
  }

  Future<void> _submit() async {
    if (_role == 'CUSTOMER' && !_consent) {
      setState(() => _error = 'يجب الموافقة على الشروط ومعالجة البيانات');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/auth/register', body: {
        'email': _email.text.trim(),
        'password': _password.text,
        'role': _role,
        if (_role == 'CUSTOMER') ...{
          'fullName': _fullName.text.trim(),
          'nationalId': _nationalId.text.trim(),
          'birthDate': _birthDate!.toIso8601String().split('T').first,
          'phone': _phone.text.trim(),
          'governorate': _governorate,
          'city': _city.text.trim(),
          if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
          'consentAccepted': true,
        },
      });
      final t = data['accessToken'] as String;
      ref.read(sessionTokenProvider.notifier).state = t;
      await SessionService.saveToken(t);
      final r = data['refreshToken'] as String?;
      if (r != null && r.isNotEmpty) await SessionService.saveRefreshToken(r);
      // رفع صور الهوية ثم ربطها بالملف (بتوكن الجلسة الجديدة)
      if (_role == 'CUSTOMER' && (_frontPath != null || _backPath != null)) {
        String? frontUrl;
        String? backUrl;
        if (_frontPath != null) frontUrl = await api.uploadImage('/media/upload', _frontPath!);
        if (_backPath != null) backUrl = await api.uploadImage('/media/upload', _backPath!);
        await api.patch('/users/me/profile', body: {
          if (frontUrl != null) 'idFrontUrl': frontUrl,
          if (backUrl != null) 'idBackUrl': backUrl,
        });
      }
      if (!mounted) return;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_role == 'CUSTOMER'
              ? 'تم إنشاء الحساب — التوثيق قيد المراجعة، والمحفظة تتفعل بعد الموافقة'
              : 'تم إنشاء الحساب التجاري بنجاح'),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(ApiException e) {
    final m = e.message;
    if (m.contains('already') || m.contains('مسجل مسبقاً')) {
      return m.contains('الوطني') ? 'هذا الرقم الوطني مسجل مسبقاً' : 'هذا البريد مسجل مسبقاً — سجّل الدخول';
    }
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
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() { _step--; _error = null; }))
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_maxStep > 0) _stepper(c),
          if (_maxStep > 0) const SizedBox(height: AppSpacing.s16),
          if (_step == 0) ..._accountStep(c),
          if (_step == 1) ..._personalStep(c),
          if (_step == 2) ..._docsStep(c),
          const SizedBox(height: AppSpacing.s20),
          ElevatedButton(
            onPressed: _loading ? null : _next,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_step < _maxStep ? 'التالي' : (_role == 'VENDOR' ? 'إنشاء حساب تجاري' : 'إرسال للمراجعة')),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
          if (_step == 0 && _role == 'VENDOR') ...[
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

  Widget _stepper(AppColors c) {
    const titles = ['الحساب', 'البيانات', 'التوثيق'];
    return Row(children: [
      for (var i = 0; i <= _maxStep; i++) ...[
        Expanded(
          child: Column(children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= _step ? c.primary : c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Text(titles[i],
                style: AppText.caption(i <= _step ? c.primary : c.textMuted)),
          ]),
        ),
        if (i < _maxStep) const SizedBox(width: AppSpacing.s8),
      ],
    ]);
  }

  List<Widget> _accountStep(AppColors c) {
    return [
      const SizedBox(height: AppSpacing.s8),
      Row(children: [
        Expanded(child: _roleCard(c,
            icon: Icons.person_rounded, title: 'حساب عادي', subtitle: 'أحجز وأطلب', value: 'CUSTOMER')),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: _roleCard(c,
            icon: Icons.storefront_rounded, title: 'حساب تجاري', subtitle: 'أعرض محلي', value: 'VENDOR')),
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
        decoration: const InputDecoration(hintText: 'كلمة المرور', helperText: '8 أحرف على الأقل'),
      ),
    ];
  }

  List<Widget> _personalStep(AppColors c) {
    return [
      Text('بياناتك الشخصية (مطابقة للهوية)', style: AppText.headingS(c.textPrimary)),
      const SizedBox(height: AppSpacing.s4),
      Text('هالخطوة بتحمي حقك وحقنا بالقانون', style: AppText.caption(c.textSecondary)),
      const SizedBox(height: AppSpacing.s12),
      TextField(controller: _fullName, decoration: const InputDecoration(hintText: 'الاسم الثلاثي')),
      const SizedBox(height: AppSpacing.s12),
      TextField(
        controller: _nationalId,
        keyboardType: TextInputType.number,
        maxLength: 11,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'الرقم الوطني (11 رقماً)', counterText: ''),
      ),
      const SizedBox(height: AppSpacing.s12),
      InkWell(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 25),
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year - 18, now.month, now.day),
          );
          if (d != null) setState(() => _birthDate = d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(hintText: 'تاريخ الميلاد (18+ سنة)'),
          child: Text(
            _birthDate == null
                ? ''
                : '${_birthDate!.year}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.day.toString().padLeft(2, '0')}',
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.s12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'رقم الموبايل (09XXXXXXXX)', counterText: ''),
      ),
      const SizedBox(height: AppSpacing.s12),
      DropdownButtonFormField<String>(
        value: _governorate,
        decoration: const InputDecoration(hintText: 'المحافظة'),
        items: _governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => _governorate = v),
      ),
      const SizedBox(height: AppSpacing.s12),
      TextField(controller: _city, decoration: const InputDecoration(hintText: 'المدينة / المنطقة')),
      const SizedBox(height: AppSpacing.s12),
      TextField(controller: _address, decoration: const InputDecoration(hintText: 'العنوان التفصيلي (اختياري)')),
    ];
  }

  List<Widget> _docsStep(AppColors c) {
    return [
      Text('توثيق الهوية', style: AppText.headingS(c.textPrimary)),
      const SizedBox(height: AppSpacing.s4),
      Text('صور واضحة لوجه الهوية وخلفيتها — ما بتنعرض لحدا، بس للإدارة للتحقق',
          style: AppText.caption(c.textSecondary)),
      const SizedBox(height: AppSpacing.s12),
      Row(children: [
        Expanded(child: _idPick(c, front: true)),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: _idPick(c, front: false)),
      ]),
      const SizedBox(height: AppSpacing.s16),
      Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: _consent,
            activeColor: c.primary,
            onChanged: (v) => setState(() => _consent = v ?? false),
          ),
          Expanded(child: Text(_consentText, style: AppText.caption(c.textSecondary))),
        ]),
      ),
    ];
  }

  Widget _idPick(AppColors c, {required bool front}) {
    final picked = front ? _frontPath != null : _backPath != null;
    return InkWell(
      onTap: () => _pickId(front),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: picked ? c.primary.withOpacity(0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: picked ? c.primary : c.border, width: picked ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(picked ? Icons.check_circle : Icons.badge_outlined,
              size: 28, color: picked ? c.primary : c.textMuted),
          const SizedBox(height: 6),
          Text(front ? 'وجه الهوية' : 'خلف الهوية',
              style: AppText.caption(picked ? c.primary : c.textSecondary)),
        ]),
      ),
    );
  }

  Widget _roleCard(AppColors c, {required IconData icon, required String title, required String subtitle, required String value}) {
    final selected = _role == value;
    return InkWell(
      onTap: () => setState(() { _role = value; _step = 0; _error = null; }),
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
