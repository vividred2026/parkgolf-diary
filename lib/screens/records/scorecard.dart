import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// 리더보드 (총 타수 오름차순). 입력한 홀이 없는 사람은 빼요.
class Board {
  Board(this.name, this.total, this.isMe);
  final String name;
  final int total;
  final bool isMe;

  static List<Board> of(Round r, String me) {
    final list = <Board>[
      if (r.myEntered > 0) Board(me, r.myTotal, true),
      for (var k = 0; k < r.companions.length; k++)
        if (r.otherEntered(k) > 0) Board(r.companions[k], r.otherTotal(k), false),
    ]..sort((a, b) => a.total.compareTo(b.total));
    return list;
  }

  static int? myRank(Round r, String me) {
    final b = of(r, me);
    final i = b.indexWhere((e) => e.isMe);
    if (i < 0) return null;
    return b.where((e) => e.total < b[i].total).length + 1;
  }
}

String roundSummary(Round r, String me) {
  final rank = Board.myRank(r, me);
  return [
    signed(r.myOver),
    '퍼트 ${r.myPutts}',
    if (r.myPenalty > 0) '벌타 ${r.myPenalty}',
    if (r.companions.isNotEmpty && rank != null)
      '동반 ${r.companions.length}명 중 $rank위',
  ].join(' · ');
}

/// 홀별 스코어 표 (코스마다 9칸).
class ScoreGrid extends StatelessWidget {
  const ScoreGrid({super.key, required this.round, this.withCompanions = true});

  final Round round;
  final bool withCompanions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = round;
    Widget row(String head, List<String> cells,
            {bool bold = false, Color? color, bool boxed = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
              width: 40,
              child: Text(head,
                  overflow: TextOverflow.ellipsis,
                  style: ts(context, 11, color: c.textSecondary)),
            ),
            for (final t in cells)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: boxed
                      ? BoxDecoration(
                          color: c.surfaceDefault,
                          borderRadius: BorderRadius.circular(4))
                      : null,
                  child: Text(t,
                      textAlign: TextAlign.center,
                      style: ts(context, 12.5,
                          w: bold ? FontWeight.w700 : FontWeight.w500,
                          color: color ?? c.textPrimary)),
                ),
              ),
          ]),
        );

    return Column(children: [
      for (var k = 0; k < r.courseNames.length; k++) ...[
        if (k > 0) const SizedBox(height: 8),
        row(r.courseNames[k], [for (var i = 1; i <= 9; i++) '$i'],
            color: c.textSecondary),
        row('파', [for (var i = k * 9; i < k * 9 + 9; i++) '${r.pars[i]}'],
            color: c.textSecondary),
        row('나', [
          for (var i = k * 9; i < k * 9 + 9; i++)
            r.mine[i]?.total.toString() ?? '–'
        ], bold: true, boxed: true),
        if (withCompanions)
          for (var p = 0; p < r.companions.length; p++)
            row(r.companions[p], [
              for (var i = k * 9; i < k * 9 + 9; i++)
                r.others[p][i]?.toString() ?? '–'
            ]),
      ],
    ]);
  }
}

/// S-31-1 스코어카드 이미지 공유 (이미지만, 서버에 올리지 않아요)
class ScorecardShareSheet extends StatefulWidget {
  const ScorecardShareSheet({super.key, required this.round});

  final Round round;

  static Future<void> open(BuildContext context, Round r) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ScorecardShareSheet(round: r),
      );

  @override
  State<ScorecardShareSheet> createState() => _ScorecardShareSheetState();
}

class _ScorecardShareSheetState extends State<ScorecardShareSheet> {
  final _key = GlobalKey();
  bool withCompanions = true;
  bool busy = false;

  Future<void> _share() async {
    setState(() => busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final r = widget.round;
      final name =
          'scorecard-${r.date.year}${r.date.month.toString().padLeft(2, '0')}${r.date.day.toString().padLeft(2, '0')}.png';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
      ));
    } catch (_) {
      if (mounted) toast(context, '이미지를 만들지 못했어요');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.round;
    final store = context.read<AppStore>();
    final disp = store.settings.scoreDisplay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Text('스코어카드 이미지 공유',
                  style: ts(context, 20, w: FontWeight.w700)),
              const SizedBox(height: 14),
              RepaintBoundary(
                key: _key,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.borderDefault),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.parkName,
                                      style: ts(context, 15,
                                          w: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${r.date.month}월 ${r.date.day}일 (${weekday(r.date)}) · ${r.courseRoute}',
                                      style: ts(context, 12,
                                          color: c.textSecondary)),
                                ]),
                          ),
                          Text(formatRoundScore(r, disp),
                              style: ts(context, 32,
                                  w: FontWeight.w800,
                                  color: c.brandPrimary)),
                        ]),
                        const SizedBox(height: 12),
                        ScoreGrid(round: r, withCompanions: withCompanions),
                        const SizedBox(height: 10),
                        Text(roundSummary(r, store.nickname),
                            style: ts(context, 12, color: c.textSecondary)),
                        const SizedBox(height: 4),
                        Text('파크골프다이어리',
                            style: ts(context, 10, color: c.textSecondary)),
                      ]),
                ),
              ),
              if (r.companions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Pill(
                      label: '나만',
                      selected: !withCompanions,
                      onTap: () => setState(() => withCompanions = false)),
                  const SizedBox(width: 8),
                  Pill(
                      label: '동반자 포함',
                      selected: withCompanions,
                      onTap: () => setState(() => withCompanions = true)),
                ]),
              ],
              const SizedBox(height: 10),
              Text('카카오톡 · 메시지 등 휴대폰 공유 시트로 보내요. 서버에 올리지 않아요.',
                  style: ts(context, 12, color: c.textSecondary)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: LineButton(
                        label: '닫기', onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 8),
                Expanded(
                    child: PrimaryButton(
                        label: busy ? '만드는 중…' : '공유하기',
                        onPressed: busy ? null : _share)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
