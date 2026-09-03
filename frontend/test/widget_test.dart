import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('App boots to shell with bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // التبويبات الخمسة معتمدة من الـ IA
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('استكشف'), findsOneWidget);
    expect(find.text('حجوزاتي'), findsOneWidget);
    expect(find.text('طلباتي'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });

  testWidgets('home keeps search and quick filters visible after scrolling', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final scroll = find.byType(CustomScrollView);
    final search = find.text('قاعة أعراس؟ صالون؟ هدية؟');
    final openNow = find.text('مفتوح الآن');
    expect(search, findsOneWidget);
    expect(openNow, findsOneWidget);

    await tester.drag(scroll, const Offset(0, -420));
    await tester.pump();

    expect(tester.getTopLeft(search).dy, greaterThanOrEqualTo(0));
    expect(tester.getTopLeft(search).dy, lessThan(160));
    expect(tester.getTopLeft(openNow).dy, greaterThanOrEqualTo(0));
    expect(tester.getTopLeft(openNow).dy, lessThan(220));
  });

  testWidgets('home shell fits a narrow 320dp phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });
}
