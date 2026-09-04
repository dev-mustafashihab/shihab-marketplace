import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/transfer_model.dart';
import 'receipt_sheet.dart';
import 'transfer_card.dart' show kReceiveGreen;

/// Bottom Sheet تفاصيل العملية: المستفيد/المبلغ/النوع/الرقم/التاريخ/الحالة/ملاحظات.
class TransferDetailsSheet extends StatelessWidget {
  const TransferDetailsSheet({super.key, required this.t});
  final TransferModel t;

  static Future<void> show(BuildContext context, TransferModel t) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferDetailsSheet(t: t),
    );
  }

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
            Text('تفاصيل العملية', style: AppText.headingS(c.textPrimary)),
            const SizedBox(height: AppSpacing.s16),
            _row(c, 'المستفيد', t.recipientName),
            _row(
              c,
              'المبلغ',
              t.amountLine,
              ltr: true,
              valueColor: t.isSend ? c.error : kReceiveGreen,
              bold: true,
            ),
            _row(c, 'نوع العملية', t.typeAr),
            _row(c, 'رقم العملية', t.receiptId, ltr: true),
            _row(c, 'التاريخ والوقت', t.dateTimeLine, ltr: true),
            _row(c, 'الحالة', t.statusAr,
                valueColor: switch (t.status) {
                  TransferStatus.success => kReceiveGreen,
                  TransferStatus.pending => c.warning,
                  TransferStatus.failed => c.error,
                }),
            if (t.note != null && t.note!.isNotEmpty)
              _row(c, 'ملاحظات', t.note!),
            const SizedBox(height: AppSpacing.s20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ReceiptSheet.show(context, t);
              },
              child: Text('عرض الإيصال', style: AppText.button(Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AppColors c, String label, String value,
      {bool ltr = false, Color? valueColor, bool bold = false}) {
    final base = ltr
        ? AppText.en(valueColor ?? c.textPrimary,
            size: 14, weight: bold ? FontWeight.w700 : FontWeight.w500)
        : AppText.bodyM(valueColor ?? c.textPrimary)
            .copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500);
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
              style: base,
            ),
          ),
        ],
      ),
    );
  }
}
