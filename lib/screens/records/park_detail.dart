import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/library.dart';
import 'records_screen.dart';
import 'round_detail.dart';

/// S-32 파크골프장 상세 (날짜별)
class ParkDetailScreen extends StatefulWidget {
  const ParkDetailScreen({super.key, required this.parkId});

  final String parkId;

  @override
  State<ParkDetailScreen> createState() => _ParkDetailScreenState();
}

class _ParkDetailScreenState extends State<ParkDetailScreen> {
  bool byScore = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final disp = store.settings.scoreDisplay;
    final summary = Stats(store.liveRounds)
        .byPark(PeriodFilter.all, DateTime.now())
        .where((p) => p.parkId == widget.parkId)
        .firstOrNull;
    if (summary == null) {
      return const Scaffold(
        appBar: TopBar(title: ''),
        body: SizedBox(),
      );
    }
    final park = store.parkById(widget.parkId);
    final rounds = List.of(summary.rounds);
    if (byScore) {
      rounds.sort((a, b) => a.myTotal.compareTo(b.myTotal));
    }
    final best = summary.bestRound;
    final over = disp == ScoreDisplay.overPar;

    Widget box(String label, String value) => Expanded(
      child: BoxCard(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(label, style: ts(context, 12, color: c.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: ts(context, 18, w: FontWeight.w700)),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: TopBar(title: summary.parkName),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        children: [
          BoxCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (park != null && park.region.isNotEmpty) park.region,
                    if (park != null) '${park.holes}홀',
                    '${summary.count}회 라운드',
                  ].join(' · '),
                  style: ts(context, 12, color: c.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    box(
                      '평균',
                      over
                          ? fmtSigned1(summary.avgOver)
                          : fmt1(summary.avgTotal),
                    ),
                    const SizedBox(width: 8),
                    box(
                      '베스트',
                      best == null
                          ? '–'
                          : (over ? signed(best.myOver) : '${best.myTotal}'),
                    ),
                    const SizedBox(width: 8),
                    box('최근', formatRoundScore(summary.latest, disp)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BoxCard(
            color: c.surfaceSubtle,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _TrendPainter(
                  values: summary.rounds.reversed
                      .where((r) => r.myComplete)
                      .map((r) => (over ? r.myOver : r.myTotal).toDouble())
                      .toList(),
                  line: c.brandPrimary,
                  text: c.textSecondary,
                  signedLabels: over,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          LabelSort(
            title: '날짜별 스코어',
            count: rounds.length,
            unit: '회',
            sortText: byScore ? '스코어순' : '최신순',
            onSort: () => setState(() => byScore = !byScore),
          ),
          for (final r in rounds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RoundListItem(
                date: mdw(r.date),
                title: '${r.courseRoute}${best?.id == r.id ? ' · 베스트' : ''}',
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
      ),
    );
  }
}

/// 날짜순 스코어 꺾은선.
class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.line,
    required this.text,
    required this.signedLabels,
  });

  final List<double> values;
  final bool signedLabels;
  final Color line;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: '18홀을 모두 입력한 라운드가 쌓이면 추이를 보여 드려요',
          style: TextStyle(fontFamily: kFont, fontSize: 12, color: text),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
      return;
    }
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final n = values.length;
    Offset pt(int i) => Offset(
      n == 1 ? size.width / 2 : 8 + (size.width - 16) * i / (n - 1),
      12 + (size.height - 28) * (values[i] - lo) / span,
    );
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(pt(i), 3.5, Paint()..color = line);
      if (i == 0 || i == n - 1 || values[i] == lo) {
        final v = values[i];
        final tp = TextPainter(
          text: TextSpan(
            text: signedLabels ? signed(v.round()) : v.toStringAsFixed(0),
            style: TextStyle(fontFamily: kFont, fontSize: 10, color: text),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pt(i) + Offset(-tp.width / 2, -16));
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.line != line;
}
