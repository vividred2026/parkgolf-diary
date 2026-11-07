import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/rules.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/library.dart';

/// S-35 라운드 다이어리 (메모 · 사진 · 자동 하이라이트)
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.roundId});

  final String roundId;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final TextEditingController memo;
  bool adding = false;

  @override
  void initState() {
    super.initState();
    memo = TextEditingController(
      text: context.read<AppStore>().roundById(widget.roundId)?.memo ?? '',
    );
  }

  @override
  void dispose() {
    memo.dispose();
    super.dispose();
  }

  Future<void> _addPhotos(Round r) async {
    final store = context.read<AppStore>();
    setState(() => adding = true);
    try {
      final compress = store.settings.compressPhotos;
      final files = await ImagePicker().pickMultiImage(
        imageQuality: compress ? 80 : null,
        maxWidth: compress ? 2048 : null,
        maxHeight: compress ? 2048 : null,
      );
      for (final f in files) {
        final ext = f.name.contains('.')
            ? f.name.split('.').last.toLowerCase()
            : 'jpg';
        await store.addPhoto(r, await f.readAsBytes(), ext);
      }
    } catch (_) {
      if (mounted) toast(context, '사진을 불러오지 못했어요 · 사진 권한을 확인해 주세요');
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> _removePhoto(Round r, String name) async {
    final ok = await confirmDialog(
      context,
      title: '사진을 지울까요?',
      confirm: '지우기',
      danger: true,
    );
    if (ok && mounted) await context.read<AppStore>().removePhoto(r, name);
  }

  void _save(Round r) {
    r.memo = memo.text.trim();
    context.read<AppStore>().touch();
    Navigator.pop(context);
    toast(context, '다이어리를 저장했어요');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final r = store.roundById(widget.roundId);
    if (r == null) return const Scaffold();
    final c = context.c;

    final birdieHoles = [
      for (var i = 0; i < r.holeCount; i++)
        if (r.mine[i] != null && r.mine[i]!.total < r.pars[i]) i + 1,
    ];
    final avgPutts = Stats(store.liveRounds).avgPutts;

    return Scaffold(
      appBar: const TopBar(title: '다이어리'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
        children: [
          BoxCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.parkName} · ${formatRoundScoreWithUnit(r, store.settings.scoreDisplay)}',
                  style: ts(context, 15, w: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ymd(r.date)} (${weekday(r.date)}) · ${r.courseRoute}',
                  style: ts(context, 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionLabel(
            '사진 ${r.photos.length}',
            trailing: GestureDetector(
              onTap: adding ? null : () => _addPhotos(r),
              child: Text(
                adding ? '추가 중…' : '+ 추가',
                style: ts(
                  context,
                  13,
                  w: FontWeight.w700,
                  color: c.brandPrimary,
                ),
              ),
            ),
          ),
          if (r.photos.isEmpty)
            BoxCard(
              onTap: () => _addPhotos(r),
              color: c.surfaceSubtle,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '스코어카드 · 홀 · 동반자 사진을 남겨 보세요',
                  style: ts(context, 13, color: c.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onLongPress: () => _removePhoto(r, r.photos[i]),
                  child: _Photo(key: ValueKey(r.photos[i]), name: r.photos[i]),
                ),
              ),
            ),
          const SizedBox(height: 6),
          NoteText(
            store.settings.compressPhotos
                ? '화질을 유지하며 용량을 줄여 저장해요 · 길게 누르면 지워요'
                : '원본 그대로 저장해요 · 길게 누르면 지워요',
          ),
          const SizedBox(height: 18),
          const SectionLabel('메모'),
          TextField(
            controller: memo,
            minLines: 3,
            maxLines: 8,
            style: ts(context, 14, height: 1.5),
            decoration: const InputDecoration(
              hintText: '오늘 라운드에서 기억할 것을 적어 보세요',
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('이번 라운드 하이라이트 (자동)'),
          RowGroup(
            children: [
              ListRow(
                title: '버디',
                trailing: birdieHoles.isEmpty
                    ? '없음'
                    : birdieHoles.map((h) => '$h번홀').join(' · '),
              ),
              ListRow(
                title: '퍼트',
                trailing: avgPutts == null || !r.myComplete
                    ? '${r.myPutts}개'
                    : '${r.myPutts}개 (평균 ${signed((r.myPutts - avgPutts).round())})',
              ),
              ListRow(title: '벌타', trailing: '${r.myPenalty}타'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: PrimaryButton(label: '저장', onPressed: () => _save(r)),
      ),
    );
  }
}

class _Photo extends StatefulWidget {
  const _Photo({super.key, required this.name});

  final String name;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late Future<Uint8List?> bytes = context.read<AppStore>().storage.readPhoto(
    widget.name,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder<Uint8List?>(
        future: bytes,
        builder: (context, snap) => Container(
          width: 84,
          height: 84,
          color: context.c.surfaceSubtle,
          child: snap.data == null
              ? null
              : Image.memory(
                  snap.data!,
                  fit: BoxFit.cover,
                  cacheWidth: 252,
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}
