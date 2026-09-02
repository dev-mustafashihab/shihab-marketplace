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

/// استكشف — بحث نصي حي + فلاتر أساسية (سعر/تقييم) فوق /search.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.categoryId});
  final String? categoryId;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _controller = TextEditingController();
  String _query = '';
  double? _maxPrice;
  String _currency = 'USD'; // USD | SYP | TRY

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) _maxPrice = null;
    _controller.addListener(() {
      if (_controller.text.trim() != _query) {
        _query = _controller.text.trim();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final api = ref.read(apiClientProvider);
    final query = {
      'limit': '30',
      if (_query.isNotEmpty) 'q': _query,
      if (_maxPrice != null) 'maxPrice': _maxPrice!.round().toString(),
      if (widget.categoryId != null) 'categoryId': widget.categoryId!,
    };

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
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            children: [
              _priceChip(c, 'الكل', null),
              _priceChip(c, '\$', 50),
              _priceChip(c, '\$\$', 200),
              _priceChip(c, '\$\$\$', 500),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: api.get('/search', query: query).then((d) {
              if (d is List) return d.cast<dynamic>();
              if (d is Map && d['data'] is List) return (d['data'] as List).cast<dynamic>();
              return const <dynamic>[];
            }),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Column(children: List.generate(4, (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
                  child: SkeletonLoader(height: 80),
                )));
              }
              if (snap.hasError) {
                return ErrorState(message: (snap.error as dynamic).message ?? 'خطأ', onRetry: () => setState(() {}));
              }
              final rows = (snap.data ?? []).cast<Map<String, dynamic>>();
              if (rows.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'لا نتائج مطابقة',
                  message: 'جرّب كلمات أخرى أو وسّع الفلاتر.',
                  actionLabel: 'مسح البحث',
                  onAction: () { _controller.clear(); setState(() => _maxPrice = null); },
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                itemBuilder: (context, i) {
                  final v = rows[i];
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
                              if (v['averageRating'] != null && (v['averageRating'] as num) > 0) ...[
                                Icon(Icons.star_rounded, size: 16, color: c.accent),
                                Text(' ${v['averageRating']}', style: AppText.caption(c.textSecondary)),
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
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _currencyChip(AppColors c, String label, String code) {
    final selected = _currency == code;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() { _currency = code; _maxPrice = null; }),
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
        onSelected: (_) => setState(() => _maxPrice = value),
        labelStyle: AppText.button(selected ? c.surface : c.textSecondary),
        selectedColor: c.primary,
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
