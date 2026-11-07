import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkgolf_diary/data/app_store.dart';
import 'package:parkgolf_diary/data/park_catalog.dart';
import 'package:parkgolf_diary/data/storage.dart';
import 'package:parkgolf_diary/main.dart';
import 'package:parkgolf_diary/models/models.dart';
import 'package:parkgolf_diary/screens/score/score_input.dart';
import 'package:parkgolf_diary/services/speech.dart';

/// 말한 내용을 바로 돌려주는 가짜 음성 인식.
class FakeSpeech extends SpeechService {
  FakeSpeech(this.says);
  final List<String> says;

  @override
  Future<bool> init() async => true;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal, List<String> alternates)
    onResult,
    required void Function(double level) onLevel,
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    final w = says.removeAt(0);
    final parts = w.split('|'); // '첫 후보|다른 후보'
    Future.microtask(() => onResult(parts.first, true, parts.skip(1).toList()));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

Park park() => Park(
  id: 'p1',
  name: '한강 둔치 파크골프장',
  courses: [
    Course(name: '아웃코스', pars: [3, 4, 5, 4, 3, 5, 4, 3, 5]),
    Course(name: '인코스', pars: [4, 3, 5, 3, 4, 5, 3, 4, 5]),
  ],
);

Future<(AppStore, Round)> setup(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 860));
  final store = await AppStore.open(MemoryStorage(), ParkCatalog([]));
  store.setNickname('라이언');
  final r = store.startRound(
    park: park(),
    courseIndexes: [0, 1],
    companions: ['어피치', '무지'],
  );
  await tester.pumpWidget(
    ParkGolfDiaryApp(
      store: store,
      home: ScoreInputScreen(roundId: r.id),
    ),
  );
  await tester.pumpAndSettle();
  return (store, r);
}

void main() {
  testWidgets('버튼으로 입력: + 를 누르면 파 기준에서 시작', (tester) async {
    final (_, r) = await setup(tester);
    expect(find.text('1H'), findsOneWidget);
    await tester.tap(find.byTooltip('그린까지 (벌타 포함) 더하기'));
    await tester.pumpAndSettle();
    // 1H 는 Par 3 → 그린까지 1 + 1 = 2, 퍼트 2
    expect(r.mine[0], const HoleScore(toGreen: 2, putts: 2));
    expect(find.textContaining('총 4타'), findsOneWidget);

    await tester.tap(find.text('벌타 +2'));
    await tester.pumpAndSettle();
    expect(r.mine[0], const HoleScore(toGreen: 4, putts: 2, penalty: 2));

    await tester.tap(find.text('다음 홀 2H ▶'));
    await tester.pumpAndSettle();
    expect(find.text('2H'), findsOneWidget);
  });

  testWidgets('음성: 들은 결과 확인 → 적용 → 되돌리기', (tester) async {
    SpeechService.instance = FakeSpeech(['그린까지 삼 퍼트 2 어피치 4']);
    final (_, r) = await setup(tester);
    await tester.tap(find.text('눌러서 말하기'));
    await tester.pumpAndSettle();
    expect(find.text('이렇게 들었어요'), findsOneWidget);
    // 자동 반영하지 않아요
    expect(r.mine[0], isNull);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(r.mine[0], const HoleScore(toGreen: 3, putts: 2));
    expect(r.others[0][0], 4);
    expect(find.text('음성으로 1H 입력했어요'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(r.mine[0], isNull);
    expect(r.others[0][0], isNull);
  });

  testWidgets('음성: 쓰리온 투퍼트 · 다른 후보로 알아듣기', (tester) async {
    SpeechService.instance = FakeSpeech(['음 글쎄|쓰리온 투퍼트']);
    final (_, r) = await setup(tester);
    await tester.tap(find.text('눌러서 말하기'));
    await tester.pumpAndSettle();
    expect(find.text('이렇게 들었어요'), findsOneWidget);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(r.mine[0], const HoleScore(toGreen: 3, putts: 2));
  });

  testWidgets('음성: 퍼트가 애매하면 되묻기', (tester) async {
    SpeechService.instance = FakeSpeech(['다섯 타']);
    final (_, r) = await setup(tester);
    await tester.tap(find.text('눌러서 말하기'));
    await tester.pumpAndSettle();
    expect(find.text('퍼트가 맞나요?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2로 적용'));
    await tester.pumpAndSettle();
    expect(r.mine[0], const HoleScore(toGreen: 3, putts: 2));
  });

  testWidgets('음성: 못 알아들으면 안내', (tester) async {
    SpeechService.instance = FakeSpeech(['음 글쎄']);
    final (_, r) = await setup(tester);
    await tester.tap(find.text('눌러서 말하기'));
    await tester.pumpAndSettle();
    expect(find.text('잘 못 알아들었어요'), findsOneWidget);
    await tester.tap(find.text('버튼으로 입력'));
    await tester.pumpAndSettle();
    expect(r.mine[0], isNull);
  });

  testWidgets('음성 명령: 다음 홀', (tester) async {
    SpeechService.instance = FakeSpeech(['다음 홀']);
    await setup(tester);
    await tester.tap(find.text('눌러서 말하기'));
    await tester.pumpAndSettle();
    expect(find.text('2H'), findsOneWidget);
  });
}
