import 'dart:convert';
import 'dart:typed_data';

/// 이어폰 데이터 해석 (안드로이드 의존 없음 · 단위 테스트 가능).
/// - 에어팟 BLE 광고(애플 0x004C, 0x07 · 길이 0x19): 왼쪽 · 오른쪽 · 케이스 배터리(10% 단위) · 충전 · 착용
/// - 에어팟 AACP 메시지: 1% 배터리 · 착용 · 청취 모드 · 기기 정보, 청취 모드 · 이름 변경 요청

class PodsStatus {
  const PodsStatus({
    this.left,
    this.right,
    this.caseLevel,
    this.leftCharging = false,
    this.rightCharging = false,
    this.caseCharging = false,
    this.leftInEar,
    this.rightInEar,
  });

  /// 0~100, 모르면 null.
  final int? left;
  final int? right;
  final int? caseLevel;
  final bool leftCharging;
  final bool rightCharging;
  final bool caseCharging;
  final bool? leftInEar;
  final bool? rightInEar;

  bool get hasBattery => left != null || right != null || caseLevel != null;

  /// 귀에 끼고 있는 개수 (모르면 null).
  int? get wornCount => leftInEar == null && rightInEar == null
      ? null
      : (leftInEar == true ? 1 : 0) + (rightInEar == true ? 1 : 0);

  /// 이어폰(양쪽) 중 낮은 배터리.
  int? get lowestBud {
    final v = [left, right].whereType<int>();
    return v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
  }

  PodsStatus merge(PodsStatus o) => PodsStatus(
    left: o.left ?? left,
    right: o.right ?? right,
    caseLevel: o.caseLevel ?? caseLevel,
    leftCharging: o.left != null ? o.leftCharging : leftCharging,
    rightCharging: o.right != null ? o.rightCharging : rightCharging,
    caseCharging: o.caseLevel != null ? o.caseCharging : caseCharging,
    leftInEar: o.leftInEar ?? leftInEar,
    rightInEar: o.rightInEar ?? rightInEar,
  );
}

class AppleBle {
  /// 애플 광고는 [유형][길이][내용]이 이어붙어 올 수 있어 0x07 메시지만 꺼내요.
  static Uint8List? findProximity(Uint8List data) {
    var i = 0;
    while (i + 1 < data.length) {
      final type = data[i];
      final len = data[i + 1];
      if (type == 0x07) {
        final end = (i + 2 + len).clamp(0, data.length);
        return Uint8List.sublistView(data, i, end);
      }
      i += 2 + len;
    }
    return null;
  }

  static int? _battery(int raw) =>
      raw == 10 ? 100 : (raw < 10 ? raw * 10 + 5 : null);

  /// manufacturerSpecificData(0x004C) → 배터리 · 충전 · 착용. 형식이 아니면 null.
  static PodsStatus? parse(Uint8List raw) {
    final data = findProximity(raw);
    if (data == null || data.length < 16) return null;
    if (data[0] != 0x07 || data[1] != 0x19) return null;
    final s = data
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
    int hex(int i) => int.parse(s[i], radix: 16);
    final flip = (hex(10) & 0x02) == 0;
    final leftRaw = hex(flip ? 12 : 13);
    final rightRaw = hex(flip ? 13 : 12);
    final caseRaw = hex(15);
    final charge = hex(14);
    final status = int.parse(
      s.substring(10, 12),
      radix: 16,
    ).toRadixString(2).padLeft(8, '0');
    return PodsStatus(
      left: _battery(leftRaw),
      right: _battery(rightRaw),
      caseLevel: _battery(caseRaw),
      leftCharging: (charge & (flip ? 0x1 : 0x2)) != 0,
      rightCharging: (charge & (flip ? 0x2 : 0x1)) != 0,
      caseCharging: (charge & 0x4) != 0,
      leftInEar: status[flip ? 4 : 6] == '1',
      rightInEar: status[flip ? 6 : 4] == '1',
    );
  }
}

enum ListenMode { off, anc, transparency, adaptive }

extension ListenModeX on ListenMode {
  int get code => switch (this) {
    ListenMode.off => 0x01,
    ListenMode.anc => 0x02,
    ListenMode.transparency => 0x03,
    ListenMode.adaptive => 0x04,
  };
  String get label => switch (this) {
    ListenMode.off => '끄기',
    ListenMode.anc => '노이즈 캔슬링',
    ListenMode.transparency => '주변음 허용',
    ListenMode.adaptive => '적응형',
  };
  static ListenMode? fromCode(int c) =>
      ListenMode.values.where((m) => m.code == c).firstOrNull;
}

class EarInfo {
  const EarInfo({
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.serial,
    required this.firmware,
  });
  final String name;
  final String model;
  final String manufacturer;
  final String serial;
  final String firmware;
}

/// AACP 메시지 해석 결과 (해당 없는 항목은 null).
class AacpUpdate {
  AacpUpdate({this.pods, this.listenMode, this.info});
  final PodsStatus? pods;
  final ListenMode? listenMode;
  final EarInfo? info;
}

class Aacp {
  static const nameMaxBytes = 32;

  static int? opcode(Uint8List p) {
    if (p.length < 6 ||
        p[0] != 0x04 ||
        p[1] != 0x00 ||
        p[2] != 0x04 ||
        p[3] != 0x00) {
      return null;
    }
    return p[4] | (p[5] << 8);
  }

  static AacpUpdate? parse(Uint8List p) {
    final op = opcode(p);
    if (op == null) return null;
    switch (op) {
      case 0x04: // 배터리
        if (p.length < 7) return null;
        final n = p[6];
        int? l, r, c;
        var lc = false, rc = false, cc = false;
        for (var i = 0; i < n; i++) {
          final o = 7 + i * 5;
          if (o + 3 >= p.length) break;
          final level = p[o + 2].clamp(0, 100);
          final state = p[o + 3];
          if (state == 0x04) continue; // 연결 안 됨
          final charging = state == 0x01;
          switch (p[o]) {
            case 0x04:
              l = level;
              lc = charging;
            case 0x02:
              r = level;
              rc = charging;
            case 0x08:
              c = level;
              cc = charging;
            case 0x01:
              l = level;
              r = level;
          }
        }
        return AacpUpdate(
          pods: PodsStatus(
            left: l,
            right: r,
            caseLevel: c,
            leftCharging: lc,
            rightCharging: rc,
            caseCharging: cc,
          ),
        );
      case 0x06: // 착용: 0 = 귀, 1 = 밖, 2 = 케이스
        if (p.length < 8) return null;
        return AacpUpdate(
          pods: PodsStatus(leftInEar: p[6] == 0x00, rightInEar: p[7] == 0x00),
        );
      case 0x09: // 제어 — 청취 모드
        if (p.length >= 8 && p[6] == 0x0D) {
          return AacpUpdate(listenMode: ListenModeX.fromCode(p[7]));
        }
        return null;
      case 0x1D: // 기기 정보
        final tokens = <List<int>>[];
        var start = 6;
        for (var i = 6; i <= p.length; i++) {
          if (i == p.length || p[i] == 0) {
            if (i > start) tokens.add(p.sublist(start, i));
            start = i + 1;
          }
        }
        final strings = tokens
            .skipWhile((t) => t.any((b) => b < 0x20))
            .map((t) => utf8.decode(t, allowMalformed: true))
            .toList();
        if (strings.isEmpty) return null;
        String s(int i) => i < strings.length ? strings[i] : '';
        return AacpUpdate(
          info: EarInfo(
            name: s(0),
            model: s(1),
            manufacturer: s(2),
            serial: s(3),
            firmware: s(4),
          ),
        );
    }
    return null;
  }

  static Uint8List listenModePacket(ListenMode m) => Uint8List.fromList([
    0x04,
    0x00,
    0x04,
    0x00,
    0x09,
    0x00,
    0x0D,
    m.code,
    0x00,
    0x00,
    0x00,
  ]);

  /// 이름 변경 요청. 비었거나 너무 길면 null.
  static Uint8List? renamePacket(String name) {
    final n = utf8.encode(name.trim());
    if (n.isEmpty || n.length > nameMaxBytes) return null;
    return Uint8List.fromList([
      0x04,
      0x00,
      0x04,
      0x00,
      0x1A,
      0x00,
      0x01,
      n.length,
      0x00,
      ...n,
    ]);
  }

  /// 정보 · 키 등은 연결 직후 자동으로 오지만, 오지 않으면 다시 알림 요청.
  static final requestNotifications = Uint8List.fromList([
    0x04,
    0x00,
    0x04,
    0x00,
    0x0F,
    0x00,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
  ]);
}
