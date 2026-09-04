import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../vendors/vendor_details_screen.dart';
import 'models/home_feed.dart';
import 'state/home_feed_provider.dart';

Future<void> showHomeSearchSheet(
  BuildContext context,
  WidgetRef ref, {
  bool openFilters = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HomeSearchSheet(initialFiltersOpen: openFilters),
  );
}

class _HomeSearchSheet extends ConsumerStatefulWidget {
  const _HomeSearchSheet({required this.initialFiltersOpen});

  final bool initialFiltersOpen;

  @override
  ConsumerState<_HomeSearchSheet> createState() => _HomeSearchSheetState();
}

class _HomeSearchSheetState extends ConsumerState<_HomeSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';
  // القسم المفتوح حالياً — قسم واحد فقط كل مرة لمنع الازدحام.
  // 'category' | 'price' | null
  String? _openSection;

  @override
  void initState() {
    super.initState();
    _openSection = widget.initialFiltersOpen ? 'price' : null;
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _query) return;
    _query = query;
    _debounce?.cancel();
    setState(() => _future = null);
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 280), () {
      final future = _search();
      if (mounted) {
        setState(() {
          _future = future;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _search() async {
    // نتائج الورقة تحترم نفس فلاتر الرئيسية المشتركة (تصنيف/سعر/عملة)
    final catId = ref.read(homeCategoryProvider);
    final maxPrice = ref.read(homeMaxPriceProvider);
    final currency = ref.read(homeCurrencyProvider);
    final query = <String, String>{
      'q': _query,
      'limit': '12',
      if (catId != null) 'categoryId': catId,
      // الفلترة المزدوجة: العملة تُرسل مع السعر فقط
      if (maxPrice != null) ...{
        'maxPrice': maxPrice.round().toString(),
        'currency': currency,
      },
    };
    final d = await ref.read(apiClientProvider).get('/search', query: query);
    final raw = d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
    return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _refreshResults() {
    if (_query.isEmpty) return;
    final future = _search();
    setState(() {
      _future = future;
    });
  }

  void _setPrice(double? value) {
    ref.read(homeMaxPriceProvider.notifier).state = value;
    _refreshResults();
  }

  void _setCurrency(String code) {
    ref.read(homeCurrencyProvider.notifier).state = code;
    ref.read(homeMaxPriceProvider.notifier).state = null;
    _refreshResults();
  }

  void _setCategory(String? id) {
    ref.read(homeCategoryProvider.notifier).state = id;
    // طيّ القسم بعد الاختيار لتظهر النتائج فوراً
    setState(() => _openSection = null);
    _refreshResults();
  }

  void _openVendor(Map<String, dynamic> vendor) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(
      builder: (_) => VendorDetailsScreen(idOrSlug: (vendor['slug'] ?? vendor['id'] ?? '') as String),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - bottom;
    // الفلاتر المشتركة مع الرئيسية — أي تغيير هنا يفلتر الرئيسية فوراً
    final catId = ref.watch(homeCategoryProvider);
    final maxPrice = ref.watch(homeMaxPriceProvider);
    final currency = ref.watch(homeCurrencyProvider);
    final catsAsync = ref.watch(homeCategoriesProvider);
    final hasFilters = catId != null || maxPrice != null;
    String? catName;
    final cats = catsAsync.valueOrNull;
    if (cats != null) {
      for (final t in cats) {
        if (t.id == catId) {
          catName = t.nameAr;
          break;
        }
      }
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: availableHeight * 0.82,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s8),
            child: Row(children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const Spacer(),
              Text('بحث سريع', style: AppText.headingS(c.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: c.textMuted),
                tooltip: 'إغلاق',
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن قاعة أو صالون أو هدية',
                    prefixIcon: Icon(Icons.search_rounded, color: c.primary),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _controller.clear,
                            icon: const Icon(Icons.clear_rounded),
                            tooltip: 'مسح',
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // مسح الفلاتر — يظهر فقط عند وجود فلتر نشط
              if (hasFilters)
                IconButton(
                  key: const Key('home-search-filter'),
                  onPressed: () {
                    clearHomeFilters(ref);
                    _refreshResults();
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: c.primary.withOpacity(0.12),
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    fixedSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  tooltip: 'مسح الفلاتر',
                ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s8),
          // أقسام الفلاتر — قسم واحد مفتوح كل مرة لمنع الازدحام
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Column(children: [
              _FilterSection(
                c: c,
                icon: Icons.grid_view_rounded,
                title: 'التصنيف',
                value: catName ?? 'الكل',
                open: _openSection == 'category',
                onTap: () => setState(
                    () => _openSection = _openSection == 'category' ? null : 'category'),
                child: catsAsync.when(
                  loading: () => const SkeletonLoader(height: 40),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      _sheetChoice(c, 'الكل', catId == null, () => _setCategory(null)),
                      for (final t in list)
                        _sheetChoice(c, t.nameAr, catId == t.id,
                            () => _setCategory(catId == t.id ? null : t.id)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              _FilterSection(
                c: c,
                icon: Icons.payments_outlined,
                title: 'العملة والسعر',
                value: maxPrice == null
                    ? currencyName(currency)
                    : 'حتى ${maxPrice.round()} ${currencyName(currency)}',
                open: _openSection == 'price',
                onTap: () => setState(
                    () => _openSection = _openSection == 'price' ? null : 'price'),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // مبدّل العملة المدمج — زر واحد بدل 3 شرائح
                      PopupMenuButton<String>(
                        onSelected: _setCurrency,
                        itemBuilder: (_) => [
                          for (final code in homeSupportedCurrencies)
                            PopupMenuItem(
                                value: code, child: Text(currencyName(code))),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.primary.withOpacity(0.4)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.currency_exchange_rounded,
                                size: 16, color: c.primary),
                            const SizedBox(width: 4),
                            Text('العملة: ${currencyName(currency)}',
                                style: AppText.caption(c.primary)),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: c.primary),
                          ]),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
                        if (currency == 'USD') ...[
                          _sheetChoice(c, 'الكل', maxPrice == null,
                              () => _setPrice(null)),
                          _sheetChoice(c, 'حتى 50 دولار', maxPrice == 50,
                              () => _setPrice(50)),
                          _sheetChoice(c, 'حتى 200 دولار', maxPrice == 200,
                              () => _setPrice(200)),
                          _sheetChoice(c, 'حتى 500 دولار', maxPrice == 500,
                              () => _setPrice(500)),
                        ] else if (currency == 'SYP') ...[
                          _sheetChoice(c, 'الكل', maxPrice == null,
                              () => _setPrice(null)),
                          _sheetChoice(c, 'حتى 100 ألف ل.س', maxPrice == 100000,
                              () => _setPrice(100000)),
                          _sheetChoice(c, 'حتى 500 ألف ل.س', maxPrice == 500000,
                              () => _setPrice(500000)),
                          _sheetChoice(c, 'مليون ل.س فأكثر', maxPrice == 1000000,
                              () => _setPrice(1000000)),
                        ] else ...[
                          _sheetChoice(c, 'الكل', maxPrice == null,
                              () => _setPrice(null)),
                          _sheetChoice(c, 'حتى 500 ل.ت', maxPrice == 500,
                              () => _setPrice(500)),
                          _sheetChoice(c, 'حتى 2000 ل.ت', maxPrice == 2000,
                              () => _setPrice(2000)),
                          _sheetChoice(c, '5000 ل.ت فأكثر', maxPrice == 5000,
                              () => _setPrice(5000)),
                        ],
                      ]),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(child: _results(c)),
        ]),
      ),
    );
  }

  Widget _sheetChoice(AppColors c, String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c.primary.withOpacity(0.14),
      labelStyle: AppText.caption(selected ? c.primary : c.textSecondary),
      side: BorderSide(color: selected ? c.primary : c.border),
    );
  }

  Widget _results(AppColors c) {
    if (_query.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.manage_search_rounded, size: 48, color: c.primary.withOpacity(0.35)),
            const SizedBox(height: AppSpacing.s8),
            Text('اكتب ما تبحث عنه', style: AppText.bodyL(c.textSecondary)),
            const SizedBox(height: AppSpacing.s4),
            Text('ستظهر النتائج هنا مباشرة', style: AppText.caption(c.textMuted)),
          ]),
        ),
      );
    }
    final future = _future;
    if (future == null) {
      return SingleChildScrollView(
        child: Column(children: List.generate(3, (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          child: SkeletonLoader(height: 68),
        ))),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SingleChildScrollView(
            child: Column(children: List.generate(3, (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 68),
            ))),
          );
        }
        if (snap.hasError) {
          return ErrorState(
            message: 'تعذر تنفيذ البحث',
            onRetry: () {
              final future = _search();
              setState(() {
                _future = future;
              });
            },
          );
        }
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Center(child: Text('لا توجد نتائج مطابقة', style: AppText.bodyL(c.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
          itemBuilder: (context, index) {
            final vendor = rows[index];
            return InkWell(
              onTap: () => _openVendor(vendor),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: c.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.storefront_rounded, color: c.primary),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(vendor['name'] as String? ?? '', style: AppText.headingS(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.s4),
                    Text('${vendor['category'] ?? ''}${vendor['address'] != null ? ' • ${vendor['address']}' : ''}',
                        style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Icon(Icons.chevron_left_rounded, color: c.textMuted),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

/// قسم فلتر مطوي — رأسه يعرض القيمة الحالية دائماً، وجسمه ينفتح وحده
/// (فتح قسم يغلق الآخر) لمنع ازدحام الورقة.
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.c,
    required this.icon,
    required this.title,
    required this.value,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final AppColors c;
  final IconData icon;
  final String title;
  final String value;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: open ? c.primary : c.border),
      ),
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
              Expanded(
                child: Text(value,
                    style: AppText.caption(c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end),
              ),
              Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20, color: c.textMuted),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s12),
                  child: child,
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
