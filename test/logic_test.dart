import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkgolf_diary/data/app_store.dart';
import 'package:parkgolf_diary/data/backup.dart';
import 'package:parkgolf_diary/data/park_catalog.dart';
import 'package:parkgolf_diary/data/storage.dart';
import 'package:parkgolf_diary/logic/rules.dart';
import 'package:parkgolf_diary/logic/stats.dart';
import 'package:parkgolf_diary/logic/voice_parser.dart';
import 'package:parkgolf_diary/models/models.dart';

Park samplePark() => Park(id: 'p1', name: '테스트 파크골프장', courses: [
      Course(name: '아웃코스', pars: [3, 4, 5, 4, 3, 5, 4, 3, 5]),
      Course(name: '인코스', pars: [4, 3, 5, 3, 4, 5, 3, 4, 5]),
    ]);

void main() {
  group('규정 3-3-3', () {
    test('Par 3·4·5 가 3개씩이면 맞음', () {
      expect(Rules.matches333([3, 4, 5, 4, 3, 5, 4, 3, 5]), isTrue);
      expect(Rules.matches333([3, 3, 3, 3, 4, 4, 5, 5, 5]), isFalse);
      expect(Rules.matches333([3, 4, 5, 4, 3, 5, 4, 3, null]), isFalse);
    });
    test('파 대비 이름', () {
      expect(Rules.termFor(5, 4), '보기');
      expect(Rules.termFor(3, 4), '버디');
      expect(Rules.termFor(1, 3), '홀인원');
      expect(Rules.termFor(9, 4), '+5');
    });
  });

  group('음성 해석', () {
    const comps = ['어피치', '무지', '프로도'];

    test('그린까지 · 퍼트 · 동반자', () {
      final p = VoiceParser.parse('그린까지 3, 퍼트 2, 어피치 4', comps);
      expect(p.toGreen, 3);
      expect(p.putts, 2);
      expect(p.others, {0: 4});
      final o = VoiceParser.resolve(p, null);
      expect(o.mine, const HoleScore(toGreen: 3, putts: 2));
    });

    test('한글 숫자', () {
      final p = VoiceParser.parse('그린까지 삼 퍼트 이 무지 다섯', comps);
      expect(p.toGreen, 3);
      expect(p.putts, 2);
      expect(p.others, {1: 5});
    });

    test('N타 퍼트 M → 그린까지 = N − M', () {
      final o = VoiceParser.resolve(VoiceParser.parse('5타 퍼트 2', comps), null);
      expect(o.mine, const HoleScore(toGreen: 3, putts: 2));
    });

    test('총 타수만 말하면 퍼트를 되물어요', () {
      final p = VoiceParser.parse('다섯 타', comps);
      final o = VoiceParser.resolve(p, null);
      expect(o.ask, AskField.putts);
      final o2 = VoiceParser.resolve(p, null,
          forcedField: AskField.putts, forcedValue: 2);
      expect(o2.mine, const HoleScore(toGreen: 3, putts: 2));
    });

    test('퍼트 숫자가 없으면 되묻기', () {
      final o =
          VoiceParser.resolve(VoiceParser.parse('그린까지 3 퍼트', comps), null);
      expect(o.ask, AskField.putts);
    });

    test('벌타만 말하면 +2', () {
      final o = VoiceParser.resolve(VoiceParser.parse('OB', comps),
          const HoleScore(toGreen: 2, putts: 2));
      expect(o.mine, const HoleScore(toGreen: 4, putts: 2, penalty: 2));
    });

    test('그린까지와 벌타를 함께 말하면 벌타는 포함된 것으로', () {
      final o = VoiceParser.resolve(
          VoiceParser.parse('그린까지 5 벌타 퍼트 2', comps), null);
      expect(o.mine, const HoleScore(toGreen: 5, putts: 2, penalty: 2));
    });

    test('명령', () {
      expect(VoiceParser.parse('다음 홀', comps).command, VoiceCommand.nextHole);
      expect(VoiceParser.parse('이전홀', comps).command, VoiceCommand.prevHole);
      expect(VoiceParser.parse('취소', comps).command, VoiceCommand.undo);
    });

    test('동반자만', () {
      final p = VoiceParser.parse('어피치 4 무지 이', comps);
      expect(p.aboutMe, isFalse);
      expect(p.others, {0: 4, 1: 2});
    });

    test('못 알아들음', () {
      expect(VoiceParser.parse('음 잘 모르겠네', comps).isEmpty, isTrue);
    });
  });

  group('저장 · 통계 · 백업', () {
    late AppStore store;
    setUp(() async {
      store = await AppStore.open(MemoryStorage(), ParkCatalog([]));
      store.setNickname('라이언');
    });

    Round play(DateTime date, int base) {
      final r = store.startRound(
          park: samplePark(),
          courseIndexes: [0, 1],
          companions: ['어피치'],
          date: date);
      for (var i = 0; i < 18; i++) {
        store.setMine(r, i, HoleScore(toGreen: base, putts: 2));
        store.setOther(r, 0, i, 4);
      }
      store.finishRound(r);
      return r;
    }

    test('라운드 합계 · 통계', () {
      final r = play(DateTime(2026, 10, 18), 3);
      play(DateTime(2026, 10, 11), 2);
      expect(r.parTotal, 72);
      expect(r.myTotal, 90);
      expect(r.myOver, 18);
      final s = Stats(store.liveRounds);
      expect(s.count, 2);
      expect(s.best, 72);
      expect(s.avgTotal, 81);
      expect(s.byPark(PeriodFilter.all, DateTime(2026, 11)).single.count, 2);
    });

    test('삭제 → 30일 뒤 사라짐', () async {
      final r = play(DateTime(2026, 9, 1), 3);
      store.deleteRound(r, now: DateTime(2026, 10, 1));
      expect(store.trash.length, 1);
      expect(store.liveRounds, isEmpty);
      await store.purgeTrash(DateTime(2026, 10, 20));
      expect(store.trash.length, 1);
      await store.purgeTrash(DateTime(2026, 11, 1));
      expect(store.trash, isEmpty);
    });

    test('백업 만들기 → 복원', () async {
      final r = play(DateTime(2026, 10, 18), 3);
      await store.addPhoto(r, Uint8List.fromList([1, 2, 3]), 'jpg');
      final zip = await Backup.build(store.data, store.storage, DateTime(2026, 10, 19));
      final content = Backup.read(zip);
      expect(content.roundCount, 1);
      expect(content.photos.length, 1);
      final other = await AppStore.open(MemoryStorage(), ParkCatalog([]));
      await other.replaceAll(content.data, content.photos);
      expect(other.nickname, '라이언');
      expect(other.doneRounds.single.myTotal, 90);
      expect(await other.storage.readPhoto(r.photos.single), [1, 2, 3]);
    });

    test('백업이 아닌 파일은 거절', () {
      expect(() => Backup.read(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });
}
