import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// S-60-1 삭제된 라운드 복구 (30일 보관)
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final now = DateTime.now();
    final list = store.trash;

    return Scaffold(
      appBar: const TopBar(title: '삭제된 라운드'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        children: [
          const InfoBox(title: '삭제한 라운드는 30일 동안 보관했다가 자동으로 지워져요.'),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('삭제된 라운드가 없어요',
                    style: ts(context, 13, color: c.textSecondary)),
              ),
            )
          else
            RowGroup(children: [
              for (final r in list)
                Row(children: [
                  Expanded(
                    child: ListRow(
                      title: '${md(r.date)} ${r.parkName}',
                      subtitle:
                          '${r.myEntered == 0 ? '입력 없음' : '${r.myTotal}타'} · ${store.daysLeft(r, now)}일 남음',
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: LineButton(
                      label: '복구',
                      height: 46,
                      onPressed: () {
                        store.restoreRound(r);
                        toast(context, '라운드를 복구했어요');
                      },
                    ),
                  ),
                ]),
            ]),
        ],
      ),
      bottomNavigationBar: list.isEmpty
          ? null
          : BottomArea(
              child: TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: '휴지통을 비울까요?',
                      body: '${list.length}개 라운드와 사진이 지워지고 되돌릴 수 없어요.',
                      confirm: '비우기',
                      danger: true);
                  if (ok) await store.emptyTrash();
                },
                child: Text('휴지통 비우기',
                    style: ts(context, 13, w: FontWeight.w700, color: c.danger)),
              ),
            ),
    );
  }
}
