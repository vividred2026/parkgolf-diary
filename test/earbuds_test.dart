import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkgolf_diary/data/app_store.dart';
import 'package:parkgolf_diary/data/park_catalog.dart';
import 'package:parkgolf_diary/data/storage.dart';
import 'package:parkgolf_diary/logic/earbuds.dart';
import 'package:parkgolf_diary/main.dart';
import 'package:parkgolf_diary/models/models.dart';
import 'package:parkgolf_diary/screens/earphone/earphone_screen.dart';
import 'package:parkgolf_diary/screens/score/score_input.dart';
import 'package:parkgolf_diary/services/earphone.dart';

Uint8List b(List<int> v) => Uint8List.fromList(v);

void main() {
  group('에어팟 BLE 광고', () {
    test('배터리 · 충전 · 착용', () {
      final p = AppleBle.parse(
        b([
          0x07, 0x19, 0x01, 0x0E, 0x20, 0x2B, 0x87, 0x46, //
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]),
      )!;
      expect(p.left, 75);
      expect(p.right, 85);
      expect(p.caseLevel, 65);
      expect(p.caseCharging, isTrue);
      expect(p.leftCharging, isFalse);
      expect(p.wornCount, 2);
    });
    test('배터리 형식이 아니면 무시 (0x07 길이 0x11)', () {
      expect(AppleBle.parse(b([0x07, 0x11, ...List.filled(17, 1)])), isNull);
    });
    test('여러 메시지가 이어붙어 있어도 0x07만 꺼냄', () {
      final raw = b([
        0x10,
        0x02,
        0xAA,
        0xBB,
        0x07,
        0x19,
        0x01,
        0x0E,
        0x20,
        0x2B,
        0x87,
        0x46,
        ...List.filled(19, 0),
      ]);
      expect(AppleBle.parse(raw)!.left, 75);
    });
  });

  group('AACP', () {
    test('배터리', () {
      final u = Aacp.parse(
        b([
          4,
          0,
          4,
          0,
          4,
          0,
          3,
          0x04,
          1,
          90,
          2,
          1,
          0x02,
          1,
          80,
          1,
          1,
          0x08,
          1,
          50,
          4,
          1,
        ]),
      )!;
      expect(u.pods!.left, 90);
      expect(u.pods!.right, 80);
      expect(u.pods!.rightCharging, isTrue);
      expect(u.pods!.caseLevel, isNull);
    });
    test('착용', () {
      final u = Aacp.parse(b([4, 0, 4, 0, 6, 0, 0, 1]))!;
      expect(u.pods!.wornCount, 1);
    });
    test('청취 모드', () {
      expect(
        Aacp.parse(b([4, 0, 4, 0, 9, 0, 0x0D, 3, 0, 0, 0]))!.listenMode,
        ListenMode.transparency,
      );
      expect(
        Aacp.listenModePacket(ListenMode.anc),
        b([4, 0, 4, 0, 9, 0, 0x0D, 2, 0, 0, 0]),
      );
    });
    test('기기 정보', () {
      final info = Aacp.parse(
        b([
          4,
          0,
          4,
          0,
          0x1D,
          0,
          1,
          2,
          0,
          ...'Buds'.codeUnits,
          0,
          ...'A2084'.codeUnits,
          0,
          ...'Apple Inc.'.codeUnits,
          0,
          ...'SN1234'.codeUnits,
          0,
          ...'6A300'.codeUnits,
          0,
        ]),
      )!.info!;
      expect(info.name, 'Buds');
      expect(info.model, 'A2084');
      expect(info.firmware, '6A300');
    });
    test('이름 변경 패킷', () {
      expect(Aacp.renamePacket(''), isNull);
      expect(Aacp.renamePacket('a' * 40), isNull);
      expect(
        Aacp.renamePacket('Pods')!.sublist(0, 9),
        b([4, 0, 4, 0, 0x1A, 0, 1, 4, 0]),
      );
    });
  });

  group('이어폰 화면', () {
    late AppStore store;
    late EarphoneService ear;
    setUp(() async {
      store = await AppStore.open(MemoryStorage(), ParkCatalog([]));
      store.setNickname('라이언');
      ear = EarphoneService(demo: true);
      await ear.start();
      EarphoneService.instance = ear;
    });

    testWidgets('상태 화면: 배터리 · 청취 모드', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      await tester.pumpWidget(
        ParkGolfDiaryApp(store: store, home: const EarphoneScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('60% ⚡'), findsOneWidget);
      await tester.tap(find.text('노이즈 캔슬링'));
      await tester.pumpAndSettle();
      expect(ear.listenMode, ListenMode.anc);
    });

    testWidgets('라운드 중 착용 감지 · 배터리 부족', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final r = store.startRound(
        park: Park(
          id: 'p',
          name: '테스트',
          courses: [Course(name: 'A', pars: List.filled(9, 4))],
        ),
        courseIndexes: [0],
        companions: [],
      );
      await tester.pumpWidget(
        ParkGolfDiaryApp(
          store: store,
          home: ScoreInputScreen(roundId: r.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('L 80 · R 75'), findsOneWidget);

      ear.pods = const PodsStatus(
        left: 80,
        right: 75,
        leftInEar: false,
        rightInEar: false,
      );
      ear.notifyListeners();
      await tester.pump();
      expect(find.text('이어폰을 빼서 음성 입력을 멈췄어요'), findsOneWidget);

      ear.pods = const PodsStatus(left: 10, right: 15);
      ear.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('이어폰 배터리가 10% 남았어요'), findsOneWidget);
      await tester.tap(find.text('휴대폰 마이크로'));
      await tester.pumpAndSettle();
      expect(store.settings.earMic, isFalse);
    });
  });
}
