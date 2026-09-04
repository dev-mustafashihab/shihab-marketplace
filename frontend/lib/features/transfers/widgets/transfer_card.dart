import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/transfer_model.dart';

/// أخضر الاستلام — من عائلة زر الاستقبال.
const Color kReceiveGreen = Color(0xFF1E9E6A);

/// بطاقة عملية تحويل: الاسم يمين + المبلغ تحته، الرقم والتاريخ يسار.
/// ضغطة عادية → التفاصيل، ضغطة مطولة → الإيصال.
class TransferCard extends StatelessWidget {
  const TransferCard({
    super.key,
    required this.t,
    this.onTap,
    this.onLongPress,
  });

  final TransferModel t;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amountColor = t.isSend ? c.error : kReceiveGreen;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // اليمين: الاسم + المبلغ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.recipientName,
                      style: AppText.bodyM(c.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      t.amountLine,
                      textDirection: TextDirection.ltr,
                      style: AppText.price(amountColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // اليسار: الرقم + التاريخ + الحالة
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.receiptId,
                    textDirection: TextDirection.ltr,
                    style: AppText.en(c.textMuted, size: 12, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    t.dateTimeLine,
                    textDirection: TextDirection.ltr,
                    style: AppText.en(c.textMuted, size: 11),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  _StatusPill(status: t.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شارة حالة صغيرة: نقطة ملونة + نص.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, String label) = switch (status) {
      TransferStatus.success => (kReceiveGreen, 'ناجحة'),
      TransferStatus.pending => (c.warning, 'قيد المعالجة'),
      TransferStatus.failed => (c.error, 'فاشلة'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption(fg)),
        ],
      ),
    );
  }
}
