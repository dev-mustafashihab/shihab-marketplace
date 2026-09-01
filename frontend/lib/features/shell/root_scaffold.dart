import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
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

/// Home — كما في التصميم المعتمد (موقع/بحث/تصنيفات/عروض/قريب منك).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final Future<List<Map<String, dynamic>>> _future;
  late final Future<List<Map<String, dynamic>>> _cats;

  @override
  void initState() {
    super.initState();
    final api = ref.read(apiClientProvider);
    _future = api.get('/vendors?limit=10').then((d) {
      final raw = d['data'];
      return (raw as List).cast<Map<String, dynamic>>();
    });
    _cats = api.get('/categories').then((d) => (d as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () async => setState(() {}),
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
                      Icon(Icons.notifications_none, size: 26, color: c.textPrimary),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Container(
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
                  const SizedBox(height: AppSpacing.s24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Text('التصنيفات', style: AppText.headingM(c.textPrimary)),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _cats,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(4, (_) => const SkeletonLoader(width: 60, height: 60, borderRadius: BorderRadius.all(Radius.circular(999)))),
                        );
                      }
                      final cats = (snap.data ?? []).take(6).toList();
                      if (cats.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s16),
                          itemBuilder: (context, i) {
                            final cat = cats[i];
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
                sliver: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return SliverToBoxAdapter(child: Column(
                        children: List.generate(3, (_) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.s12),
                          child: SkeletonLoader(height: 120),
                        )),
                      ));
                    }
                    if (snap.hasError) {
                      return SliverToBoxAdapter(child: ErrorState(
                        message: 'تعذر تحميل البائعين، تحقق من اتصالك',
                        onRetry: () => setState(() {}),
                      ));
                    }
                    final vendors = snap.data ?? [];
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
                        return Container(
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
