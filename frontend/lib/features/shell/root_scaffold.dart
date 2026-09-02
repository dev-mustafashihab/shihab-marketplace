import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../notifications/notifications_screen.dart';
import '../vendors/vendor_details_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../features/bookings/my_bookings_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/profile_screen.dart';

/// الجذر: Bottom Shell + عربي RTL من اللحظة الأولى.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const ExploreScreen(),
      const MyBookingsScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];
    return AppShell(child: pages[_tab], currentIndex: _tab, onTap: (i) => setState(() => _tab = i));
  }
}

/// بيانات الرئيسية — FutureProvider يعاد إنشاؤه تلقائياً عند الإبطال.
final homeVendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/vendors?limit=10');
  if (d is List) return d.cast<Map<String, dynamic>>();
  if (d is Map && d['data'] is List) return (d['data'] as List).cast<Map<String, dynamic>>();
  return const <Map<String, dynamic>>[];
});

final homeCategoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/categories');
  if (d is List) return d.cast<Map<String, dynamic>>();
  return const <Map<String, dynamic>>[];
});

/// Home — كما في التصميم المعتمد (موقع/بحث/تصنيفات/عروض/قريب منك).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final vendorsAsync = ref.watch(homeVendorsProvider);
    final catsAsync = ref.watch(homeCategoriesProvider);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () async {
            ref.invalidate(homeVendorsProvider);
            ref.invalidate(homeCategoriesProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
                    child: Row(children: [
                      Icon(Icons.location_on_outlined, size: 20, color: c.primary),
                      const SizedBox(width: AppSpacing.s4),
                      Flexible(child: Text('دمشق', style: AppText.headingS(c.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Icon(Icons.keyboard_arrow_down, size: 20, color: c.textMuted),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        child: Icon(Icons.notifications_none, size: 26, color: c.textPrimary),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ExploreScreen(),
                    )),
                    child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.search, size: 22, color: c.textMuted),
                      const SizedBox(width: AppSpacing.s12),
                      Text('ابحث عن خدمة...', style: AppText.bodyM(c.textMuted)),
                    ]),
                  ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Text('التصنيفات', style: AppText.headingM(c.textPrimary)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  catsAsync.when(
                    loading: () { return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(4, (_) => const SkeletonLoader(width: 60, height: 60, borderRadius: BorderRadius.all(Radius.circular(999)))),
                    ); },
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) {
                      final shown = cats.take(6).toList();
                      if (shown.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s16),
                          itemBuilder: (context, i) {
                            final cat = shown[i];
                            return SizedBox(
                              width: 68,
                              child: Column(children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(color: c.primary.withOpacity(0.08), shape: BoxShape.circle),
                                  child: Icon(Icons.storefront_outlined, size: 26, color: c.primary),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Text(cat['nameAr'] as String? ?? '',
                                    style: AppText.caption(c.textSecondary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Text('قريب منك', style: AppText.headingM(c.textPrimary)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: vendorsAsync.when(
                  loading: () => const SliverToBoxAdapter(child: Column(
                    children: [
                      Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                      Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                      Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                    ],
                  )),
                  error: (_, __) => SliverToBoxAdapter(child: ErrorState(
                    message: 'تعذر تحميل البائعين، تحقق من اتصالك',
                    onRetry: () { ref.invalidate(homeVendorsProvider); },
                  )),
                  data: (vendors) {
                    if (vendors.isEmpty) {
                      return SliverToBoxAdapter(child: EmptyState(
                        icon: Icons.store_mall_directory_outlined,
                        title: 'لا يوجد بائعون بعد',
                        message: 'البائعون القريبون منك سيظهرون هنا.',
                        actionLabel: 'استكشف الخدمات',
                      ));
                    }
                    return SliverList.separated(
                      itemCount: vendors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (context, i) {
                        final v = vendors[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VendorDetailsScreen(idOrSlug: v['slug'] as String? ?? v['id'] as String),
                          )),
                          child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(v['name'] as String? ?? '',
                                  style: AppText.headingS(c.textPrimary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: AppSpacing.s8),
                              Icon(Icons.star, size: 16, color: c.accent),
                              Text(' ${v['minPrice'] != null ? '${v['minPrice']} \$+' : '—'}',
                                  style: AppText.caption(c.textSecondary)),
                            ]),
                            const SizedBox(height: AppSpacing.s8),
                            Text(v['description'] as String? ?? '',
                                style: AppText.bodyM(c.textSecondary),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: AppSpacing.s8),
                            Row(children: [
                              if (v['address'] != null) ...[
                                Icon(Icons.place_outlined, size: 14, color: c.textMuted),
                                const SizedBox(width: 2),
                                Flexible(child: Text(v['address'] as String,
                                    style: AppText.caption(c.textMuted),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ]),
                          ]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
            ],
          ),
        ),
      ),
    );
  }
}
