import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// S-60-2 타수 표시 (오버타수 / 총타수)
class ScoreDisplayScreen extends StatelessWidget {
  const ScoreDisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final cur = store.settings.scoreDisplay;
    final sample = store.doneRounds.where((r) => r.myComplete).firstOrNull;
    final name = sample?.parkName ?? '한강 둔치 파크골프장';
    final total = sample?.myTotal ?? 89;
    final over = sample?.myOver ?? 17;

    Widget option(ScoreDisplay d, String title, String sub) => InkWell(
      onTap: () => store.setScoreDisplay(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            RadioDot(selected: cur == d),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(context, 15, w: FontWeight.w700)),
                Text(sub, style: ts(context, 12, color: c.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );

    final o = over > 0 ? '+$over' : '$over';
    return Scaffold(
      appBar: const TopBar(title: '타수 표시'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          8,
          gutter,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '라운드 기록과 통계에서 스코어를 어떻게 보여 줄지 골라요.',
            style: ts(context, 13, color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          RowGroup(
            children: [
              option(ScoreDisplay.overPar, '오버타수', '$o · 파 기준 위아래'),
              option(ScoreDisplay.total, '총타수', '$total타'),
            ],
          ),
          const SizedBox(height: 20),
          Text('미리보기', style: ts(context, 12, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '$name   ${cur == ScoreDisplay.overPar ? o : '$total타'}',
            style: ts(context, 16, w: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
