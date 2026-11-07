import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../logic/earbuds.dart';

/// 주변에서 찾은 블루투스 기기.
class FoundDevice {
  FoundDevice({
    required this.name,
    required this.address,
    required this.audio,
    required this.mic,
    required this.bonded,
  });

  final String name;
  final String address;
  final bool audio;
  final bool mic;
  bool bonded;
}

enum AacpState { none, connecting, connected, failed }

/// 블루투스 이어폰 연동 상태 (Android 전용 · 다른 플랫폼은 미지원).
class EarphoneService extends ChangeNotifier {
  EarphoneService({this.demo = false});

  static EarphoneService instance = EarphoneService();

  static const _method = MethodChannel('parkgolf/earphone');
  static const _events = EventChannel('parkgolf/earphone/events');

  /// 미리보기 · 테스트용 예시 상태.
  final bool demo;

  bool supported = false;
  bool enabled = false;
  bool connected = false;
  String? name;
  String? address;
  bool mic = false;

  /// 시스템(HFP)이 알려 준 전체 배터리.
  int? battery;
  PodsStatus pods = const PodsStatus();
  AacpState aacp = AacpState.none;
  ListenMode? listenMode;
  EarInfo? info;

  bool permissionsOk = false;
  bool discovering = false;
  final Map<String, FoundDevice> found = {};
  String? bondingAddress;

  StreamSubscription<dynamic>? _sub;
  bool _started = false;
  DateTime? _bleSeenAt;

  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 이어폰 배터리 중 낮은 값 (왼쪽 · 오른쪽 → 전체 배터리 순).
  int? get lowestBattery => pods.lowestBud ?? battery;

  /// 착용 개수 (모르면 null — 착용 감지는 에어팟에서만 돼요).
  int? get wornCount => connected ? pods.wornCount : null;

  bool get canChangeListenMode => aacp == AacpState.connected;
  bool get canRename => aacp == AacpState.connected;

  String get batteryLabel {
    if (pods.left != null || pods.right != null) {
      return 'L ${pods.left ?? '–'} · R ${pods.right ?? '–'}';
    }
    if (battery != null) return '$battery%';
    return '연결됨';
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (demo) {
      _fillDemo();
      return;
    }
    if (!android) return;
    supported = true;
    permissionsOk = await _hasPermissions();
    _sub = _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    await refresh();
  }

  void _fillDemo() {
    supported = true;
    enabled = true;
    connected = true;
    permissionsOk = true;
    name = 'Galaxy Buds3 Pro';
    mic = true;
    battery = 80;
    pods = const PodsStatus(
      left: 80,
      right: 75,
      caseLevel: 60,
      caseCharging: true,
      leftInEar: true,
      rightInEar: true,
    );
    aacp = AacpState.connected;
    listenMode = ListenMode.transparency;
    info = const EarInfo(
      name: '라이언의 Buds',
      model: 'SM-R630',
      manufacturer: 'Samsung',
      serial: 'R3CX0000002F',
      firmware: 'R630XXU0AXK1',
    );
    found
      ..clear()
      ..addAll({
        'a': FoundDevice(
          name: 'Galaxy Buds3 Pro',
          address: 'a',
          audio: true,
          mic: true,
          bonded: true,
        ),
        'b': FoundDevice(
          name: 'AirPods Pro',
          address: 'b',
          audio: true,
          mic: true,
          bonded: false,
        ),
        'c': FoundDevice(
          name: 'JBL Go 3',
          address: 'c',
          audio: true,
          mic: false,
          bonded: false,
        ),
      });
  }

  Future<bool> _hasPermissions() async {
    final s = await Future.wait([
      Permission.bluetoothConnect.status,
      Permission.bluetoothScan.status,
    ]);
    return s.every((x) => x.isGranted || x.isLimited);
  }

  /// 블루투스 권한 요청 (안드로이드 12+: 근처 기기, 11 이하: 위치).
  Future<bool> requestPermissions() async {
    if (demo) return true;
    if (!android) return false;
    final r = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    permissionsOk =
        (r[Permission.bluetoothConnect]?.isGranted ?? false) &&
        (r[Permission.bluetoothScan]?.isGranted ?? false);
    notifyListeners();
    if (permissionsOk) await refresh();
    return permissionsOk;
  }

  Future<T?> _call<T>(String m, [Map<String, dynamic>? args]) async {
    if (demo || !android) return null;
    try {
      return await _method.invokeMethod<T>(m, args);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    final s = await _call<Map<dynamic, dynamic>>('state');
    if (s != null) _applyState(s);
  }

  void _applyState(Map<dynamic, dynamic> s) {
    final was = connected;
    final wasAddr = address;
    enabled = s['enabled'] == true;
    connected = s['connected'] == true;
    name = s['name'] as String?;
    address = s['address'] as String?;
    mic = s['mic'] == true;
    battery = s['battery'] as int?;
    if (!connected || wasAddr != address) {
      pods = const PodsStatus();
      listenMode = null;
      info = null;
      if (aacp != AacpState.none) _call('aacpStop');
      aacp = AacpState.none;
    }
    if (connected && (!was || wasAddr != address)) {
      _call('startBle');
      _tryAacp();
    }
    if (!connected) _call('stopBle');
    notifyListeners();
  }

  /// 에어팟 · 비츠로 보이면 AACP 채널을 열어 봐요 (휴대폰이 막으면 실패).
  void _tryAacp() {
    final n = (name ?? '').toLowerCase();
    final apple =
        n.contains('airpods') ||
        n.contains('beats') ||
        n.contains('에어팟') ||
        (_bleSeenAt != null &&
            DateTime.now().difference(_bleSeenAt!) <
                const Duration(seconds: 30));
    if (!apple || aacp == AacpState.connecting || aacp == AacpState.connected) {
      return;
    }
    aacp = AacpState.connecting;
    _call('aacpStart');
  }

  void _onEvent(dynamic e) {
    if (e is! Map) return;
    switch (e['type']) {
      case 'state':
        _applyState(e);
      case 'found':
        final addr = e['address'] as String?;
        final n = e['name'] as String?;
        if (addr == null || n == null || n.isEmpty) return;
        found[addr] = FoundDevice(
          name: n,
          address: addr,
          audio: e['audio'] == true,
          mic: e['mic'] == true || e['headset'] == true,
          bonded: e['bonded'] == true,
        );
        notifyListeners();
      case 'discoveryDone':
        discovering = false;
        notifyListeners();
      case 'bond':
        final addr = e['address'] as String?;
        if (addr != null && found[addr] != null && e['bonded'] == true) {
          found[addr]!.bonded = true;
        }
        if (e['bonding'] != true) bondingAddress = null;
        notifyListeners();
        refresh();
      case 'ble':
        final data = e['data'];
        if (data is Uint8List && connected) {
          final p = AppleBle.parse(data);
          if (p != null) {
            _bleSeenAt = DateTime.now();
            // AACP(1% 단위)가 연결돼 있으면 BLE(10% 단위)는 착용 정보만 보조로 써요.
            pods = aacp == AacpState.connected
                ? pods.merge(
                    PodsStatus(
                      leftInEar: p.leftInEar,
                      rightInEar: p.rightInEar,
                    ),
                  )
                : pods.merge(p);
            notifyListeners();
            _tryAacp();
          }
        }
      case 'aacpState':
        aacp = switch (e['state']) {
          'connected' => AacpState.connected,
          'failed' => AacpState.failed,
          _ => AacpState.none,
        };
        notifyListeners();
      case 'aacp':
        final data = e['data'];
        if (data is Uint8List) {
          final u = Aacp.parse(data);
          if (u == null) return;
          if (u.pods != null) pods = pods.merge(u.pods!);
          if (u.listenMode != null) listenMode = u.listenMode;
          if (u.info != null) info = u.info;
          notifyListeners();
        }
    }
  }

  Future<List<FoundDevice>> loadBonded() async {
    if (demo) return found.values.where((d) => d.bonded).toList();
    final list = await _call<List<dynamic>>('bonded') ?? [];
    for (final m in list.cast<Map<dynamic, dynamic>>()) {
      final addr = m['address'] as String?;
      final n = m['name'] as String?;
      if (addr == null || n == null) continue;
      if (m['audio'] != true) continue;
      found[addr] = FoundDevice(
        name: n,
        address: addr,
        audio: true,
        mic: m['mic'] == true || m['headset'] == true,
        bonded: true,
      );
    }
    notifyListeners();
    return found.values.toList();
  }

  Future<void> startDiscovery() async {
    if (demo) return;
    found.removeWhere((k, v) => !v.bonded);
    discovering = (await _call<bool>('startDiscovery')) ?? false;
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    discovering = false;
    await _call('stopDiscovery');
    notifyListeners();
  }

  Future<bool> pair(FoundDevice d) async {
    bondingAddress = d.address;
    notifyListeners();
    final ok = (await _call<bool>('pair', {'address': d.address})) ?? demo;
    if (!ok) bondingAddress = null;
    notifyListeners();
    return ok;
  }

  Future<bool> disconnect() async {
    if (address == null) return false;
    return (await _call<bool>('disconnect', {'address': address})) ?? false;
  }

  Future<void> openSettings() => _call('openSettings');

  Future<bool> setListenMode(ListenMode m) async {
    if (demo) {
      listenMode = m;
      notifyListeners();
      return true;
    }
    if (!canChangeListenMode) return false;
    final ok =
        (await _call<bool>('aacpSend', {'data': Aacp.listenModePacket(m)})) ??
        false;
    if (ok) {
      listenMode = m;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> rename(String newName) async {
    final p = Aacp.renamePacket(newName);
    if (p == null) return false;
    if (demo) {
      info = EarInfo(
        name: newName.trim(),
        model: info?.model ?? '',
        manufacturer: info?.manufacturer ?? '',
        serial: info?.serial ?? '',
        firmware: info?.firmware ?? '',
      );
      notifyListeners();
      return true;
    }
    if (!canRename) return false;
    final ok = (await _call<bool>('aacpSend', {'data': p})) ?? false;
    if (ok && info != null) {
      info = EarInfo(
        name: newName.trim(),
        model: info!.model,
        manufacturer: info!.manufacturer,
        serial: info!.serial,
        firmware: info!.firmware,
      );
      notifyListeners();
    }
    return ok;
  }

  /// 이어폰 마이크(SCO)로 듣기 시작 / 끝.
  Future<bool> earMic(bool on) async =>
      (await _call<bool>(on ? 'scoStart' : 'scoStop')) ?? false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
