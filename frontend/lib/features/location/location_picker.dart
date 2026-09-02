import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// منتقي الموقع: GPS حقيقي أو مدينة من القائمة — bottom sheet أنيق.
Future<void> showLocationPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _LocationSheet(),
  );
}

class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet();

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  bool _locating = false;
  String? _error;

  Future<void> _useGps() async {
    setState(() { _locating = true; _error = null; });
    final ok = await acquireLocation(ref);
    if (!mounted) return;
    if (ok) {
      ref.read(userCityProvider.notifier).state = 'موقعي الحالي';
      await SessionService.saveLocation(
        ref.read(userLocationProvider)?.lat,
        ref.read(userLocationProvider)?.lng,
        'موقعي الحالي',
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _locating = false;
        _error = 'تعذّر تحديد موقعك — فعّل خدمة الموقع وامنح الصلاحية';
      });
    }
  }

  Future<void> _pickCity(String name, LatLng pos) async {
    ref.read(userLocationProvider.notifier).state = pos;
    ref.read(userCityProvider.notifier).state = name;
    await SessionService.saveLocation(pos.lat, pos.lng, name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.center,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text('اختر موقعك', style: AppText.headingM(c.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s4),
          Text('لعرض البائعين القريبين منك والمسافات', style: AppText.caption(c.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s16),
          // زر GPS
          OutlinedButton.icon(
            onPressed: _locating ? null : _useGps,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: Text(_locating ? 'جارٍ تحديد موقعك…' : 'استخدم موقعي الحالي (GPS)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: c.primary,
              side: BorderSide(color: c.primary.withOpacity(0.4)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(_error!, style: AppText.caption(c.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.s16),
          Text('أو اختر مدينة', style: AppText.bodyL(c.textSecondary)),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            height: 260,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: SYRIA_CITIES.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
              itemBuilder: (context, i) {
                final name = SYRIA_CITIES.keys.elementAt(i);
                final selected = ref.watch(userCityProvider) == name;
                return ListTile(
                  dense: true,
                  title: Text(name, style: AppText.bodyL(selected ? c.primary : c.textPrimary)),
                  trailing: selected ? Icon(Icons.check_circle, color: c.primary, size: 20) : null,
                  onTap: () => _pickCity(name, SYRIA_CITIES[name]!),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// حساب المسافة كم (هافرزاينوس) — للعرض على البطاقات.
String distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final d = 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  if (d < 1) return '${(d * 1000).round()} م';
  return '${d.toStringAsFixed(1)} كم';
}

double _rad(double d) => d * 3.141592653589793 / 180;
double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120; // تايلور يكفي للعرض
double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
double _sqrt(double x) => x < 0 ? 0 : _newton(x);
double _newton(double x) {
  if (x == 0) return 0;
  var g = x / 2;
  for (var i = 0; i < 12; i++) {
    g = (g + x / g) / 2;
  }
  return g;
}
double _atan2(double y, double x) {
  if (x > 0) return _atan(y / x);
  if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
  if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
  if (y > 0) return 3.141592653589793 / 2;
  if (y < 0) return -3.141592653589793 / 2;
  return 0;
}
double _atan(double x) => x - x * x * x / 3 + x * x * x * x * x / 5 - x * x * x * x * x * x * x / 7;

