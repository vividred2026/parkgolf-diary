import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/park_catalog.dart';
import 'data/storage.dart';
import 'models/models.dart';
import 'screens/onboarding.dart';
import 'services/earphone.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 상태바 · 하단 내비게이션 바까지 앱 배경을 그려요 (검은 띠 없이).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await AppStore.open(
    await Storage.create(),
    await ParkCatalog.load(),
  );
  // 이어폰 상태 (권한이 이미 있을 때만 바로 연결 상태를 읽어요)
  EarphoneService.instance.start();
  runApp(ParkGolfDiaryApp(store: store));
}

class ParkGolfDiaryApp extends StatelessWidget {
  const ParkGolfDiaryApp({super.key, required this.store, this.home});

  final AppStore store;

  /// 시작 화면 (기본: 스플래시). 개발용 미리보기에서만 바꿔요.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: EarphoneService.instance),
      ],
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
          // 화면 모드(라이트 / 다크)에 맞춰 시스템 바 아이콘 색을 바꿔요.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: systemBarsStyle(Theme.of(context).brightness),
            child: child!,
          ),
          home: home ?? const SplashScreen(),
        ),
      ),
    );
  }
}
