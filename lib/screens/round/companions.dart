import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../score/score_input.dart';

/// S-15 동반자 · 시작
class CompanionsScreen extends StatefulWidget {
  const CompanionsScreen(
      {super.key, required this.park, required this.courseIndexes});

  final Park park;
  final List<int> courseIndexes;

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  final List<String> names = [];
  final DateTime start = DateTime.now();

  Future<void> _openSheet() async {
    final added = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCompanionSheet(already: names),
    );
    if (added != null) setState(() => names.addAll(added));
  }

  void _start() {
    final store = context.read<AppStore>();
    final r = store.startRound(
        park: widget.park,
        courseIndexes: widget.courseIndexes,
        companions: names,
        date: start);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ScoreInputScreen(roundId: r.id)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.watch<AppStore>();
    final route =
        widget.courseIndexes.map((i) => widget.park.courses[i].name).join(' → ');
    final recent = store.data.recentCompanions
        .where((n) => !names.contains(n))
        .take(3)
        .toList();

    return Scaffold(
      appBar: const TopBar(title: '라운드 시작'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
        children: [
          BoxCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.park.name} · $route',
                  style: ts(context, 14, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(fullDate(start),
                  style: ts(context, 12, color: c.textSecondary)),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionLabel('동반자'),
          RowGroup(children: [
            ListRow(title: '${store.nickname} (나)', trailing: '나'),
            for (final n in names)
              Row(children: [
                Expanded(child: ListRow(title: n)),
                IconButton(
                  tooltip: '$n 빼기',
                  onPressed: () => setState(() => names.remove(n)),
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: c.textSecondary),
                ),
              ]),
            if (names.length < Rules.maxPlayers - 1)
              ListRow(
                title: '+ 동반자 이름 추가',
                subtitle: recent.isEmpty ? '이름만 저장돼요' : '최근: ${recent.join(' · ')}',
                trailing: '선택 ›',
                onTap: _openSheet,
              ),
          ]),
          const SizedBox(height: 10),
          Text('동반자는 홀별 총 타수만 기록해요. 나 포함 최대 ${Rules.maxPlayers}명 (1조).',
              style: ts(context, 12, color: c.textSecondary)),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: PrimaryButton(label: '라운드 시작', onPressed: _start),
      ),
    );
  }
}

/// S-15-1 동반자 추가 (시트)
class _AddCompanionSheet extends StatefulWidget {
  const _AddCompanionSheet({required this.already});

  final List<String> already;

  @override
  State<_AddCompanionSheet> createState() => _AddCompanionSheetState();
}

class _AddCompanionSheetState extends State<_AddCompanionSheet> {
  final _ctl = TextEditingController();
  final List<String> picked = [];

  int get room => Rules.maxPlayers - 1 - widget.already.length;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _typed() {
    final v = _ctl.text.trim();
    if (v.isEmpty || picked.contains(v) || widget.already.contains(v)) return;
    if (picked.length >= room) return;
    setState(() {
      picked.add(v);
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.read<AppStore>();
    final recent = {
      ...store.data.recentCompanions,
      ...picked,
    }.where((n) => !widget.already.contains(n)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          gutter, 0, gutter, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text('동반자 추가', style: ts(context, 20, w: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _ctl,
              autofocus: store.data.recentCompanions.isEmpty,
              maxLength: 10,
              style: ts(context, 15),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _typed(),
              decoration: InputDecoration(
                hintText: '이름 입력',
                counterText: '',
                suffixIcon: IconButton(
                    tooltip: '추가',
                    onPressed: _typed,
                    icon: const Icon(Icons.add_rounded)),
              ),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('최근 동반자', style: ts(context, 13, color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in recent)
                  Pill(
                    label: n,
                    selected: picked.contains(n),
                    onTap: () => setState(() {
                      if (!picked.remove(n) && picked.length < room) {
                        picked.add(n);
                      }
                    }),
                  ),
              ]),
            ],
            const SizedBox(height: 10),
            Text('이름만 이 휴대폰에 저장돼요 · 나 포함 최대 ${Rules.maxPlayers}명 (1조)',
                style: ts(context, 12, color: c.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: LineButton(
                      label: '취소', onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: picked.isEmpty ? '추가' : '${picked.length}명 추가',
                  onPressed: picked.isEmpty
                      ? null
                      : () => Navigator.pop(context, picked),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
