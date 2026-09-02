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
import '../auth/login_screen.dart';

/// حجوزاتي — قائمة حجوزات العميل بالحالة (tab الحجوزات في الشل).
/// مصممة كـ FutureProvider.family: أي تغيّر بالتوكن يعيد إنشاء الـ future تلقائياً.
final myBookingsProvider = FutureProvider.autoDispose<dynamic>((ref) {
  final token = ref.watch(sessionTokenProvider);
  if (token == null) return null;
  return ref.watch(apiClientProvider).get('/bookings/mine').catchError((_) => null);
});

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final token = ref.watch(sessionTokenProvider);
    final bookingsAsync = ref.watch(myBookingsProvider);

    if (token == null) {
      return Scaffold(backgroundColor: c.background, appBar: AppBar(title: const Text('حجوزاتي')), body: EmptyState(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لعرض حجوزاتك',
        message: 'بعد تسجيل الدخول ستظهر كل حجوزاتك القادمة والسابقة هنا.',
        actionLabel: 'تسجيل الدخول',
        onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
      ));
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('حجوزاتي')),
      body: bookingsAsync.when(
        loading: () => Column(children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
          child: SkeletonLoader(height: 88),
        ))),
        error: (_, __) => ErrorState(message: 'تعذر تحميل الحجوزات', onRetry: () => ref.invalidate(myBookingsProvider)),
        data: (data) {
          if (data == null) {
            return ErrorState(message: 'تعذر تحميل الحجوزات', onRetry: () => ref.invalidate(myBookingsProvider));
          }
          final rows = _rowsOf(data);
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'لا حجوزات بعد',
              message: 'حجوزاتك القادمة ستظهر هنا عند إتمام أول حجز.',
              actionLabel: 'استكشف الخدمات',
            );
          }
          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async => ref.refresh(myBookingsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        Expanded(child: Text((b['bookingRef'] ?? '') as String,
                            style: AppText.headingS(c.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: AppSpacing.s8),
                        StatusBadge(status: _map((b['status'] ?? 'PENDING') as String)),
                      ]),
                      const SizedBox(height: AppSpacing.s8),
                      Text(_fmtDate((b['startsAt'] ?? '') as String),
                          style: AppText.caption(c.textMuted)),
                    ])),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// الاستجابة قد تكون [total, rows] أو [rows] أو {data:[...]} — بأمان.
  static List<Map<String, dynamic>> _rowsOf(dynamic d) {
    if (d is List) {
      if (d.length == 2 && d[0] is num && d[1] is List) return (d[1] as List).cast<Map<String, dynamic>>();
      return d.cast<Map<String, dynamic>>();
    }
    if (d is Map && d['data'] is List) return (d['data'] as List).cast<Map<String, dynamic>>();
    return const [];
  }

  static String _fmtDate(String iso) {
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
