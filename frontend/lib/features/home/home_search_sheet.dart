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
  double? _maxPrice;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _filtersOpen = widget.initialFiltersOpen;
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
    final query = <String, String>{
      'q': _query,
      'limit': '12',
      if (_maxPrice != null) 'maxPrice': _maxPrice!.round().toString(),
    };
    final d = await ref.read(apiClientProvider).get('/search', query: query);
    final raw = d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
    return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _setPrice(double? value) {
    setState(() => _maxPrice = value);
    if (_query.isNotEmpty) {
      final future = _search();
      setState(() {
        _future = future;
      });
    }
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
              IconButton(
                key: const Key('home-search-filter'),
                onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
                style: IconButton.styleFrom(
                  backgroundColor: _filtersOpen ? c.primary.withOpacity(0.12) : c.surface,
                  foregroundColor: c.primary,
                  side: BorderSide(color: _filtersOpen ? c.primary : c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  fixedSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'فلترة النتائج',
              ),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _filtersOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('خيارات الفلترة', style: AppText.bodyL(c.textPrimary)),
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(spacing: AppSpacing.s8, runSpacing: AppSpacing.s8, children: [
                          _priceChoice(c, 'الكل', null),
                          _priceChoice(c, 'حتى 50\$', 50),
                          _priceChoice(c, 'حتى 200\$', 200),
                          _priceChoice(c, 'حتى 500\$', 500),
                        ]),
                      ]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(child: _results(c)),
        ]),
      ),
    );
  }

  Widget _priceChoice(AppColors c, String label, double? value) {
    final selected = _maxPrice == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setPrice(value),
      selectedColor: c.primary.withOpacity(0.14),
      labelStyle: AppText.caption(selected ? c.primary : c.textSecondary),
      side: BorderSide(color: selected ? c.primary : c.border),
    );
  }

  Widget _results(AppColors c) {
    if (_query.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search_rounded, size: 48, color: c.primary.withOpacity(0.35)),
          const SizedBox(height: AppSpacing.s8),
          Text('اكتب ما تبحث عنه', style: AppText.bodyL(c.textSecondary)),
          const SizedBox(height: AppSpacing.s4),
          Text('ستظهر النتائج هنا مباشرة', style: AppText.caption(c.textMuted)),
        ]),
      );
    }
    final future = _future;
    if (future == null) {
      return Column(children: List.generate(3, (_) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
        child: SkeletonLoader(height: 68),
      )));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Column(children: List.generate(3, (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
            child: SkeletonLoader(height: 68),
          )));
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
