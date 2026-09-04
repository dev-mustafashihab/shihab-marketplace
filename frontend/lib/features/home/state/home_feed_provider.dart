// حالة وبيانات Feed الرئيسية — منقولة من root_scaffold (المرحلة 1).
// السلوك مطابق تماماً للسابق: نفس المسارات، نفس البراميترات، نفس الترتيب الوقائي.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_service.dart';
import '../models/home_feed.dart';

/// التصنيف المختار في الرئيسية — null = الكل. الفلترة داخل الصفحة بلا انتقال.
/// يُضبط من ورقة البحث الموحدة (التصنيفات تعيش داخل البحث).
final homeCategoryProvider = StateProvider<String?>((ref) => null);

/// حد السعر المشترك بين ورقة البحث والرئيسية — null = بلا حد.
final homeMaxPriceProvider = StateProvider<double?>((ref) => null);

/// عملة فلتر السعر المشتركة — تُرسل مع السعر فقط (نفس قاعدة /search).
final homeCurrencyProvider = StateProvider<String>((ref) => 'USD');

/// عملة عرض الرصيد في الشريط العلوي — منفصلة عن فلتر البحث، بالسحب
final homeBalanceCurrencyProvider = StateProvider<String>((ref) => 'USD');

/// إخفاء الرصيد — زر العين
final homeBalanceHiddenProvider = StateProvider<bool>((ref) => false);

/// مسح كل فلاتر الرئيسية دفعة واحدة.
void clearHomeFilters(WidgetRef ref) {
  ref.read(homeCategoryProvider.notifier).state = null;
  ref.read(homeMaxPriceProvider.notifier).state = null;
  ref.read(homeCurrencyProvider.notifier).state = 'USD';
}

/// بيانات الرئيسية — عند توفر موقع المستخدم: بحث جغرافي PostGIS مرتب بالأقرب (50 كم)
/// وإلا: قائمة مميزة عامة. يحترم التصنيف والسعر المختارين في ورقة البحث.
final homeVendorsProvider = FutureProvider.autoDispose<List<VendorCard>>((ref) async {
  final me = ref.watch(userLocationProvider);
  final api = ref.watch(apiClientProvider);
  final catId = ref.watch(homeCategoryProvider);
  final maxPrice = ref.watch(homeMaxPriceProvider);
  final currency = ref.watch(homeCurrencyProvider);
  final priceQuery = <String, String>{
    if (maxPrice != null) ...{
      'maxPrice': maxPrice.round().toString(),
      'currency': currency,
    },
  };
  if (me != null) {
    final d = await api.get(
      '/search',
      query: {
        'lat': me.lat.toStringAsFixed(6),
        'lng': me.lng.toStringAsFixed(6),
        'radiusKm': '50',
        'limit': '10',
        if (catId != null) 'categoryId': catId,
        ...priceQuery,
      },
    );
    final rows = parseVendorCards(d);
    // الـ API يرتب بالأقرب أصلاً (ORDER BY distance) — ترتيب وقائي على نسخة قابلة للتعديل
    rows.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });
    return rows;
  }
  final d = await api.get('/vendors', query: {
    'limit': '10',
    if (catId != null) 'categoryId': catId,
    ...priceQuery,
  });
  return parseVendorCards(d);
});

final homeCategoriesProvider = FutureProvider.autoDispose<List<HomeCategory>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/categories');
  return parseHomeCategories(d);
});
