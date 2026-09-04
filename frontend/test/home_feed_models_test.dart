import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:marketplace_app/features/home/models/home_feed.dart';

/// اختبارات نماذج Feed الرئيسية — المرحلة 1: pure unit، بلا Widgets.
Map<String, dynamic> _fixture(String name) {
  final raw = File('test/fixtures/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _rows(String fixture) =>
    (_fixture(fixture)['data'] as List).cast<Map<String, dynamic>>();

void main() {
  group('parseVendorCards', () {
    test('parses search envelope rows', () {
      final cards = parseVendorCards(_fixture('search_geo_200'));
      expect(cards.length, greaterThan(0));
    });

    test('accepts a raw list too', () {
      final cards = parseVendorCards(_rows('search_plain_200'));
      expect(cards.length, greaterThan(0));
    });

    test('garbage in, empty list out', () {
      expect(parseVendorCards(null), isEmpty);
      expect(parseVendorCards({}), isEmpty);
      expect(parseVendorCards({'data': 'nope'}), isEmpty);
      expect(parseVendorCards([42, 'x', null]), isEmpty);
    });

    test('unifies vendors-shape rows (object category + singular count)', () {
      final cards = parseVendorCards(_fixture('vendors_200'));
      expect(cards.isNotEmpty, isTrue);
      final first = cards.first;
      expect(first.categoryName.isNotEmpty, isTrue);
      expect(first.reviewsCount >= 0, isTrue);
      // نفس البائع من /search و/vendors يعطي نفس الاسم
      final searchCards = parseVendorCards(_fixture('search_plain_200'));
      final byId = {for (final c in searchCards) c.id: c};
      expect(byId[first.id]?.name, first.name);
    });

    test('defensive sort keeps nearest first', () {
      final cards = parseVendorCards(_fixture('search_geo_200'));
      cards.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
      for (var i = 1; i < cards.length; i++) {
        expect((cards[i - 1].distanceKm ?? double.infinity) <= (cards[i].distanceKm ?? double.infinity),
            isTrue);
      }
    });
  });

  group('VendorCard fields', () {
    test('full search row maps 1:1', () {
      final v = VendorCard.fromJson(_rows('search_plain_200').first);
      expect(v.name, 'قصر الأمل للاحتفالات');
      expect(v.slug, 'qasr-al-amal');
      expect(v.minPrice, 450);
      expect(v.currency, 'USD');
      expect(v.isOpen, isTrue);
      expect(v.averageRating, 5);
      expect(v.reviewsCount, 1);
      expect(v.distanceKm, isNull);
      expect(v.categoryName, 'قاعات ومناسبات');
    });

    test('missing optionals degrade to safe defaults', () {
      const v = VendorCard(id: 'x', slug: '', name: 'n');
      expect(v.description, '');
      expect(v.address, '');
      expect(v.currency, 'USD');
      expect(v.isOpen, isFalse);
      expect(v.averageRating, 0);
      expect(v.reviewsCount, 0);
      expect(v.distanceKm, isNull);
      expect(v.distanceLabel, isNull);
    });

    test('priceLabel per currency', () {
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', minPrice: 450, currency: 'USD').priceLabel,
          'من 450 دولار');
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', minPrice: 100000, currency: 'SYP').priceLabel,
          'من 100000 ل.س');
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', minPrice: 500, currency: 'TRY').priceLabel,
          'من 500 ل.ت');
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', minPrice: 10, currency: 'WEIRD').priceLabel,
          'من 10 دولار');
    });

    test('ratingText matches legacy raw print', () {
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', averageRating: 5, reviewsCount: 1).ratingText,
          '5 (1)');
      expect(const VendorCard(id: 'a', slug: 'a', name: 'n', averageRating: 4.5, reviewsCount: 3).ratingText,
          '4.5 (3)');
    });

    test('distanceLabel uses metres under 1 km', () {
      const sub = VendorCard(id: 'a', slug: 'a', name: 'n', distanceKm: 0.3);
      const one = VendorCard(id: 'a', slug: 'a', name: 'n', distanceKm: 1.0);
      const frac = VendorCard(id: 'a', slug: 'a', name: 'n', distanceKm: 1.3);
      expect(sub.distanceLabel, '300 م');
      expect(one.distanceLabel, '1 كم');
      expect(frac.distanceLabel, '1.3 كم');
    });
  });

  group('parseHomeCategories', () {
    test('parses fixture rows with iconKey', () {
      final cats = parseHomeCategories(_fixture('categories_200'));
      expect(cats.length, greaterThanOrEqualTo(6));
      expect(cats.map((c) => c.iconKey).toSet(),
          containsAll({'venue', 'salon', 'restaurant', 'gift', 'pool', 'camera'}));
      expect(cats.every((c) => c.id.isNotEmpty && c.nameAr.isNotEmpty), isTrue);
    });

    test('garbage in, empty list out', () {
      expect(parseHomeCategories(null), isEmpty);
      expect(parseHomeCategories({'data': []}), isEmpty);
    });
  });

  group('currencyName', () {
    test('known codes and fallback', () {
      expect(currencyName('USD'), 'دولار');
      expect(currencyName('SYP'), 'ل.س');
      expect(currencyName('TRY'), 'ل.ت');
      expect(currencyName(null), 'دولار');
      expect(currencyName('EUR'), 'دولار');
    });
  });
}
