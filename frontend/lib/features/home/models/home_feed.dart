// نماذج Feed الرئيسية — عقد واحد فوق /search و/vendors.
// المرحلة 1: فصل البيانات عن الواجهة، بلا تغيير سلوك.

/// العملات المسموحة في فلترة السعر (مطابق SearchQueryDto في الباكند).
const homeSupportedCurrencies = {'USD', 'SYP', 'TRY'};

/// اسم العملة بالعربية للعرض.
String currencyName(String? code) => switch (code) {
      'SYP' => 'ل.س',
      'TRY' => 'ل.ت',
      _ => 'دولار',
    };

/// تصنيف كما يرجعه /categories.
class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.nameAr,
    this.slug,
    this.iconKey,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String? slug;
  final String? iconKey;
  final int sortOrder;

  factory HomeCategory.fromJson(Map<String, dynamic> j) => HomeCategory(
        id: (j['id'] ?? '') as String,
        nameAr: (j['nameAr'] ?? '') as String,
        slug: j['slug'] as String?,
        iconKey: j['iconKey'] as String?,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

/// بطاقة بائع موحدة: تقبل شكل /search (category نص + reviewsCount)
/// وشكل /vendors (category كائن + reviewCount) وتنتج نموذجاً واحداً.
class VendorCard {
  const VendorCard({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.address = '',
    this.minPrice,
    this.currency = 'USD',
    this.isOpen = false,
    this.imageUrl,
    this.categoryName = '',
    this.averageRating = 0,
    this.reviewsCount = 0,
    this.distanceKm,
    this.phone,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String address;
  final num? minPrice;
  final String currency;
  final bool isOpen;
  final String? imageUrl;
  final String categoryName;
  final double averageRating;
  final int reviewsCount;
  final double? distanceKm;
  final String? phone;

  /// تسمية السعر بعملة البائع — نفس نص الواجهة السابقة حرفياً.
  String get priceLabel => 'من $minPrice ${currencyName(currency)}';

  /// نص التقييم كما كان يُطبع من JSON الخام (5 لا 5.0).
  String get ratingText => '$averageRating ($reviewsCount)'.replaceFirst('.0 (', ' (');

  /// مسافة العرض: أمتار تحت الكيلومتر بدل «0 كم»، وتقليم .0 فوقه.
  String? get distanceLabel {
    final d = distanceKm;
    if (d == null || d < 0) return null;
    if (d < 0.05) return 'قريب جداً';
    if (d < 1) return '${(d * 1000).round()} م';
    return d == d.roundToDouble() ? '${d.toInt()} كم' : '${d.toStringAsFixed(1)} كم';
  }

  factory VendorCard.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    final categoryName =
        cat is Map ? ((cat['nameAr'] ?? '') as String) : ((cat ?? '') as String);
    return VendorCard(
      id: (j['id'] ?? '') as String,
      slug: ((j['slug'] ?? j['id']) ?? '') as String,
      name: (j['name'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      address: (j['address'] ?? '') as String,
      minPrice: j['minPrice'] as num?,
      currency: (j['currency'] as String?) ?? 'USD',
      isOpen: j['isOpen'] == true,
      imageUrl: j['imageUrl'] as String?,
      categoryName: categoryName,
      averageRating: ((j['averageRating'] as num?) ?? 0).toDouble(),
      reviewsCount: ((j['reviewsCount'] ?? j['reviewCount']) as num?)?.toInt() ?? 0,
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      phone: j['phone'] as String?,
    );
  }
}

/// normalizer واحد لقوائم البطاقات من أي endpoint (List خام أو envelope).
List<VendorCard> parseVendorCards(dynamic d) {
  final raw = d is List
      ? d
      : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
  return raw
      .whereType<Map>()
      .map((m) => VendorCard.fromJson(Map<String, dynamic>.from(m)))
      .toList();
}

/// normalizer واحد لقائمة التصنيفات.
List<HomeCategory> parseHomeCategories(dynamic d) {
  final raw = d is List
      ? d
      : (d is Map && d['data'] is List ? d['data'] as List : const <dynamic>[]);
  return raw
      .whereType<Map>()
      .map((m) => HomeCategory.fromJson(Map<String, dynamic>.from(m)))
      .toList();
}
