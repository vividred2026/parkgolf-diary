import '../models/models.dart';
import 'rules.dart';

/// 음성 명령 해석.
///
/// 지원하는 말:
/// - "그린까지 3, 퍼트 2"
/// - "5타, 퍼트 2"      → 그린까지 = 5 − 2
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
    Map<int, int>? others,
    this.command,
  }) : others = others ?? {};

  final String heard;
  final int? toGreen;
  final int? putts;
  final int? total;
  final int penaltyCount;
  final bool mentionedGreen;
  final bool mentionedPutts;

  /// 동반자 순서 → 총 타수.
  final Map<int, int> others;
  final VoiceCommand? command;

  bool get aboutMe =>
      toGreen != null ||
      putts != null ||
      total != null ||
      penaltyCount > 0 ||
      mentionedGreen ||
      mentionedPutts;

  bool get isEmpty => !aboutMe && others.isEmpty && command == null;
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
  };

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

    // 동반자 (이름이 숫자 단어를 포함할 수 있어 먼저 처리)
    final others = <int, int>{};
    for (var k = 0; k < companions.length; k++) {
      final name = RegExp.escape(companions[k].toLowerCase());
      final v = take(RegExp('$name\\s*(?:은|는|이|가)?\\s*$_num$_end'));
      if (v != null) others[k] = v;
    }

    final mentionedGreen = t.contains('그린');
    final toGreen = take(RegExp('그린\\s*(?:까지)?\\s*(?:은|는)?\\s*$_num$_end'));
    final mentionedPutts = RegExp('퍼트|퍼팅|퍼터|버트').hasMatch(t);
    final putts = take(RegExp('(?:퍼트|퍼팅|퍼터|버트)\\s*(?:는|은)?\\s*$_num$_end'));
    var total = take(RegExp('(?:^|\\s)(?:나|내|저|제)\\s*(?:는)?\\s*$_num$_end'));
    total ??= take(RegExp('(?:^|\\s)$_num\\s*타(?=\\s|\$|,)'));

    return VoiceParse(
      heard: raw.trim(),
      toGreen: toGreen,
      putts: putts,
      total: total,
      penaltyCount: penaltyCount,
      mentionedGreen: mentionedGreen,
      mentionedPutts: mentionedPutts,
      others: others,
      command: command,
    );
  }

  /// 현재 홀 기록에 해석 결과를 적용해 볼 때의 결과.
  /// [forced] 는 되묻기에서 사용자가 고른 값.
  static VoiceOutcome resolve(
    VoiceParse p,
    HoleScore? current, {
    AskField? forcedField,
    int? forcedValue,
  }) {
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
        askReason: '그린까지 숫자가 확실하지 않아요',
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
        askReason: '그린까지 몇 타였는지 알려 주세요',
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
