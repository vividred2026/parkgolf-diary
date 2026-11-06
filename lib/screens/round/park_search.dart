import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/park_catalog.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'hole_par.dart';

/// S-14 파크골프장 검색 · 선택 (앱에 들어 있는 전국 목록, 인터넷 없이 검색)
class ParkSearchScreen extends StatefulWidget {
  const ParkSearchScreen({super.key});

  @override
  State<ParkSearchScreen> createState() => _ParkSearchScreenState();
}

enum _Tab { recent, favorite, all }

class _ParkSearchScreenState extends State<ParkSearchScreen> {
  final _q = TextEditingController();
  late _Tab tab =
      context.read<AppStore>().recentParks.isEmpty ? _Tab.all : _Tab.recent;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final p = await Navigator.push<Park>(
        context, MaterialPageRoute(builder: (_) => const ParkAddScreen()));
    if (p != null && mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.watch<AppStore>();
    final query = _q.text.trim();
    final source = query.isNotEmpty
        ? store.allParks
        : switch (tab) {
            _Tab.recent => store.recentParks,
            _Tab.favorite => store.favoriteParks,
            _Tab.all => store.allParks,
          };
    final list = ParkCatalog.search(source, query);

    return Scaffold(
      appBar: const TopBar(title: '파크골프장 선택'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
        children: [
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            style: ts(context, 15),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '파크골프장 이름 · 지역 검색',
              prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          if (query.isEmpty)
            Wrap(spacing: 8, children: [
              Pill(
                  label: '최근',
                  selected: tab == _Tab.recent,
                  onTap: () => setState(() => tab = _Tab.recent)),
              Pill(
                  label: '즐겨찾기',
                  selected: tab == _Tab.favorite,
                  onTap: () => setState(() => tab = _Tab.favorite)),
              Pill(
                  label: '전국',
                  selected: tab == _Tab.all,
                  onTap: () => setState(() => tab = _Tab.all)),
            ]),
          const SizedBox(height: 12),
          const InfoBox(
              warning: true,
              title: '전국 파크골프장 목록이 앱에 들어 있어요 · 인터넷 없이 검색'),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                    query.isNotEmpty
                        ? '"$query" 검색 결과가 없어요'
                        : tab == _Tab.favorite
                            ? '즐겨찾기한 파크골프장이 없어요.\n☆를 눌러 추가해 보세요.'
                            : '아직 다녀온 파크골프장이 없어요.',
                    textAlign: TextAlign.center,
                    style: ts(context, 13, color: c.textSecondary, height: 1.5)),
              ),
            )
          else
            RowGroup(children: [
              for (final p in list)
                InkWell(
                  onTap: () => Navigator.pop(context, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: ts(context, 14, w: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                [
                                  p.summary,
                                  if (p.region.isNotEmpty) p.region,
                                  if (!p.builtIn) '직접 추가',
                                ].join(' · '),
                                style:
                                    ts(context, 12, color: c.textSecondary)),
                          ],
                        ),
                      ),
                      if (store.roundCountAt(p.id) > 0)
                        Text('${store.roundCountAt(p.id)}회',
                            style: ts(context, 14,
                                w: FontWeight.w700, color: c.textSecondary)),
                      IconButton(
                        tooltip: store.isFavorite(p.id) ? '즐겨찾기 해제' : '즐겨찾기',
                        onPressed: () => store.toggleFavorite(p.id),
                        icon: Icon(
                          store.isFavorite(p.id)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: store.isFavorite(p.id)
                              ? c.brandPrimary
                              : c.textSecondary,
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: TextButton(
          onPressed: _add,
          child: Text('+ 목록에 없는 파크골프장 직접 추가',
              style: ts(context, 13, w: FontWeight.w700, color: c.textSecondary)),
        ),
      ),
    );
  }
}

/// S-14-2 파크골프장 직접 추가 (이 휴대폰에만 저장)
class ParkAddScreen extends StatefulWidget {
  const ParkAddScreen({super.key});

  @override
  State<ParkAddScreen> createState() => _ParkAddScreenState();
}

class _ParkAddScreenState extends State<ParkAddScreen> {
  final _name = TextEditingController();
  final _region = TextEditingController();
  final List<TextEditingController> _courses = [
    TextEditingController(text: 'A코스'),
    TextEditingController(text: 'B코스'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    for (final c in _courses) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _courses.every((c) => c.text.trim().isNotEmpty);

  Future<void> _next() async {
    final store = context.read<AppStore>();
    final park = store.newCustomPark(
      name: _name.text,
      region: _region.text,
      courseNames: _courses.map((c) => c.text.trim()).toList(),
    );
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HoleParScreen(
          park: park,
          courseIndexes: [for (var i = 0; i < park.courses.length; i++) i],
          finishLabel: '저장',
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, store.parkById(park.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: const TopBar(title: '파크골프장 추가'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
        children: [
          Text('전국 목록에 없는 파크골프장을 직접 추가해요. 이 휴대폰에만 저장돼요.',
              style: ts(context, 13, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          Text('파크골프장 이름', style: ts(context, 12, color: c.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
            style: ts(context, 15),
            decoration: const InputDecoration(hintText: '예) 탄천 파크골프장'),
          ),
          Text('지역', style: ts(context, 12, color: c.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _region,
            style: ts(context, 15),
            decoration: const InputDecoration(hintText: '예) 성남시 분당구'),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: Text('코스 (${_courses.length}코스 · ${_courses.length * 9}홀)',
                    style: ts(context, 13, w: FontWeight.w700))),
            IconButton(
              tooltip: '코스 빼기',
              onPressed: _courses.length > 1
                  ? () => setState(() => _courses.removeLast().dispose())
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            IconButton(
              tooltip: '코스 더하기',
              onPressed: _courses.length < 8
                  ? () => setState(() => _courses.add(TextEditingController(
                      text: '${String.fromCharCode(65 + _courses.length)}코스')))
                  : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ]),
          for (var i = 0; i < _courses.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _courses[i],
                onChanged: (_) => setState(() {}),
                style: ts(context, 15),
                decoration: InputDecoration(
                    prefixText: '${i + 1}.  ', hintText: '코스 이름'),
              ),
            ),
          const SizedBox(height: 6),
          const InfoBox(title: '다음 화면에서 홀별 파를 골라요 (규정집 3-3-3 개수 체크)'),
        ],
      ),
      bottomNavigationBar: BottomArea(
        child: PrimaryButton(
            label: '다음 · 홀별 파', onPressed: _valid ? _next : null),
      ),
    );
  }
}
