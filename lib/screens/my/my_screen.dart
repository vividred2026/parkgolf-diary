import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../services/earphone.dart';
import '../earphone/earphone_screen.dart';
import '../../widgets/library.dart';
import '../records/records_screen.dart';
import 'backup_screen.dart';
import 'score_display.dart';
import 'trash_screen.dart';

const themeLabels = {
  AppThemeMode.system: '시스템 설정',
  AppThemeMode.light: '라이트',
  AppThemeMode.dark: '다크',
};

/// S-60 MY · 설정
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  Future<void> _editName(BuildContext context, AppStore store) async {
    final ctl = TextEditingController(text: store.nickname);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('닉네임 바꾸기'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (t) => Navigator.pop(ctx, t),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v != null && v.trim().isNotEmpty) store.setNickname(v);
  }

  Future<void> _pickTheme(BuildContext context, AppStore store) async {
    final m = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SheetHeader('화면 모드'),
              const SizedBox(height: 8),
              for (final e in themeLabels.entries)
                InkWell(
                  onTap: () => Navigator.pop(ctx, e.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        RadioDot(selected: store.settings.themeMode == e.key),
                        const SizedBox(width: 12),
                        Text(e.value, style: ts(ctx, 15)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (m != null) store.setThemeMode(m);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final s = Stats(store.liveRounds);
    final trash = store.trash.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
      children: [
        InkWell(
          onTap: () => _editName(context, store),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: c.surfaceSubtle,
                  child: Text(
                    store.nickname.isEmpty
                        ? ''
                        : store.nickname.characters.first,
                    style: ts(
                      context,
                      18,
                      w: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.nickname,
                        style: ts(context, 18, w: FontWeight.w700),
                      ),
                      Text(
                        '평균 ${fmt1(s.avgTotal)}타 · 라운드 ${s.count} · 베스트 ${s.best ?? '–'}',
                        style: ts(context, 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        RowGroup(
          children: [
            ListRow(
              title: '이어폰',
              trailing: context.watch<EarphoneService>().connected
                  ? (context.watch<EarphoneService>().name ?? '연결됨')
                  : '연결 안 됨',
              chevron: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EarphoneScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionLabel('라운드 · 데이터'),
        RowGroup(
          children: [
            ListRow(
              title: '타수 표시',
              trailing: store.settings.scoreDisplay == ScoreDisplay.overPar
                  ? '오버타수'
                  : '총타수',
              chevron: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScoreDisplayScreen()),
              ),
            ),
            ListRow(
              title: '화면 모드',
              trailing: themeLabels[store.settings.themeMode],
              chevron: true,
              onTap: () => _pickTheme(context, store),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RowGroup(
          children: [
            ListRow(
              title: '삭제된 라운드 복구',
              trailing: trash == 0 ? '없음' : '30일 이내 · $trash건',
              chevron: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ),
            ),
            ListRow(
              title: '데이터 백업 · 복원',
              trailing: store.settings.lastBackupAt == null
                  ? '백업 전'
                  : '마지막 ${md(store.settings.lastBackupAt!)}',
              chevron: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '모든 기록은 이 휴대폰에만 저장돼요. 계정 · 로그인은 없어요.',
          style: ts(context, 12, color: c.textSecondary),
        ),
      ],
    );
  }
}
