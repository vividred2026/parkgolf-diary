import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../score/score_input.dart';
import 'diary.dart';
import 'scorecard.dart';

/// S-33 라운드 상세 (1화면)
class RoundDetailScreen extends StatefulWidget {
  const RoundDetailScreen({super.key, required this.roundId});

  final String roundId;

  @override
  State<RoundDetailScreen> createState() => _RoundDetailScreenState();
}

class _RoundDetailScreenState extends State<RoundDetailScreen> {
  int tab = 0;

  Future<void> _delete(Round r) async {
    final ok = await confirmDialog(context,
        title: '이 라운드를 삭제할까요?',
        body: '삭제한 라운드는 30일 동안 MY › 삭제된 라운드에서 복구할 수 있어요.',
        confirm: '삭제',
        danger: true);
    if (!ok || !mounted) return;
    context.read<AppStore>().deleteRound(r);
    Navigator.pop(context);
    toast(context, '라운드를 삭제했어요 · 30일 안에 복구할 수 있어요');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final r = store.roundById(widget.roundId);
    if (r == null || r.deletedAt != null) {
      return const Scaffold(body: SizedBox());
    }
    final c = context.c;
    final disp = store.settings.scoreDisplay;
    final board = Board.of(r, store.nickname);

    return Scaffold(
      appBar: TopBar(
        title: '${md(r.date)} · ${r.parkName}',
        actions: [
          IconButton(
            tooltip: '스코어카드 이미지 공유',
            onPressed: () => ScorecardShareSheet.open(context, r),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '더 보기',
            onSelected: (v) {
              if (v == 'edit') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ScoreInputScreen(roundId: r.id)));
              } else {
                _delete(r);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('스코어 고치기')),
              PopupMenuItem(value: 'delete', child: Text('라운드 삭제')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        children: [
          BoxCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text(formatRoundScore(r, disp),
                  style: ts(context, 40, w: FontWeight.w800, height: 1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      [
                        if (disp == ScoreDisplay.total) signed(r.myOver) else '${r.myTotal}타',
                        '퍼트 ${r.myPutts}',
                        if (r.myPenalty > 0) '벌타 ${r.myPenalty}',
                      ].join(' · '),
                      style: ts(context, 14, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      '${r.courseRoute}${r.companions.isEmpty ? '' : ' · 동반 ${r.companions.length}명'}'
                      '${r.myComplete ? '' : ' · ${r.myEntered}/${r.holeCount}홀'}',
                      style: ts(context, 12, color: c.textSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Pill(
                label: '스코어카드',
                selected: tab == 0,
                onTap: () => setState(() => tab = 0)),
            const SizedBox(width: 8),
            if (r.companions.isNotEmpty)
              Pill(
                  label: '리더보드',
                  selected: tab == 1,
                  onTap: () => setState(() => tab = 1)),
          ]),
          const SizedBox(height: 12),
          if (tab == 0)
            BoxCard(
              padding: const EdgeInsets.all(12),
              child: ScoreGrid(round: r),
            )
          else
            RowGroup(children: [
              for (var i = 0; i < board.length; i++)
                ListRow(
                  title:
                      '${board.where((b) => b.total < board[i].total).length + 1}위  ${board[i].name}${board[i].isMe ? ' (나)' : ''}',
                  trailing: '${board[i].total}타',
                  trailingColor: board[i].isMe ? c.brandPrimary : null,
                ),
            ]),
          const SizedBox(height: 12),
          RowGroup(children: [
            if (r.companions.isNotEmpty)
              ListRow(
                title: '리더보드 (동반 ${r.companions.length})',
                subtitle: board.map((b) => '${b.name} ${b.total}').join(' · '),
                trailing: Board.myRank(r, store.nickname) == null
                    ? null
                    : '나 ${Board.myRank(r, store.nickname)}위',
                onTap: () => setState(() => tab = 1),
              ),
            ListRow(
              title: '라운드 다이어리',
              subtitle: r.memo.isEmpty && r.photos.isEmpty
                  ? '메모 · 사진'
                  : '사진 ${r.photos.length} · ${r.memo.isEmpty ? '메모 없음' : r.memo.split('\n').first}',
              trailing: r.memo.isEmpty && r.photos.isEmpty ? '+ 추가 ›' : '보기 ›',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DiaryScreen(roundId: r.id))),
            ),
          ]),
        ],
      ),
    );
  }
}
