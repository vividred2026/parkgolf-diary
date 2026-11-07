import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'park_catalog.dart';
import 'storage.dart';

/// 앱 전체 상태. 바뀔 때마다 휴대폰에 바로 저장해요.
class AppStore extends ChangeNotifier {
  AppStore(this.storage, this.catalog, [AppData? data])
    : data = data ?? AppData();

  final Storage storage;
  final ParkCatalog catalog;
  AppData data;

  static const trashDays = 30;
  static const _uuid = Uuid();

  Future<void> _pending = Future.value();

  static Future<AppStore> open(
    Storage storage,
    ParkCatalog catalog, {
    DateTime? now,
  }) async {
    final raw = await storage.readData();
    AppData data;
    try {
      data = raw == null
          ? AppData()
          : AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      data = AppData();
    }
    final s = AppStore(storage, catalog, data);
    await s.purgeTrash(now ?? DateTime.now());
    return s;
  }

  /// 저장은 순서대로 하나씩 해요.
  Future<void> save() {
    final json = jsonEncode(data.toJson());
    _pending = _pending.then((_) => storage.writeData(json));
    return _pending;
  }

  void _changed() {
    notifyListeners();
    save();
  }

  // ── 프로필 · 설정 ─────────────────────────────

  String get nickname => data.nickname ?? '';
  bool get onboarded => (data.nickname ?? '').isNotEmpty;
  Settings get settings => data.settings;

  void setNickname(String v) {
    data.nickname = v.trim();
    _changed();
  }

  void setScoreDisplay(ScoreDisplay d) {
    data.settings.scoreDisplay = d;
    _changed();
  }

  void setThemeMode(AppThemeMode m) {
    data.settings.themeMode = m;
    _changed();
  }

  void setCompressPhotos(bool v) {
    data.settings.compressPhotos = v;
    _changed();
  }

  void setEarphone({bool? autoPause, bool? lowBattery, bool? mic}) {
    final s = data.settings;
    if (autoPause != null) s.earAutoPause = autoPause;
    if (lowBattery != null) s.earLowBattery = lowBattery;
    if (mic != null) s.earMic = mic;
    _changed();
  }

  // ── 파크골프장 ─────────────────────────────

  /// 공공데이터 목록 + 직접 추가 · 수정한 파크골프장.
  List<Park> get allParks {
    final mine = {for (final p in data.parks) p.id: p};
    return [
      ...catalog.parks.map((p) => mine.remove(p.id) ?? p),
      ...mine.values,
    ];
  }

  Park? parkById(String id) {
    for (final p in data.parks) {
      if (p.id == id) return p;
    }
    for (final p in catalog.parks) {
      if (p.id == id) return p;
    }
    return null;
  }

  void savePark(Park park) {
    final i = data.parks.indexWhere((p) => p.id == park.id);
    if (i >= 0) {
      data.parks[i] = park;
    } else {
      data.parks.add(park);
    }
    _changed();
  }

  Park newCustomPark({
    required String name,
    required String region,
    required List<String> courseNames,
  }) => Park(
    id: 'my-${_uuid.v4()}',
    name: name.trim(),
    region: region.trim(),
    courses: courseNames.map((n) => Course(name: n)).toList(),
  );

  bool isFavorite(String id) => data.favorites.contains(id);

  void toggleFavorite(String id) {
    if (!data.favorites.remove(id)) data.favorites.add(id);
    _changed();
  }

  List<Park> get favoriteParks =>
      data.favorites.map(parkById).whereType<Park>().toList();

  List<Park> get recentParks =>
      data.recentParkIds.map(parkById).whereType<Park>().toList();

  int roundCountAt(String parkId) =>
      liveRounds.where((r) => r.parkId == parkId && r.done).length;

  // ── 라운드 ─────────────────────────────

  List<Round> get liveRounds =>
      data.rounds.where((r) => r.deletedAt == null).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Round> get doneRounds => liveRounds.where((r) => r.done).toList();

  Round? get inProgress {
    for (final r in liveRounds) {
      if (!r.done) return r;
    }
    return null;
  }

  Round? roundById(String id) {
    for (final r in data.rounds) {
      if (r.id == id) return r;
    }
    return null;
  }

  Round startRound({
    required Park park,
    required List<int> courseIndexes,
    required List<String> companions,
    DateTime? date,
  }) {
    final courses = courseIndexes.map((i) => park.courses[i]).toList();
    final r = Round(
      id: _uuid.v4(),
      parkId: park.id,
      parkName: park.name,
      date: date ?? DateTime.now(),
      courseNames: courses.map((c) => c.name).toList(),
      pars: [for (final c in courses) ...c.pars.map((p) => p ?? 4)],
      companions: List.of(companions),
    );
    data.rounds.add(r);
    data.recentParkIds
      ..remove(park.id)
      ..insert(0, park.id);
    if (data.recentParkIds.length > 10) data.recentParkIds.removeLast();
    for (final n in companions.reversed) {
      data.recentCompanions
        ..remove(n)
        ..insert(0, n);
    }
    if (data.recentCompanions.length > 12) {
      data.recentCompanions.removeRange(12, data.recentCompanions.length);
    }
    _changed();
    return r;
  }

  void setMine(Round r, int hole, HoleScore? v) {
    r.mine[hole] = v;
    _changed();
  }

  void setOther(Round r, int k, int hole, int? v) {
    r.others[k][hole] = v;
    _changed();
  }

  void finishRound(Round r) {
    r.done = true;
    _changed();
  }

  void touch() => _changed();

  /// 삭제하면 30일 동안 휴지통에 보관해요.
  void deleteRound(Round r, {DateTime? now}) {
    r.deletedAt = now ?? DateTime.now();
    _changed();
  }

  void restoreRound(Round r) {
    r.deletedAt = null;
    _changed();
  }

  List<Round> get trash =>
      data.rounds.where((r) => r.deletedAt != null).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  int daysLeft(Round r, DateTime now) =>
      trashDays - now.difference(r.deletedAt!).inDays;

  Future<void> _removeForever(Iterable<Round> rs) async {
    final list = rs.toList();
    for (final r in list) {
      for (final p in r.photos) {
        await storage.deletePhoto(p);
      }
      data.rounds.remove(r);
    }
  }

  Future<void> emptyTrash() async {
    await _removeForever(trash);
    _changed();
  }

  Future<void> purgeTrash(DateTime now) async {
    final old = trash.where((r) => daysLeft(r, now) <= 0);
    if (old.isEmpty) return;
    await _removeForever(old);
    await save();
  }

  // ── 다이어리 사진 ─────────────────────────────

  Future<void> addPhoto(Round r, Uint8List bytes, String ext) async {
    final name = '${r.id}-${_uuid.v4().substring(0, 8)}.$ext';
    await storage.savePhoto(name, bytes);
    r.photos.add(name);
    _changed();
  }

  Future<void> removePhoto(Round r, String name) async {
    r.photos.remove(name);
    await storage.deletePhoto(name);
    _changed();
  }

  int get photoCount => data.rounds.fold(0, (a, r) => a + r.photos.length);

  // ── 백업 · 초기화 ─────────────────────────────

  Future<void> replaceAll(AppData next, Map<String, Uint8List> photos) async {
    await storage.clearAll();
    for (final e in photos.entries) {
      await storage.savePhoto(e.key, e.value);
    }
    data = next;
    _changed();
    await _pending;
  }

  Future<void> deleteEverything() async {
    await storage.clearAll();
    data = AppData();
    notifyListeners();
  }

  void markBackedUp(DateTime at) {
    data.settings.lastBackupAt = at;
    _changed();
  }
}
