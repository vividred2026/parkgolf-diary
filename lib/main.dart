import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/park_catalog.dart';
import 'data/storage.dart';
import 'models/models.dart';
import 'screens/onboarding.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.open(
    await Storage.create(),
    await ParkCatalog.load(),
  );
  runApp(ParkGolfDiaryApp(store: store));
}

class ParkGolfDiaryApp extends StatelessWidget {
  const ParkGolfDiaryApp({super.key, required this.store, this.home});

  final AppStore store;

  /// 시작 화면 (기본: 스플래시). 개발용 미리보기에서만 바꿔요.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: Selector<AppStore, AppThemeMode>(
        selector: (_, s) => s.settings.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: '파크골프다이어리',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (mode) {
            AppThemeMode.system => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
          },
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [Locale('ko', 'KR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home ?? const SplashScreen(),
        ),
      ),
    );
  }
}
