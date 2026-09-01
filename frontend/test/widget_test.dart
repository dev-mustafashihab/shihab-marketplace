import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('Home renders search bar and sections after load', (tester) async {
    await tester.pumpWidget(const MarketplaceApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('ابحث عن خدمة...'), findsOneWidget);
    expect(find.text('قريب منك'), findsOneWidget);
    expect(find.text('الأكثر طلباً'), findsOneWidget);
  });
}
