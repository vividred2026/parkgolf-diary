import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../services/earphone.dart';

import 'package:provider/provider.dart';

import '../../logic/rules.dart';
import '../../logic/voice_parser.dart';
import '../../models/models.dart';
import '../../services/speech.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// 음성 시트가 돌려주는 결과.
class VoiceSheetResult {
  VoiceSheetResult.apply(this.outcome) : command = null;
  VoiceSheetResult.command(this.command) : outcome = null;

  final VoiceOutcome? outcome;
  final VoiceCommand? command;
}

enum _Phase { starting, listening, result, ask, fail }

/// SV-02 듣는 중 → SV-08 결과 확인(탭) / SV-04 되묻기 / SV-06 못 알아들음
/// 결과는 자동으로 반영하지 않고, 사용자가 "적용"을 눌러야 반영돼요.
class VoiceSheet extends StatefulWidget {
  const VoiceSheet({
    super.key,
    required this.round,
    required this.hole,
    this.speech,
  });

  final Round round;
  final int hole;
  final SpeechService? speech;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  late final SpeechService speech = widget.speech ?? SpeechService.instance;
  _Phase phase = _Phase.starting;
  String words = '';
  String? failReason;
  final List<double> levels = List.filled(13, 0.15);
  VoiceParse? parsed;
  VoiceOutcome? outcome;
  int? askPick;
  bool _handled = false;
  final _debugCtl = TextEditingController();

  int get par => widget.round.pars[widget.hole];

  late final EarphoneService ear = context.read<EarphoneService>();
  late final bool earMic =
      context.read<AppStore>().settings.earMic && ear.connected && ear.mic;
  late final bool autoPause = context.read<AppStore>().settings.earAutoPause;
  int? _worn;

  @override
  void initState() {
    super.initState();
    _worn = ear.wornCount;
    ear.addListener(_onEar);
    _start();
  }

  @override
  void dispose() {
    ear.removeListener(_onEar);
    speech.cancel();
    if (earMic) ear.earMic(false);
    _debugCtl.dispose();
    super.dispose();
  }

  /// 귀에서 빼면 듣기를 멈추고 닫아요 (EP-09).
  void _onEar() {
    final w = ear.wornCount;
    final removed = autoPause && _worn != null && _worn! > 0 && w == 0;
    _worn = w;
    if (removed && mounted && phase == _Phase.listening) {
      _handled = true;
      speech.cancel();
      Navigator.pop(context);
    }
  }

  Future<void> _start() async {
    setState(() {
      phase = _Phase.starting;
      words = '';
      parsed = null;
      outcome = null;
      askPick = null;
      _handled = false;
    });
    final ok = await speech.init();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        phase = _Phase.fail;
        failReason =
            '마이크 · 음성 인식 권한이 꺼져 있거나 이 기기에서 음성 인식을 쓸 수 없어요. '
            '설정에서 권한을 켜거나 버튼으로 입력해 주세요.';
      });
      return;
    }
    if (earMic) await ear.earMic(true);
    if (!mounted) return;
    setState(() => phase = _Phase.listening);
    await speech.listen(
      onResult: (w, isFinal) {
        if (!mounted) return;
        setState(() => words = w);
        if (isFinal) _handle(w);
      },
      onLevel: (l) {
        if (!mounted || phase != _Phase.listening) return;
        setState(() {
          levels.removeAt(0);
          levels.add(((l + 2) / 12).clamp(0.12, 1.0));
        });
      },
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && phase == _Phase.listening) _handle(words);
          });
        }
      },
      onError: (_) {
        if (mounted && phase == _Phase.listening) _handle(words);
      },
    );
  }

  void _handle(String text) {
    if (_handled) return;
    _handled = true;
    speech.stop();
    final p = VoiceParser.parse(text, widget.round.companions);
    if (p.isEmpty) {
      setState(() {
        phase = _Phase.fail;
        failReason = null;
      });
      return;
    }
    if (p.command != null && !p.aboutMe && p.others.isEmpty) {
      Navigator.pop(context, VoiceSheetResult.command(p.command));
      return;
    }
    final o = VoiceParser.resolve(p, widget.round.mine[widget.hole]);
    setState(() {
      parsed = p;
      outcome = o;
      phase = o.needsAsk ? _Phase.ask : _Phase.result;
      askPick = null;
    });
  }

  void _apply() {
    var o = outcome!;
    if (phase == _Phase.ask) {
      if (askPick == null) return;
      o = VoiceParser.resolve(
        parsed!,
        widget.round.mine[widget.hole],
        forcedField: o.ask,
        forcedValue: askPick,
      );
      if (o.needsAsk) {
        setState(() {
          outcome = o;
          askPick = null;
        });
        return;
      }
    }
    Navigator.pop(context, VoiceSheetResult.apply(o));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        0,
        gutter,
        MediaQuery.viewInsetsOf(context).bottom + 14,
      ),
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              ...switch (phase) {
                _Phase.starting || _Phase.listening => _listening(context),
                _Phase.result => _result(context),
                _Phase.ask => _ask(context),
                _Phase.fail => _fail(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _micTag(BuildContext context, String text) => Align(
    alignment: Alignment.centerRight,
    child: Tag(text, color: context.c.brandPrimary),
  );

  Widget _quote(BuildContext context, String text) => Text(
    '"$text"',
    style: ts(context, 14, color: context.c.textSecondary, height: 1.4),
  );

  List<Widget> _listening(BuildContext context) {
    final c = context.c;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '${widget.hole + 1}H · PAR $par',
              style: ts(context, 15, w: FontWeight.w700),
            ),
          ),
          _micTag(context, earMic ? '이어폰 마이크로 듣는 중' : '휴대폰 마이크로 듣는 중'),
        ],
      ),
      const SizedBox(height: 18),
      Center(
        child: GestureDetector(
          onTap: () => _handle(words),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surfaceSelected,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.brandPrimary,
              ),
              child: Icon(
                Icons.mic_none_rounded,
                size: 36,
                color: c.brandOnPrimary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          phase == _Phase.starting ? '준비 중…' : '듣고 있어요',
          style: ts(context, 20, w: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < levels.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height:
                    36 *
                    levels[i] *
                    (0.6 + 0.4 * math.sin((i + 1) / levels.length * math.pi)),
                decoration: BoxDecoration(
                  color: c.brandPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          words.isEmpty ? '"그린까지 3, 퍼트 2…"' : '"$words"',
          textAlign: TextAlign.center,
          style: ts(
            context,
            15,
            w: FontWeight.w500,
            color: words.isEmpty ? c.textSecondary : c.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '예) 그린까지 3, 퍼트 2 · 5타 퍼트 2 · ${widget.round.companions.isEmpty ? '' : '${widget.round.companions.first} 4 · '}벌타\n'
        '말이 끝나면 자동으로 멈춰요. 마이크를 누르면 바로 끝나요.',
        textAlign: TextAlign.center,
        style: ts(context, 12, color: c.textSecondary, height: 1.4),
      ),
      if (kDebugMode) _debugInput(context),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: LineButton(
              label: '취소',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(
              label: '직접 입력',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ];
  }

  /// 개발용: 음성 대신 글자로 넣어 보기 (디버그 빌드에서만 보여요).
  Widget _debugInput(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: _debugCtl,
      style: ts(context, 13),
      decoration: const InputDecoration(
        isDense: true,
        hintText: '(개발용) 말한 내용을 글자로 입력',
      ),
      onSubmitted: (v) {
        _handled = false;
        speech.cancel();
        setState(() => words = v);
        _handle(v);
      },
    ),
  );

  Widget _summary(BuildContext context, VoiceOutcome o) {
    final c = context.c;
    final r = widget.round;
    final rows = <Widget>[];
    final m = o.mine;
    if (m != null) {
      rows.add(
        Row(
          children: [
            Text(
              '나 · ${widget.hole + 1}H',
              style: ts(context, 13, color: c.textSecondary),
            ),
            const Spacer(),
            Text(
              '그린까지 ${m.toGreen}${m.penalty > 0 ? ' (벌타 ${m.penalty})' : ''} · 퍼트 ${m.putts}',
              style: ts(context, 15, w: FontWeight.w700),
            ),
          ],
        ),
      );
      rows.add(
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '총 ${m.total}타 · ${_rel(m.total)}',
            style: ts(context, 17, w: FontWeight.w700, color: c.brandPrimary),
          ),
        ),
      );
    }
    for (final e in o.others.entries) {
      rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            Text(
              r.companions[e.key],
              style: ts(context, 13, color: c.textSecondary),
            ),
            const Spacer(),
            Text(
              '총 ${e.value}타 · ${Rules.termFor(e.value, par)}',
              style: ts(context, 15, w: FontWeight.w700),
            ),
          ],
        ),
      );
    }
    return BoxCard(
      selected: true,
      padding: const EdgeInsets.all(16),
      child: Column(children: rows),
    );
  }

  String _rel(int total) {
    final d = total - par;
    final term = Rules.termFor(total, par);
    if (d == 0 || term == '홀인원') return term;
    return '${signed(d)} $term';
  }

  List<Widget> _result(BuildContext context) {
    final c = context.c;
    return [
      Row(
        children: [
          Expanded(
            child: Text('이렇게 들었어요', style: ts(context, 20, w: FontWeight.w700)),
          ),
          _micTag(context, earMic ? '이어폰 마이크' : '휴대폰 마이크'),
        ],
      ),
      const SizedBox(height: 10),
      _quote(context, parsed!.heard),
      const SizedBox(height: 14),
      _summary(context, outcome!),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '화면을 확인하고 "적용"을 탭하세요',
              style: ts(context, 13, w: FontWeight.w700, color: c.brandPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              '틀렸다면 "다시 말하기"를 누르세요. 자동으로 반영하지 않아요.',
              style: ts(context, 12, color: c.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: LineButton(label: '다시 말하기', onPressed: _start),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(label: '적용', onPressed: _apply),
          ),
        ],
      ),
    ];
  }

  List<Widget> _ask(BuildContext context) {
    final c = context.c;
    final o = outcome!;
    final isPutts = o.ask == AskField.putts;
    final field = isPutts ? '퍼트' : '그린까지';
    final options = isPutts ? [0, 1, 2, 3] : [1, 2, 3, 4, 5, 6];
    final p = parsed!;
    final known = isPutts ? p.toGreen ?? p.total : p.putts;
    final knownLabel = isPutts ? (p.toGreen != null ? '그린까지' : '총 타수') : '퍼트';
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '$field가 맞나요?',
              style: ts(context, 20, w: FontWeight.w700),
            ),
          ),
          _micTag(context, '확인 필요'),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '"${p.heard}" — ${o.askReason}',
        style: ts(context, 13, color: c.textSecondary, height: 1.4),
      ),
      const SizedBox(height: 14),
      BoxCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (known != null)
              Row(
                children: [
                  Text(knownLabel, style: ts(context, 14)),
                  const Spacer(),
                  Text('$known', style: ts(context, 17, w: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Tag(
                    '확실',
                    color: c.success,
                    bg: c.success.withValues(alpha: 0.12),
                  ),
                ],
              ),
            if (known != null) const SizedBox(height: 8),
            Row(
              children: [
                Text(field, style: ts(context, 14)),
                const Spacer(),
                Text(
                  askPick == null ? '?' : '$askPick',
                  style: ts(context, 17, w: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Tag('확인 필요', color: c.warningText, bg: c.warningBg),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text('$field 고르기', style: ts(context, 13, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in options)
            SizedBox(
              width:
                  (MediaQuery.sizeOf(context).width - gutter * 2 - 16) /
                  (options.length > 4 ? 3 : 4),
              child: askPick == v
                  ? PrimaryButton(
                      label: '$v',
                      height: 50,
                      onPressed: () => _pick(v),
                    )
                  : LineButton(
                      label: '$v',
                      height: 50,
                      color: c.textPrimary,
                      onPressed: () => _pick(v),
                    ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: LineButton(label: '다시 말하기', onPressed: _start),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(
              label: askPick == null ? '적용' : '$askPick로 적용',
              onPressed: askPick == null ? null : _apply,
            ),
          ),
        ],
      ),
    ];
  }

  void _pick(int v) => setState(() => askPick = v);

  List<Widget> _fail(BuildContext context) {
    final c = context.c;
    return [
      const SizedBox(height: 8),
      Center(
        child: CircleAvatar(
          radius: 32,
          backgroundColor: c.surfaceSubtle,
          child: Text(
            '!',
            style: ts(context, 26, w: FontWeight.w700, color: c.textSecondary),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text('잘 못 알아들었어요', style: ts(context, 22, w: FontWeight.w700)),
      ),
      const SizedBox(height: 10),
      Text(
        failReason ??
            '주변 소리가 커요. 휴대폰을 입 가까이 대고 숫자를 또박또박 말해 주세요.'
                '${words.isEmpty ? '' : '\n들은 말: "$words"'}',
        textAlign: TextAlign.center,
        style: ts(context, 14, color: c.textSecondary, height: 1.45),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          '예) 그린까지 3, 퍼트 2 · 5타 퍼트 2',
          style: ts(context, 12, color: c.textSecondary),
        ),
      ),
      if (kDebugMode) _debugInput(context),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: LineButton(
              label: '버튼으로 입력',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(label: '다시 말하기', onPressed: _start),
          ),
        ],
      ),
    ];
  }
}
