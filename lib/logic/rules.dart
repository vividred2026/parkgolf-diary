import '../models/models.dart';

/// (사)한국프로파크골프협회 규정집 기준 상수와 계산.
/// - 18홀 Par 72, 3-3-3 방식 (9홀마다 Par 3·4·5 가 3개씩, 9홀 Par 36)
/// - 벌타 2타 (OB · 분실구 · 언플레이어블)
/// - 헛스윙은 타수에 넣지 않음 (제26조)
class Rules {
  static const penaltyStrokes = 2;
  static const parsPerCourse = 9;
  static const standardCourseCount = {3: 3, 4: 3, 5: 3};
  static const standardCoursePar = 36;
  static const maxPlayers = 4; // 나 포함 1조

  /// 9홀 코스의 파별 개수.
  static Map<int, int> parCounts(List<int?> pars) {
    final m = {3: 0, 4: 0, 5: 0};
    for (final p in pars) {
      if (p != null) m[p] = (m[p] ?? 0) + 1;
    }
    return m;
  }

  /// 3-3-3 규정과 맞는지.
  static bool matches333(List<int?> pars) {
    if (pars.any((p) => p == null)) return false;
    final m = parCounts(pars);
    return m[3] == 3 && m[4] == 3 && m[5] == 3;
  }

  /// 파 대비 이름.
  static String termFor(int strokes, int par) {
    if (strokes == 1) return '홀인원';
    final d = strokes - par;
    switch (d) {
      case -3:
        return '알바트로스';
      case -2:
        return '이글';
      case -1:
        return '버디';
      case 0:
        return '파';
      case 1:
        return '보기';
      case 2:
        return '더블보기';
      case 3:
        return '트리플보기';
    }
    return d > 0 ? '+$d' : '$d';
  }
}

String signed(int v) => v > 0 ? '+$v' : (v == 0 ? 'E' : '$v');

/// 설정(오버타수 / 총타수)에 맞춘 라운드 스코어 글자.
String formatRoundScore(Round r, ScoreDisplay d) {
  if (r.myEntered == 0) return '–';
  return d == ScoreDisplay.overPar ? signed(r.myOver) : '${r.myTotal}';
}

String formatRoundScoreWithUnit(Round r, ScoreDisplay d) {
  if (r.myEntered == 0) return '–';
  return d == ScoreDisplay.overPar ? signed(r.myOver) : '${r.myTotal}타';
}
