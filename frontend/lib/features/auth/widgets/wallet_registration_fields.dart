import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// حقول قابلة لإعادة الاستخدام لشاشة تسجيل المحفظة — لا منطق API هنا.

class WalletSectionTitle extends StatelessWidget {
  const WalletSectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.headingS(c.textPrimary)),
      const SizedBox(height: 2),
      Text(subtitle, style: AppText.caption(c.textSecondary)),
    ]);
  }
}

class WalletTextField extends StatelessWidget {
  const WalletTextField({
    super.key,
    required this.hint,
    this.initial,
    this.keyboard = TextInputType.text,
    this.obscure = false,
    this.maxLength,
    this.digitsOnly = false,
    this.suffix,
    this.onChanged,
    this.helper,
  });

  final String hint;
  final String? initial;
  final TextInputType keyboard;
  final bool obscure;
  final int? maxLength;
  final bool digitsOnly;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLength: maxLength,
      buildCounter: maxLength == null
          ? null
          : (_, {required currentLength, required isFocused, maxLength}) =>
              const SizedBox.shrink(),
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      textDirection: keyboard == TextInputType.emailAddress ||
              keyboard == TextInputType.visiblePassword
          ? TextDirection.ltr
          : null,
      decoration: InputDecoration(hintText: hint, helperText: helper, suffixIcon: suffix),
      onChanged: onChanged,
    );
  }
}

class WalletStepHeader extends StatelessWidget {
  const WalletStepHeader({super.key, required this.step, required this.onTap});

  final int step;
  final ValueChanged<int> onTap;

  static const _titles = ['البيانات الشخصية', 'الهوية والتواصل', 'الأمان والمحفظة'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Expanded(
          child: InkWell(
            onTap: i < step ? () => onTap(i) : null,
            borderRadius: BorderRadius.circular(6),
            child: Column(children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step ? c.primary : c.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Text(_titles[i],
                  textAlign: TextAlign.center,
                  style: AppText.caption(i <= step ? c.primary : c.textMuted)),
            ]),
          ),
        ),
        if (i < 2) const SizedBox(width: AppSpacing.s8),
      ],
    ]);
  }
}
