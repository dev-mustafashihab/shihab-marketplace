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
import '../../core/widgets/status_badge.dart' show BookingStatus, StatusBadge;
import '../auth/login_screen.dart';

/// حجوزاتي — FutureProvider يتابع الجلسة، بطاقات تفصيلية (بائع/خدمة/قاعة/سعر/مدة).
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
          child: SkeletonLoader(height: 120),
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
              itemBuilder: (context, i) => _BookingCard(b: rows[i]),
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
}

/// بطاقة حجز تفصيلية.
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b});
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vendor = (b['vendor'] as Map?) ?? const {};
    final service = (b['service'] as Map?) ?? const {};
    final resource = (b['resource'] as Map?) ?? const {};
    final starts = DateTime.tryParse((b['startsAt'] ?? '') as String)?.toLocal();
    final ends = DateTime.tryParse((b['endsAt'] ?? '') as String)?.toLocal();
    final durationH = (starts != null && ends != null) ? ends.difference(starts).inHours : null;
    final dateStr = starts != null
        ? '${starts.day}/${starts.month}/${starts.year}'
        : '';
    final timeStr = starts != null
        ? '${starts.hour}:${starts.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // رأس: مرجع + حالة
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, 0),
          child: Row(children: [
            Expanded(child: Text((b['bookingRef'] ?? '') as String,
                style: AppText.headingS(c.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: AppSpacing.s8),
            StatusBadge(status: _map((b['status'] ?? 'PENDING') as String)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // البائع
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.storefront_rounded, size: 18, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((vendor['name'] ?? 'بائع') as String,
                    style: AppText.bodyL(c.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((service['name'] as String?)?.isNotEmpty == true)
                  Text(service['name'] as String, style: AppText.caption(c.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: AppSpacing.s12),
            // تفاصيل: تاريخ/وقت/مدة/قاعة
            Row(children: [
              _DetailChip(icon: Icons.calendar_today_rounded, label: dateStr),
              const SizedBox(width: AppSpacing.s8),
              _DetailChip(icon: Icons.schedule_rounded, label: timeStr),
              if (durationH != null && durationH > 0) ...[
                const SizedBox(width: AppSpacing.s8),
                _DetailChip(icon: Icons.timelapse_rounded, label: '$durationH ساعات'),
              ],
            ]),
            if ((resource['name'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.s8),
              Row(children: [
                Icon(Icons.meeting_room_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: AppSpacing.s4),
                Text(resource['name'] as String, style: AppText.caption(c.textMuted)),
              ]),
            ],
            const SizedBox(height: AppSpacing.s12),
            // السعر
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(color: c.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text('الإجمالي', style: AppText.caption(c.textSecondary)),
                const Spacer(),
                Text('${b['totalPrice']} ${b['currency'] ?? ''}',
                    style: AppText.price(c.primary)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// شريحة تفصيل صغيرة (أيقونة + نص).
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c.textMuted),
        const SizedBox(width: AppSpacing.s4),
        Text(label, style: AppText.caption(c.textSecondary)),
      ]),
    );
  }
}

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  return '${d.day}/${d.month}/${d.year} — ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

BookingStatus _map(String s) => switch (s) {
      'PENDING' => BookingStatus.pending,
      'CONFIRMED' => BookingStatus.confirmed,
      'CANCELLED' => BookingStatus.cancelled,
      'COMPLETED' => BookingStatus.completed,
      'EXPIRED' => BookingStatus.expired,
      'REJECTED' => BookingStatus.rejected,
      _ => BookingStatus.pending,
    };
