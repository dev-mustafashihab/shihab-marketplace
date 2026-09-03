import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/api_client.dart';
import '../vendors/vendor_details_screen.dart';
import '../../core/session/session_service.dart';
import '../location/location_picker.dart';

/// استكشف — بحث نصي حي + فلاتر (عملة/سعر/تصنيف) فوق /search، مع ترقيم صفحات.
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
  String _currency = 'USD'; // USD | SYP | TRY
  String? _catId;
  Future<List<Map<String, dynamic>>>? _catsFuture;

  List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _catId = widget.categoryId;
    _catsFuture = _loadCategories();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScrollNearEnd);
    _reload();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final d = await ref.read(apiClientProvider).get('/categories');
    final raw = d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _scroll
      ..removeListener(_onScrollNearEnd)
      ..dispose();
    super.dispose();
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
    return {
      'limit': '$_limit',
      'page': '$page',
      if (_query.isNotEmpty) 'q': _query,
      // الفلترة المزدوجة: العملة تُرسل مع السعر فقط — بلا سعر لا تضييق بالعملة
      if (_maxPrice != null) ...{
        'maxPrice': _maxPrice!.round().toString(),
        'currency': _currency,
      },
      if (_catId != null) 'categoryId': _catId!,
      if (widget.openNow) 'openNow': 'true',
      if (widget.lowestPrice) 'sort': 'price',
      if (widget.nearby && location != null) ...{
        'lat': location.lat.toString(),
        'lng': location.lng.toString(),
        'radiusKm': '50',
        'sort': 'distance',
      },
    };
  }

  static List<Map<String, dynamic>> _rowsOf(dynamic d) {
    final raw = d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

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
      final d = await ref.read(apiClientProvider).get('/search', query: _params(_page));
      if (seq != _loadSeq || !mounted) return;
      final got = _rowsOf(d);
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_page == 1) {
          _rows = got;
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('استكشف'), automaticallyImplyLeading: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن قاعة، صالون، مطعم…',
                  prefixIcon: Icon(Icons.search_rounded, color: c.primary),
                  filled: true,
                  fillColor: c.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            // زر الموقع السريع
            InkWell(
              onTap: () => showLocationPicker(context, ref),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.location_on_rounded, color: c.primary, size: 22),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s12),
        // منتقي التصنيف
        SizedBox(
          height: 40,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _catsFuture,
            builder: (context, snap) {
              final cats = snap.data ?? const <Map<String, dynamic>>[];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                children: [
                  _catChip(c, 'الكل', null),
                  for (final cat in cats)
                    _catChip(c, (cat['nameAr'] ?? '') as String, cat['id'] as String?),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        // مبدّل العملة
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            children: [
              _currencyChip(c, 'دولار أمريكي', 'USD'),
              _currencyChip(c, 'ليرة سورية', 'SYP'),
              _currencyChip(c, 'ليرة تركية', 'TRY'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        // شرائح السعر حسب العملة المختارة
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            children: [
              if (_currency == 'USD') ...[
                _priceChip(c, 'الكل', null),
                _priceChip(c, 'حتى 50 دولار', 50),
                _priceChip(c, 'حتى 200 دولار', 200),
                _priceChip(c, 'حتى 500 دولار', 500),
              ] else if (_currency == 'SYP') ...[
                _priceChip(c, 'الكل', null),
                _priceChip(c, 'حتى 100 ألف ل.س', 100000),
                _priceChip(c, 'حتى 500 ألف ل.س', 500000),
                _priceChip(c, 'مليون ل.س فأكثر', 1000000),
              ] else ...[
                _priceChip(c, 'الكل', null),
                _priceChip(c, 'حتى 500 ل.ت', 500),
                _priceChip(c, 'حتى 2000 ل.ت', 2000),
                _priceChip(c, '5000 ل.ت فأكثر', 5000),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Expanded(child: _body(c)),
      ]),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) {
      return SingleChildScrollView(
        child: Column(children: List.generate(4, (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
          child: SkeletonLoader(height: 80),
        ))),
      );
    }
    if (_error != null) {
      return ErrorState(
        message: ((_error as dynamic)?.message as String?) ?? 'خطأ',
        onRetry: _reload,
      );
    }
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'لا نتائج مطابقة',
        message: 'جرّب كلمات أخرى أو وسّع الفلاتر.',
        actionLabel: 'مسح البحث',
        onAction: () {
          _controller.clear();
          setState(() {
            _maxPrice = null;
            _catId = null;
          });
          _reload();
        },
      );
    }
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, i) {
          if (i >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
              child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          }
          final v = _rows[i];
          return _vendorCard(c, v);
        },
      ),
    );
  }

  Widget _vendorCard(AppColors c, Map<String, dynamic> v) {
    final rc = (v['reviewsCount'] ?? v['reviewCount'] ?? 0).toString();
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VendorDetailsScreen(idOrSlug: (v['slug'] ?? v['id'] ?? '') as String),
      )),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (v['imageUrl'] != null)
            CachedNetworkImage(
              imageUrl: 'https://panel.fahd-car.cloud${v['imageUrl']}',
              height: 110, width: double.infinity, fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 110, color: c.primary.withOpacity(0.06)),
              errorWidget: (_, __, ___) => Container(height: 110, color: c.primary.withOpacity(0.06)),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v['name'], style: AppText.headingS(c.textPrimary),
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
                if (v['averageRating'] != null && (v['averageRating'] as num) > 0) ...[
                  Icon(Icons.star_rounded, size: 16, color: c.accent),
                  Text(' ${v['averageRating']} ($rc)', style: AppText.caption(c.textSecondary)),
                ],
              ]),
              const SizedBox(height: AppSpacing.s4),
              Row(children: [
                Flexible(child: Text('${v['category'] ?? ''}${v['address'] != null ? ' • ${v['address']}' : ''}',
                    style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                // المسافة
                Builder(builder: (context) {
                  final me = ref.watch(userLocationProvider);
                  final vLat = v['latitude'];
                  final vLng = v['longitude'];
                  if (me == null || vLat == null || vLng == null) return const SizedBox.shrink();
                  final dist = distanceKm(me.lat, me.lng,
                      double.parse(vLat.toString()), double.parse(vLng.toString()));
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
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
                  );
                }),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _catChip(AppColors c, String label, String? id) {
    final selected = _catId == id;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(id),
        labelStyle: AppText.button(selected ? c.surface : c.textSecondary),
        selectedColor: c.primary,
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _currencyChip(AppColors c, String label, String code) {
    final selected = _currency == code;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setCurrency(code),
        labelStyle: AppText.button(selected ? c.surface : c.textSecondary),
        selectedColor: c.accent,
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _priceChip(AppColors c, String label, double? value) {
    final selected = _maxPrice == value;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setPrice(value),
        labelStyle: AppText.button(selected ? c.surface : c.textSecondary),
        selectedColor: c.primary,
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
