import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../wallet/state/customer_wallet_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';

/// اسم العملة بالعربية — بدل `$` الثابتة.
String _curName(String? code) => switch (code) {
      'SYP' => 'ل.س',
      'TRY' => 'ل.ت',
      _ => 'دولار',
    };

/// أسماء الأيام — الباكند: 0=الأحد .. 6=السبت.
const _dayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
/// ترتيب العرض: الأسبوع السوري يبدأ السبت.
const _dayOrder = [6, 0, 1, 2, 3, 4, 5];

String _fmtMin(int m) {
  final h = m ~/ 60, mm = m % 60;
  return '$h:${mm.toString().padLeft(2, '0')}';
}

String _fmtDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.day}/${d.month}/${d.year}';
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

/// بيانات الصفحة: البائع + تقييماته + دوام مورده الأول (كلها اختيارية عدا البائع).
class _VendorPageData {
  _VendorPageData({required this.vendor, required this.reviews, required this.rules});
  final Map<String, dynamic> vendor;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> rules;
}

/// صفحة البائع: معرض، تقييمات، دوام حقيقي، حجز لكل خدمة.
class VendorDetailsScreen extends ConsumerStatefulWidget {
  const VendorDetailsScreen({super.key, required this.idOrSlug});
  final String idOrSlug;

  @override
  ConsumerState<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends ConsumerState<VendorDetailsScreen> {
  late Future<_VendorPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  static List<Map<String, dynamic>> _asList(dynamic raw) {
    final d = raw is Map ? raw['data'] : raw;
    if (d is! List) return [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<_VendorPageData> _load() async {
    final api = ref.read(apiClientProvider);
    final v = Map<String, dynamic>.from(await api.get('/vendors/${widget.idOrSlug}') as Map);
    final resources = (v['resources'] as List? ?? []).whereType<Map>().toList();
    final resId = resources.isNotEmpty ? '${resources.first['id']}' : null;
    List<Map<String, dynamic>> reviews = [];
    List<Map<String, dynamic>> rules = [];
    await Future.wait([
      () async {
        try {
          reviews = _asList(await api.get('/reviews/vendor/${v['id']}', query: {'limit': '100'}));
        } catch (_) {}
      }(),
      () async {
        if (resId == null) return;
        try {
          rules = _asList(await api.get('/availability/resource/$resId'));
        } catch (_) {}
      }(),
    ]);
    return _VendorPageData(vendor: v, reviews: reviews, rules: rules);
  }

  void _openBooking(Map<String, dynamic> vendor, Map<String, dynamic> service, List<Map<String, dynamic>> rules) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BookingSheet(vendor: vendor, service: service, rules: rules),
    );
  }

  void _pickService(Map<String, dynamic> vendor, List<Map<String, dynamic>> services, List<Map<String, dynamic>> rules) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اختر الخدمة', style: AppText.headingM(context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.s12),
            ...services.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s['name'] as String? ?? '', style: AppText.bodyL(context.colors.textPrimary)),
                  subtitle: Text('من ${s['price']} ${_curName(s['currency'] as String?)}',
                      style: AppText.bodyM(context.colors.primary)),
                  trailing: const Icon(Icons.arrow_back_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openBooking(vendor, Map<String, dynamic>.from(s), rules);
                  },
                )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('تفاصيل البائع')),
      body: FutureBuilder<_VendorPageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 90),
            )));
          }
          if (snap.hasError) {
            return ErrorState(message: 'تعذر تحميل بيانات البائع', onRetry: () => setState(() => _future = _load()));
          }
          final data = snap.data!;
          final v = data.vendor;
          final services = (v['services'] as List? ?? []).cast<Map<String, dynamic>>();
          final rules = data.rules;
          double? minPrice;
          String? minCur;
          for (final s in services) {
            final p = _num(s['price']);
            if (minPrice == null || p < minPrice) {
              minPrice = p;
              minCur = s['currency'] as String?;
            }
          }
          return Stack(children: [
            ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              if (v['imageUrl'] != null)
                CachedNetworkImage(
                  imageUrl: 'https://panel.fahd-car.cloud${v['imageUrl']}',
                  height: 190, width: double.infinity, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(height: 190, color: c.primary.withOpacity(0.06)),
                  errorWidget: (_, __, ___) => Container(height: 190, color: c.primary.withOpacity(0.06), child: Icon(Icons.storefront_outlined, size: 48, color: c.primary)),
                )
              else
                Container(
                  height: 190,
                  color: c.primary.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: Icon(Icons.storefront_outlined, size: 48, color: c.primary),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(v['name'] as String, style: AppText.headingL(c.textPrimary))),
                    const SizedBox(width: AppSpacing.s8),
                    Icon(Icons.star, size: 18, color: c.accent),
                    const SizedBox(width: 2),
                    Text('${v['averageRating'] ?? 0} (${v['reviewCount'] ?? 0})',
                        style: AppText.bodyM(c.textSecondary)),
                  ]),
                  const SizedBox(height: AppSpacing.s8),
                  Text(v['description'] as String? ?? '',
                      style: AppText.bodyM(c.textSecondary)),
                  const SizedBox(height: AppSpacing.s16),
                  if (v['address'] != null)
                    Row(children: [
                      Icon(Icons.place_outlined, size: 16, color: c.textMuted),
                      const SizedBox(width: AppSpacing.s4),
                      Text(v['address'] as String, style: AppText.caption(c.textMuted)),
                    ]),
                  const SizedBox(height: AppSpacing.s20),
                  if (rules.isNotEmpty) ...[
                    _HoursSection(rules: rules),
                    const SizedBox(height: AppSpacing.s20),
                  ],
                  Text('الخدمات', style: AppText.headingM(c.textPrimary)),
                  const SizedBox(height: AppSpacing.s12),
                  if (services.isEmpty)
                    Text('لا خدمات متاحة حالياً', style: AppText.bodyM(c.textMuted))
                  else
                    ...services.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.border)),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s['name'] as String, style: AppText.headingS(c.textPrimary)),
                                const SizedBox(height: AppSpacing.s4),
                                Text('من ${s['price']} ${_curName(s['currency'] as String?)}',
                                    style: AppText.price(c.primary)),
                              ]),
                            ),
                            OutlinedButton(
                              onPressed: () => _openBooking(v, s, rules),
                              child: const Text('احجز'),
                            ),
                          ]),
                        )),
                  const SizedBox(height: AppSpacing.s20),
                  _ReviewsSection(
                    vendorId: '${v['id']}',
                    services: services,
                    reviews: data.reviews,
                    avg: _num(v['averageRating']),
                    count: (v['reviewCount'] as num?)?.toInt() ?? data.reviews.length,
                    onSubmitted: () => setState(() => _future = _load()),
                  ),
                ]),
              ),
            ]),
            if (services.isNotEmpty)
              Positioned(
                left: AppSpacing.screenH,
                right: AppSpacing.screenH,
                bottom: AppSpacing.s16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                    boxShadow: [BoxShadow(color: c.textPrimary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ابتداء من', style: AppText.caption(c.textMuted)),
                        Text('${minPrice!.toStringAsFixed(minPrice % 1 == 0 ? 0 : 2)} ${_curName(minCur)}',
                            style: AppText.price(c.primary)),
                      ]),
                    ),
                    ElevatedButton(
                      onPressed: () => services.length == 1
                          ? _openBooking(v, services.first, rules)
                          : _pickService(v, services, rules),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                      child: const Text('احجز الآن'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// بطاقة الدوام الأسبوعي مع شارة مفتوح/مغلق الآن.
class _HoursSection extends StatelessWidget {
  const _HoursSection({required this.rules});
  final List<Map<String, dynamic>> rules;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final todayBackend = now.weekday % 7; // Dart: 1=Mon..7=Sun → باكند 0=Sun..6=Sat
    final nowMin = now.hour * 60 + now.minute;
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final r in rules) {
      final w = (r['weekday'] as num?)?.toInt();
      if (w == null) continue;
      byDay.putIfAbsent(w, () => []).add(r);
    }
    bool openNow = false;
    for (final r in (byDay[todayBackend] ?? [])) {
      final s = (r['startMin'] as num?)?.toInt() ?? 0;
      final e = (r['endMin'] as num?)?.toInt() ?? 0;
      if (nowMin >= s && nowMin < e) openNow = true;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.access_time_rounded, size: 18, color: c.primary),
          const SizedBox(width: AppSpacing.s8),
          Text('أوقات العمل', style: AppText.headingS(c.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 4),
            decoration: BoxDecoration(
              color: (openNow ? c.success : c.error).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(openNow ? 'مفتوح الآن' : 'مغلق الآن',
                style: AppText.caption(openNow ? c.success : c.error)),
          ),
        ]),
        const SizedBox(height: AppSpacing.s12),
        ..._dayOrder.map((w) {
          final list = byDay[w] ?? [];
          final isToday = w == todayBackend;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 72,
                child: Text(_dayNames[w],
                    style: AppText.bodyM(isToday ? c.primary : c.textPrimary)),
              ),
              Expanded(
                child: Text(
                  list.isEmpty
                      ? 'مغلق'
                      : list.map((r) => '${_fmtMin((r['startMin'] as num).toInt())} – ${_fmtMin((r['endMin'] as num).toInt())}').join(' • '),
                  style: AppText.bodyM(list.isEmpty ? c.textMuted : c.textSecondary),
                ),
              ),
              if (isToday)
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
            ]),
          );
        }),
      ]),
    );
  }
}

/// نجوم صغيرة للعرض.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 14});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      final fill = (rating - i).clamp(0.0, 1.0);
      return Icon(
        fill >= 0.75 ? Icons.star : (fill >= 0.25 ? Icons.star_half : Icons.star_border),
        size: size,
        color: c.accent,
      );
    }));
  }
}

/// قسم التقييمات: ملخص + توزيع + الأحدث + زر إضافة.
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.vendorId,
    required this.services,
    required this.reviews,
    required this.avg,
    required this.count,
    required this.onSubmitted,
  });
  final String vendorId;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> reviews;
  final double avg;
  final int count;
  final VoidCallback onSubmitted;

  String _reviewerName(Map<String, dynamic> r) {
    final cust = r['customer'] as Map?;
    final prof = cust?['profile'] as Map?;
    final fn = '${prof?['firstName'] ?? ''}'.trim();
    final ln = '${prof?['lastName'] ?? ''}'.trim();
    final full = '$fn $ln'.trim();
    return full.isEmpty ? 'مستخدم' : full;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dist = [0, 0, 0, 0, 0];
    for (final r in reviews) {
      final rating = (r['rating'] as num?)?.toInt() ?? 0;
      if (rating >= 1 && rating <= 5) dist[5 - rating]++;
    }
    final shown = reviews.take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('التقييمات ($count)', style: AppText.headingM(c.textPrimary)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final ok = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (_) => _AddReviewSheet(vendorId: vendorId, services: services),
            );
            if (ok == true) onSubmitted();
          },
          child: const Text('قيّم تجربتك'),
        ),
      ]),
      const SizedBox(height: AppSpacing.s12),
      if (reviews.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
              color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Text('لا تقييمات بعد — كن أول من يقيّم هذه التجربة',
              style: AppText.bodyM(c.textMuted), textAlign: TextAlign.center),
        )
      else ...[
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
              color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Row(children: [
            Column(children: [
              Text(avg.toStringAsFixed(1), style: AppText.headingL(c.textPrimary)),
              _Stars(rating: avg),
              const SizedBox(height: 4),
              Text('$count تقييم', style: AppText.caption(c.textMuted)),
            ]),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(children: List.generate(5, (i) {
                final star = 5 - i;
                final n = dist[i];
                final frac = reviews.isEmpty ? 0.0 : n / reviews.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('$star', style: AppText.caption(c.textMuted)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 6,
                          backgroundColor: c.border.withOpacity(0.5),
                          color: c.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(width: 24, child: Text('$n', style: AppText.caption(c.textMuted))),
                  ]),
                );
              })),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s12),
        ...shown.map((r) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_reviewerName(r), style: AppText.bodyM(c.textPrimary))),
                  _Stars(rating: _num(r['rating'])),
                ]),
                if ('${r['comment'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${r['comment']}', style: AppText.bodyM(c.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(_fmtDate(r['createdAt'] as String?), style: AppText.caption(c.textMuted)),
              ]),
            )),
        if (reviews.length > shown.length)
          Text('و ${reviews.length - shown.length} تقييمات أخرى',
              style: AppText.caption(c.textMuted)),
      ],
    ]);
  }
}

/// ورقة إضافة تقييم — يختار المستخدم حجزاً مكتملاً من حجوزاته لهذا البائع.
class _AddReviewSheet extends ConsumerStatefulWidget {
  const _AddReviewSheet({required this.vendorId, required this.services});
  final String vendorId;
  final List<Map<String, dynamic>> services;

  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _bookingId;
  int _rating = 5;
  final _comment = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final api = ref.read(apiClientProvider);
    final raw = await api.get('/bookings/mine', query: {'limit': '100'});
    final d = raw is Map ? raw['data'] : raw;
    if (d is! List) return [];
    return d
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((b) => '${b['vendorId']}' == widget.vendorId && '${b['status']}' == 'COMPLETED')
        .toList();
  }

  String _serviceName(String? serviceId) {
    for (final s in widget.services) {
      if ('${s['id']}' == serviceId) return '${s['name']}';
    }
    return 'خدمة';
  }

  Future<void> _submit() async {
    if (_bookingId == null || _submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/reviews', body: {
        'bookingId': _bookingId,
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message.contains('already reviewed')
          ? 'قيّمت هذا الحجز مسبقاً'
          : e.message);
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('قيّم تجربتك', style: AppText.headingM(c.textPrimary)),
            const SizedBox(height: AppSpacing.s16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text('سجّل الدخول أولاً لتقييم تجربتك — التقييم متاح لمن أتم حجزاً',
                      style: AppText.bodyM(c.textMuted), textAlign: TextAlign.center);
                }
                final bookings = snap.data!;
                if (bookings.isEmpty) {
                  return Text('التقييم متاح بعد إتمام حجز — احجز جرّب ثم قيّم',
                      style: AppText.bodyM(c.textMuted), textAlign: TextAlign.center);
                }
                _bookingId ??= '${bookings.first['id']}';
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('الحجز', style: AppText.bodyM(c.textSecondary)),
                  const SizedBox(height: AppSpacing.s8),
                  DropdownButtonFormField<String>(
                    value: _bookingId,
                    items: bookings.map((b) => DropdownMenuItem(
                      value: '${b['id']}',
                      child: Text('${b['bookingRef']} • ${_serviceName(b['serviceId'] as String?)} • ${_fmtDate(b['startsAt'] as String?)}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _bookingId = v),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      onPressed: () => setState(() => _rating = star),
                      icon: Icon(star <= _rating ? Icons.star : Icons.star_border,
                          size: 32, color: c.accent),
                    );
                  })),
                  const SizedBox(height: AppSpacing.s8),
                  TextField(
                    controller: _comment,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(hintText: 'اكتب تعليقك (اختياري)', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: AppSpacing.s12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إرسال التقييم'),
                  ),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// BookingSheet — اختيار تاريخ ووقت + تأكيد (فعلي عبر /bookings).
/// يمنع اختيار يوم مغلق حسب دوام المورد، ويتحقق أن الوقت ضمن الدوام.
class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.vendor, required this.service, this.rules = const []});
  final Map<String, dynamic> vendor;
  final Map<String, dynamic> service;
  final List<Map<String, dynamic>> rules;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _confirmed;
  Map<String, dynamic>? _payment;
  bool _paying = false;
  String? _payError;
  bool _walletPaying = false;
  String? _walletError;
  Map<String, dynamic>? _walletPaid;

  /// دفع الحجز من رصيد المحفظة — ذري بالباكند (خصم + دفعة PAID + تأكيد).
  Future<void> _payWithWallet() async {
    final id = _confirmed!['id'] as String?;
    if (id == null || _walletPaying) return;
    setState(() { _walletPaying = true; _walletError = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/customer-wallet/pay-booking', body: {'bookingId': id});
      if (!mounted) return;
      setState(() => _walletPaid = (data as Map).cast<String, dynamic>());
      ref.invalidate(customerWalletProvider);
    } on ApiException catch (e) {
      setState(() => _walletError = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _walletError = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _walletPaying = false);
    }
  }

  /// أيام الباكند المفتوحة (0=الأحد..6=السبت) — فارغة = بلا تقييد.
  Set<int> get _openDays => widget.rules
      .map((r) => (r['weekday'] as num?)?.toInt())
      .whereType<int>()
      .toSet();

  List<Map<String, dynamic>> _windowsFor(DateTime d) {
    final w = d.weekday % 7;
    return widget.rules.where((r) => (r['weekday'] as num?)?.toInt() == w).toList();
  }

  String get _hoursSummary {
    if (widget.rules.isEmpty) return '';
    final open = _dayOrder.where((w) => _openDays.contains(w)).map((w) => _dayNames[w]).toList();
    if (open.isEmpty) return 'هذا المزود لا يستقبل حجوزات حالياً';
    return 'أيام العمل: ${open.join('، ')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      selectableDayPredicate: _openDays.isEmpty
          ? null
          : (d) {
              if (d.isBefore(DateTime(now.year, now.month, now.day))) return false;
              return _openDays.contains(d.weekday % 7);
            },
    );
    if (d != null) setState(() { _date = d; _error = null; });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t != null) setState(() { _time = t; _error = null; });
  }

  Future<void> _confirm() async {
    if (_date == null || _time == null) return;
    // تحقق الوقت ضمن الدوام قبل الإرسال
    if (_openDays.isNotEmpty) {
      final wins = _windowsFor(_date!);
      final mins = _time!.hour * 60 + _time!.minute;
      final ok = wins.any((r) {
        final s = (r['startMin'] as num?)?.toInt() ?? 0;
        final e = (r['endMin'] as num?)?.toInt() ?? 0;
        return mins >= s && mins < e;
      });
      if (!ok) {
        final ranges = wins.map((r) => '${_fmtMin((r['startMin'] as num).toInt())} – ${_fmtMin((r['endMin'] as num).toInt())}').join(' • ');
        setState(() => _error = 'اختر وقتاً ضمن الدوام (${_dayNames[_date!.weekday % 7]}: $ranges)');
        return;
      }
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final start = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
      final durationMin = (widget.service['durationMin'] as num?)?.toInt() ?? 240;
      final end = start.add(Duration(minutes: durationMin));
      final data = await api.post('/bookings', body: {
        'vendorId': widget.vendor['id'],
        'resourceId': (widget.vendor['resources'] as List).first['id'],
        'serviceId': widget.service['id'],
        'startsAt': start.toUtc().toIso8601String(),
        'endsAt': end.toUtc().toIso8601String(),
        'clientRequestId': 'app-${DateTime.now().millisecondsSinceEpoch}',
      });
      setState(() => _confirmed = data as Map<String, dynamic>? ?? {});
    } on ApiException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// إنشاء دفعة يدوية (تحويل بنكي) على الحجز المؤكد — يؤكدها الأدمن لاحقاً.
  Future<void> _createPayment() async {
    final id = _confirmed!['id'] as String?;
    if (id == null || _paying) return;
    setState(() { _paying = true; _payError = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/payments', body: {'bookingId': id});
      setState(() => _payment = (data as Map?)?.cast<String, dynamic>() ?? {});
    } on ApiException catch (e) {
      setState(() => _payError = e.message);
    } catch (_) {
      setState(() => _payError = 'تعذر الاتصال، أعد المحاولة');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// ترجمة رفض الحجز لرسائل عربية واضحة مع السبب الحقيقي.
  String _friendly(ApiException e) {
    final m = e.message;
    if (m.contains('outside working hours')) {
      return 'هذا الوقت خارج دوام المزود — اختر يوماً ووقتاً ضمن أوقات العمل';
    }
    if (m.contains('already booked')) return 'هذه الفترة محجوزة — جرّب يوماً أو وقتاً آخر';
    if (m.contains('cross midnight')) return 'الحجز يجب أن ينتهي قبل منتصف الليل';
    if (m.contains('in the past')) return 'لا يمكن الحجز في تاريخ ماضٍ';
    if (m.contains('not accepting')) return 'هذا المزود لا يستقبل حجوزات حالياً';
    if (m.contains('duration')) return 'مدة الحجز غير مناسبة لهذه الخدمة';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_confirmed != null) {
      final price = (_confirmed!['totalPrice'] as num?)?.toInt() ?? 0;
      final currency = '${_confirmed!['currency'] ?? ''}';
      final paid = _payment != null;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 56, color: c.success),
            const SizedBox(height: AppSpacing.s12),
            Text('تم استلام طلب الحجز', style: AppText.headingM(c.textPrimary)),
            const SizedBox(height: AppSpacing.s8),
            Text('المرجع: ${_confirmed!['bookingRef']} — بانتظار تأكيد البائع',
                style: AppText.bodyM(c.textSecondary), textAlign: TextAlign.center),
            if (price > 0) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: c.border),
                ),
                child: Row(children: [
                  Text('المبلغ', style: AppText.caption(c.textSecondary)),
                  const Spacer(),
                  Text('$price $currency', style: AppText.price(c.primary)),
                ]),
              ),
              if (_payError != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(_payError!, style: AppText.caption(c.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpacing.s12),
              if (_walletPaid != null)
                Row(children: [
                  Icon(Icons.check_circle, size: 18, color: c.success),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text('تم الدفع من رصيد المحفظة — الرصيد المتبقي: ${_walletPaid!['balance']} ${_walletPaid!['currency']}',
                        style: AppText.bodyM(c.textSecondary)),
                  ),
                ])
              else ...[
                if (_walletError != null) ...[
                  Text(_walletError!, style: AppText.caption(c.error), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.s8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _walletPaying ? null : _payWithWallet,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.success,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                    ),
                    child: _walletPaying
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('ادفع من رصيد المحفظة', style: AppText.button(Colors.white)),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              if (paid)
                Row(children: [
                  Icon(Icons.hourglass_top_rounded, size: 18, color: c.warning),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text('الدفعة قيد المراجعة — حوّل المبلغ وسيؤكد الأدمن الاستلام',
                        style: AppText.bodyM(c.textSecondary)),
                  ),
                ])
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _paying ? null : _createPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                    ),
                    child: _paying
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('ادفع الآن (تحويل بنكي)', style: AppText.button(Colors.white)),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.s20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('تم'),
            ),
          ]),
        ),
      );
    }

    final canSubmit = _date != null && _time != null && !_submitting;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('حجز: ${widget.service['name']}', style: AppText.headingM(c.textPrimary)),
          const SizedBox(height: AppSpacing.s16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _pickDate,
              child: Text(_date == null ? 'اختر التاريخ' : '${_date!.day}/${_date!.month}/${_date!.year}'),
            )),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: OutlinedButton(
              onPressed: _pickTime,
              child: Text(_time == null ? 'اختر الوقت' : '${_time!.hour}:${_time!.minute.toString().padLeft(2, '0')}'),
            )),
          ]),
          const SizedBox(height: AppSpacing.s12),
          Text('السعر: ${widget.service['price']} ${_curName(widget.service['currency'] as String?)}',
              style: AppText.bodyL(c.textPrimary)),
          const SizedBox(height: AppSpacing.s4),
          if (_hoursSummary.isNotEmpty)
            Text(_hoursSummary, style: AppText.caption(c.textMuted)),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.bodyM(c.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.s16),
          ElevatedButton(
            onPressed: canSubmit ? _confirm : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('تأكيد الحجز'),
          ),
        ]),
      ),
    );
  }
}
