import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'state/wallet_registration_provider.dart';
import 'utils/wallet_validators.dart';
import 'widgets/wallet_registration_fields.dart';

/// شاشة إنشاء حساب محفظة جديدة — معالج من 3 خطوات (PageView).
///
/// * الخطوة 1: البيانات الشخصية والنسب.
/// * الخطوة 2: بيانات الهوية والتواصل.
/// * الخطوة 3: أمان الحساب ورقم المحفظة (16 رقماً) وتأكيد الشروط.
///
/// عربية RTL بالكامل، متجاوبة، بلا API calls داخل الـ Widgets
/// (كل المنطق في [walletRegistrationProvider]).
class WalletRegisterScreen extends ConsumerStatefulWidget {
  const WalletRegisterScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  ConsumerState<WalletRegisterScreen> createState() => _WalletRegisterScreenState();
}

const _consentText =
    'أوافق على الشروط والأحكام وسياسة الخصوصية، وأقرّ بأن جميع البيانات والمستندات '
    'المقدمة صحيحة ومطابقة للواقع وأتحمل كامل المسؤولية القانونية عن أي بيانات كاذبة، '
    'وأوافق على معالجة بياناتي لغايات تشغيل الحساب والمحفظة والتحقق من الهوية.';

class _WalletRegisterScreenState extends ConsumerState<WalletRegisterScreen> {
  late final PageController _pages;
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncPage(int step) {
    if (_pages.hasClients) {
      _pages.animateToPage(step,
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  Future<void> _pickBirth(DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (d != null) {
      ref.read(walletRegistrationProvider.notifier).update(
            (m) => m.copyWith(birthDate: () => d),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final st = ref.watch(walletRegistrationProvider);
    final ctrl = ref.read(walletRegistrationProvider.notifier);

    ref.listen(walletRegistrationProvider, (prev, next) {
      if (prev?.step != next.step) _syncPage(next.step);
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('إنشاء حساب محفظة'),
        leading: st.step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: st.loading ? null : ctrl.back,
              )
            : null,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 560;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.s12, AppSpacing.screenH, 0),
                child: WalletStepHeader(
                  step: st.step,
                  onTap: (i) {
                    if (!st.loading && i < st.step) ctrl.goTo(i);
                  },
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: ctrl.goTo,
                  children: [
                    _stepOne(c, st, ctrl, wide),
                    _stepTwo(c, st, ctrl),
                    _stepThree(c, st, ctrl),
                  ],
                ),
              ),
              _bottomBar(c, st, ctrl),
            ]),
          ),
        );
      }),
    );
  }

  Widget _stepOne(AppColors c, WalletRegistrationState st,
      WalletRegistrationController ctrl, bool wide) {
    final m = st.model;
    final fields = [
      WalletTextField(
          hint: 'الاسم الأول', initial: m.firstName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(firstName: v))),
      WalletTextField(
          hint: 'اسم الأب', initial: m.fatherName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(fatherName: v))),
      WalletTextField(
          hint: 'الكنية / اللقب', initial: m.lastName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(lastName: v))),
      WalletTextField(
          hint: 'اسم الأم', initial: m.motherName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(motherName: v))),
      WalletTextField(
          hint: 'اسم والد الأم', initial: m.motherFatherName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(motherFatherName: v))),
      WalletTextField(
          hint: 'كنية الأم (النسب)', initial: m.motherMaidenName,
          onChanged: (v) => ctrl.update((x) => x.copyWith(motherMaidenName: v))),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WalletSectionTitle(
            title: 'البيانات الشخصية والنسب',
            subtitle: 'مطابقة للهوية — تُستخدم للتوثيق القانوني'),
        const SizedBox(height: AppSpacing.s12),
        if (wide)
          ..._grid(fields)
        else
          ..._spaced(fields),
      ]),
    );
  }

  Widget _stepTwo(AppColors c, WalletRegistrationState st,
      WalletRegistrationController ctrl) {
    final m = st.model;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WalletSectionTitle(
            title: 'بيانات الهوية والتواصل',
            subtitle: 'الرقم الوطني 11 رقماً — الهاتف بالمفتاح الدولي'),
        const SizedBox(height: AppSpacing.s12),
        WalletTextField(
          hint: 'الرقم الوطني (11 رقماً)',
          initial: m.nationalId,
          keyboard: TextInputType.number,
          digitsOnly: true,
          maxLength: 11,
          onChanged: (v) => ctrl.update((x) => x.copyWith(nationalId: v)),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 128,
            child: DropdownButtonFormField<String>(
              value: m.countryCode,
              decoration: const InputDecoration(hintText: 'المفتاح'),
              items: walletCountryCodes
                  .map((e) => DropdownMenuItem(
                      value: e['code'], child: Text(e['code']!, textDirection: TextDirection.ltr)))
                  .toList(),
              onChanged: (v) {
                if (v != null) ctrl.update((x) => x.copyWith(countryCode: v));
              },
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: WalletTextField(
              hint: 'رقم الهاتف',
              initial: m.phone,
              keyboard: TextInputType.phone,
              onChanged: (v) => ctrl.update((x) => x.copyWith(phone: v)),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s12),
        WalletTextField(
          hint: 'البريد الإلكتروني',
          initial: m.email,
          keyboard: TextInputType.emailAddress,
          onChanged: (v) => ctrl.update((x) => x.copyWith(email: v)),
        ),
        const SizedBox(height: AppSpacing.s12),
        WalletTextField(
          hint: 'كلمة المرور (8 أحرف على الأقل)',
          initial: m.password,
          keyboard: TextInputType.visiblePassword,
          obscure: _obscurePassword,
          suffix: IconButton(
            icon: Icon(_obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          onChanged: (v) => ctrl.update((x) => x.copyWith(password: v)),
        ),
        const SizedBox(height: AppSpacing.s12),
        InkWell(
          onTap: st.loading ? null : () => _pickBirth(m.birthDate),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration:
                const InputDecoration(hintText: 'تاريخ الميلاد (18+ سنة)'),
            child: Text(
              m.birthDate == null
                  ? ''
                  : '${m.birthDate!.year}/${m.birthDate!.month.toString().padLeft(2, '0')}/${m.birthDate!.day.toString().padLeft(2, '0')}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stepThree(AppColors c, WalletRegistrationState st,
      WalletRegistrationController ctrl) {
    final m = st.model;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WalletSectionTitle(
            title: 'أمان الحساب ورقم المحفظة',
            subtitle: 'رقم مولّد تلقائياً من 16 رقماً — يمكنك توليد غيره'),
        const SizedBox(height: AppSpacing.s12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مُعرّف الحساب', style: AppText.caption(c.textSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(m.formattedAccountId,
                    textDirection: TextDirection.ltr,
                    style: AppText.price(c.textPrimary)),
              ),
              IconButton.filledTonal(
                tooltip: 'توليد رقم جديد',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: st.loading ? null : ctrl.regenerateAccountId,
              ),
            ]),
          ]),
        ),
        const SizedBox(height: AppSpacing.s12),
        WalletTextField(
          hint: 'رمز حماية المحفظة (4 أو 6 أرقام)',
          initial: m.walletPin,
          keyboard: TextInputType.number,
          obscure: _obscurePin,
          digitsOnly: true,
          maxLength: 6,
          suffix: IconButton(
            icon: Icon(_obscurePin
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
          onChanged: (v) => ctrl.update((x) => x.copyWith(walletPin: v)),
        ),
        const SizedBox(height: AppSpacing.s12),
        WalletTextField(
          hint: 'تأكيد رمز الحماية',
          initial: st.confirmPin,
          keyboard: TextInputType.number,
          obscure: _obscureConfirm,
          digitsOnly: true,
          maxLength: 6,
          suffix: IconButton(
            icon: Icon(_obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          onChanged: ctrl.setConfirmPin,
        ),
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
              value: m.consentAccepted,
              activeColor: c.primary,
              onChanged: st.loading
                  ? null
                  : (v) => ctrl.update(
                      (x) => x.copyWith(consentAccepted: v ?? false)),
            ),
            const Expanded(child: Text(_consentText, style: TextStyle(fontSize: 12, height: 1.8))),
          ]),
        ),
      ]),
    );
  }

  Widget _bottomBar(AppColors c, WalletRegistrationState st,
      WalletRegistrationController ctrl) {
    final last = st.step == 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (st.error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.error.withOpacity(0.3)),
              ),
              child: Text(st.error!,
                  style: AppText.bodyM(c.error), textAlign: TextAlign.center),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: st.loading
                  ? null
                  : () async {
                      if (!last) {
                        ctrl.next();
                        return;
                      }
                      HapticFeedback.lightImpact();
                      final ok = await ctrl.submit();
                      if (ok && mounted) {
                        widget.onSuccess?.call();
                        Navigator.of(context).pop(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'تم إنشاء المحفظة — رقم حسابك: ${st.successAccountId ?? ref.read(walletRegistrationProvider).successAccountId ?? ''}'),
                          ),
                        );
                      }
                    },
              child: st.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(last ? 'تأكيد وإنشاء المحفظة' : 'التالي'),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> fields) {
    final out = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      out.add(fields[i]);
      if (i < fields.length - 1) out.add(const SizedBox(height: AppSpacing.s12));
    }
    return out;
  }

  List<Widget> _grid(List<Widget> fields) {
    final out = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      out.add(Row(children: [
        Expanded(child: fields[i]),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: i + 1 < fields.length ? fields[i + 1] : const SizedBox()),
      ]));
      out.add(const SizedBox(height: AppSpacing.s12));
    }
    return out;
  }
}
