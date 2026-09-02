import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';

/// صفحة البائع (من البحث) + CTA حجز → BookingSheet.
class VendorDetailsScreen extends ConsumerStatefulWidget {
  const VendorDetailsScreen({super.key, required this.idOrSlug});
  final String idOrSlug;

  @override
  ConsumerState<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends ConsumerState<VendorDetailsScreen> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).get('/vendors/${widget.idOrSlug}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('تفاصيل البائع')),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(children: List.generate(4, (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.s8),
              child: SkeletonLoader(height: 90),
            )));
          }
          if (snap.hasError) {
            return ErrorState(message: 'تعذر تحميل بيانات البائع', onRetry: () => setState(() {}));
          }
          final v = Map<String, dynamic>.from(snap.data as Map);
          final services = (v['services'] as List? ?? []).cast<Map<String, dynamic>>();
          return Stack(children: [
            ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              Container(
                height: 140,
                color: c.primary.withOpacity(0.1),
                alignment: Alignment.center,
                child: Icon(Icons.storefront_outlined, size: 48, color: c.primary),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v['name'] as String, style: AppText.headingL(c.textPrimary)),
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
                  Text('الخدمات', style: AppText.headingM(c.textPrimary)),
                  const SizedBox(height: AppSpacing.s12),
                  ...services.map((s) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'] as String, style: AppText.headingS(c.textPrimary)),
                          const SizedBox(height: AppSpacing.s4),
                          Text('من \$${s['price']}', style: AppText.price(c.primary)),
                        ]),
                      )),
                ]),
              ),
            ]),
            Positioned(
              left: AppSpacing.screenH,
              right: AppSpacing.screenH,
              bottom: AppSpacing.s16,
              child: ElevatedButton(
                onPressed: services.isEmpty ? null : () => _openBooking(context, v, services.first),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('احجز الآن'),
              ),
            ),
          ]);
        },
      ),
    );
  }

  void _openBooking(BuildContext context, Map<String, dynamic> vendor, Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BookingSheet(vendor: vendor, service: service),
    );
  }
}

/// BookingSheet — اختيار تاريخ ووقت + تأكيد (فعلي عبر /bookings).
class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.vendor, required this.service});
  final Map<String, dynamic> vendor;
  final Map<String, dynamic> service;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _confirmed;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t != null) setState(() => _time = t);
  }

  Future<void> _confirm() async {
    if (_date == null || _time == null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final start = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
      final end = start.add(const Duration(hours: 4));
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
      setState(() => _error = e.status == 409
          ? 'هذه الفترة حُجزت للتو — جرّب وقتاً آخر'
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
    if (_confirmed != null) {
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
          Text('السعر: \$${widget.service['price']} ${widget.service['currency'] ?? ''}',
              style: AppText.bodyL(c.textPrimary)),
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
