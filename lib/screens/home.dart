import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../logic/rules.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/library.dart';
import 'records/round_detail.dart';
import 'round/round_start.dart';
import 'score/score_input.dart';
import 'shell.dart';

/// S-10 홈
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return '좋은 밤이에요';
    if (h < 11) return '좋은 아침이에요';
    if (h < 17) return '좋은 오후예요';
    return '좋은 저녁이에요';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final recent = store.doneRounds.take(3).toList();
    final playing = store.inProgress;
    final disp = store.settings.scoreDisplay;

    return ListView(
      padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greeting(DateTime.now())}, ${store.nickname}님',
                    style: ts(context, 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text('파크골프다이어리', style: ts(context, 22, w: FontWeight.w700)),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'MY',
              child: GestureDetector(
                onTap: () => MainShell.of(context)?.go(2),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: c.surfaceSubtle,
                  child: Text(
                    store.nickname.isEmpty
                        ? ''
                        : store.nickname.characters.first,
                    style: ts(
                      context,
                      14,
                      w: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (playing != null) ...[
          BoxCard(
            selected: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScoreInputScreen(roundId: playing.id),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '진행 중인 라운드',
                        style: ts(context, 14, w: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '이어서 입력 ›',
                      style: ts(
                        context,
                        13,
                        w: FontWeight.w700,
                        color: c.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${md(playing.date)} ${playing.parkName} · '
                  '${playing.myEntered}/${playing.holeCount}홀 입력',
                  style: ts(context, 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: '라운드 시작',
          onPressed: () async {
            if (playing != null) {
              final ok = await confirmDialog(
                context,
                title: '진행 중인 라운드가 있어요',
                body: '${playing.parkName} 라운드를 저장하고 새 라운드를 시작할까요?',
                confirm: '저장하고 시작',
              );
              if (!ok || !context.mounted) return;
              store.finishRound(playing);
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoundStartScreen()),
            );
          },
        ),
        const SizedBox(height: 22),
        LabelSort(
          title: '최근 라운드',
          count: store.doneRounds.length,
          unit: '회',
          sortText: '전체',
          onSort: () => MainShell.of(context)?.go(1),
        ),
        if (recent.isEmpty)
          BoxCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Center(
              child: Text(
                '아직 라운드 기록이 없어요.\n라운드를 시작해 첫 스코어를 남겨 보세요.',
                textAlign: TextAlign.center,
                style: ts(context, 13, color: c.textSecondary, height: 1.5),
              ),
            ),
          )
        else
          for (final r in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoundListItem(
                date: mdw(r.date),
                title: r.parkName,
                score: formatRoundScore(r, disp),
                people: r.companions.length + 1,
                holes: r.holeCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoundDetailScreen(roundId: r.id),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
