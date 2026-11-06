import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'round_detail.dart';
import 'scorecard.dart';

/// S-31 라운드 완료 · 저장
class RoundCompleteScreen extends StatelessWidget {
  const RoundCompleteScreen({super.key, required this.roundId});

  final String roundId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final r = store.roundById(roundId);
    if (r == null) return const Scaffold();
    final c = context.c;
    final park = Stats(store.liveRounds)
        .byPark(PeriodFilter.all, DateTime.now())
        .where((p) => p.parkId == r.parkId)
        .firstOrNull;
    final big = store.settings.scoreDisplay == ScoreDisplay.total
        ? '${r.myTotal}'
        : signed(r.myOver);

    return Scaffold(
      appBar: const TopBar(title: '라운드 완료'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
        children: [
          BoxCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.circle, size: 8, color: c.brandPrimary),
                const SizedBox(width: 6),
                Text('휴대폰에 저장했어요',
                    style: ts(context, 12, color: c.brandPrimary)),
              ]),
              const SizedBox(height: 4),
              Text('${r.parkName} · ${r.date.month}월 ${r.date.day}일',
                  style: ts(context, 13, color: c.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Text(big, style: ts(context, 44, w: FontWeight.w800, height: 1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            store.settings.scoreDisplay == ScoreDisplay.total
                                ? roundSummary(r, store.nickname)
                                : '${r.myTotal}타 · 퍼트 ${r.myPutts}${r.myPenalty > 0 ? ' · 벌타 ${r.myPenalty}' : ''}',
                            style: ts(context, 14, w: FontWeight.w700)),
                        if (park != null && park.count > 1)
                          Text(
                              '이 파크골프장 베스트 ${park.bestRound?.myTotal ?? '–'} · '
                              '평균 ${park.avgTotal?.toStringAsFixed(1) ?? '–'}',
                              style:
                                  ts(context, 12, color: c.textSecondary)),
                      ]),
                ),
              ]),
            ]),
          ),
          if (!r.myComplete) ...[
            const SizedBox(height: 12),
            InfoBox(
                warning: true,
                title: '${r.holeCount - r.myEntered}홀이 비어 있어요',
                body: '평균 · 베스트 통계에는 18홀(모든 홀)을 입력한 라운드만 들어가요.'),
          ],
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(
            label: '라운드 상세 보기',
            onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => RoundDetailScreen(roundId: r.id))),
          ),
          TextButton(
            onPressed: () => ScorecardShareSheet.open(context, r),
            child: Text('스코어카드 이미지 공유',
                style: ts(context, 13,
                    w: FontWeight.w700, color: c.textSecondary)),
          ),
        ]),
      ),
    );
  }
}
