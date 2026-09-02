import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../vendors/vendor_details_screen.dart';

/// المفضلة — قائمة بائعين محفوظين عبر GET /favorites.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiClientProvider).get('/favorites').catchError((_) => 'ERR');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (ref.watch(apiClientProvider).token == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(title: const Text('المفضلة')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'سجّل الدخول لعرض المفضلة',
          message: 'اضغط على القلب في صفحة البائع لإضافته للمفضلة.',
          actionLabel: 'تسجيل الدخول',
          onAction: () => _goLogin(context),
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('المفضلة')),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 72),
            )));
          }
          if (snap.data == 'ERR' || snap.hasError) {
            return ErrorState(message: 'تعذر تحميل المفضلة', onRetry: _load);
          }
          final rows = _rowsOf(snap.data);
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'لا مفضلة بعد',
              message: 'اضغط على القلب في صفحة أي بائع ليظهر هنا.',
              actionLabel: 'استكشف البائعين',
              onAction: () => Navigator.of(context).maybePop(),
            );
          }
          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
              itemBuilder: (context, i) {
                final f = rows[i];
                final v = (f['vendor'] as Map?) ?? const {};
                return InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VendorDetailsScreen(idOrSlug: (v['slug'] ?? v['id'] ?? '') as String),
                  )),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border)),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: c.primary.withOpacity(0.08), shape: BoxShape.circle),
                        child: Icon(Icons.storefront_outlined, size: 22, color: c.primary),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((v['name'] ?? '') as String, style: AppText.headingS(c.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text((((v['category'] ?? const {}) as Map)['nameAr'] ?? '') as String,
                            style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      Icon(Icons.favorite, size: 20, color: c.accent),
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

  /// الاستجابة قد تكون [total, rows] أو [rows] — بأمان.
  List<Map<String, dynamic>> _rowsOf(dynamic d) {
    if (d is List) {
      if (d.length == 2 && d[0] is num && d[1] is List) return (d[1] as List).cast<Map<String, dynamic>>();
      return d.cast<Map<String, dynamic>>();
    }
    if (d is Map && d['data'] is List) return (d['data'] as List).cast<Map<String, dynamic>>();
    return const [];
  }

  void _goLogin(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LoginScreen(),
      settings: const RouteSettings(name: '/login'),
    ));
  }
}
