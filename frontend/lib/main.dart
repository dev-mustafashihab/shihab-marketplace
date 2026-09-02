import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/session/session_service.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/root_scaffold.dart';

/// الجذر: عربي أولاً + RTL من اللحظة الأولى (لا "نضيف RTL لاحقاً").
class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سوق المناسبات',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // darkTheme: AppTheme.dark(), // معمّر وجاهز — التفعيل في Phase 2
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootScaffold(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await SessionService.restore(container);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const MarketplaceApp(),
  ));
}
