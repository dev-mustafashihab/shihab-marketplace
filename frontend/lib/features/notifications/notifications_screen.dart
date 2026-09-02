import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';

/// الإشعارات — قائمة حية + عداد غير المقروء + قراءة الكل.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<dynamic> _future;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _future = api.get('/notifications?limit=50').catchError((_) => 'ERR');
    if (api.token != null) {
      api.get('/notifications/unread-count').then((d) {
        final n = d is Map ? (d['unreadCount'] ?? d['count'] ?? 0) : 0;
        if (mounted) setState(() => _unread = (n as num).toInt());
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (ref.watch(apiClientProvider).token == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('الإشعارات')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'سجّل الدخول لعرض الإشعارات',
          message: 'إشعارات الحجز والطلبات ستظهر هنا.',
          actionLabel: 'تسجيل الدخول',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('قراءة الكل ($_unread)', style: AppText.button(c.primary)),
            ),
        ],
      ),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 64),
            )));
          }
          if (snap.data == 'ERR' || snap.hasError) {
            return EmptyState(icon: Icons.notifications_off_outlined, title: 'تعذر تحميل الإشعارات', message: 'اسحب للأسفل للتحديث.');
          }
          final rows = _rowsOf(snap.data);
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: 'لا إشعارات',
              message: 'تحديثات حجوزاتك وطلباتك ستظهر هنا.',
            );
          }
          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, i) {
                final n = rows[i];
                final read = n['isRead'] == true;
                return InkWell(
                  onTap: read ? null : () => _markRead(n['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: read ? c.surface : c.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: read ? c.border : c.primary.withOpacity(0.3)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: (read ? c.textMuted : c.primary).withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(_iconFor(n['type'] as String?), size: 18, color: read ? c.textMuted : c.primary),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['titleAr'] ?? n['title'] ?? 'إشعار', style: AppText.bodyL(read ? c.textSecondary : c.textPrimary)),
                        const SizedBox(height: 2),
                        if (n['bodyAr'] ?? n['body'] != null)
                          Text((n['bodyAr'] ?? n['body']) as String, style: AppText.caption(c.textMuted), maxLines: 2),
                        const SizedBox(height: 4),
                        Text(_fmtDate(n['createdAt'] as String?), style: AppText.caption(c.textMuted)),
                      ])),
                      if (!read) Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    ]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _markRead(String id) {
    ref.read(apiClientProvider).patch('/notifications/$id/read').then((_) {
      if (mounted) setState(_load);
    }).catchError((_) {});
  }

  void _markAllRead() {
    ref.read(apiClientProvider).patch('/notifications/read-all').then((_) {
      if (mounted) setState(() { _unread = 0; _load(); });
    }).catchError((_) {});
  }

  IconData _iconFor(String? type) => switch (type) {
        'BOOKING_CONFIRMED' => Icons.event_available,
        'BOOKING_REJECTED' => Icons.event_busy,
        'BOOKING_COMPLETED' => Icons.celebration_outlined,
        _ => Icons.notifications_active_outlined,
      };

  String _fmtDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _rowsOf(dynamic d) {
    if (d is List) return d.cast<Map<String, dynamic>>();
    if (d is Map && d['data'] is List) return (d['data'] as List).cast<Map<String, dynamic>>();
    return const [];
  }
}
