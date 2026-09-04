import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/transfer_model.dart';
import 'transfer_card.dart' show kReceiveGreen;

/// نص الإيصال للمشاركة/النسخ — مشترك بين ورقة الإيصال وخيارات البطاقة.
String receiptShareText(TransferModel t) => '''
إيصال تحويل — دبرني
المستفيد: ${t.recipientName}
المبلغ: ${t.amountLine}
نوع العملية: ${t.typeAr}
رقم العملية: ${t.receiptId}
التاريخ والوقت: ${t.dateTimeLine}
الحالة: ${t.statusAr}''';

/// إيصال العملية — يُفتح بالضغط المطول أو من التفاصيل. مع مشاركة ونسخ.
class ReceiptSheet extends StatelessWidget {
  const ReceiptSheet({super.key, required this.t});
  final TransferModel t;

  static Future<void> show(BuildContext context, TransferModel t) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptSheet(t: t),
    );
  }

  String get _shareText => receiptShareText(t);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.l),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kReceiveGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedShield01,
                      color: kReceiveGreen,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إيصال تحويل',
                        style: AppText.headingS(c.textPrimary)),
                    Text(t.receiptId,
                        textDirection: TextDirection.ltr,
                        style: AppText.en(c.textMuted,
                            size: 13, weight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                Text(
                  t.amountLine,
                  textDirection: TextDirection.ltr,
                  style: AppText.price(
                      t.isSend ? c.error : kReceiveGreen),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            const _DashedDivider(),
            const SizedBox(height: AppSpacing.s16),
            _row(c, 'المستفيد', t.recipientName),
            _row(c, 'نوع العملية', t.typeAr),
            _row(c, 'رقم العملية', t.receiptId, ltr: true),
            _row(c, 'التاريخ والوقت', t.dateTimeLine, ltr: true),
            _row(c, 'الحالة', t.statusAr),
            if (t.note != null && t.note!.isNotEmpty)
              _row(c, 'ملاحظات', t.note!),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.s),
                      ),
                    ),
                    onPressed: () => Share.share(_shareText),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare01,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text('مشاركة',
                        style: AppText.button(Colors.white)),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.s),
                      ),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _shareText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم نسخ الإيصال')),
                        );
                      }
                    },
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCopy01,
                      color: c.primary,
                      size: 18,
                    ),
                    label: Text('نسخ الإيصال',
                        style: AppText.button(c.primary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AppColors c, String label, String value,
      {bool ltr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.caption(c.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: ltr ? TextAlign.end : TextAlign.start,
              style: ltr
                  ? AppText.en(c.textPrimary,
                      size: 14, weight: FontWeight.w500)
                  : AppText.bodyM(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// خط متقطع بأسلوب الإيصالات.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1.5,
              color: c.border,
            ),
          ),
        );
      },
    );
  }
}
