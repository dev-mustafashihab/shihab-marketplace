import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/press_scale.dart';
import '../home/models/home_feed.dart';
import '../vendors/vendor_details_screen.dart';
import '../notifications/notifications_screen.dart';
import '../location/location_picker.dart';

/// استكشف — بحث حي + سطر واحد للتصنيف والفرز + عداد عائم + كروت أفقية.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    super.key,
    this.categoryId,
    this.openNow = false,
    this.nearby = false,
    this.lowestPrice = false,
  });
  final String? categoryId;
  final bool openNow;
  final bool nearby;
  final bool lowestPrice;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  static const _limit = 20;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  double? _maxPrice;
  String _currency = 'USD';
  String? _catId;
  Future<List<HomeCategory>>? _catsFuture;

  String? _sort;
  bool _openNow = false;

  List<VendorCard> _rows = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _total = 0;
  int _loadSeq = 0;
  bool _showCatSort = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _catId = widget.categoryId;
    _openNow = widget.openNow;
    if (widget.lowestPrice) _sort = 'price';
    if (widget.nearby) _sort = 'distance';
    _catsFuture = _loadCategories();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScrollNearEnd);
    _scroll.addListener(_onScrollForBar);
    _reload();
  }

  Future<List<HomeCategory>> _loadCategories() async {
    final d = await ref.read(apiClientProvider).get('/categories');
    return parseHomeCategories(d);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _scroll
      ..removeListener(_onScrollNearEnd)
      ..removeListener(_onScrollForBar)
      ..dispose();
    super.dispose();
  }

  void _onScrollForBar() {
    if (!_scroll.hasClients) return;
    final off = _scroll.offset;
    if (off > _lastScrollOffset + 12 && off > 40 && _showCatSort) {
      setState(() => _showCatSort = false);
    } else if (off < _lastScrollOffset - 12 && !_showCatSort) {
      setState(() => _showCatSort = true);
    }
    _lastScrollOffset = off;
  }

  void _onTextChanged() {
    final q = _controller.text.trim();
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _onScrollNearEnd() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore || _rows.isEmpty) return;
    if (_scroll.position.extentAfter < 500) _fetch();
  }

  Map<String, String> _params(int page) {
    final location = ref.read(userLocationProvider);
    final q = <String, String>{
      'limit': '$_limit',
      'page': '$page',
      if (_query.isNotEmpty) 'q': _query,
      if (_maxPrice != null) ...{
        'maxPrice': _maxPrice!.round().toString(),
        'currency': _currency,
      },
      if (_catId != null) 'categoryId': _catId!,
      if (_openNow) 'openNow': 'true',
      if (_sort != null) 'sort': _sort!,
    };
    if (location != null) {
      q['lat'] = location.lat.toString();
      q['lng'] = location.lng.toString();
      if (_sort == 'distance') q['radiusKm'] = '50';
    }
    return q;
  }

  Map<String, String> _effectiveParams(int page) => _params(page);

  Future<void> _reload() async {
    _loadSeq++;
    setState(() {
      _page = 1;
      _rows = [];
      _hasMore = true;
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    if (!_hasMore || _loadingMore) return;
    final seq = _loadSeq;
    setState(() => _loadingMore = true);
    try {
      final d = await ref.read(apiClientProvider).get('/search', query: _effectiveParams(_page));
      if (seq != _loadSeq || !mounted) return;
      final got = parseVendorCards(d);
      final meta = d is Map ? d['meta'] as Map? : null;
      final total = (meta?['total'] as num?)?.toInt() ?? got.length;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_page == 1) {
          _rows = got;
          _total = total;
        } else {
          _rows.addAll(got);
        }
        _hasMore = got.length >= _limit;
        if (_hasMore) _page++;
      });
    } catch (e) {
      if (seq != _loadSeq || !mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_rows.isEmpty) {
          _error = e;
        } else {
          _hasMore = false;
        }
      });
    }
  }

  void _selectCategory(String? id) {
    if (_catId == id) return;
    setState(() => _catId = id);
    _reload();
  }

  void _setPrice(double? value) {
    setState(() => _maxPrice = value);
    _reload();
  }

  void _setCurrency(String code) {
    setState(() {
      _currency = code;
      _maxPrice = null;
    });
    _reload();
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _query = '';
      _catId = null;
      _maxPrice = null;
      _currency = 'USD';
      _sort = null;
      _openNow = false;
    });
    _reload();
  }

  void _setSort(String? sort) {
    if (_sort == sort) {
      setState(() => _sort = null);
    } else {
      if (sort == 'distance' && ref.read(userLocationProvider) == null) {
        showLocationPicker(context, ref);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر موقعك أولاً لترتيب الأقرب إليك')),
        );
        return;
      }
      setState(() => _sort = sort);
    }
    _reload();
  }

  void _toggleOpenNow() {
    setState(() => _openNow = !_openNow);
    _reload();
  }

  Future<void> _openFilters() async {
    final cats = await _catsFuture;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExploreFilterSheet(
        catId: _catId,
        maxPrice: _maxPrice,
        currency: _currency,
        categories: cats ?? [],
        onCategory: (id) => _selectCategory(id),
        onPrice: _setPrice,
        onCurrency: _setCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasActive = _catId != null || _maxPrice != null || _openNow || _sort != null;
    // رسالة ترحيبية حسب الوقت — نفس منطق الرئيسية
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'صباح الخير' : (h < 18 ? 'مساء النور' : 'مساء الخير');
    final city = ref.watch(userCityProvider);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
        // برداية علوية: ترحيب + جرس + بحث — نفس مقاسات الرئيسية (s12 + divider 56 + بحث 52)
        Column(children: [
              // سطر الترحيب مع زر الإشعارات — نفس padding الرئيسية
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.s12, AppSpacing.screenH, 0),
                child: Column(children: [
                  Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greet, style: AppText.caption(c.textMuted)),
                    const SizedBox(height: AppSpacing.s4),
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 14, color: c.primary),
                      const SizedBox(width: 4),
                      Flexible(child: Text(city, style: AppText.headingS(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ])),
                  _ExploreBell(c: c),
                ]),
                  const SizedBox(height: AppSpacing.s8),
                  Container(height: 2, width: 56, decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2))),
                ]),
              ),
              const SizedBox(height: AppSpacing.s12),
              // مربع البحث — نفس ارتفاع الرئيسية 52 مع نفس الحواف والظل
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن قاعة، صالون، مطعم…',
                        prefixIcon: Icon(Icons.search_rounded, color: c.primary),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => _controller.clear(),
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: 'مسح',
                              ),
                        filled: true,
                        fillColor: c.surface,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _openFilters,
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: hasActive || _query.isNotEmpty ? c.primary : c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hasActive || _query.isNotEmpty ? c.primary : c.border),
                        ),
                        child: Icon(Icons.tune_rounded, color: hasActive || _query.isNotEmpty ? Colors.white : c.primary, size: 20),
                      ),
                      if ((() {
                        var n = 0;
                        if (_catId != null) n++;
                        if (_maxPrice != null) n++;
                        if (_openNow) n++;
                        if (_sort != null) n++;
                        return n;
                      }()) > 0)
                        Positioned(
                          top: -4, left: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '${(_catId != null ? 1 : 0) + (_maxPrice != null ? 1 : 0) + (_openNow ? 1 : 0) + (_sort != null ? 1 : 0)}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ]),
        const SizedBox(height: 10),
        // سطر واحد للتصنيف والفرز — أنحف 32px ويختفي عند النزول
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _showCatSort
              ? SizedBox(
          height: 32,
          child: FutureBuilder<List<HomeCategory>>(
            future: _catsFuture,
            builder: (context, snap) {
              final cats = snap.data ?? const <HomeCategory>[];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                children: [
                  for (final cat in [null, ...cats])
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s8),
                      child: _catChip(c, cat == null ? 'الكل' : cat.nameAr, cat?.id),
                    ),
                  // فاصل رفيع
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: VerticalDivider(width: 1, thickness: 1, color: c.border),
                  ),
                  _sortChip(c, 'المميز', null, _sort == null && !_openNow),
                  _sortChip(c, 'مفتوح الآن', '__open__', _openNow, icon: Icons.schedule_rounded),
                  _sortChip(c, 'الأعلى تقييماً', 'rating', _sort == 'rating', icon: Icons.star_rounded),
                  _sortChip(c, 'الأقرب', 'distance', _sort == 'distance', icon: Icons.near_me_rounded),
                  _sortChip(c, 'الأقل سعراً', 'price', _sort == 'price', icon: Icons.local_offer_rounded),
                ],
              );
            },
          ),
        )
              : const SizedBox.shrink(),
        ),
        // عداد خفيف فقط — بلا كرت عائم، الشرائح النشطة صارت شارة على زر الفلترة
        if (!_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('$_total مزود', style: AppText.caption(c.textMuted)),
            ),
          ),
        const SizedBox(height: AppSpacing.s8),
        Expanded(child: _body(c)),
      ]),
      ),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonLoader(height: 160),
      );
    }
    if (_error != null) {
      return ErrorState(
        message: ((_error as dynamic)?.message as String?) ?? 'خطأ',
        onRetry: _reload,
      );
    }
    if (_rows.isEmpty) {
      return FutureBuilder<List<HomeCategory>>(
        future: _catsFuture,
        builder: (context, snap) {
          final cats = snap.data ?? [];
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                EmptyState(
                  icon: Icons.search_off,
                  title: 'لا نتائج مطابقة',
                  message: 'جرّب كلمات أخرى أو وسّع الفلاتر.',
                  actionLabel: 'مسح الكل',
                  onAction: _clearAll,
                ),
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Text('جرّب تصنيفاً شائعاً:', style: AppText.caption(c.textMuted)),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final cat in cats.take(6))
                        ActionChip(
                          label: Text(cat.nameAr),
                          onPressed: () => _selectCategory(cat.id),
                        ),
                    ],
                  ),
                ],
              ]),
            ),
          );
        },
      );
    }
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _reload,
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _rows.length + (_hasMore ? 2 : 0),
        itemBuilder: (context, i) {
          if (i >= _rows.length) {
            return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2)));
          }
          return _ExploreGridCard(v: _rows[i]);
        },
      ),
    );
  }

  Widget _catChip(AppColors c, String label, String? id) {
    final selected = _catId == id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? c.surface : c.textSecondary)),
      selected: selected,
      onSelected: (_) => _selectCategory(id),
      selectedColor: c.primary,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: selected ? c.primary : c.border, width: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _sortChip(AppColors c, String label, String? value, bool selected, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      child: ChoiceChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: selected ? Colors.white : c.textMuted), const SizedBox(width: 3)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : c.textSecondary)),
        ]),
        selected: selected,
        onSelected: (_) {
          if (value == '__open__') {
            _toggleOpenNow();
          } else {
            _setSort(value);
          }
        },
        selectedColor: value == '__open__' ? c.success : c.primary,
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: selected ? (value == '__open__' ? c.success : c.primary) : c.border, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// كرت شبكي مربع لاستكشف — صورة علوية + معلومات منظمة بسطر واحد بلا زر اتصال
class _ExploreGridCard extends ConsumerWidget {
  const _ExploreGridCard({required this.v});
  final VendorCard v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dist = v.distanceLabel;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VendorDetailsScreen(idOrSlug: v.slug.isEmpty ? v.id : v.slug)));
    return PressScale(
      onTap: open,
      child: InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: v.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://panel.fahd-car.cloud${v.imageUrl}',
                      height: 110, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 110, color: c.primary.withOpacity(0.06)),
                      errorWidget: (_, __, ___) => Container(height: 110, color: c.primary.withOpacity(0.06), child: Icon(Icons.storefront_outlined, color: c.primary.withOpacity(0.4))),
                    )
                  : Container(height: 110, color: c.primary.withOpacity(0.06), child: Icon(Icons.storefront_outlined, color: c.primary.withOpacity(0.4))),
            ),
            Positioned(
              top: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: v.isOpen ? c.success : Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                child: Text(v.isOpen ? 'مفتوح' : 'مغلق', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
            if (dist != null)
              Positioned(
                bottom: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.near_me_rounded, size: 10, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(dist, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: AppText.headingS(c.textPrimary).copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                if (v.averageRating > 0) ...[
                  Icon(Icons.star_rounded, size: 12, color: c.accent),
                  const SizedBox(width: 2),
                  Text(v.ratingText, style: AppText.caption(c.textSecondary).copyWith(fontSize: 11)),
                ] else
                  Text(v.categoryName, style: AppText.caption(c.textMuted).copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                if (v.minPrice != null)
                  Text(v.priceLabel, style: AppText.caption(c.primary).copyWith(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1),
              ]),
              const SizedBox(height: 2),
              Text(v.address.isEmpty ? v.categoryName : v.address, style: AppText.caption(c.textMuted).copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

/// كرت أفقي مضغوط لاستكشف — صورة 92 يسار + معلومات يمين
class _ExploreHorizontalCard extends ConsumerWidget {
  const _ExploreHorizontalCard({required this.v});
  final VendorCard v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dist = v.distanceLabel;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VendorDetailsScreen(idOrSlug: v.slug.isEmpty ? v.id : v.slug)));
    Future<void> call() async {
      final phone = v.phone;
      if (phone == null || phone.isEmpty) return;
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // صورة مربعة يسار (في RTL تكون يمين — نضعها أول عنصر فيزيائياً يسار الشاشة = بداية السطر بالعربي يمين؟ نتركها start)
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
            child: v.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: 'https://panel.fahd-car.cloud${v.imageUrl}',
                    width: 96, height: 96, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 96, height: 96, color: c.primary.withOpacity(0.06)),
                    errorWidget: (_, __, ___) => Container(width: 96, height: 96, color: c.primary.withOpacity(0.06), child: Icon(Icons.storefront_outlined, color: c.primary.withOpacity(0.4))),
                  )
                : Container(width: 96, height: 96, color: c.primary.withOpacity(0.06), child: Icon(Icons.storefront_outlined, color: c.primary.withOpacity(0.4))),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(v.name, style: AppText.headingS(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (v.averageRating > 0) ...[
                    Icon(Icons.star_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 2),
                    Text(v.ratingText, style: AppText.caption(c.textSecondary)),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (v.categoryName.isNotEmpty) ...[
                    Text(v.categoryName, style: AppText.caption(c.textMuted)),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.place_outlined, size: 12, color: c.textMuted),
                  const SizedBox(width: 2),
                  Expanded(child: Text(v.address, style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: v.isOpen ? c.success.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: v.isOpen ? c.success : Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(v.isOpen ? 'مفتوح' : 'مغلق', style: AppText.caption(v.isOpen ? c.success : c.textMuted)),
                    ]),
                  ),
                  if (v.minPrice != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: c.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                      child: Text(v.priceLabel, style: AppText.caption(c.primary)),
                    ),
                  ],
                  if (dist != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.near_me_rounded, size: 12, color: c.primary),
                    const SizedBox(width: 2),
                    Text(dist, style: AppText.caption(c.primary)),
                  ],
                  const Spacer(),
                  if (v.phone != null && v.phone!.isNotEmpty)
                    InkWell(
                      onTap: call,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.phone_outlined, size: 16, color: c.primary),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// جرس الإشعارات لاستكشف — نسخة خفيفة من جرس الرئيسية
class _ExploreBell extends ConsumerWidget {
  const _ExploreBell({required this.c});
  final AppColors c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(sessionTokenProvider);
    final unreadAsync = ref.watch(_exploreUnreadProvider(token));
    final unread = unreadAsync.valueOrNull ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 48, height: 48, child: Icon(Icons.notifications_none_rounded, size: 26, color: c.textPrimary)),
        ),
      ),
      if (unread > 0)
        Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)), constraints: const BoxConstraints(minWidth: 16), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center))),
    ]);
  }
}

final _exploreUnreadProvider = FutureProvider.autoDispose.family<int, String?>((ref, token) async {
  if (token == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    return d is int ? d : (d is num ? d.toInt() : 0);
  } catch (_) { return 0; }
});

/// ورقة فلاتر الاستكشاف — قسمان مطويان: التصنيف / العملة والسعر
class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({
    required this.catId,
    required this.maxPrice,
    required this.currency,
    required this.categories,
    required this.onCategory,
    required this.onPrice,
    required this.onCurrency,
  });
  final String? catId;
  final double? maxPrice;
  final String currency;
  final List<HomeCategory> categories;
  final ValueChanged<String?> onCategory;
  final ValueChanged<double?> onPrice;
  final ValueChanged<String> onCurrency;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  String? _open; // 'cat' | 'price' | null
  late String? _catId;
  late double? _maxPrice;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _catId = widget.catId;
    _maxPrice = widget.maxPrice;
    _currency = widget.currency;
  }

  void _applyCategory(String? id) {
    setState(() => _catId = id);
    widget.onCategory(id);
    setState(() => _open = null);
  }

  void _applyPrice(double? v) {
    setState(() => _maxPrice = v);
    widget.onPrice(v);
  }

  void _applyCurrency(String code) {
    setState(() {
      _currency = code;
      _maxPrice = null;
    });
    widget.onCurrency(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: AppSpacing.s12),
            Row(children: [
              Text('فلترة النتائج', style: AppText.headingM(c.textPrimary)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: c.textMuted)),
            ]),
            const SizedBox(height: AppSpacing.s12),
            _section(
              c: c,
              icon: Icons.grid_view_rounded,
              title: 'التصنيف',
              value: () {
                if (_catId == null) return 'الكل';
                for (final t in widget.categories) {
                  if (t.id == _catId) return t.nameAr;
                }
                return 'الكل';
              }(),
              open: _open == 'cat',
              onTap: () => setState(() => _open = _open == 'cat' ? null : 'cat'),
              child: Wrap(
                spacing: AppSpacing.s8, runSpacing: AppSpacing.s8,
                children: [
                  _choice(c, 'الكل', _catId == null, () => _applyCategory(null)),
                  for (final t in widget.categories)
                    _choice(c, t.nameAr, _catId == t.id, () => _applyCategory(_catId == t.id ? null : t.id)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            _section(
              c: c,
              icon: Icons.payments_outlined,
              title: 'العملة والسعر',
              value: _maxPrice == null ? currencyName(_currency) : 'حتى ${_maxPrice!.round()} ${currencyName(_currency)}',
              open: _open == 'price',
              onTap: () => setState(() => _open = _open == 'price' ? null : 'price'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PopupMenuButton<String>(
                  onSelected: _applyCurrency,
                  itemBuilder: (_) => [for (final code in homeSupportedCurrencies) PopupMenuItem(value: code, child: Text(currencyName(code)))],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.primary.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.currency_exchange_rounded, size: 16, color: c.primary),
                      const SizedBox(width: 4),
                      Text('العملة: ${currencyName(_currency)}', style: AppText.caption(c.primary)),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: c.primary),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
                  if (_currency == 'USD') ...[
                    _choice(c, 'الكل', _maxPrice == null, () => _applyPrice(null)),
                    _choice(c, 'حتى 50 دولار', _maxPrice == 50, () => _applyPrice(50)),
                    _choice(c, 'حتى 200 دولار', _maxPrice == 200, () => _applyPrice(200)),
                    _choice(c, 'حتى 500 دولار', _maxPrice == 500, () => _applyPrice(500)),
                  ] else if (_currency == 'SYP') ...[
                    _choice(c, 'الكل', _maxPrice == null, () => _applyPrice(null)),
                    _choice(c, 'حتى 100 ألف ل.س', _maxPrice == 100000, () => _applyPrice(100000)),
                    _choice(c, 'حتى 500 ألف ل.س', _maxPrice == 500000, () => _applyPrice(500000)),
                    _choice(c, 'مليون ل.س فأكثر', _maxPrice == 1000000, () => _applyPrice(1000000)),
                  ] else ...[
                    _choice(c, 'الكل', _maxPrice == null, () => _applyPrice(null)),
                    _choice(c, 'حتى 500 ل.ت', _maxPrice == 500, () => _applyPrice(500)),
                    _choice(c, 'حتى 2000 ل.ت', _maxPrice == 2000, () => _applyPrice(2000)),
                    _choice(c, '5000 ل.ت فأكثر', _maxPrice == 5000, () => _applyPrice(5000)),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('تم'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _choice(AppColors c, String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c.primary.withOpacity(0.14),
        labelStyle: AppText.caption(selected ? c.primary : c.textSecondary),
        side: BorderSide(color: selected ? c.primary : c.border),
      );

  Widget _section({required AppColors c, required IconData icon, required String title, required String value, required bool open, required VoidCallback onTap, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: open ? c.primary : c.border)),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
            child: Row(children: [
              Icon(icon, size: 18, color: open ? c.primary : c.textMuted),
              const SizedBox(width: AppSpacing.s8),
              Text(title, style: AppText.bodyM(open ? c.primary : c.textPrimary)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text(value, style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
              Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: c.textMuted),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: open ? Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s12), child: child) : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

/// Helper لإضافة child اختياري للـ EmptyState (إن لم يكن موجوداً الأصل)
