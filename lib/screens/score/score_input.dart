import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../logic/voice_parser.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../records/round_complete.dart';
import 'voice_sheet.dart';

/// S-23 스코어 입력 · 한 홀씩 / 표
/// 내 기록: 그린까지(벌타 포함) + 퍼트 → 총 타수 자동 계산. 동반자: 총 타수만.
class ScoreInputScreen extends StatefulWidget {
  const ScoreInputScreen({super.key, required this.roundId});

  final String roundId;

  @override
  State<ScoreInputScreen> createState() => _ScoreInputScreenState();
}

class _Undo {
  _Undo(this.hole, this.mine, this.others);
  final int hole;
  final HoleScore? mine;
  final Map<int, int?> others;
}

class _ScoreInputScreenState extends State<ScoreInputScreen> {
  int mode = 0; // 0 한 홀씩, 1 표
  int hole = 0;
  int player = 0; // 0 나, k+1 동반자
  _Undo? _undo;

  AppStore get store => context.read<AppStore>();

  @override
  void initState() {
    super.initState();
    final r = context.read<AppStore>().roundById(widget.roundId);
    if (r != null) {
      final i = r.mine.indexWhere((h) => h == null);
      hole = i < 0 ? 0 : i;
    }
  }

  // ── 값 바꾸기 ─────────────────────────────

  HoleScore _base(Round r, int i) =>
      r.mine[i] ?? HoleScore(toGreen: (r.pars[i] - 2).clamp(1, 9), putts: 2);

  void _changeGreen(Round r, int d) {
    final h = _base(r, hole);
    final g = (h.toGreen + d).clamp(1, 30);
    store.setMine(
      r,
      hole,
      h.copyWith(toGreen: g, penalty: h.penalty > g ? g : h.penalty),
    );
  }

  void _changePutts(Round r, int d) {
    final h = _base(r, hole);
    store.setMine(r, hole, h.copyWith(putts: (h.putts + d).clamp(0, 20)));
  }

  void _penalty(Round r, int sign) {
    final h = _base(r, hole);
    const p = Rules.penaltyStrokes;
    if (sign < 0 && h.penalty < p) return;
    store.setMine(
      r,
      hole,
      h.copyWith(
        toGreen: (h.toGreen + sign * p).clamp(1, 30),
        penalty: h.penalty + sign * p,
      ),
    );
  }

  void _changeOther(Round r, int k, int d) {
    final v = r.others[k][hole] ?? r.pars[hole];
    store.setOther(r, k, hole, (v + d).clamp(1, 30));
  }

  void _goHole(Round r, int i) {
    if (i < 0 || i >= r.holeCount) return;
    setState(() => hole = i);
  }

  // ── 음성 ─────────────────────────────

  Future<void> _voice(Round r) async {
    final res = await showModalBottomSheet<VoiceSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoiceSheet(round: r, hole: hole),
    );
    if (res == null || !mounted) return;
    switch (res.command) {
      case VoiceCommand.nextHole:
        _goHole(r, hole + 1);
        return;
      case VoiceCommand.prevHole:
        _goHole(r, hole - 1);
        return;
      case VoiceCommand.undo:
        _doUndo(r);
        return;
      case null:
    }
    final o = res.outcome!;
    _undo = _Undo(hole, r.mine[hole], {
      for (final k in o.others.keys) k: r.others[k][hole],
    });
    if (o.mine != null) store.setMine(r, hole, o.mine);
    o.others.forEach((k, v) => store.setOther(r, k, hole, v));

    final parts = [
      if (o.mine != null) '그린까지 ${o.mine!.toGreen} · 퍼트 ${o.mine!.putts}',
      for (final e in o.others.entries) '${r.companions[e.key]} ${e.value}',
    ];
    // 라이브러리 toast: 한 줄 글자 + 되돌리기
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            '음성으로 ${hole + 1}H 입력했어요',
            semanticsLabel: '음성으로 ${hole + 1}H 입력했어요. ${parts.join(', ')}',
          ),
          action: SnackBarAction(label: '되돌리기', onPressed: () => _doUndo(r)),
        ),
      );
  }

  void _doUndo(Round r) {
    final u = _undo;
    if (u == null) return;
    store.setMine(r, u.hole, u.mine);
    u.others.forEach((k, v) => store.setOther(r, k, u.hole, v));
    _undo = null;
    setState(() => hole = u.hole);
    toast(context, '${u.hole + 1}H 입력을 되돌렸어요');
  }

  // ── 저장 ─────────────────────────────

  Future<void> _save(Round r) async {
    if (r.done) {
      // 저장된 라운드를 고치는 중 — 바로 반영돼 있으니 닫기만 해요.
      Navigator.pop(context);
      toast(context, '스코어를 고쳤어요');
      return;
    }
    final empty = r.holeCount - r.myEntered;
    if (empty > 0) {
      final ok = await confirmDialog(
        context,
        title: '$empty홀이 비어 있어요',
        body: '빈 홀은 빼고 저장해요. 나중에 라운드 상세에서 고칠 수 있어요.',
        confirm: '저장',
      );
      if (!ok || !mounted) return;
    }
    store.finishRound(r);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RoundCompleteScreen(roundId: r.id)),
    );
  }

  Future<void> _menu(Round r) async {
    final ok = await confirmDialog(
      context,
      title: '이 라운드를 삭제할까요?',
      body: '삭제한 라운드는 30일 동안 MY › 삭제된 라운드에서 복구할 수 있어요.',
      confirm: '삭제',
      danger: true,
    );
    if (!ok || !mounted) return;
    store.deleteRound(r);
    Navigator.pop(context);
  }

  // ── 화면 ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppStore>().roundById(widget.roundId);
    if (r == null) {
      return const Scaffold(body: Center(child: Text('라운드를 찾을 수 없어요')));
    }
    final last = hole == r.holeCount - 1;
    return Scaffold(
      appBar: TopBar(
        title: '스코어 입력',
        actions: [
          IconButton(
            tooltip: '라운드 삭제',
            onPressed: () => _menu(r),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 12),
        children: [
          Segmented(
            labels: const ['한 홀씩', '표'],
            index: mode,
            onChanged: (i) => setState(() => mode = i),
          ),
          const SizedBox(height: 10),
          ...(mode == 0 ? _oneHole(context, r) : _table(context, r)),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: mode == 0
            ? Row(
                children: [
                  Expanded(
                    child: LineButton(
                      label: hole == 0 ? '◀' : '◀ ${hole}H',
                      onPressed: hole == 0 ? null : () => _goHole(r, hole - 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: PrimaryButton(
                      label: last ? '라운드 저장' : '다음 홀 ${hole + 2}H ▶',
                      onPressed: last
                          ? () => _save(r)
                          : () => _goHole(r, hole + 1),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: LineButton(
                      label: last ? '◀ ${hole}H' : '${hole + 2}H ▶',
                      onPressed: () => _goHole(r, last ? hole - 1 : hole + 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label: '라운드 저장',
                      onPressed: () => _save(r),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _holeTotal(Round r, int p) {
    if (p == 0) return r.mine[hole]?.total.toString() ?? '–';
    return r.others[p - 1][hole]?.toString() ?? '–';
  }

  List<Widget> _oneHole(BuildContext context, Round r) {
    final c = context.c;
    final par = r.pars[hole];
    final players = ['나', ...r.companions];
    final h = r.mine[hole];
    final base = _base(r, hole);
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var p = 0; p < players.length; p++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Pill(
                  label: '${players[p]} ${_holeTotal(r, p)}',
                  selected: player == p,
                  onTap: () => setState(() => player = p),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${hole + 1}H',
            style: ts(context, 36, w: FontWeight.w800, height: 1),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              'PAR $par · ${r.courseOf(hole)} ${r.holeNoInCourse(hole)}번',
              style: ts(context, 13, color: c.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (player == 0) ...[
        _StepperCard(
          label: '그린까지 (벌타 포함)',
          value: base.toGreen,
          empty: h == null,
          highlighted: true,
          onMinus: () => _changeGreen(r, -1),
          onPlus: () => _changeGreen(r, 1),
        ),
        const SizedBox(height: 10),
        _StepperCard(
          label: '퍼트',
          value: base.putts,
          empty: h == null,
          onMinus: () => _changePutts(r, -1),
          onPlus: () => _changePutts(r, 1),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Pill(label: '벌타 +2', selected: true, onTap: () => _penalty(r, 1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'OB · 분실구 · 언플레이어블',
                style: ts(context, 12, color: c.textSecondary),
              ),
            ),
            if ((h?.penalty ?? 0) > 0)
              TextButton(
                onPressed: () => _penalty(r, -1),
                child: Text(
                  '벌타 ${h!.penalty} 빼기',
                  style: ts(
                    context,
                    12,
                    w: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          h == null
              ? '아직 입력 전 (± 를 누르면 파 기준으로 시작)'
              : '총 ${h.total}타 · ${_rel(h.total, par)}',
          style: ts(
            context,
            h == null ? 14 : 20,
            w: FontWeight.w700,
            color: h == null ? c.textSecondary : c.brandPrimary,
          ),
        ),
      ] else ...[
        _StepperCard(
          label: '${r.companions[player - 1]} 총 타수',
          value: r.others[player - 1][hole] ?? par,
          empty: r.others[player - 1][hole] == null,
          highlighted: true,
          onMinus: () => _changeOther(r, player - 1, -1),
          onPlus: () => _changeOther(r, player - 1, 1),
        ),
        const SizedBox(height: 10),
        Text(
          '동반자는 홀별 총 타수만 기록해요',
          style: ts(context, 13, color: c.textSecondary),
        ),
      ],
      if (r.companions.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: c.brandPrimary),
            const SizedBox(width: 6),
            Text(
              '동반자 ${r.companions.length}명과 함께 기록 중',
              style: ts(context, 12, color: c.brandPrimary),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      _MicBar(onTap: () => _voice(r)),
    ];
  }

  String _rel(int total, int par) {
    final term = Rules.termFor(total, par);
    final d = total - par;
    return d == 0 || term == '홀인원' ? term : '${signed(d)} $term';
  }

  List<Widget> _table(BuildContext context, Round r) {
    final c = context.c;
    final course = hole ~/ 9;
    final start = course * 9;
    int courseTotal(int k) {
      var t = 0;
      for (var i = k * 9; i < k * 9 + 9; i++) {
        t += r.mine[i]?.total ?? 0;
      }
      return t;
    }

    final h = r.mine[hole];
    final base = _base(r, hole);
    TextStyle head = ts(context, 11, color: c.textSecondary);
    Widget cell(String t, {bool bold = false, Color? color}) => Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: ts(
          context,
          14,
          w: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? c.textSecondary,
        ),
      ),
    );

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var k = 0; k < r.courseNames.length; k++)
            Pill(
              label: courseTotal(k) > 0
                  ? '${r.courseNames[k]} ${courseTotal(k)}'
                  : r.courseNames[k],
              selected: course == k,
              onTap: () => setState(() => hole = k * 9),
            ),
        ],
      ),
      const SizedBox(height: 12),
      BoxCard(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Column(
          children: [
            Row(
              children: [
                for (final t in ['홀', '파', '그린까지', '퍼트', '총'])
                  Expanded(
                    child: Text(t, textAlign: TextAlign.center, style: head),
                  ),
              ],
            ),
            Divider(color: c.borderDefault),
            for (var i = start; i < start + 9; i++)
              InkWell(
                onTap: () => setState(() => hole = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: i == hole ? c.surfaceSelected : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      cell('${r.holeNoInCourse(i)}'),
                      cell('${r.pars[i]}'),
                      cell(
                        r.mine[i]?.toGreen.toString() ?? '–',
                        bold: true,
                        color: c.textPrimary,
                      ),
                      cell(r.mine[i]?.putts.toString() ?? '–'),
                      cell(r.mine[i]?.total.toString() ?? '–'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MiniStepper(
              label: '그린까지',
              value: h == null ? '–' : '${base.toGreen}',
              onMinus: () => _changeGreen(r, -1),
              onPlus: () => _changeGreen(r, 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniStepper(
              label: '퍼트',
              value: h == null ? '–' : '${base.putts}',
              onMinus: () => _changePutts(r, -1),
              onPlus: () => _changePutts(r, 1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        h == null
            ? '${hole + 1}H 입력 전 (총 타수는 자동 계산)'
            : '${hole + 1}H 총 ${h.total}타 · ${signed(h.total - r.pars[hole])}  (총 타수는 자동 계산)',
        style: ts(context, 13, w: FontWeight.w700),
      ),
      if (r.companions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: c.brandPrimary),
            const SizedBox(width: 6),
            Text(
              '동반자 ${r.companions.length}명에게 함께 기록 중 · 한 홀씩 화면에서 입력',
              style: ts(context, 12, color: c.brandPrimary),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      _MicBar(onTap: () => _voice(r)),
    ];
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.label,
    required this.value,
    required this.empty,
    required this.onMinus,
    required this.onPlus,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final bool empty;
  final bool highlighted;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BoxCard(
      selected: highlighted,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ts(
              context,
              13,
              w: FontWeight.w700,
              color: highlighted ? c.brandPrimary : c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              RoundIconButton(
                icon: Icons.remove_rounded,
                tooltip: '$label 빼기',
                onTap: onMinus,
              ),
              Expanded(
                child: Semantics(
                  label: '$label ${empty ? '입력 전' : value}',
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: ts(
                      context,
                      56,
                      w: FontWeight.w800,
                      height: 1.1,
                      color: empty ? c.textDisabled : c.textPrimary,
                    ),
                  ),
                ),
              ),
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: '$label 더하기',
                filled: true,
                onTap: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BoxCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(label, style: ts(context, 12, color: c.textSecondary)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '$label 빼기',
                onPressed: onMinus,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: ts(context, 22, w: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '$label 더하기',
                onPressed: onPlus,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 눌러서 말하기 (휴대폰 마이크)
class _MicBar extends StatelessWidget {
  const _MicBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BoxCard(
      selected: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.brandPrimary,
            child: Icon(
              Icons.mic_none_rounded,
              color: c.brandOnPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('눌러서 말하기', style: ts(context, 15, w: FontWeight.w700)),
                Text(
                  '휴대폰 마이크 · 예) 그린까지 3, 퍼트 2',
                  style: ts(context, 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
