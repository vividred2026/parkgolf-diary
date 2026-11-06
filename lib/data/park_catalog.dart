import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// 앱에 들어 있는 전국 파크골프장 목록 (공공데이터 "파크골프장 표준데이터").
/// assets/data/parks.json — tools/build_parks.py 로 CSV 에서 만들어요.
class ParkCatalog {
  ParkCatalog(this.parks);

  final List<Park> parks;

  static Future<ParkCatalog> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/parks.json');
      return ParkCatalog(parse(raw));
    } catch (_) {
      return ParkCatalog([]);
    }
  }

  static List<Park> parse(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) {
      final j = e as Map<String, dynamic>;
      final holes = (j['holes'] as num?)?.toInt() ?? 9;
      var courseCount = (j['courses'] as num?)?.toInt() ?? 0;
      if (courseCount <= 0) courseCount = (holes / 9).ceil().clamp(1, 8);
      return Park(
        id: j['id'] as String,
        name: j['name'] as String,
        address: (j['address'] ?? '') as String,
        region: (j['region'] ?? '') as String,
        builtIn: true,
        courses: defaultCourses(courseCount),
      );
    }).toList();
  }

  static List<Course> defaultCourses(int n) => List.generate(
      n, (i) => Course(name: '${String.fromCharCode(65 + i)}코스'));

  /// 이름 · 주소 검색 (띄어쓰기 무시).
  static List<Park> search(Iterable<Park> parks, String q) {
    final k = q.replaceAll(' ', '').toLowerCase();
    if (k.isEmpty) return parks.toList();
    return parks
        .where((p) => '${p.name}${p.address}${p.region}'
            .replaceAll(' ', '')
            .toLowerCase()
            .contains(k))
        .toList();
  }
}
