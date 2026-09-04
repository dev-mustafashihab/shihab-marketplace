import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/widgets/press_scale.dart';
import '../auth/login_screen.dart';

/// طلباتي — بطاقات موسعة: بائع + منتجات + timeline حالات + عنوان وسعر.
final myOrdersProvider = FutureProvider.autoDispose<dynamic>((ref) {
  final token = ref.watch(sessionTokenProvider);
  if (token == null) return null;
  return ref.watch(apiClientProvider).get('/orders/mine').catchError((_) => null);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final token = ref.watch(sessionTokenProvider);
    final ordersAsync = ref.watch(myOrdersProvider);

    if (token == null) {
      return Scaffold(backgroundColor: c.background, body: SafeArea(child: Column(children: [
        const UnifiedHeader(),
        const SizedBox(height: AppSpacing.s12),
        Expanded(child: EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'طلباتك',
        message: 'تتبع طلبات المطاعم والهدايا لحظة بلحظة بعد تسجيل الدخول.',
        actionLabel: 'تسجيل الدخول',
        onAction: null,
      )),
      ])));
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        const UnifiedHeader(),
        const SizedBox(height: AppSpacing.s12),
        Expanded(child: ordersAsync.when(
        loading: () => Column(children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
          child: SkeletonLoader(height: 130),
        ))),
        error: (_, __) => ErrorState(message: 'تعذر تحميل الطلبات', onRetry: () => ref.invalidate(myOrdersProvider)),
        data: (data) {
          if (data == null) {
            return ErrorState(message: 'تعذر تحميل الطلبات', onRetry: () => ref.invalidate(myOrdersProvider));
          }
          final rows = _rowsOf(data);
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'لا طلبات بعد',
              message: 'اطلب من مطعمك المفضل أو أرسل هدية، وتابع الطلب هنا خطوة بخطوة.',
              actionLabel: 'استكشف',
            );
          }
          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async => ref.refresh(myOrdersProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
              itemBuilder: (context, i) => _OrderCard(o: rows[i]),
            ),
          );
        },
      )),
      ])),
    );
  }

  static List<Map<String, dynamic>> _rowsOf(dynamic d) {
    if (d is List) {
      if (d.length == 2 && d[0] is num && d[1] is List) return (d[1] as List).cast<Map<String, dynamic>>();
      return d.cast<Map<String, dynamic>>();
    }
    if (d is Map && d['data'] is List) return (d['data'] as List).cast<Map<String, dynamic>>();
    return const [];
  }
}

/// بطاقة طلب موسعة.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.o});
  final Map<String, dynamic> o;

  static const _stages = ['PENDING', 'CONFIRMED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vendor = (o['vendor'] as Map?) ?? const {};
    final items = (o['items'] as List?) ?? const [];
    final status = (o['status'] ?? 'PENDING') as String;
    final created = DateTime.tryParse((o['createdAt'] ?? '') as String)?.toLocal();

    return PressScale(
      onTap: () {},
      child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // رأس: مرجع + الحالة العربية ملونة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          color: _statusColor(c, status).withOpacity(0.08),
          child: Row(children: [
            Expanded(child: Text((o['orderRef'] ?? '') as String,
                style: AppText.headingS(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 2),
              decoration: BoxDecoration(color: _statusColor(c, status), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusAr(status),
                  style: AppText.caption(Colors.white)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // البائع
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.storefront_rounded, size: 17, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text((vendor['name'] ?? 'متجر') as String,
                  style: AppText.bodyL(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (created != null)
                Text('${created.day}/${created.month}', style: AppText.caption(c.textMuted)),
            ]),
            // المنتجات
            if (items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              ...items.take(3).map((it) {
                final m = it as Map;
                final product = (m['product'] as Map?) ?? const {};
                final qty = m['quantity'] ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.circle, size: 4, color: c.textMuted),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(child: Text('${product['name'] ?? 'منتج'} ×$qty',
                        style: AppText.caption(c.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${m['unitPrice'] ?? ''}', style: AppText.caption(c.textMuted)),
                  ]),
                );
              }),
              if (items.length > 3)
                Text('+${items.length - 3} عناصر أخرى', style: AppText.caption(c.textMuted)),
            ],
            const SizedBox(height: AppSpacing.s12),
            // Timeline الحالات
            if (status != 'CANCELLED' && status != 'REFUNDED')
              _StatusTimeline(status: status),
            const SizedBox(height: AppSpacing.s12),
            // السعر الإجمالي
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(color: c.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text('الإجمالي', style: AppText.caption(c.textSecondary)),
                const Spacer(),
                Text('${o['total']} ${o['currency'] ?? ''}', style: AppText.price(c.primary)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
    );
  }

  static Color _statusColor(AppColors c, String s) {
    if (s == 'CANCELLED' || s == 'REFUNDED') return c.error;
    if (s == 'DELIVERED') return c.success;
    return c.primary;
  }

  static String _statusAr(String s) => switch (s) {
        'PENDING' => 'قيد المراجعة',
        'CONFIRMED' => 'تم التأكيد',
        'PREPARING' => 'قيد التحضير',
        'READY' => 'جاهز',
        'OUT_FOR_DELIVERY' => 'في الطريق',
        'DELIVERED' => 'تم التسليم',
        'CANCELLED' => 'ملغي',
        'REFUNDED' => 'مسترجع',
        _ => s,
      };
}

/// Timeline بصري: نقاط المراحل المنجزة حتى الحالة الحالية.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stages = _OrderCard._stages;
    final currentIdx = stages.indexOf(status);
    return Row(children: [
      for (var i = 0; i < stages.length; i++) ...[
        if (i > 0)
          Expanded(child: Container(
            height: 2,
            color: i <= currentIdx ? c.primary : c.border,
          )),
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= currentIdx ? c.primary : c.surface,
            border: Border.all(color: i <= currentIdx ? c.primary : c.border, width: 1.5),
          ),
        ),
      ],
    ]);
  }
}
