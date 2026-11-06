import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_store.dart';
import '../../data/backup.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../onboarding.dart';

/// S-61 데이터 백업 · 복원 (파일 내보내기 · 가져오기)
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;

  Future<void> _make() async {
    final store = context.read<AppStore>();
    setState(() => busy = true);
    try {
      final now = DateTime.now();
      final bytes = await Backup.build(store.data, store.storage, now);
      final name = Backup.fileName(now);
      final res = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/zip', name: name)],
        fileNameOverrides: [name],
        subject: '파크골프다이어리 백업',
      ));
      if (res.status != ShareResultStatus.dismissed) {
        store.markBackedUp(now);
        if (mounted) toast(context, '백업 파일을 만들었어요');
      }
    } catch (_) {
      if (mounted) toast(context, '백업 파일을 만들지 못했어요');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final store = context.read<AppStore>();
    final PlatformFile? f;
    try {
      f = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ['zip']);
    } catch (_) {
      if (mounted) toast(context, '파일을 열지 못했어요');
      return;
    }
    if (f == null || !mounted) return;
    final BackupContent content;
    try {
      content = Backup.read(await f.xFile.readAsBytes());
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
      return;
    }
    if (!mounted) return;
    final at = content.createdAt;
    final ok = await _confirmRestore(f.name, at, content);
    if (!ok || !mounted) return;
    await store.replaceAll(content.data, content.photos);
    if (mounted) toast(context, '백업 파일로 복원했어요');
  }

  Future<bool> _confirmRestore(
      String name, DateTime? at, BackupContent content) async {
    final c = context.c;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('백업 파일로 복원할까요?',
                  style: ts(ctx, 18, w: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('지금 휴대폰의 기록이 백업 파일 내용으로 바뀌어요. 복원 전 기록은 사라져요.',
                  style: ts(ctx, 14, color: c.textSecondary, height: 1.45)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: ts(ctx, 14, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (at != null) ymd(at),
                            '라운드 ${content.roundCount}',
                            '사진 ${content.photos.length}장',
                            formatBytes(content.sizeBytes),
                          ].join(' · '),
                          style: ts(ctx, 12, color: c.textSecondary)),
                    ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                    child: LineButton(
                        label: '취소',
                        height: 50,
                        onPressed: () => Navigator.pop(ctx, false))),
                const SizedBox(width: 8),
                Expanded(
                    child: PrimaryButton(
                        label: '복원',
                        height: 50,
                        onPressed: () => Navigator.pop(ctx, true))),
              ]),
            ],
          ),
        ),
      ),
    );
    return r ?? false;
  }

  Future<void> _deleteAll() async {
    final store = context.read<AppStore>();
    final step1 = await confirmDialog(context,
        title: '모든 데이터를 삭제할까요?',
        body: '1 / 2 단계 · 다음 단계에서 한 번 더 확인해요.',
        confirm: '다음',
        danger: true);
    if (!step1 || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAllDialog(lastBackup: store.settings.lastBackupAt),
    );
    if (ok != true || !mounted) return;
    await store.deleteEverything();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PermissionScreen()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = context.c;
    final rounds = store.liveRounds.length;
    final last = store.settings.lastBackupAt;

    return Scaffold(
      appBar: const TopBar(title: '데이터 백업 · 복원'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 24),
        children: [
          const InfoBox(
            title: '모든 기록은 이 휴대폰에만 저장돼요',
            body: '기기를 바꾸거나 앱을 지우기 전에 백업 파일을 만들어 드라이브 · 메일 · 메신저 등 원하는 곳에 저장해 두세요.',
          ),
          const SizedBox(height: 16),
          const SectionLabel('백업'),
          RowGroup(children: [
            ListRow(
              title: '백업 파일 만들기',
              subtitle:
                  '${last == null ? '아직 백업 전' : '마지막 백업 ${md(last)}'} · 라운드 $rounds · 사진 포함',
              trailing: '만들기 ›',
              trailingColor: c.brandPrimary,
              onTap: busy ? null : _make,
            ),
            ListRow(
              title: '백업 파일 불러오기',
              subtitle: '지금 데이터를 백업 내용으로 바꿔요',
              trailing: '불러오기 ›',
              trailingColor: c.brandPrimary,
              onTap: _restore,
            ),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('저장 공간'),
          RowGroup(children: [
            FutureBuilder<int>(
              future: store.storage.photoBytes(),
              builder: (context, snap) => ListRow(
                title: '라운드 $rounds · 사진 ${store.photoCount}장',
                trailing: snap.hasData ? formatBytes(snap.data!) : '',
                trailingColor: c.brandPrimary,
              ),
            ),
            Row(children: [
              Expanded(
                child: ListRow(
                    title: '사진 압축 저장', subtitle: '화질을 유지하며 용량을 줄여요'),
              ),
              BrandSwitch(
                  value: store.settings.compressPhotos,
                  onChanged: store.setCompressPhotos),
            ]),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('데이터 삭제'),
          RowGroup(children: [
            ListRow(
              title: '모든 데이터 삭제',
              subtitle: '되돌릴 수 없어요 · 삭제 전 백업 권장',
              titleColor: c.danger,
              onTap: _deleteAll,
            ),
          ]),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: PrimaryButton(
            label: busy ? '만드는 중…' : '백업 파일 만들기',
            onPressed: busy ? null : _make),
      ),
    );
  }
}

/// S-61-2 모든 데이터 삭제 (2단계, "삭제" 입력)
class _DeleteAllDialog extends StatefulWidget {
  const _DeleteAllDialog({required this.lastBackup});

  final DateTime? lastBackup;

  @override
  State<_DeleteAllDialog> createState() => _DeleteAllDialogState();
}

class _DeleteAllDialogState extends State<_DeleteAllDialog> {
  final ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ok = ctl.text.trim() == '삭제';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2 / 2 단계', style: ts(context, 12, color: c.textSecondary)),
            const SizedBox(height: 8),
            Text('모든 데이터를 삭제할까요?',
                style: ts(context, 18, w: FontWeight.w700, color: c.danger)),
            const SizedBox(height: 10),
            Text('라운드 · 스코어 · 다이어리 사진 · 파크골프장 · 동반자 · 설정이 모두 지워지고 되돌릴 수 없어요.',
                style: ts(context, 14, color: c.textSecondary, height: 1.45)),
            const SizedBox(height: 12),
            InfoBox(
              warning: true,
              title: widget.lastBackup == null
                  ? '아직 백업 파일이 없어요 · 삭제 전에 백업을 만들어 두세요'
                  : '마지막 백업 ${md(widget.lastBackup!)} · 삭제 전에 백업 파일을 만들어 두세요',
            ),
            const SizedBox(height: 14),
            Text('확인을 위해 "삭제"를 입력하세요',
                style: ts(context, 13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: ctl,
              onChanged: (_) => setState(() {}),
              style: ts(context, 15),
              decoration: const InputDecoration(hintText: '삭제'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: LineButton(
                      label: '취소',
                      height: 50,
                      onPressed: () => Navigator.pop(context, false))),
              const SizedBox(width: 8),
              Expanded(
                  child: PrimaryButton(
                      label: '삭제',
                      height: 50,
                      color: c.danger,
                      onPressed: ok ? () => Navigator.pop(context, true) : null)),
            ]),
          ],
        ),
      ),
    );
  }
}
