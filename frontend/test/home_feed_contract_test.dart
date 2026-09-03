import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';

import 'package:marketplace_app/core/network/api_client.dart';

/// عقد Feed الرئيسية — المرحلة 0: يثبّت شكل JSON الحقيقي.
/// أي تغيير باكند يكسر هذه الاختبارات قبل أن يكسر الواجهة.
Map<String, dynamic> _fixture(String name) {
  final raw = File('test/fixtures/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

ApiClient _clientFor(Map<String, String> bodies) {
  return ApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      for (final entry in bodies.entries) {
        if (request.url.path.endsWith(entry.key)) {
          final status = entry.key == '/search-bad' ? 400 : 200;
          return Response(entry.value, status,
              headers: {'content-type': 'application/json'});
        }
      }
      return Response(jsonEncode({'success': true, 'data': []}), 200,
          headers: {'content-type': 'application/json'});
    }),
  );
}

void main() {
  group('envelope', () {
    test('categories/search/vendors unwrap to data lists', () async {
      final bodies = {
        '/categories': jsonEncode(_fixture('categories_200')),
        '/search': jsonEncode(_fixture('search_plain_200')),
        '/vendors': jsonEncode(_fixture('vendors_200')),
      };
      final api = _clientFor(bodies);

      final cats = await api.get('/categories') as List;
      final search = await api.get('/search', query: {'limit': '10'}) as List;
      final vendors = await api.get('/vendors', query: {'limit': '10'}) as List;

      expect(cats.length, greaterThan(0));
      expect(search.length, greaterThan(0));
      expect(vendors.length, greaterThan(0));
    });

    test('every envelope carries pagination meta', () {
      for (final name in ['search_plain_200', 'search_geo_200', 'vendors_200', 'search_empty_200']) {
        final meta = _fixture(name)['meta'] as Map<String, dynamic>;
        expect(meta.keys.toSet(), containsAll({'page', 'limit', 'total', 'totalPages'}),
            reason: '$name meta incomplete');
      }
    });
  });

  group('category contract', () {
    test('rows carry id/nameAr/slug/iconKey/sortOrder', () {
      final cats = (_fixture('categories_200')['data'] as List).cast<Map<String, dynamic>>();
      expect(cats.length, greaterThanOrEqualTo(6));
      for (final c in cats) {
        expect(c['id'], isA<String>());
        expect((c['nameAr'] as String).isNotEmpty, isTrue);
        expect((c['slug'] as String).isNotEmpty, isTrue);
        expect((c['iconKey'] as String).isNotEmpty, isTrue);
        expect(c['sortOrder'], isA<int>());
      }
      const knownKeys = {'venue', 'salon', 'restaurant', 'gift', 'pool', 'camera'};
      expect(knownKeys.containsAll(cats.map((c) => c['iconKey'] as String)), isTrue);
    });
  });

  group('vendor card contract (search rows)', () {
    late List<Map<String, dynamic>> rows;

    setUpAll(() {
      rows = (_fixture('search_geo_200')['data'] as List).cast<Map<String, dynamic>>();
    });

    test('required keys and types', () {
      const required = {
        'id', 'slug', 'name', 'description', 'address', 'minPrice', 'currency',
        'isOpen', 'imageUrl', 'category', 'averageRating', 'reviewsCount', 'distanceKm',
      };
      for (final v in rows) {
        expect(required.difference(v.keys.toSet()), isEmpty);
        expect(v['id'], isA<String>());
        expect(v['slug'], isA<String>());
        expect(v['name'], isA<String>());
        expect(v['isOpen'], isA<bool>());
        expect(v['category'], isA<String>());
      }
    });

    test('currency is always present and known', () {
      for (final v in rows) {
        expect({'USD', 'SYP', 'TRY'}, contains(v['currency']));
      }
    });

    test('rating bounds and review count sane', () {
      for (final v in rows) {
        final rating = (v['averageRating'] as num).toDouble();
        expect(rating, inInclusiveRange(0, 5));
        expect(v['reviewsCount'], isA<int>());
        expect((v['reviewsCount'] as int) >= 0, isTrue);
        if (rating == 0) expect(v['reviewsCount'], 0);
      }
    });

    test('geo rows carry decimal kilometre distances', () {
      final withDist = rows.where((v) => v['distanceKm'] != null).toList();
      expect(withDist.isNotEmpty, isTrue);
      for (final v in withDist) {
        expect((v['distanceKm'] as num).toDouble() >= 0, isTrue);
      }
      // اللقطة الحية: 0.3 كم موجودة — التقريب الصحيح ميت
      expect(withDist.any((v) => ((v['distanceKm'] as num) % 1) != 0), isTrue);
    });

    test('plain rows carry null distance without location', () {
      final plain = (_fixture('search_plain_200')['data'] as List).cast<Map<String, dynamic>>();
      for (final v in plain) {
        expect(v['distanceKm'], isNull);
      }
    });
  });

  group('vendors endpoint pinned shape (drift to unify in phase 2)', () {
    test('category is an object and count key is singular here', () {
      final rows = (_fixture('vendors_200')['data'] as List).cast<Map<String, dynamic>>();
      expect(rows.isNotEmpty, isTrue);
      for (final v in rows) {
        expect(v['category'], isA<Map>());
        expect(v.containsKey('reviewCount'), isTrue);
        expect(v['status'], 'APPROVED');
      }
    });
  });

  group('filter semantics', () {
    test('invalid currency is rejected with 400', () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async => Response(
              jsonEncode(_fixture('search_bad_currency_400')),
              400,
              headers: {'content-type': 'application/json'},
            )),
      );
      try {
        await api.get('/search', query: {'currency': 'XXX', 'limit': '2'});
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.status, 400);
      }
    });

    test('empty result is an empty list with total 0', () async {
      final api = _clientFor({'/search': jsonEncode(_fixture('search_empty_200'))});
      final rows = await api.get('/search', query: {'q': 'zzzznomatchquery'}) as List;
      expect(rows, isEmpty);
      expect((_fixture('search_empty_200')['meta'] as Map)['total'], 0);
    });
  });
}
