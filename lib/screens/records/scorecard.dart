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
import '../../widgets/library.dart';

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
        if (r.otherEntered(k) > 0)
          Board(r.companions[k], r.otherTotal(k), false),
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

/// 라이브러리 report/scorecard — 사람별 스코어카드 (프로필 + 코스마다 HOLE · PAR · SCORE · PUTT).
class ScoreGrid extends StatelessWidget {
  const ScoreGrid({super.key, required this.round, this.withCompanions = true});

  final Round round;
  final bool withCompanions;

  @override
  Widget build(BuildContext context) {
    final r = round;
    final me = context.read<AppStore>().nickname;
    return Column(
      children: [
        PersonalScorecard(
          name: me,
          isMe: true,
          pars: r.pars,
          courseNames: r.courseNames,
          scores: [for (final h in r.mine) h?.total],
          putts: [for (final h in r.mine) h?.putts],
        ),
        if (withCompanions)
          for (var k = 0; k < r.companions.length; k++) ...[
            const SizedBox(height: 12),
            PersonalScorecard(
              name: r.companions[k],
              pars: r.pars,
              courseNames: r.courseNames,
              scores: r.others[k],
            ),
          ],
      ],
    );
  }
}

class PersonalScorecard extends StatelessWidget {
  const PersonalScorecard({
    super.key,
    required this.name,
    required this.pars,
    required this.courseNames,
    required this.scores,
    this.putts,
    this.isMe = false,
  });

  final String name;
  final List<int> pars;
  final List<String> courseNames;
  final List<int?> scores;
  final List<int?>? putts;
  final bool isMe;

  // 라이브러리 scorecard/personal 상태 색 (라이트 · 다크 공통)
  static const eagle = Color(0xFFFF9D88);
  static const birdie = Color(0xFFFFD9D0);
  static const bogeyLine = Color(0xFFADB9C2);
  static const doubleBogey = Color(0xFFD0D7DC);
  static const onMark = Color(0xFF101214);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    int sumOf(Iterable<int?> v) => v.fold(0, (a, b) => a + (b ?? 0));
    final entered = [
      for (var i = 0; i < pars.length; i++)
        if (scores[i] != null) i,
    ];
    final total = sumOf(scores);
    final over = entered.fold(0, (a, i) => a + scores[i]! - pars[i]);

    Widget cell(Widget child) => Expanded(child: Center(child: child));
    Widget label(String s) => SizedBox(
      width: 40,
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: ts(context, 11, color: c.textSecondary),
      ),
    );
    Text num(String s, {bool bold = false, Color? color}) => Text(
      s,
      textAlign: TextAlign.center,
      style: ts(
        context,
        12,
        w: bold ? FontWeight.w700 : FontWeight.w500,
        color: color ?? c.textPrimary,
      ),
    );

    Widget mark(int? s, int par) {
      if (s == null) return num('–', color: c.textSecondary);
      final d = s - par;
      BoxDecoration? deco;
      var onColor = false;
      if (d <= -2) {
        deco = const BoxDecoration(color: eagle, shape: BoxShape.circle);
        onColor = true;
      } else if (d == -1) {
        deco = const BoxDecoration(color: birdie, shape: BoxShape.circle);
        onColor = true;
      } else if (d == 1) {
        deco = BoxDecoration(border: Border.all(color: bogeyLine));
      } else if (d >= 2) {
        deco = const BoxDecoration(color: doubleBogey);
        onColor = true;
      }
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: deco,
        child: num('$s', color: onColor ? onMark : null),
      );
    }

    Widget row(
      String head,
      List<Widget> cells,
      Widget totalCell, {
      bool tinted = false,
    }) => Container(
      height: 36,
      decoration: BoxDecoration(
        color: tinted ? c.surfaceSubtle : null,
        border: Border(bottom: BorderSide(color: c.borderDefault, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [label(head), ...cells.map(cell), cell(totalCell)]),
    );

    final rows = <Widget>[];
    for (var k = 0; k < courseNames.length; k++) {
      final r0 = k * 9;
      final idx = List.generate(9, (i) => r0 + i);
      rows.add(
        row(
          'HOLE',
          [for (final i in idx) num('${i + 1}', color: c.textSecondary)],
          num('T', color: c.textSecondary),
          tinted: true,
        ),
      );
      rows.add(
        row('PAR', [
          for (final i in idx) num('${pars[i]}'),
        ], num('${sumOf(idx.map((i) => pars[i]))}', color: c.textSecondary)),
      );
      rows.add(
        row('SCORE', [
          for (final i in idx) mark(scores[i], pars[i]),
        ], num('${sumOf(idx.map((i) => scores[i]))}', bold: true)),
      );
      if (putts != null) {
        rows.add(
          row('PUTT', [
            for (final i in idx)
              num(putts![i]?.toString() ?? '–', color: c.textSecondary),
          ], num('${sumOf(idx.map((i) => putts![i]))}', bold: true)),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceDefault,
        border: Border.all(color: c.borderDefault),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isMe ? c.brandPrimary : c.surfaceSubtle,
                    child: Text(
                      name.isEmpty ? '' : name.characters.first,
                      style: ts(
                        context,
                        14,
                        w: FontWeight.w700,
                        color: isMe ? c.brandOnPrimary : c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMe ? '$name (나)' : name,
                      overflow: TextOverflow.ellipsis,
                      style: ts(context, 16, w: FontWeight.w700),
                    ),
                  ),
                  Text(
                    entered.isEmpty ? '–' : '$total',
                    style: ts(context, 16, w: FontWeight.w700),
                  ),
                  if (entered.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      '(${signed(over)})',
                      style: ts(context, 14, w: FontWeight.w400),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: c.borderDefault),
          ...rows,
        ],
      ),
    );
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: [name],
        ),
      );
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
              const SheetHeader('스코어카드 이미지 공유'),
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.parkName,
                                  style: ts(context, 15, w: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.date.month}월 ${r.date.day}일 (${weekday(r.date)}) · ${r.courseRoute}',
                                  style: ts(
                                    context,
                                    12,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRoundScore(r, disp),
                            style: ts(
                              context,
                              32,
                              w: FontWeight.w800,
                              color: c.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ScoreGrid(round: r, withCompanions: withCompanions),
                      const SizedBox(height: 10),
                      Text(
                        roundSummary(r, store.nickname),
                        style: ts(context, 12, color: c.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '파크골프다이어리',
                        style: ts(context, 10, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (r.companions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Pill(
                      label: '나만',
                      selected: !withCompanions,
                      onTap: () => setState(() => withCompanions = false),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      label: '동반자 포함',
                      selected: withCompanions,
                      onTap: () => setState(() => withCompanions = true),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const NoteText('카카오톡 · 메시지 등 휴대폰 공유 시트로 보내요. 서버에 올리지 않아요.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LineButton(
                      label: '닫기',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label: busy ? '만드는 중…' : '공유하기',
                      onPressed: busy ? null : _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
