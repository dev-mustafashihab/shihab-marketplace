import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';

import 'package:marketplace_app/core/network/api_client.dart';
import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('home search opens its own search sheet and filter controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('home-search-filter-inline')));
    await tester.pumpAndSettle();
    expect(find.text('بحث سريع'), findsOneWidget);
    expect(find.text('خيارات الفلترة'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قاعة أعراس؟ صالون؟ هدية؟'));
    await tester.pumpAndSettle();

    expect(find.text('بحث سريع'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-search-filter')));
    await tester.pumpAndSettle();
    expect(find.text('خيارات الفلترة'), findsOneWidget);
  });

  testWidgets('location selector lets the user choose a Syrian governorate', (tester) async {
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

  testWidgets('notification bell opens a visible notifications screen', (tester) async {
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
}
