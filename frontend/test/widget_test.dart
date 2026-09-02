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
}
