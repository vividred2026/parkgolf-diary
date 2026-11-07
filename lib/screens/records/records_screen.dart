import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/library.dart';
import 'park_detail.dart';

String fmt1(double? v) => v == null
    ? '–'
    : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

String fmtSigned1(double? v) {
  if (v == null) return '–';
  final s = fmt1(v.abs());
  return v > 0 ? '+$s' : (v < 0 ? '-$s' : 'E');
}

/// S-30 기록 (통계 + 파크골프장별)
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

enum _Sort { recent, count, name }

class _RecordsScreenState extends State<RecordsScreen> {
  PeriodFilter period = PeriodFilter.all;
  _Sort sort = _Sort.recent;
  int months = 6;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final now = DateTime.now();
    final s = Stats(store.liveRounds);
    final over = store.settings.scoreDisplay == ScoreDisplay.overPar;
    final parks = s.byPark(period, now);
    switch (sort) {
      case _Sort.recent:
        parks.sort((a, b) => b.latest.date.compareTo(a.latest.date));
      case _Sort.count:
        parks.sort((a, b) => b.count.compareTo(a.count));
      case _Sort.name:
        parks.sort((a, b) => a.parkName.compareTo(b.parkName));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
      children: [
        Text('기록', style: ts(context, 24, w: FontWeight.w700)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: [
            _StatTile(value: '${s.count}', unit: '회', label: '라운드'),
            over
                ? _StatTile(value: fmtSigned1(s.avgOver), label: '평균')
                : _StatTile(value: fmt1(s.avgTotal), unit: '타', label: '평균'),
            over
                ? _StatTile(
                    value: s.bestOver == null ? '–' : signed(s.bestOver!),
                    label: '베스트',
                  )
                : _StatTile(
                    value: s.best?.toString() ?? '–',
                    unit: '타',
                    label: '베스트',
                  ),
            _StatTile(value: fmt1(s.avgPutts), unit: '타', label: '평균 퍼트'),
            _StatTile(value: fmt1(s.avgPenalty), unit: '타', label: '평균 벌타'),
            _StatTile(value: '${s.birdies}', unit: '개', label: '버디'),
          ],
        ),
        const SizedBox(height: 14),
        BoxCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '월별 평균 추이',
                      style: ts(context, 13, w: FontWeight.w700),
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: '기간',
                    initialValue: months,
                    onSelected: (v) => setState(() => months = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 6, child: Text('최근 6개월')),
                      PopupMenuItem(value: 12, child: Text('최근 12개월')),
                    ],
                    child: IgnorePointer(
                      child: SortChip(label: '최근 $months개월', onTap: () {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MonthBars(
                months: s.monthly(now, months: months),
                over: over,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LabelContents(title: '파크골프장별 기록', count: parks.length, unit: '곳'),
        Row(
          children: [
            Pill(
              label: '전체',
              selected: period == PeriodFilter.all,
              onTap: () => setState(() => period = PeriodFilter.all),
            ),
            const SizedBox(width: 6),
            Pill(
              label: '이번 달',
              selected: period == PeriodFilter.thisMonth,
              onTap: () => setState(() => period = PeriodFilter.thisMonth),
            ),
            const SizedBox(width: 6),
            Pill(
              label: '올해',
              selected: period == PeriodFilter.thisYear,
              onTap: () => setState(() => period = PeriodFilter.thisYear),
            ),
            const Spacer(),
            PopupMenuButton<_Sort>(
              tooltip: '정렬',
              initialValue: sort,
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Sort.recent, child: Text('최근순')),
                PopupMenuItem(value: _Sort.count, child: Text('라운드순')),
                PopupMenuItem(value: _Sort.name, child: Text('이름순')),
              ],
              child: IgnorePointer(
                child: SortChip(
                  label: const {
                    _Sort.recent: '최근순',
                    _Sort.count: '라운드순',
                    _Sort.name: '이름순',
                  }[sort]!,
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (parks.isEmpty)
          BoxCard(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                '이 기간에 저장한 라운드가 없어요',
                style: ts(context, 13, color: c.textSecondary),
              ),
            ),
          )
        else
          RowGroup(
            children: [
              for (final p in parks)
                ListRow(
                  title: p.parkName,
                  subtitle: [
                    '${p.count}회',
                    if (p.avgTotal != null)
                      over
                          ? '평균 ${fmtSigned1(p.avgOver)}'
                          : '평균 ${fmt1(p.avgTotal)}',
                    if (p.bestRound != null)
                      over
                          ? '베스트 ${signed(p.bestRound!.myOver)}'
                          : '베스트 ${p.bestRound!.myTotal}',
                  ].join(' · '),
                  trailing: formatRoundScore(
                    p.latest,
                    store.settings.scoreDisplay,
                  ),
                  trailingColor: c.textPrimary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParkDetailScreen(parkId: p.parkId),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, this.unit, required this.label});

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: ts(context, 18, w: FontWeight.w700),
                ),
                if (unit != null && value != '–')
                  TextSpan(text: unit, style: ts(context, 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: ts(context, 13, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.months, required this.over});

  final List<MonthAvg> months;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final vals = months.map((m) => m.avgTotal).whereType<double>().toList();
    final lo = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a < b ? a : b);
    final hi = vals.isEmpty ? 1.0 : vals.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < months.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (months[i].avgTotal != null)
                    Text(
                      over
                          ? fmtSigned1(months[i].avgOver)
                          : fmt1(months[i].avgTotal),
                      style: ts(context, 10, color: c.textSecondary),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    width: months.length > 6 ? 14 : 22,
                    height: months[i].avgTotal == null
                        ? 4
                        : 14 +
                              (hi == lo
                                  ? 30
                                  : 40 *
                                        (months[i].avgTotal! - lo) /
                                        (hi - lo)),
                    decoration: BoxDecoration(
                      color: i == months.length - 1
                          ? c.brandPrimary
                          : c.surfaceSelected,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${months[i].month.month}월',
                    style: ts(context, 11, color: c.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
