import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marketplace_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full customer journey: home → vendor → booking sheet → explore → login → bookings → favorites', (tester) async {
    await tester.pumpWidget(const MarketplaceApp());

    // 1) الرئيسية: بائعون حقيقيون من الـ API الحي
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('قصر الأمل للاحتفالات'), findsWidgets);
    expect(find.text('التصنيفات'), findsOneWidget);
    expect(find.text('قريب منك'), findsOneWidget);

    // 2) بطاقة البائع → التفاصيل
    await tester.tap(find.text('قصر الأمل للاحتفالات').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('الخدمات'), findsOneWidget);
    expect(find.text('احجز الآن'), findsOneWidget);

    // 3) شاشة الحجز
    await tester.tap(find.text('احجز الآن'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('اختر التاريخ'), findsOneWidget);
    expect(find.textContaining('أيام العمل'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 4) استكشف: بحث حي
    await tester.tap(find.text('استكشف'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField).first, 'قصر');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('قصر الأمل للاحتفالات'), findsWidgets);

    // 5) حجوزاتي → بوابة الدخول → دخول حقيقي
    await tester.tap(find.text('حجوزاتي'));
    await tester.pumpAndSettle();
    expect(find.text('سجّل الدخول لعرض حجوزاتك'), findsOneWidget);
    final loginBtn = find.byType(FilledButton);
    expect(loginBtn.evaluate(), isNotEmpty);
    await tester.tap(loginBtn.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.at(0), 'qa.cust@example.com');
    await tester.enterText(fields.at(1), 'Str0ng!Passw0rd');
    await tester.tap(find.text('تسجيل الدخول').last);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining('BK-'), findsWidgets);

    // 6) حسابي → المفضلة
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('قصر الأمل للاحتفالات'), findsWidgets);

    debugPrint('ALL JOURNEY STEPS PASSED');
  });
}
