import '../models/models.dart';
import 'rules.dart';

/// 음성 명령 해석.
///
/// 지원하는 말 (골프에서 실제로 쓰는 표현):
/// - "쓰리온 투퍼트" / "3온 2퍼트" / "쓰리온 투펏" / "three on two putt"
/// - "그린까지 3, 퍼트 2"
/// - "5타, 2퍼트"       → 그린까지 = 5 − 2
/// - "보기 투퍼트" / "파" / "버디" → 파 대비 타수 (퍼트를 모르면 되물어요)
/// - "홀인원" → 1온 0퍼트, "칩인" / "노퍼트" → 0퍼트
/// - "벌타" / "OB" / "오비" / "분실구" / "언플레이어블" → 벌타 +2
/// - "어피치 4"          → 동반자 총 타수
/// - "나 5" / "내 5"     → 내 총 타수 (퍼트를 되물어요)
/// - "다음 홀" / "이전 홀" / "취소"
enum VoiceCommand { nextHole, prevHole, undo }

class VoiceParse {
  VoiceParse({
    required this.heard,
    this.toGreen,
    this.putts,
    this.total,
    this.penaltyCount = 0,
    this.mentionedGreen = false,
    this.mentionedPutts = false,
    this.overPar,
    Map<int, int>? others,
    Map<int, int>? othersOverPar,
    this.command,
  }) : others = others ?? {},
       othersOverPar = othersOverPar ?? {};

  final String heard;
  final int? toGreen;
  final int? putts;
  final int? total;
  final int penaltyCount;
  final bool mentionedGreen;
  final bool mentionedPutts;

  /// "파" · "보기" · "버디" 처럼 파 대비로 말한 타수.
  final int? overPar;

  /// 동반자 순서 → 총 타수.
  final Map<int, int> others;

  /// 동반자 순서 → 파 대비 ("어피치 보기").
  final Map<int, int> othersOverPar;
  final VoiceCommand? command;

  bool get aboutMe =>
      toGreen != null ||
      putts != null ||
      total != null ||
      overPar != null ||
      penaltyCount > 0 ||
      mentionedGreen ||
      mentionedPutts;

  bool get isEmpty =>
      !aboutMe && others.isEmpty && othersOverPar.isEmpty && command == null;
}

/// 확인이 더 필요한 항목.
enum AskField { toGreen, putts }

class VoiceOutcome {
  VoiceOutcome({this.mine, required this.others, this.ask, this.askReason});

  /// 반영할 내 기록 (null 이면 내 기록은 그대로).
  final HoleScore? mine;
  final Map<int, int> others;
  final AskField? ask;
  final String? askReason;

  bool get needsAsk => ask != null;
}

class VoiceParser {
  static const _numWords = <String, int>{
    '열': 10,
    '십': 10,
    '하나': 1,
    '한': 1,
    '둘': 2,
    '두': 2,
    '셋': 3,
    '세': 3,
    '삼': 3,
    '넷': 4,
    '네': 4,
    '사': 4,
    '다섯': 5,
    '오': 5,
    '여섯': 6,
    '육': 6,
    '일곱': 7,
    '칠': 7,
    '여덟': 8,
    '팔': 8,
    '아홉': 9,
    '구': 9,
    '일': 1,
    '이': 2,
    '영': 0,
    '공': 0,
    // 골프장에서 많이 쓰는 영어 숫자 (쓰리온 · 투퍼트)
    '원': 1,
    '투': 2,
    '쓰리': 3,
    '스리': 3,
    '뜨리': 3,
    '포': 4,
    '파이브': 5,
    '식스': 6,
    '세븐': 7,
    '에잇': 8,
    '나인': 9,
    '텐': 10,
    'one': 1,
    'two': 2,
    'to': 2,
    'too': 2,
    'three': 3,
    'tree': 3,
    'four': 4,
    'for': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
  };

  /// 파 대비 이름 → 타수 차이.
  static const _terms = <String, int>{
    '알바트로스': -3,
    '이글': -2,
    '버디': -1,
    '파세이브': 0,
    '파': 0,
    '보기': 1,
    '더블보기': 2,
    '더블': 2,
    '트리플보기': 3,
    '트리플': 3,
    'birdie': -1,
    'eagle': -2,
    'par': 0,
    'bogey': 1,
    'double': 2,
    'triple': 3,
  };
  static final String _term =
      '(${(_terms.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|')})';
  static const _termEnd = r'(?=\s|$|,|투|원|쓰리|\d)';
  static const _puttWord = r'(?:퍼트|퍼팅|펏트|펏|퍼터|버트|퍼드|putts|putt|put)';

  static final String _num =
      '(\\d{1,2}|${(_numWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|')})';
  static const _end = r'(?=\s|$|타|개|번|,)';

  static int? _toInt(String s) => int.tryParse(s) ?? _numWords[s];

  static VoiceParse parse(String raw, List<String> companions) {
    var t = ' ${raw.toLowerCase()} '
        .replaceAll(RegExp(r'[.!?~·]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // 명령
    VoiceCommand? command;
    if (RegExp(r'다음\s*홀').hasMatch(t)) {
      command = VoiceCommand.nextHole;
    } else if (RegExp(r'(이전|앞)\s*홀').hasMatch(t)) {
      command = VoiceCommand.prevHole;
    } else if (RegExp(r'취소|되돌려').hasMatch(t)) {
      command = VoiceCommand.undo;
    }
    t = t.replaceAll(RegExp(r'(다음|이전|앞)\s*홀|취소|되돌려'), ' ');

    // 벌타
    t = t
        .replaceAll(RegExp(r'오비|o\s*b|아웃\s*오브\s*바운즈'), ' 벌타 ')
        .replaceAll(RegExp(r'분실구|언플레이어블|언플레이어블볼'), ' 벌타 ');
    final penaltyCount = RegExp('벌타').allMatches(t).length;
    t = t.replaceAll('벌타', ' ');

    int? take(RegExp re) {
      final m = re.firstMatch(t);
      if (m == null) return null;
      final v = _toInt(m.group(1)!);
      t = t.replaceRange(m.start, m.end, ' ');
      return v;
    }

    int? termOf(String s) => _terms[s.replaceAll(' ', '')];

    // 홀인원 · 칩인 (숫자 '원'보다 먼저)
    int? toGreen, putts;
    if (RegExp(r'홀\s*인\s*원|hole\s*in\s*one|에이스').hasMatch(t)) {
      toGreen = 1;
      putts = 0;
      t = t.replaceAll(RegExp(r'홀\s*인\s*원|hole\s*in\s*one|에이스'), ' ');
    }
    if (RegExp(r'칩\s*인|노\s*퍼트|노\s*펏|노\s*퍼팅|chip\s*in').hasMatch(t)) {
      putts = 0;
      t = t.replaceAll(RegExp(r'칩\s*인|노\s*퍼트|노\s*펏|노\s*퍼팅|chip\s*in'), ' ');
    }

    // 동반자 (이름이 숫자 단어를 포함할 수 있어 먼저 처리)
    final others = <int, int>{};
    final othersOverPar = <int, int>{};
    for (var k = 0; k < companions.length; k++) {
      final name = RegExp.escape(companions[k].toLowerCase());
      final v = take(RegExp('$name\\s*(?:은|는|이|가)?\\s*$_num\\s*타?$_end'));
      if (v != null) {
        others[k] = v;
        continue;
      }
      final m = RegExp('$name\\s*(?:은|는|이|가)?\\s*$_term$_termEnd')
          .firstMatch(t);
      if (m != null) {
        othersOverPar[k] = termOf(m.group(1)!)!;
        t = t.replaceRange(m.start, m.end, ' ');
      }
    }

    // 1) "그린까지 3" · "퍼트 2" 처럼 단어 뒤에 숫자 (뒤에 온 · 퍼트 · 타가 오면 다음 말의 숫자예요)
    final notNext = '(?!\\s*(?:온|on\\b|타|$_puttWord))';
    final mentionedGreen = t.contains('그린');
    toGreen ??= take(
      RegExp('그린\\s*(?:까지)?\\s*(?:은|는)?\\s*$_num(?!\\s*(?:온|on\\b))$_end'),
    );
    putts ??= take(RegExp('$_puttWord\\s*(?:는|은)?\\s*$_num$notNext$_end'));
    // 2) "쓰리온" · "3온" · "3 on"
    toGreen ??= take(RegExp('$_num\\s*(?:온|on\\b)'));
    // 3) "투퍼트" · "2퍼트" · "투펏" · "two putt"
    putts ??= take(RegExp('$_num\\s*$_puttWord'));
    final mentionedPutts = RegExp(_puttWord).hasMatch(t);
    var total = take(RegExp('(?:^|\\s)(?:나|내|저|제)\\s*(?:는)?\\s*$_num$_end'));
    total ??= take(RegExp('(?:^|\\s)$_num\\s*타(?=\\s|\$|,)'));

    // "보기" · "파" · "버디"
    int? overPar;
    final tm = RegExp('(?:^|\\s)$_term$_termEnd').firstMatch(t);
    if (tm != null) {
      overPar = termOf(tm.group(1)!);
      t = t.replaceRange(tm.start, tm.end, ' ');
    }

    return VoiceParse(
      heard: raw.trim(),
      toGreen: toGreen,
      putts: putts,
      total: total,
      penaltyCount: penaltyCount,
      mentionedGreen: mentionedGreen && toGreen == null,
      mentionedPutts: mentionedPutts && putts == null,
      overPar: overPar,
      others: others,
      othersOverPar: othersOverPar,
      command: command,
    );
  }

  /// 현재 홀 기록에 해석 결과를 적용해 볼 때의 결과.
  /// [forced] 는 되묻기에서 사용자가 고른 값.
  static VoiceOutcome resolve(
    VoiceParse p,
    HoleScore? current, {
    int? par,
    AskField? forcedField,
    int? forcedValue,
  }) {
    final others = {
      ...p.others,
      if (par != null)
        for (final e in p.othersOverPar.entries)
          e.key: (par + e.value).clamp(1, 30),
    };
    p = VoiceParse(
      heard: p.heard,
      toGreen: p.toGreen,
      putts: p.putts,
      total:
          p.total ??
          (par != null && p.overPar != null ? par + p.overPar! : null),
      penaltyCount: p.penaltyCount,
      mentionedGreen: p.mentionedGreen,
      mentionedPutts: p.mentionedPutts,
      overPar: p.overPar,
      others: others,
      command: p.command,
    );
    if (!p.aboutMe) return VoiceOutcome(others: p.others);

    int? putts = p.putts;
    int? toGreen = p.toGreen;
    if (forcedField == AskField.putts) putts = forcedValue;
    if (forcedField == AskField.toGreen) toGreen = forcedValue;

    final penalty = p.penaltyCount * Rules.penaltyStrokes;
    var newPenalty = current?.penalty ?? 0;

    if (toGreen == null && p.total != null) {
      if (putts == null) {
        return VoiceOutcome(
          others: p.others,
          ask: AskField.putts,
          askReason: '총 ${p.total}타 중 퍼트 수를 알려 주세요',
        );
      }
      toGreen = p.total! - putts;
      if (toGreen < 1) {
        return VoiceOutcome(
          others: p.others,
          ask: AskField.putts,
          askReason: '총 ${p.total}타보다 퍼트가 많아요',
        );
      }
    }

    if (toGreen != null || p.total != null) {
      // 말한 그린까지 타수에 벌타가 이미 포함돼 있어요.
      if (p.penaltyCount > 0) newPenalty = penalty;
    } else if (p.penaltyCount > 0) {
      toGreen = (current?.toGreen ?? 0) + penalty;
      newPenalty += penalty;
    }

    if (p.mentionedGreen && toGreen == null) {
      return VoiceOutcome(
        others: p.others,
        ask: AskField.toGreen,
        askReason: '몇 온인지 확실하지 않아요',
      );
    }
    if (p.mentionedPutts && putts == null) {
      return VoiceOutcome(
        others: p.others,
        ask: AskField.putts,
        askReason: '퍼트 숫자가 확실하지 않아요',
      );
    }

    toGreen ??= current?.toGreen;
    putts ??= current?.putts;
    if (toGreen == null) {
      return VoiceOutcome(
        others: p.others,
        ask: AskField.toGreen,
        askReason: '몇 온이었는지 알려 주세요',
      );
    }
    if (putts == null) {
      return VoiceOutcome(
        others: p.others,
        ask: AskField.putts,
        askReason: '퍼트 수를 알려 주세요',
      );
    }
    if (toGreen < 1) toGreen = 1;
    if (newPenalty > toGreen) newPenalty = toGreen;
    return VoiceOutcome(
      mine: HoleScore(toGreen: toGreen, putts: putts, penalty: newPenalty),
      others: p.others,
    );
  }
}
