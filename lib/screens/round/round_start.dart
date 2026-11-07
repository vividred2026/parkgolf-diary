import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'companions.dart';
import 'hole_par.dart';
import 'park_search.dart';

/// S-13 라운드 시작 — 파크골프장 · 코스 고르기
class RoundStartScreen extends StatefulWidget {
  const RoundStartScreen({super.key});

  @override
  State<RoundStartScreen> createState() => _RoundStartScreenState();
}

class _RoundStartScreenState extends State<RoundStartScreen> {
  Park? park;
  List<int> sel = [];

  @override
  void initState() {
    super.initState();
    final recent = context.read<AppStore>().recentParks;
    if (recent.isNotEmpty) _setPark(recent.first);
  }

  void _setPark(Park p) {
    park = p;
    // 기본: 앞의 두 코스(18홀)
    sel = [for (var i = 0; i < p.courses.length && i < 2; i++) i];
  }

  Future<void> _pickPark() async {
    final p = await Navigator.push<Park>(
      context,
      MaterialPageRoute(builder: (_) => const ParkSearchScreen()),
    );
    if (p != null) setState(() => _setPark(p));
  }

  Future<bool> _editPars({required String finishLabel}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HoleParScreen(
          park: park!,
          courseIndexes: sel,
          finishLabel: finishLabel,
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() => park = context.read<AppStore>().parkById(park!.id));
    }
    return ok == true;
  }

  Future<void> _next() async {
    final p = park!;
    final needPars = sel.any((i) => !p.courses[i].parsComplete);
    if (needPars && !await _editPars(finishLabel: '다음 · 동반자')) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CompanionsScreen(park: park!, courseIndexes: List.of(sel)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.watch<AppStore>();
    final p = park;
    final lastPlayed = p == null
        ? null
        : store.doneRounds.where((r) => r.parkId == p.id).firstOrNull;

    return Scaffold(
      appBar: const TopBar(title: '라운드 시작'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        children: [
          BoxCard(
            onTap: _pickPark,
            padding: const EdgeInsets.all(16),
            child: p == null
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          '파크골프장을 골라 주세요',
                          style: ts(context, 16, w: FontWeight.w700),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (store.recentParks.firstOrNull?.id == p.id)
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: c.brandPrimary),
                            const SizedBox(width: 6),
                            Text(
                              '최근 파크골프장',
                              style: ts(context, 12, color: c.brandPrimary),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(p.name, style: ts(context, 18, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          '${p.holes}홀',
                          if (p.region.isNotEmpty) p.region,
                          if (lastPlayed != null)
                            '마지막 라운드 ${md(lastPlayed.date)}',
                        ].join(' · '),
                        style: ts(context, 12, color: c.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '다른 파크골프장 (즐겨찾기 · 추가) ›',
                        style: ts(context, 13, w: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
          if (p != null) ...[
            const SizedBox(height: 20),
            const SectionLabel('코스 (누른 순서대로 돌아요)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < p.courses.length; i++)
                  Pill(
                    label: sel.contains(i)
                        ? '${sel.indexOf(i) + 1}  ${p.courses[i].name}'
                        : p.courses[i].name,
                    selected: sel.contains(i),
                    onTap: () => setState(() {
                      if (!sel.remove(i)) sel.add(i);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              sel.isEmpty
                  ? '코스를 하나 이상 골라 주세요'
                  : '${sel.map((i) => p.courses[i].name).join(' → ')} · ${sel.length * 9}홀',
              style: ts(context, 12, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            if (sel.isNotEmpty)
              RowGroup(
                children: [
                  ListRow(
                    title: '홀별 파',
                    trailing: sel.every((i) => p.courses[i].parsComplete)
                        ? '확인 · 수정'
                        : '입력 필요',
                    trailingColor: sel.every((i) => p.courses[i].parsComplete)
                        ? null
                        : c.brandPrimary,
                    chevron: true,
                    onTap: () => _editPars(finishLabel: '저장'),
                  ),
                ],
              ),
          ],
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: PrimaryButton(
          label: '다음 · 동반자',
          onPressed: p == null || sel.isEmpty ? null : _next,
        ),
      ),
    );
  }
}
