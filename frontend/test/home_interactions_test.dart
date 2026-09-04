import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';

import 'package:marketplace_app/core/network/api_client.dart';
import 'package:marketplace_app/main.dart';

Response _json(Object data) => Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  testWidgets('home search opens unified sheet with collapsible filter sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('home-search-filter-inline')));
    await tester.pumpAndSettle();
    expect(find.text('بحث سريع'), findsOneWidget);
    expect(find.text('التصنيف'), findsOneWidget);
    expect(find.text('العملة والسعر'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قاعة أعراس؟ صالون؟ هدية؟'));
    await tester.pumpAndSettle();

    expect(find.text('بحث سريع'), findsOneWidget);

    // قسم العملة والسعر ينفتح وحده ويعرض مبدّل العملة المدمج
    await tester.tap(find.text('العملة والسعر'));
    await tester.pumpAndSettle();
    expect(find.textContaining('العملة:'), findsOneWidget);
    expect(find.text('حتى 200 دولار'), findsOneWidget);
  });

  testWidgets('location selector lets the user choose a Syrian governorate',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('دمشق'));
    await tester.pumpAndSettle();
    expect(find.text('اختر موقعك'), findsOneWidget);

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();
    expect(find.text('اختر موقعك'), findsNothing);
    expect(find.text('حلب'), findsOneWidget);
  });

  testWidgets('notification bell opens a visible notifications screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.bySemanticsLabel('الإشعارات'));
    await tester.pumpAndSettle();

    expect(find.text('الإشعارات'), findsOneWidget);
  });

  testWidgets('home search requests and renders live API results', (tester) async {
    final queries = <Map<String, String>>[];
    final api = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        queries.add(request.url.queryParameters);
        return Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'vendor-1',
                'slug': 'qasr-alamal',
                'name': 'قصر الأمل',
                'category': 'قاعات',
                'address': 'دمشق',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MarketplaceApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('قاعة أعراس؟ صالون؟ هدية؟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'قصر');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('قصر الأمل'), findsAtLeastNWidgets(1));
    expect(queries.any((query) => query['q'] == 'قصر'), isTrue);
  });

  testWidgets('category inside search sheet filters home with summary chip',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vendorQueries = <Map<String, String>>[];
    final api = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/categories')) {
          return _json([
            {'id': 'cat-1', 'nameAr': 'قاعات', 'slug': 'venues', 'iconKey': 'venue'},
            {'id': 'cat-2', 'nameAr': 'مطاعم', 'slug': 'restaurants', 'iconKey': 'restaurant'},
          ]);
        }
        if (path.endsWith('/vendors')) {
          vendorQueries.add(request.url.queryParameters);
        }
        return _json([]);
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MarketplaceApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // لا صف تصنيفات في الرئيسية بعد النقل لداخل البحث
    expect(find.text('التصنيفات'), findsNothing);

    // اختيار التصنيف من داخل ورقة البحث
    await tester.tap(find.text('قاعة أعراس؟ صالون؟ هدية؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التصنيف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قاعات'));
    await tester.pumpAndSettle();

    // الفلترة أُرسلت للباكند
    expect(vendorQueries.any((query) => query['categoryId'] == 'cat-1'), isTrue);

    // إغلاق الورقة — ملخص الفلتر يظهر في الرئيسية مع حالة فارغة
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('قاعات'), findsOneWidget);
    expect(find.text('لا نتائج مطابقة للفلاتر'), findsOneWidget);

    // مسح الكل يعيد القائمة بلا فلتر
    await tester.tap(find.text('مسح الكل'));
    await tester.pumpAndSettle();
    expect(find.text('قاعات'), findsNothing);
    expect(vendorQueries.last.containsKey('categoryId'), isFalse);
  });
}
