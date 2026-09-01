import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/network/api_client.dart';

/// طلباتي — Timeline بصري لحالة الطلب (design: OrderTimeline).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final api = ref.read(apiClientProvider);
    if (api.token == null) {
      return Scaffold(backgroundColor: c.background, appBar: AppBar(title: const Text('طلباتي')), body: EmptyState(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لعرض طلباتك',
        message: 'ستجد هنا طلبات المطاعم والهدايا مع حالة التوصيل لحظة بلحظة.',
        actionLabel: 'تسجيل الدخول',
      ));
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('طلباتي')),
      body: FutureBuilder<dynamic>(
        future: api.get('/orders/mine').catchError((_) => null),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 88),
            )));
          }
          if (snap.hasError || snap.data == null) {
            return ErrorState(message: 'تعذر تحميل الطلبات', onRetry: () => ref.invalidate(apiClientProvider));
          }
          final rows = (snap.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'لا طلبات بعد',
              message: 'اطلب من مطعمك المفضل أو أرسل هدية، وتابع الطلب هنا خطوة بخطوة.',
              actionLabel: 'استكشف',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, i) {
              final o = rows[i];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(o['orderRef'] as String,
                        style: AppText.headingS(c.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${o['total']} ${o['currency']}', style: AppText.price(c.primary)),
                  ]),
                  const SizedBox(height: AppSpacing.s8),
                  Text(_statusAr(o['status'] as String), style: AppText.caption(c.textSecondary)),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  static String _statusAr(String s) => switch (s) {
        'PENDING' => 'قيد المراجعة',
        'CONFIRMED' => 'تم التأكيد',
        'PREPARING' => 'قيد التحضير',
        'READY' => 'جاهز للتسليم',
        'OUT_FOR_DELIVERY' => 'في الطريق إليك',
        'DELIVERED' => 'تم التسليم',
        'CANCELLED' => 'ملغي',
        'REFUNDED' => 'مسترجع',
        _ => s,
      };
}
