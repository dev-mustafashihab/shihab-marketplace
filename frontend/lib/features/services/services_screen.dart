import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../home/state/home_feed_provider.dart';
import '../home/models/home_feed.dart';
import '../../core/session/session_service.dart';
import '../home/home_search_sheet.dart';
import '../explore/explore_screen.dart';
import '../location/location_picker.dart';
import '../home/widgets/vendor_proximity_card.dart';

/// خدمات — كان محتوى الرئيسية سابقاً (بحث + فلتر + كروت)
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});
  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
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
    _scrollController..removeListener(_handleScroll)..dispose();
    _topOpacity.dispose();
    super.dispose();
  }

  void _openNearby(BuildContext context) {
    if (ref.read(userLocationProvider) == null) {
      showLocationPicker(context, ref);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen(nearby: true)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vendorsAsync = ref.watch(homeVendorsProvider);
    final topIdentity = const UnifiedHeader();
    final filterBar = _ServicesFilterBar(
      c: c,
      onSearch: () => showHomeSearchSheet(context, ref),
      onFilter: () => showHomeSearchSheet(context, ref, openFilters: true),
      onOpenNow: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen(openNow: true))),
      onNearby: () => _openNearby(context),
      onLowestPrice: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen(lowestPrice: true))),
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
                delegate: _ServicesFilterHeaderDelegate(child: filterBar, height: ref.watch(homeCategoryProvider) != null || ref.watch(homeMaxPriceProvider) != null ? 164 : 124),
              ),
              const SliverToBoxAdapter(child: _BookingCategoriesSection()),
              SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: AppSpacing.s12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                    child: Row(children: [
                      Icon(Icons.near_me_rounded, size: 16, color: c.primary),
                      const SizedBox(width: AppSpacing.s4),
                      Text(ref.watch(userLocationProvider) != null ? 'الأقرب إليك' : 'مميز لك', style: AppText.headingM(c.textPrimary)),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: vendorsAsync.when(
                  loading: () => const SliverToBoxAdapter(child: Column(children: [
                    Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                    Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                    Padding(padding: EdgeInsets.only(bottom: AppSpacing.s12), child: SkeletonLoader(height: 120)),
                  ])),
                  error: (_, __) => SliverToBoxAdapter(child: ErrorState(message: 'تعذر تحميل البائعين، تحقق من اتصالك', onRetry: () { ref.invalidate(homeVendorsProvider); })),
                  data: (vendors) {
                    final filtered = ref.watch(homeCategoryProvider) != null || ref.watch(homeMaxPriceProvider) != null;
                    if (vendors.isEmpty) {
                      return SliverToBoxAdapter(child: EmptyState(
                        icon: Icons.store_mall_directory_outlined,
                        title: filtered ? 'لا نتائج مطابقة للفلاتر' : 'لا يوجد بائعون بعد',
                        message: filtered ? 'جرّب تعديل الفلاتر أو اعرض الكل.' : 'البائعون القريبون منك سيظهرون هنا.',
                        actionLabel: filtered ? 'عرض الكل' : 'استكشف الخدمات',
                        onAction: filtered ? () => clearHomeFilters(ref) : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                      ));
                    }
                    return SliverList.separated(
                      itemCount: vendors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (context, i) => VendorProximityCard(v: vendors[i]),
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

/// أقسام الحجز السريع: قاعات / مسابح / صالونات / هدايا.
/// الضغط يفلتر قائمة المزودين على القسم (نفس فلتر التصنيف).
class _BookingCategoriesSection extends ConsumerWidget {
  const _BookingCategoriesSection();

  static const _cats = [
    (slug: 'venues', label: 'قاعات ومناسبات', icon: HugeIcons.strokeRoundedBuilding02),
    (slug: 'pools', label: 'مسابح وشاليهات', icon: HugeIcons.strokeRoundedDroplet),
    (slug: 'salons', label: 'صالونات وتجميل', icon: HugeIcons.strokeRoundedChairBarber),
    (slug: 'gifts', label: 'هدايا وورد', icon: HugeIcons.strokeRoundedGift),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final cats = ref.watch(homeCategoriesProvider).valueOrNull ?? const <HomeCategory>[];
    final selectedId = ref.watch(homeCategoryProvider);
    String? idFor(String slug) {
      for (final t in cats) {
        if (t.slug == slug) return t.id;
      }
      return null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.s12, AppSpacing.screenH, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('احجز حسب القسم', style: AppText.headingM(c.textPrimary)),
        const SizedBox(height: AppSpacing.s8),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.s8,
          mainAxisSpacing: AppSpacing.s8,
          childAspectRatio: 2.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final cat in _cats)
              Builder(builder: (_) {
                final id = idFor(cat.slug);
                final sel = id != null && id == selectedId;
                return Material(
                  color: sel ? c.primary.withOpacity(0.10) : c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  child: InkWell(
                    onTap: id == null
                        ? null
                        : () => ref.read(homeCategoryProvider.notifier).state = sel ? null : id,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: sel ? c.primary : c.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(sel ? 0.16 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: HugeIcon(icon: cat.icon, color: c.primary, size: 19)),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(cat.label,
                              style: AppText.bodyM(c.textPrimary).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (sel) Icon(Icons.check_circle_rounded, size: 18, color: c.primary),
                      ]),
                    ),
                  ),
                );
              }),
          ],
        ),
      ]),
    );
  }
}

/// Re-export filter bar for services (same as home)
class _ServicesFilterBar extends ConsumerWidget {
  const _ServicesFilterBar({required this.c, required this.onSearch, required this.onFilter, required this.onOpenNow, required this.onNearby, required this.onLowestPrice});
  final AppColors c;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onOpenNow;
  final VoidCallback onNearby;
  final VoidCallback onLowestPrice;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: c.background,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        decoration: BoxDecoration(color: c.background, border: Border(bottom: BorderSide(color: c.border)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
            child: Row(children: [
              Expanded(child: InkWell(onTap: onSearch, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12), child: Row(children: [Icon(Icons.search_rounded, size: 22, color: c.primary), const SizedBox(width: AppSpacing.s12), Expanded(child: Text('قاعة أعراس؟ صالون؟ هدية؟', style: AppText.bodyM(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis))])))),
              IconButton(key: const Key('home-search-filter-inline'), onPressed: onFilter, icon: Icon(Icons.tune_rounded, size: 20, color: c.primary), tooltip: 'فلترة النتائج'),
            ]),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH), children: [
            _QuickChip(icon: Icons.schedule_rounded, label: 'مفتوح الآن', color: c.success, onTap: onOpenNow),
            const SizedBox(width: AppSpacing.s8),
            _QuickChip(icon: Icons.near_me_rounded, label: 'الأقرب إليك', color: c.primary, onTap: onNearby),
            const SizedBox(width: AppSpacing.s8),
            _QuickChip(icon: Icons.local_offer_rounded, label: 'الأقل سعراً', color: c.accent, onTap: onLowestPrice),
          ])),
          if (ref.watch(homeCategoryProvider) != null || ref.watch(homeMaxPriceProvider) != null) ...[
            const SizedBox(height: AppSpacing.s8),
            SizedBox(height: 32, child: _ServicesActiveFiltersRow(c: c, onAdjust: onSearch)),
          ],
        ]),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 48, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withOpacity(0.35))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color))])))));
  }
}

class _ServicesActiveFiltersRow extends ConsumerWidget {
  const _ServicesActiveFiltersRow({required this.c, required this.onAdjust});
  final AppColors c; final VoidCallback onAdjust;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catId = ref.watch(homeCategoryProvider);
    final maxPrice = ref.watch(homeMaxPriceProvider);
    final currency = ref.watch(homeCurrencyProvider);
    String? catName;
    final cats = ref.watch(homeCategoriesProvider).valueOrNull;
    if (cats != null) { for (final t in cats) { if (t.id == catId) { catName = t.nameAr; break; } } }
    return ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH), children: [
      if (catId != null) Padding(padding: const EdgeInsets.only(left: AppSpacing.s8), child: InputChip(label: Text(catName ?? 'تصنيف'), selected: true, onPressed: onAdjust, onDeleted: () => ref.read(homeCategoryProvider.notifier).state = null, deleteButtonTooltipMessage: 'مسح فلتر التصنيف')),
      if (maxPrice != null) Padding(padding: const EdgeInsets.only(left: AppSpacing.s8), child: InputChip(label: Text('حتى ${maxPrice.round()} ${currencyName(currency)}'), selected: true, onPressed: onAdjust, onDeleted: () => ref.read(homeMaxPriceProvider.notifier).state = null, deleteButtonTooltipMessage: 'مسح فلتر السعر')),
      ActionChip(label: const Text('مسح الكل'), onPressed: () => clearHomeFilters(ref)),
    ]);
  }
}

class _ServicesFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ServicesFilterHeaderDelegate({required this.child, required this.height});
  final Widget child; final double height;
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(covariant _ServicesFilterHeaderDelegate oldDelegate) => true;
}
