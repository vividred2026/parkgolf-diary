import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/library.dart';

/// S-14-1 코스 · 홀별 파 확인 (구장 안내판을 보며 탭, 규정집 3-3-3 개수 체크)
class HoleParScreen extends StatefulWidget {
  const HoleParScreen({
    super.key,
    required this.park,
    required this.courseIndexes,
    required this.finishLabel,
  });

  final Park park;
  final List<int> courseIndexes;
  final String finishLabel;

  @override
  State<HoleParScreen> createState() => _HoleParScreenState();
}

class _HoleParScreenState extends State<HoleParScreen> {
  late final Park park = widget.park.copy();
  int tab = 0;
  int hole = 0;

  Course get course => park.courses[widget.courseIndexes[tab]];

  @override
  void initState() {
    super.initState();
    _jumpToEmpty();
  }

  void _jumpToEmpty() {
    final i = course.pars.indexWhere((p) => p == null);
    hole = i < 0 ? 0 : i;
  }

  void _setPar(int par) {
    setState(() {
      course.pars[hole] = par;
      final next = course.pars.indexWhere((p) => p == null);
      if (next >= 0) hole = next;
    });
  }

  void _finish() {
    context.read<AppStore>().savePark(park);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final counts = Rules.parCounts(course.pars);
    final filled = course.pars.where((p) => p != null).length;
    final isLast = tab == widget.courseIndexes.length - 1;
    final allDone = widget.courseIndexes.every(
      (i) => park.courses[i].parsComplete,
    );

    return Scaffold(
      appBar: const TopBar(title: '코스 · 홀별 파'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
        children: [
          CourseInfo(
            name: park.name,
            badge: '${park.holes}H',
            courses: [for (final e in park.courses) e.name],
          ),
          const SizedBox(height: 10),
          const InfoBox(
            title: '구장 안내판을 보며 홀을 탭해 파를 고르세요',
            body:
                '규정집 3-3-3: 9홀마다 Par 3 · 4 · 5가 3개씩이에요 (9홀 Par 36). '
                '개수가 맞는지 아래에서 확인해 드려요.',
          ),
          const SizedBox(height: 12),
          if (widget.courseIndexes.length > 1)
            Segmented(
              labels: [
                for (final i in widget.courseIndexes) park.courses[i].name,
              ],
              index: tab,
              onChanged: (i) => setState(() {
                tab = i;
                _jumpToEmpty();
              }),
            ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [
              for (var i = 0; i < 9; i++)
                _HoleTile(
                  label: '${i + 1}H',
                  par: course.pars[i],
                  selected: i == hole,
                  onTap: () => setState(() => hole = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${hole + 1}H',
                  style: ts(context, 13, w: FontWeight.w700),
                ),
              ),
              for (final par in [3, 4, 5]) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: course.pars[hole] == par
                      ? PrimaryButton(
                          label: 'Par $par',
                          height: 40,
                          onPressed: () => _setPar(par),
                        )
                      : LineButton(
                          label: 'Par $par',
                          height: 40,
                          color: c.textPrimary,
                          onPressed: () => _setPar(par),
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final par in [3, 4, 5])
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Par $par',
                        style: ts(context, 12, color: c.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${counts[par]} / 3${counts[par] == 3 ? ' ✓' : ''}',
                        style: ts(
                          context,
                          14,
                          w: FontWeight.w700,
                          color: counts[par] == 3
                              ? c.brandPrimary
                              : (counts[par]! > 3 ? c.danger : c.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${course.name} $filled / 9홀'
                  '${filled < 9 ? ' · ${9 - filled}홀 남음' : ''}',
                  style: ts(context, 14, w: FontWeight.w700),
                ),
              ),
              Text(
                course.parsComplete
                    ? '9홀 Par ${course.parTotal}'
                    : '규정 9홀 Par 36',
                style: ts(context, 13, color: c.textSecondary),
              ),
            ],
          ),
          if (course.parsComplete && !Rules.matches333(course.pars)) ...[
            const SizedBox(height: 10),
            const InfoBox(
              warning: true,
              title: '규정(3-3-3)과 개수가 달라요',
              body: '구장 사정에 따라 다를 수 있어요. 안내판과 같다면 그대로 저장해도 돼요.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLast
                ? PrimaryButton(
                    label: widget.finishLabel,
                    onPressed: allDone ? _finish : null,
                  )
                : PrimaryButton(
                    label:
                        '${park.courses[widget.courseIndexes[tab + 1]].name}로 →',
                    onPressed: course.parsComplete
                        ? () => setState(() {
                            tab++;
                            _jumpToEmpty();
                          })
                        : null,
                  ),
            const SizedBox(height: 8),
            const NoteText('개수가 규정과 달라도 저장할 수 있어요 (구장 사정에 따라 다를 수 있어요)'),
          ],
        ),
      ),
    );
  }
}

class _HoleTile extends StatelessWidget {
  const _HoleTile({
    required this.label,
    required this.par,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? par;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BoxCard(
      selected: selected,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: ts(context, 12, color: c.textSecondary)),
            Text(
              par == null ? '–' : 'Par $par',
              style: ts(
                context,
                18,
                w: FontWeight.w700,
                color: par == null && selected ? c.brandPrimary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
