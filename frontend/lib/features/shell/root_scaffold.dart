import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../location/location_picker.dart';
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

/// بطاقة تصنيف — لون مميز لكل نوع + نقر يفتح الاستكشاف المفلتر.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.slug, required this.onTap});
  final String name;
  final String? slug;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spec = _catSpec(slug);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s4),
        decoration: BoxDecoration(
          color: spec.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: spec.color.withOpacity(0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: spec.color, borderRadius: BorderRadius.circular(13)),
            child: Icon(spec.icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            width: 78,
            child: Text(name, style: AppText.caption(c.textPrimary),
                maxLines: 2, textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

/// مواصفات التصنيف: أيقونة + لون مميز.
class _CatSpec {
  const _CatSpec(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_CatSpec _catSpec(String? slug) {
  // الألوان ثابتة (بلا context) — درجات متناسقة مع الهوية
  switch (slug) {
    case 'venues':
      return _CatSpec(Icons.account_balance_rounded, const Color(0xFF8E7CC3));
    case 'salons':
      return _CatSpec(Icons.content_cut_rounded, const Color(0xFFE58BA5));
    case 'restaurants':
      return _CatSpec(Icons.restaurant_rounded, const Color(0xFFE09F5A));
    case 'gifts':
      return _CatSpec(Icons.card_giftcard_rounded, const Color(0xFF64B5A4));
    case 'pools':
      return _CatSpec(Icons.pool_rounded, const Color(0xFF5A9BD5));
    case 'photography':
      return _CatSpec(Icons.photo_camera_rounded, const Color(0xFFB08968));
    default:
      return _CatSpec(Icons.storefront_rounded, const Color(0xFF6B8E7B));
  }
}

/// جرس الإشعارات مع عداد غير المقروء (حي عبر provider).
class _BellButton extends ConsumerWidget {
  const _BellButton({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(sessionTokenProvider);
    final unreadAsync = ref.watch(_unreadProvider(token));
    final unread = unreadAsync.valueOrNull ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        icon: Icon(Icons.notifications_none_rounded, size: 26, color: c.textPrimary),
      ),
      if (unread > 0)
        Positioned(
          top: 6, left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
        ),
    ]);
  }
}

final _unreadProvider = FutureProvider.autoDispose.family<int, String?>((ref, token) async {
  final token = ref.watch(sessionTokenProvider);
  if (token == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    return d is int ? d : (d is num ? d.toInt() : 0);
  } catch (_) {
    return 0;
  }
});

/// أيقونة التصنيف حسب slug — هوية بصرية مميزة لكل نوع خدمة.
IconData _iconForCategory(String? slug) => switch (slug) {
      'venues' => Icons.account_balance,
      'salons' => Icons.content_cut,
      'restaurants' => Icons.restaurant,
      'gifts' => Icons.card_giftcard,
      'pools' => Icons.pool,
      'photography' => Icons.photo_camera,
      _ => Icons.storefront_outlined,
    };

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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.s12, AppSpacing.screenH, 0),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Builder(builder: (context) {
                          final h = DateTime.now().hour;
                          final greet = h < 12 ? 'صباح الخير' : (h < 18 ? 'مساء النور' : 'مساء الخير');
                          return Text(greet, style: AppText.caption(c.textMuted));
                        }),
                        const SizedBox(height: AppSpacing.s4),
                        InkWell(
                          onTap: () => showLocationPicker(context, ref),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.location_on_rounded, size: 20, color: c.primary),
                            const SizedBox(width: AppSpacing.s4),
                            Flexible(child: Text(ref.watch(userCityProvider),
                                style: AppText.headingS(c.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: c.textMuted),
                          ]),
                        ),
                      ])),
                      _BellButton(c: c),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ExploreScreen(),
                    )),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                        boxShadow: [BoxShadow(color: c.primary.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Icon(Icons.search_rounded, size: 22, color: c.primary),
                        const SizedBox(width: AppSpacing.s12),
                        Text('قاعة أعراس؟ صالون؟ هدية؟', style: AppText.bodyM(c.textMuted)),
                        const Spacer(),
                        Icon(Icons.tune_rounded, size: 20, color: c.textMuted),
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
                      children: List.generate(4, (_) => const SkeletonLoader(width: 76, height: 84, borderRadius: BorderRadius.all(Radius.circular(16)))),
                    ); },
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) {
                      final shown = cats.take(6).toList();
                      if (shown.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 108,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s12),
                          itemBuilder: (context, i) {
                            final cat = shown[i];
                            return _CategoryCard(
                              name: (cat['nameAr'] ?? '') as String,
                              slug: cat['slug'] as String?,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ExploreScreen(categoryId: cat['id'] as String),
                              )),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Row(children: [
                      Icon(Icons.near_me_rounded, size: 16, color: c.primary),
                      const SizedBox(width: AppSpacing.s4),
                      Text(ref.watch(userCityProvider) == 'موقعي الحالي' ? 'الأقرب إليك' : 'مميز لك',
                          style: AppText.headingM(c.textPrimary)),
                      const Spacer(),
                      Text('عرض الكل', style: AppText.caption(c.primary)),
                    ]),
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
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // صورة الغلاف — 150px مع fallback أنيق
                            if (v['imageUrl'] != null)
                              CachedNetworkImage(
                                imageUrl: 'https://panel.fahd-car.cloud${v['imageUrl']}',
                                height: 130, width: double.infinity, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(height: 130, color: c.primary.withOpacity(0.06)),
                                errorWidget: (_, __, ___) => Container(
                                  height: 130, color: c.primary.withOpacity(0.06),
                                  child: Icon(Icons.storefront_outlined, size: 40, color: c.primary.withOpacity(0.4)),
                                ),
                              )
                            else
                              Container(
                                height: 130, width: double.infinity, color: c.primary.withOpacity(0.06),
                                child: Icon(Icons.storefront_outlined, size: 40, color: c.primary.withOpacity(0.5)),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(v['name'] as String? ?? '',
                                      style: AppText.headingS(c.textPrimary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: AppSpacing.s8),
                                  Icon(Icons.star, size: 16, color: c.accent),
                                  const SizedBox(width: 2),
                                  Text('${v['averageRating'] ?? 0}',
                                      style: AppText.caption(c.textSecondary)),
                                  const SizedBox(width: AppSpacing.s8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(v['minPrice'] != null ? 'من ${v['minPrice']} \$' : '—',
                                        style: AppText.caption(c.primary)),
                                  ),
                                ]),
                                const SizedBox(height: AppSpacing.s8),
                                Text(v['description'] as String? ?? '',
                                    style: AppText.bodyM(c.textSecondary),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: AppSpacing.s8),
                                Row(children: [
                                  Icon(Icons.place_outlined, size: 14, color: c.textMuted),
                                  const SizedBox(width: 2),
                                  Flexible(child: Text((v['address'] ?? '') as String,
                                      style: AppText.caption(c.textMuted),
                                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  // المسافة من موقع المستخدم إن توفرت
                                  Builder(builder: (context) {
                                    final me = ref.watch(userLocationProvider);
                                    final vLat = v['latitude'];
                                    final vLng = v['longitude'];
                                    if (me == null || vLat == null || vLng == null) return const SizedBox.shrink();
                                    final dist = distanceKm(me.lat, me.lng,
                                        double.parse(vLat.toString()), double.parse(vLng.toString()));
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: c.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.near_me_rounded, size: 11, color: c.primary),
                                          const SizedBox(width: 2),
                                          Text(dist, style: AppText.caption(c.primary)),
                                        ]),
                                      ),
                                    );
                                  }),
                                ]),
                              ]),
                            ),
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
