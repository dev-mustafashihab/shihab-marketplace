import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../location/location_picker.dart';
import '../notifications/notifications_screen.dart';
import '../home/home_search_sheet.dart';
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

/// شريحة تصنيف أفقية — أيقونة صغيرة واسم + نقر يفتح الاستكشاف المفلتر.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.slug, this.iconKey, required this.onTap});
  final String name;
  final String? slug;
  final String? iconKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spec = _catSpec(slug: slug, iconKey: iconKey);
    return Semantics(
      button: true,
      label: name,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 88, maxWidth: 220, minHeight: 48, maxHeight: 48),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: spec.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(spec.icon, size: 18, color: spec.color),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    name,
                    style: AppText.caption(c.textPrimary),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة «الكل» — تفتح الاستكشاف بلا فلترة تصنيف.
class _CategoryAll extends StatelessWidget {
  const _CategoryAll({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'الكل',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 88, maxWidth: 220, minHeight: 48, maxHeight: 48),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.explore_rounded, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'الكل',
                    style: AppText.caption(Colors.white),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// تسمية السعر بعملة البائع المرسلة من الـ API — لا `$` ثابتة.
String _priceLabel(Map<String, dynamic> v) {
  final price = v['minPrice'];
  final cur = switch ((v['currency'] as String?) ?? 'USD') {
    'SYP' => 'ل.س',
    'TRY' => 'ل.ت',
    _ => 'دولار',
  };
  return 'من $price $cur';
}

/// مواصفات التصنيف: أيقونة + لون مميز.
class _CatSpec {
  const _CatSpec(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_CatSpec _catSpec({String? slug, String? iconKey}) {
  // iconKey القادم من الباكند أولاً، ثم slug، ثم الافتراضي
  switch (iconKey) {
    case 'venue':
      return _CatSpec(Icons.account_balance_rounded, const Color(0xFF8E7CC3));
    case 'salon':
      return _CatSpec(Icons.content_cut_rounded, const Color(0xFFE58BA5));
    case 'restaurant':
      return _CatSpec(Icons.restaurant_rounded, const Color(0xFFE09F5A));
    case 'gift':
      return _CatSpec(Icons.card_giftcard_rounded, const Color(0xFF64B5A4));
    case 'pool':
      return _CatSpec(Icons.pool_rounded, const Color(0xFF5A9BD5));
    case 'camera':
      return _CatSpec(Icons.photo_camera_rounded, const Color(0xFFB08968));
  }
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
    return Semantics(
      button: true,
      label: 'الإشعارات',
      child: Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.notifications_none_rounded, size: 26, color: c.textPrimary),
            ),
          ),
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
      ]),
    );
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

/// بيانات الرئيسية — عند توفر موقع المستخدم: بحث جغرافي PostGIS مرتب بالأقرب (50 كم)
/// وإلا: قائمة مميزة عامة.
final homeVendorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final me = ref.watch(userLocationProvider);
  final api = ref.watch(apiClientProvider);
  final List<Map<String, dynamic>> rows;
  if (me != null) {
    final d = await api.get(
      '/search',
      query: {'lat': me.lat.toStringAsFixed(6), 'lng': me.lng.toStringAsFixed(6), 'radiusKm': '50', 'limit': '10'},
    );
    final raw = d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : <dynamic>[]);
    rows = raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    // الـ API يرتب بالأقرب أصلاً (ORDER BY distance) — ترتيب وقائي على نسخة قابلة للتعديل
    rows.sort((a, b) {
      final da = (a['distanceKm'] as num?)?.toDouble() ?? double.infinity;
      final db = (b['distanceKm'] as num?)?.toDouble() ?? double.infinity;
      return da.compareTo(db);
    });
    return rows;
  }
  final d = await api.get('/vendors?limit=10');
  final raw = d is List
      ? d
      : (d is Map && d['data'] is List ? d['data'] as List : <dynamic>[]);
  return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
});

final homeCategoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/categories');
  if (d is List) return d.cast<Map<String, dynamic>>();
  return const <Map<String, dynamic>>[];
});

/// بطاقة بائع — تصميم أفقي مدمج: صورة 92px + معلومات + شارة مسافة بارزة.
/// المسافة تظهر فقط عند توفر موقع المستخدم — وإلا شارة «مميز».
class _VendorProximityCard extends ConsumerWidget {
  const _VendorProximityCard({required this.v});
  final Map<String, dynamic> v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // المسافة جاهزة من الـ API عند البحث الجغرافي (distanceKm رقم كم) — لا حساب محلي
    final dKm = (v['distanceKm'] as num?)?.toDouble();
    final dist = dKm != null ? '${dKm.toStringAsFixed(dKm < 1 ? 0 : 1)} كم' : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VendorDetailsScreen(idOrSlug: v['slug'] as String? ?? v['id'] as String),
      )),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // الصورة — مربعة مستديرة
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: v['imageUrl'] != null
                ? CachedNetworkImage(
                    imageUrl: 'https://panel.fahd-car.cloud${v['imageUrl']}',
                    width: 92, height: 92, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 92, height: 92, color: c.primary.withOpacity(0.06)),
                    errorWidget: (_, __, ___) => Container(
                      width: 92, height: 92, color: c.primary.withOpacity(0.06),
                      child: Icon(Icons.storefront_outlined, size: 32, color: c.primary.withOpacity(0.4)),
                    ),
                  )
                : Container(
                    width: 92, height: 92, color: c.primary.withOpacity(0.06),
                    child: Icon(Icons.storefront_outlined, size: 32, color: c.primary.withOpacity(0.5)),
                  ),
          ),
          const SizedBox(width: AppSpacing.s12),
          // المعلومات
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v['name'] as String? ?? '',
                    style: AppText.headingS(c.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (v['isOpen'] == true) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Tooltip(
                    message: 'مفتوح الآن',
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
                    ),
                  ),
                ],
                // التقييم يظهر فقط إن وُجد (لا نجمة صفر محرجة)
                if (((v['averageRating'] as num?) ?? 0) > 0) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Icon(Icons.star_rounded, size: 16, color: c.accent),
                  const SizedBox(width: 2),
                  Text('${v['averageRating']} (${v['reviewsCount'] ?? v['reviewCount'] ?? 0})',
                      style: AppText.caption(c.textSecondary)),
                ],
              ]),
              const SizedBox(height: AppSpacing.s4),
              Text(v['description'] as String? ?? '',
                  style: AppText.caption(c.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.s8),
              Row(children: [
                // شارة المسافة أو «مميز»
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dist != null ? c.primary.withOpacity(0.08) : c.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(dist != null ? Icons.near_me_rounded : Icons.workspace_premium_rounded,
                        size: 12, color: dist != null ? c.primary : c.accent),
                    const SizedBox(width: 3),
                    Text(dist ?? 'مميز',
                        style: AppText.caption(dist != null ? c.primary : c.accent)),
                  ]),
                ),
                const SizedBox(width: AppSpacing.s8),
                Icon(Icons.place_outlined, size: 12, color: c.textMuted),
                const SizedBox(width: 2),
                Expanded(child: Text((v['address'] ?? '') as String,
                    style: AppText.caption(c.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: AppSpacing.s4),
                // السعر أدنى اليمين
                if (v['minPrice'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_priceLabel(v),
                        style: AppText.caption(c.primary)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// شريحة فلترة سريعة — أيقونة ملونة + تسمية، حد ملطف بلونها.
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 48,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط البحث والفلاتر الذي يبقى مثبتاً أسفل الهيدر العلوي.
class _HomeFilterBar extends StatelessWidget {
  const _HomeFilterBar({
    required this.c,
    required this.onSearch,
    required this.onFilter,
    required this.onOpenNow,
    required this.onNearby,
    required this.onLowestPrice,
  });

  final AppColors c;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onOpenNow;
  final VoidCallback onNearby;
  final VoidCallback onLowestPrice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.background,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(bottom: BorderSide(color: c.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Expanded(
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 22, color: c.primary),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'قاعة أعراس؟ صالون؟ هدية؟',
                          style: AppText.bodyM(c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              IconButton(
                key: const Key('home-search-filter-inline'),
                onPressed: onFilter,
                icon: Icon(Icons.tune_rounded, size: 20, color: c.primary),
                tooltip: 'فلترة النتائج',
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              children: [
                _QuickChip(
                  icon: Icons.schedule_rounded,
                  label: 'مفتوح الآن',
                  color: c.success,
                  onTap: onOpenNow,
                ),
                const SizedBox(width: AppSpacing.s8),
                _QuickChip(
                  icon: Icons.near_me_rounded,
                  label: 'الأقرب إليك',
                  color: c.primary,
                  onTap: onNearby,
                ),
                const SizedBox(width: AppSpacing.s8),
                _QuickChip(
                  icon: Icons.local_offer_rounded,
                  label: 'الأقل سعراً',
                  color: c.accent,
                  onTap: onLowestPrice,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HomeFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeFilterHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _HomeFilterHeaderDelegate oldDelegate) => true;
}

/// Home — كما في التصميم المعتمد (موقع/بحث/تصنيفات/عروض/قريب منك).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  final ValueNotifier<double> _topOpacity = ValueNotifier<double>(1);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    final opacity = (1 - (_scrollController.offset / 56)).clamp(0.0, 1.0);
    if ((_topOpacity.value - opacity).abs() > 0.01) _topOpacity.value = opacity;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _topOpacity.dispose();
    super.dispose();
  }

  void _openNearby(BuildContext context) {
    if (ref.read(userLocationProvider) == null) {
      showLocationPicker(context, ref);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ExploreScreen(nearby: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vendorsAsync = ref.watch(homeVendorsProvider);
    final catsAsync = ref.watch(homeCategoriesProvider);
    final topIdentity = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.s12, AppSpacing.screenH, 0),
      child: Column(children: [
        Row(children: [
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_rounded, size: 20, color: c.primary),
                  const SizedBox(width: AppSpacing.s4),
                  Flexible(child: Text(ref.watch(userCityProvider),
                      style: AppText.headingS(c.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: c.textMuted),
                ]),
              ),
            ),
          ])),
          _BellButton(c: c),
        ]),
        const SizedBox(height: AppSpacing.s8),
        Container(
          height: 2,
          width: 56,
          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2)),
        ),
      ]),
    );
    final filterBar = _HomeFilterBar(
      c: c,
      onSearch: () => showHomeSearchSheet(context, ref),
      onFilter: () => showHomeSearchSheet(context, ref, openFilters: true),
      onOpenNow: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ExploreScreen(openNow: true),
      )),
      onNearby: () => _openNearby(context),
      onLowestPrice: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ExploreScreen(lowestPrice: true),
      )),
    );

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
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ValueListenableBuilder<double>(
                  valueListenable: _topOpacity,
                  child: topIdentity,
                  builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeFilterHeaderDelegate(child: filterBar, height: 124),
              ),
              SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: AppSpacing.s20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Text('التصنيفات', style: AppText.headingM(c.textPrimary)),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  catsAsync.when(
                    loading: () => SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
                        itemBuilder: (_, __) => const SkeletonLoader(
                          width: 126,
                          height: 48,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) {
                      final shown = cats.toList();
                      if (shown.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                          itemCount: shown.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return _CategoryAll(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const ExploreScreen(),
                                )),
                              );
                            }
                            final cat = shown[i - 1];
                            return _CategoryCard(
                              name: (cat['nameAr'] ?? '') as String,
                              slug: cat['slug'] as String?,
                              iconKey: cat['iconKey'] as String?,
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
                      Text(ref.watch(userLocationProvider) != null ? 'الأقرب إليك' : 'مميز لك',
                          style: AppText.headingM(c.textPrimary)),
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
                        onAction: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ExploreScreen(),
                        )),
                      ));
                    }
                    return SliverList.separated(
                      itemCount: vendors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (context, i) => _VendorProximityCard(v: vendors[i]),
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
