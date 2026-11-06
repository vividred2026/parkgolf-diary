// 개발용 미리보기: 예시 데이터를 넣고 웹에서 화면을 확인할 때 써요.
// flutter run -d chrome -t tool/preview_main.dart
// ?screen=home|records|my|score|table|start|par|complete|detail|diary|backup|trash
//  &theme=dark  &empty=1
import 'package:flutter/material.dart';
import 'package:parkgolf_diary/data/app_store.dart';
import 'package:parkgolf_diary/data/park_catalog.dart';
import 'package:parkgolf_diary/data/storage.dart';
import 'package:parkgolf_diary/main.dart';
import 'package:parkgolf_diary/models/models.dart';
import 'package:parkgolf_diary/screens/shell.dart';
import 'package:parkgolf_diary/screens/score/score_input.dart';
import 'package:parkgolf_diary/screens/round/round_start.dart';
import 'package:parkgolf_diary/screens/round/hole_par.dart';
import 'package:parkgolf_diary/screens/round/park_search.dart';
import 'package:parkgolf_diary/screens/round/companions.dart';
import 'package:parkgolf_diary/screens/records/round_complete.dart';
import 'package:parkgolf_diary/screens/records/round_detail.dart';
import 'package:parkgolf_diary/screens/records/park_detail.dart';
import 'package:parkgolf_diary/screens/records/diary.dart';
import 'package:parkgolf_diary/screens/my/backup_screen.dart';
import 'package:parkgolf_diary/screens/my/trash_screen.dart';
import 'package:parkgolf_diary/screens/my/score_display.dart';
import 'package:parkgolf_diary/screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final store = await AppStore.open(MemoryStorage(), await ParkCatalog.load());
  store.setNickname('라이언');
  if (q['theme'] == 'dark') store.setThemeMode(AppThemeMode.dark);
  if (q['theme'] == 'light') store.setThemeMode(AppThemeMode.light);
  Round? last;
  Round? playing;
  if (q['empty'] != '1') {
    final parks = store.allParks;
    const sets = [
      [3, 4, 5, 4, 3, 5, 4, 3, 5],
      [4, 3, 5, 3, 4, 5, 3, 4, 5],
      [5, 4, 3, 3, 4, 5, 4, 3, 5],
      [3, 5, 4, 4, 3, 5, 5, 3, 4],
    ];
    for (final p in parks) {
      for (var i = 0; i < p.courses.length; i++) {
        p.courses[i].pars.setAll(0, sets[i % 4]);
      }
      store.savePark(p);
    }
    final now = DateTime.now();
    final plan = [
      (0, 1, 3, [2, 3, 2, 3, 3, 2, 3, 2, 3]),
      (1, 9, 2, [3, 2, 3, 2, 2, 3, 3, 2, 2]),
      (0, 22, 3, [2, 2, 3, 3, 2, 3, 2, 2, 3]),
      (2, 40, 2, [3, 3, 2, 2, 3, 3, 2, 3, 3]),
      (0, 70, 3, [3, 2, 3, 3, 3, 2, 3, 3, 2]),
      (3, 110, 1, [2, 3, 3, 2, 3, 3, 3, 2, 3]),
      (0, 150, 2, [3, 3, 3, 2, 3, 2, 3, 3, 3]),
    ];
    for (final (pi, daysAgo, comp, g) in plan) {
      final p = store.parkById(parks[pi].id)!;
      final r = store.startRound(
          park: p,
          courseIndexes: [0, 1],
          companions: ['어피치', '무지', '프로도'].take(comp).toList(),
          date: now.subtract(Duration(days: daysAgo, hours: 3)));
      for (var h = 0; h < 18; h++) {
        final putts = h % 4 == 0 ? 1 : 2;
        final pen = h == 6 ? 2 : 0;
        store.setMine(r, h,
            HoleScore(toGreen: g[h % 9] + pen, putts: putts, penalty: pen));
        for (var k = 0; k < comp; k++) {
          store.setOther(r, k, h, r.pars[h] + ((h + k) % 3 == 0 ? 1 : 0));
        }
      }
      store.finishRound(r);
      last ??= r;
    }
    last!.memo = '7번 홀 티샷이 계속 오른쪽으로… 다음엔 힘을 빼고. 그린이 빨라서 퍼트 조심.';
    final trashR = store.startRound(
        park: store.parkById(parks[1].id)!,
        courseIndexes: [0, 1],
        companions: [],
        date: now.subtract(const Duration(days: 30)));
    for (var h = 0; h < 18; h++) {
      store.setMine(trashR, h, const HoleScore(toGreen: 3, putts: 2));
    }
    store.finishRound(trashR);
    store.deleteRound(trashR, now: now.subtract(const Duration(days: 2)));

    if (const {'score', 'table'}.contains(q['screen'])) {
      playing = store.startRound(
          park: store.parkById(parks[0].id)!,
          courseIndexes: [0, 1],
          companions: ['어피치', '무지', '프로도'],
          date: now);
      for (var h = 0; h < 6; h++) {
        store.setMine(playing, h, HoleScore(toGreen: 3, putts: h % 2 + 1));
        store.setOther(playing, 0, h, 4);
        store.setOther(playing, 1, h, 5);
      }
      store.setMine(playing, 6, const HoleScore(toGreen: 3, putts: 2));
    }
    store.data.settings.lastBackupAt = now.subtract(const Duration(days: 20));
  }

  final screen = q['screen'] ?? 'home';
  final park = store.allParks.first;
  final Widget home = switch (screen) {
    'splash' => const SplashScreen(),
    'permission' => const PermissionScreen(),
    'nickname' => const NicknameScreen(),
    'records' => const MainShell(initialTab: 1),
    'my' => const MainShell(initialTab: 2),
    'score' || 'table' => ScoreInputScreen(roundId: playing!.id),
    'start' => const RoundStartScreen(),
    'search' => const ParkSearchScreen(),
    'add' => const ParkAddScreen(),
    'par' => HoleParScreen(
        park: Park(id: 'x', name: park.name, builtIn: true, courses: [
          Course(name: '아웃코스', pars: [3, 4, 5, 4, null, 3, 5, 4, null]),
          Course(name: '인코스'),
        ]),
        courseIndexes: const [0, 1],
        finishLabel: '다음 · 동반자'),
    'companions' => CompanionsScreen(park: park, courseIndexes: const [0, 1]),
    'complete' => RoundCompleteScreen(roundId: last!.id),
    'detail' => RoundDetailScreen(roundId: last!.id),
    'park' => ParkDetailScreen(parkId: last!.parkId),
    'diary' => DiaryScreen(roundId: last!.id),
    'backup' => const BackupScreen(),
    'trash' => const TrashScreen(),
    'display' => const ScoreDisplayScreen(),
    _ => const MainShell(),
  };
  runApp(ParkGolfDiaryApp(store: store, home: home));
}
