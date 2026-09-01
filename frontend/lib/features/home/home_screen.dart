import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import 'widgets/category_row.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/location_bar.dart';
import 'widgets/offer_carousel.dart';
import 'widgets/section_header.dart';
import 'widgets/vendor_card.dart';

/// Home — Marketplace ذكية لا مجرد قائمة تصنيفات.
/// الترتيب: موقع → بحث → تصنيفات → عروض → قريب منك → الأكثر طلباً.
/// الحالات: Loading (skeleton لكل قسم) / Error مع كاش / Empty لكل قسم يختفي.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeState { loading, success, error }

class _HomeScreenState extends State<HomeScreen> {
  HomeState _state = HomeState.loading;

  // TODO(Phase-2): استبدالها بـ HomeRepository عند ربط الـ API.
  Future<void> _load() async {
    setState(() => _state = HomeState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _state = HomeState.success);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: c.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocationBar(city: 'دمشق'),
                    const SizedBox(height: AppSpacing.s12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                      child: HomeSearchBar(),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    _section(context),
                    const SizedBox(height: AppSpacing.s24),
                    _offers(context),
                    const SizedBox(height: AppSpacing.s24),
                    SectionHeader(
                        title: 'قريب منك', onSeeAll: () {}),
                    const SizedBox(height: AppSpacing.s12),
                    _nearYou(context),
                    const SizedBox(height: AppSpacing.s24),
                    SectionHeader(title: 'الأكثر طلباً', onSeeAll: () {}),
                    const SizedBox(height: AppSpacing.s12),
                    _popular(context),
                    const SizedBox(height: AppSpacing.s32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// التصنيفات — تختفي كلياً إن لم تحمّل/لا بيانات (لا فراغ بلا معنى).
  Widget _section(BuildContext context) {
    switch (_state) {
      case HomeState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SizedBox(
            height: 88,
            child: Row(
              children: [
                Expanded(child: _CategorySkeleton()),
                SizedBox(width: AppSpacing.s12),
                Expanded(child: _CategorySkeleton()),
                SizedBox(width: AppSpacing.s12),
                Expanded(child: _CategorySkeleton()),
                SizedBox(width: AppSpacing.s12),
                Expanded(child: _CategorySkeleton()),
              ],
            ),
          ),
        );
      case HomeState.success:
        return CategoryRow(items: _demoCategories);
      case HomeState.error:
        return const SizedBox.shrink();
    }
  }

  Widget _offers(BuildContext context) {
    switch (_state) {
      case HomeState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SkeletonLoader(height: 120),
        );
      case HomeState.success:
        return OfferCarousel(offers: _demoOffers);
      case HomeState.error:
        return const SizedBox.shrink();
    }
  }

  Widget _nearYou(BuildContext context) {
    switch (_state) {
      case HomeState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SkeletonLoader(height: 200),
        );
      case HomeState.success:
        return SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            itemCount: _demoVendors.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s12),
            itemBuilder: (context, i) => VendorCard(vendor: _demoVendors[i]),
          ),
        );
      case HomeState.error:
        return const SizedBox.shrink();
    }
  }

  Widget _popular(BuildContext context) {
    switch (_state) {
      case HomeState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SkeletonLoader(height: 200),
        );
      case HomeState.success:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: EmptyState(
            icon: Icons.local_fire_department_outlined,
            title: 'لا يوجد طلبات بعد',
            message: 'الأكثر طلباً في منطقتك سيظهر هنا قريباً.',
            actionLabel: 'استكشف الخدمات',
            onAction: () {},
          ),
        );
      case HomeState.error:
        return const SizedBox.shrink();
    }
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(width: 64, height: 64, borderRadius: BorderRadius.all(Radius.circular(999))),
        SizedBox(height: AppSpacing.s8),
        SkeletonLoader(width: 48, height: 10),
      ],
    );
  }
}

// --- بيانات عرض مؤقتة حتى ربط الـ API (Phase 2) — لا Mock في منطق الإنتاج ---
final _demoCategories = [
  ('قاعات', Icons.account_balance_outlined),
  ('صالونات', Icons.content_cut_outlined),
  ('مطاعم', Icons.restaurant_outlined),
  ('هدايا', Icons.card_giftcard_outlined),
  ('مسابح', Icons.pool_outlined),
  ('تصوير', Icons.camera_alt_outlined),
];

final _demoOffers = [
  ('باقة العرس الكاملة', 'وفّر 20%', Icons.celebration_outlined),
  ('عروض الصالونات', 'خصم 15%', Icons.content_cut_outlined),
];

final _demoVendors = [
  ('قصر الأمل للاحتفالات', 4.8, 'من \$450', 1.2),
  ('صالون ليلى للتجميل', 4.6, 'من \$15', 0.8),
  ('مطعم الديار الشامي', 4.7, 'من \$8', 2.5),
];
