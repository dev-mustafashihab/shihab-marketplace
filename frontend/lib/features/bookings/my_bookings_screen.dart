import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/status_badge.dart' show BookingStatus, StatusBadge;
import '../../core/network/api_client.dart';

/// حجوزاتي — قائمة حجوزات العميل بالحالة (tab الحجوزات في الشل).
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  late Future<dynamic> _future;
  bool _needLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    if (api.token == null) { _needLogin = true; _future = Future.value(null); return; }
    _future = api.get('/bookings/mine').catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_needLogin) {
      return Scaffold(backgroundColor: c.background, appBar: AppBar(title: const Text('حجوزاتي')), body: EmptyState(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لعرض حجوزاتك',
        message: 'بعد تسجيل الدخول ستظهر كل حجوزاتك القادمة والسابقة هنا.',
        actionLabel: 'تسجيل الدخول',
      ));
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('حجوزاتي')),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: const SkeletonLoader(height: 88),
            )));
          }
          if (snap.hasError || snap.data == null) {
            return ErrorState(message: 'تعذر تحميل الحجوزات', onRetry: () { setState(_load); });
          }
          final rows = (snap.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'لا حجوزات بعد',
              message: 'حجوزاتك القادمة ستظهر هنا عند إتمام أول حجز.',
              actionLabel: 'استكشف الخدمات',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, i) {
              final b = rows[i];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(b['bookingRef'] as String,
                          style: AppText.headingS(c.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: AppSpacing.s8),
                      StatusBadge(status: _map(b['status'] as String)),
                    ]),
                    const SizedBox(height: AppSpacing.s8),
                    Text(fmtDate(b['startsAt'] as String),
                        style: AppText.caption(c.textMuted)),
                  ])),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  static String fmtDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year} — ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  static BookingStatus _map(String s) => switch (s) {
        'PENDING' => BookingStatus.pending,
        'CONFIRMED' => BookingStatus.confirmed,
        'CANCELLED' => BookingStatus.cancelled,
        'COMPLETED' => BookingStatus.completed,
        'EXPIRED' => BookingStatus.expired,
        'REJECTED' => BookingStatus.rejected,
        _ => BookingStatus.pending,
      };
}
