import '../models/models.dart';

enum PeriodFilter { all, thisMonth, thisYear }

/// 기록(통계 + 파크골프장별) 계산.
class Stats {
  Stats(List<Round> rounds)
      : rounds = rounds
            .where((r) => r.done && r.deletedAt == null && r.myEntered > 0)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

  final List<Round> rounds;

  int get count => rounds.length;

  double? _avg(Iterable<num> v) =>
      v.isEmpty ? null : v.fold<num>(0, (a, b) => a + b) / v.length;

  /// 모든 홀을 입력한 라운드 (평균 · 베스트 계산용).
  List<Round> get complete => rounds.where((r) => r.myComplete).toList();

  double? get avgTotal => _avg(complete.map((r) => r.myTotal));
  int? get best => complete.isEmpty
      ? null
      : complete.map((r) => r.myTotal).reduce((a, b) => a < b ? a : b);
  double? get avgOver => _avg(complete.map((r) => r.myOver));
  int? get bestOver => complete.isEmpty
      ? null
      : complete.map((r) => r.myOver).reduce((a, b) => a < b ? a : b);
  double? get avgPutts => _avg(complete.map((r) => r.myPutts));
  double? get avgPenalty => _avg(rounds.map((r) => r.myPenalty));
  int get birdies => rounds.fold(0, (a, r) => a + r.birdies);

  /// 최근 n 개월 월별 평균 타수 (오래된 달 → 최근 달).
  List<MonthAvg> monthly(DateTime now, {int months = 6}) {
    final out = <MonthAvg>[];
    for (var k = months - 1; k >= 0; k--) {
      final m = DateTime(now.year, now.month - k);
      final rs = complete.where(
          (r) => r.date.year == m.year && r.date.month == m.month);
      out.add(MonthAvg(m, _avg(rs.map((r) => r.myTotal)),
          _avg(rs.map((r) => r.myOver))));
    }
    return out;
  }

  List<Round> filter(PeriodFilter f, DateTime now) {
    switch (f) {
      case PeriodFilter.all:
        return rounds;
      case PeriodFilter.thisMonth:
        return rounds
            .where((r) => r.date.year == now.year && r.date.month == now.month)
            .toList();
      case PeriodFilter.thisYear:
        return rounds.where((r) => r.date.year == now.year).toList();
    }
  }

  /// 파크골프장별 묶음.
  List<ParkSummary> byPark(PeriodFilter f, DateTime now) {
    final map = <String, List<Round>>{};
    for (final r in filter(f, now)) {
      map.putIfAbsent(r.parkId, () => []).add(r);
    }
    return map.entries.map((e) => ParkSummary(e.key, e.value)).toList();
  }
}

class MonthAvg {
  MonthAvg(this.month, this.avgTotal, this.avgOver);
  final DateTime month;
  final double? avgTotal;
  final double? avgOver;
}

class ParkSummary {
  ParkSummary(this.parkId, List<Round> rounds)
      : rounds = (List.of(rounds)..sort((a, b) => b.date.compareTo(a.date)));

  final String parkId;
  final List<Round> rounds;

  String get parkName => rounds.first.parkName;
  int get count => rounds.length;
  Round get latest => rounds.first;
  List<Round> get complete => rounds.where((r) => r.myComplete).toList();

  double? get avgTotal => complete.isEmpty
      ? null
      : complete.fold<int>(0, (a, r) => a + r.myTotal) / complete.length;
  double? get avgOver => complete.isEmpty
      ? null
      : complete.fold<int>(0, (a, r) => a + r.myOver) / complete.length;
  Round? get bestRound => complete.isEmpty
      ? null
      : complete.reduce((a, b) => a.myTotal <= b.myTotal ? a : b);
}
