/// 앱 데이터 모델. 모든 데이터는 휴대폰에 JSON 으로 저장돼요.
library;

/// 9홀 코스 하나. pars 는 홀별 파(3·4·5), 아직 모르면 null.
class Course {
  Course({required this.name, List<int?>? pars})
      : pars = pars ?? List<int?>.filled(9, null);

  String name;
  final List<int?> pars;

  bool get parsComplete => pars.every((p) => p != null);
  int get parTotal => pars.fold(0, (a, p) => a + (p ?? 0));

  Course copy() => Course(name: name, pars: List<int?>.from(pars));

  Map<String, dynamic> toJson() => {'name': name, 'pars': pars};
  factory Course.fromJson(Map<String, dynamic> j) => Course(
        name: j['name'] as String,
        pars: (j['pars'] as List).map((e) => e as int?).toList(),
      );
}

/// 파크골프장. builtIn 은 앱에 들어 있는 공공데이터 목록에서 온 것.
class Park {
  Park({
    required this.id,
    required this.name,
    this.address = '',
    this.region = '',
    required this.courses,
    this.builtIn = false,
  });

  final String id;
  String name;
  String address;
  String region;
  final List<Course> courses;
  final bool builtIn;

  int get holes => courses.length * 9;

  String get summary => '$holes홀 · ${courses.length}코스';

  Park copy() => Park(
        id: id,
        name: name,
        address: address,
        region: region,
        courses: courses.map((c) => c.copy()).toList(),
        builtIn: builtIn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'region': region,
        'builtIn': builtIn,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  factory Park.fromJson(Map<String, dynamic> j) => Park(
        id: j['id'] as String,
        name: j['name'] as String,
        address: (j['address'] ?? '') as String,
        region: (j['region'] ?? '') as String,
        builtIn: (j['builtIn'] ?? false) as bool,
        courses: (j['courses'] as List)
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 내 한 홀 기록. toGreen 은 벌타를 포함한 그린까지 타수, penalty 는 그중 벌타.
class HoleScore {
  const HoleScore({required this.toGreen, required this.putts, this.penalty = 0});

  final int toGreen;
  final int putts;
  final int penalty;

  int get total => toGreen + putts;

  HoleScore copyWith({int? toGreen, int? putts, int? penalty}) => HoleScore(
        toGreen: toGreen ?? this.toGreen,
        putts: putts ?? this.putts,
        penalty: penalty ?? this.penalty,
      );

  Map<String, dynamic> toJson() => {'g': toGreen, 'p': putts, 'b': penalty};
  factory HoleScore.fromJson(Map<String, dynamic> j) => HoleScore(
        toGreen: j['g'] as int,
        putts: j['p'] as int,
        penalty: (j['b'] ?? 0) as int,
      );

  @override
  bool operator ==(Object other) =>
      other is HoleScore &&
      other.toGreen == toGreen &&
      other.putts == putts &&
      other.penalty == penalty;

  @override
  int get hashCode => Object.hash(toGreen, putts, penalty);
}

class Round {
  Round({
    required this.id,
    required this.parkId,
    required this.parkName,
    required this.date,
    required this.courseNames,
    required this.pars,
    required this.companions,
    List<HoleScore?>? mine,
    List<List<int?>>? others,
    this.done = false,
    this.deletedAt,
    this.memo = '',
    List<String>? photos,
  })  : mine = mine ?? List<HoleScore?>.filled(pars.length, null),
        others = others ??
            List.generate(
                companions.length, (_) => List<int?>.filled(pars.length, null)),
        photos = photos ?? [];

  final String id;
  final String parkId;
  String parkName;
  DateTime date;
  final List<String> courseNames;
  final List<int> pars;

  /// 동반자 이름 (나 제외).
  final List<String> companions;

  /// 내 홀별 기록.
  final List<HoleScore?> mine;

  /// 동반자별 홀별 총 타수.
  final List<List<int?>> others;

  bool done;
  DateTime? deletedAt;
  String memo;

  /// 사진 파일 이름 (앱 문서 폴더/photos 안).
  final List<String> photos;

  int get holeCount => pars.length;
  int get parTotal => pars.fold(0, (a, b) => a + b);

  /// 홀 i 가 속한 코스 이름과 코스 안의 홀 번호(1~9).
  String courseOf(int i) => courseNames[i ~/ 9];
  int holeNoInCourse(int i) => i % 9 + 1;

  int get myEntered => mine.where((h) => h != null).length;
  bool get myComplete => myEntered == holeCount;

  int get myTotal => mine.fold(0, (a, h) => a + (h?.total ?? 0));
  int get myPutts => mine.fold(0, (a, h) => a + (h?.putts ?? 0));
  int get myPenalty => mine.fold(0, (a, h) => a + (h?.penalty ?? 0));

  /// 입력한 홀만 기준으로 한 파 대비 타수.
  int get myOver {
    var over = 0;
    for (var i = 0; i < holeCount; i++) {
      final h = mine[i];
      if (h != null) over += h.total - pars[i];
    }
    return over;
  }

  int otherTotal(int k) => others[k].fold(0, (a, v) => a + (v ?? 0));
  int otherEntered(int k) => others[k].where((v) => v != null).length;

  int get birdies {
    var n = 0;
    for (var i = 0; i < holeCount; i++) {
      final h = mine[i];
      if (h != null && h.total == pars[i] - 1) n++;
    }
    return n;
  }

  String get courseRoute => courseNames.join(' → ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'parkId': parkId,
        'parkName': parkName,
        'date': date.toIso8601String(),
        'courseNames': courseNames,
        'pars': pars,
        'companions': companions,
        'mine': mine.map((h) => h?.toJson()).toList(),
        'others': others,
        'done': done,
        'deletedAt': deletedAt?.toIso8601String(),
        'memo': memo,
        'photos': photos,
      };

  factory Round.fromJson(Map<String, dynamic> j) => Round(
        id: j['id'] as String,
        parkId: j['parkId'] as String,
        parkName: j['parkName'] as String,
        date: DateTime.parse(j['date'] as String),
        courseNames: (j['courseNames'] as List).cast<String>(),
        pars: (j['pars'] as List).cast<int>(),
        companions: (j['companions'] as List).cast<String>(),
        mine: (j['mine'] as List)
            .map((e) =>
                e == null ? null : HoleScore.fromJson(e as Map<String, dynamic>))
            .toList(),
        others: (j['others'] as List)
            .map((l) => (l as List).map((e) => e as int?).toList())
            .toList(),
        done: (j['done'] ?? false) as bool,
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.parse(j['deletedAt'] as String),
        memo: (j['memo'] ?? '') as String,
        photos: ((j['photos'] ?? []) as List).cast<String>(),
      );
}

enum ScoreDisplay { overPar, total }

enum AppThemeMode { system, light, dark }

class Settings {
  Settings({
    this.scoreDisplay = ScoreDisplay.overPar,
    this.themeMode = AppThemeMode.system,
    this.compressPhotos = true,
    this.lastBackupAt,
  });

  ScoreDisplay scoreDisplay;
  AppThemeMode themeMode;
  bool compressPhotos;
  DateTime? lastBackupAt;

  Map<String, dynamic> toJson() => {
        'scoreDisplay': scoreDisplay.name,
        'themeMode': themeMode.name,
        'compressPhotos': compressPhotos,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        scoreDisplay: ScoreDisplay.values.firstWhere(
            (e) => e.name == j['scoreDisplay'],
            orElse: () => ScoreDisplay.overPar),
        themeMode: AppThemeMode.values.firstWhere(
            (e) => e.name == j['themeMode'],
            orElse: () => AppThemeMode.system),
        compressPhotos: (j['compressPhotos'] ?? true) as bool,
        lastBackupAt: j['lastBackupAt'] == null
            ? null
            : DateTime.parse(j['lastBackupAt'] as String),
      );
}

/// 휴대폰에 저장되는 전체 데이터.
class AppData {
  AppData({
    this.nickname,
    Settings? settings,
    List<Park>? parks,
    List<String>? favorites,
    List<String>? recentParkIds,
    List<String>? recentCompanions,
    List<Round>? rounds,
  })  : settings = settings ?? Settings(),
        parks = parks ?? [],
        favorites = favorites ?? [],
        recentParkIds = recentParkIds ?? [],
        recentCompanions = recentCompanions ?? [],
        rounds = rounds ?? [];

  static const schemaVersion = 1;

  String? nickname;
  final Settings settings;

  /// 직접 추가했거나 홀별 파를 입력한 파크골프장.
  final List<Park> parks;
  final List<String> favorites;
  final List<String> recentParkIds;
  final List<String> recentCompanions;
  final List<Round> rounds;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'nickname': nickname,
        'settings': settings.toJson(),
        'parks': parks.map((p) => p.toJson()).toList(),
        'favorites': favorites,
        'recentParkIds': recentParkIds,
        'recentCompanions': recentCompanions,
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        nickname: j['nickname'] as String?,
        settings: j['settings'] == null
            ? null
            : Settings.fromJson(j['settings'] as Map<String, dynamic>),
        parks: ((j['parks'] ?? []) as List)
            .map((e) => Park.fromJson(e as Map<String, dynamic>))
            .toList(),
        favorites: ((j['favorites'] ?? []) as List).cast<String>(),
        recentParkIds: ((j['recentParkIds'] ?? []) as List).cast<String>(),
        recentCompanions:
            ((j['recentCompanions'] ?? []) as List).cast<String>(),
        rounds: ((j['rounds'] ?? []) as List)
            .map((e) => Round.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
