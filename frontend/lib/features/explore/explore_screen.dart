import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/network/api_client.dart';

/// استكشف — بحث نصي حي + فلاتر أساسية (سعر/تقييم) فوق /search.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _controller = TextEditingController();
  String _query = '';
  double? _maxPrice;

  @override
  void initState() {
    super.initState();
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
    };

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('استكشف'), automaticallyImplyLeading: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'ابحث عن قاعة، صالون، مطعم…',
              prefixIcon: Icon(Icons.search, color: c.textMuted),
            ),
          ),
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
              final raw = d['data'];
              return (raw as List).cast<dynamic>();
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                itemBuilder: (context, i) {
                  final v = rows[i];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(v['name'], style: AppText.headingS(c.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (v['averageRating'] != null && (v['averageRating'] as num) > 0) ...[
                          Icon(Icons.star, size: 15, color: c.accent),
                          Text(' ${v['averageRating']}', style: AppText.caption(c.textSecondary)),
                        ],
                      ]),
                      const SizedBox(height: AppSpacing.s8),
                      Text('${v['category'] ?? ''}${v['address'] != null ? ' • ${v['address']}' : ''}',
                          style: AppText.caption(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
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
