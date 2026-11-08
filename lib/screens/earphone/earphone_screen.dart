import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/earbuds.dart';
import '../../services/earphone.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/library.dart';

/// EP-05 이어폰 상태 (연결 후) · 연결 전에는 연결 안내.
class EarphoneScreen extends StatefulWidget {
  const EarphoneScreen({super.key});

  @override
  State<EarphoneScreen> createState() => _EarphoneScreenState();
}

class _EarphoneScreenState extends State<EarphoneScreen> {
  @override
  void initState() {
    super.initState();
    final ear = context.read<EarphoneService>();
    ear.start().then((_) async {
      if (!ear.permissionsOk) await ear.requestPermissions();
      await ear.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ear = context.watch<EarphoneService>();
    final store = context.watch<AppStore>();
    final c = context.c;
    final s = store.settings;

    Widget body;
    if (!ear.supported) {
      body = _Empty(
        title: '이 기기에서는 이어폰 연동을 쓸 수 없어요',
        body: '안드로이드 휴대폰에서 블루투스 이어폰을 연결할 수 있어요.',
      );
    } else if (!ear.permissionsOk) {
      body = _Empty(
        title: '근처 기기 권한이 필요해요',
        body: '연결된 이어폰과 배터리를 확인하고, 주변 이어폰을 찾을 때만 써요.',
        action: '권한 허용',
        onAction: ear.requestPermissions,
      );
    } else if (!ear.enabled) {
      body = _Empty(
        title: '블루투스가 꺼져 있어요',
        body: '휴대폰 블루투스를 켜면 이어폰을 연결할 수 있어요.',
        action: '블루투스 설정 열기',
        onAction: ear.openSettings,
      );
    } else if (!ear.connected) {
      body = _Empty(
        title: '연결된 이어폰이 없어요',
        body: '마이크가 있는 블루투스 이어폰을 연결하면 라운드 중 이어폰으로 말해서 입력하고, 배터리 · 착용 상태를 볼 수 있어요.',
        action: '이어폰 연결',
        onAction: () => PairingSheets.open(context),
      );
    } else {
      final p = ear.pods;
      body = ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          12,
          gutter,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          BoxCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ear.info?.name.isNotEmpty == true
                              ? ear.info!.name
                              : (ear.name ?? '이어폰'),
                          style: ts(context, 14, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (ear.info?.model.isNotEmpty == true)
                              ear.info!.model,
                            ear.mic ? '마이크 ✓' : '마이크 없음',
                          ].join(' · '),
                          style: ts(context, 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.circle, size: 8, color: c.brandPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '연결됨',
                    style: ts(
                      context,
                      14,
                      w: FontWeight.w700,
                      color: c.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BatteryCard(ear: ear),
          const SizedBox(height: 8),
          NoteText(_batteryNote(ear)),
          const SizedBox(height: 16),
          SectionLabel('청취 모드'),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [
                ListenMode.anc,
                ListenMode.transparency,
                ListenMode.off,
              ])
                Pill(
                  label: m.label,
                  selected: ear.listenMode == m,
                  onTap: ear.canChangeListenMode
                      ? () => ear.setListenMode(m)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          NoteText(
            ear.canChangeListenMode
                ? '코스에서는 타구 소리 · 경고를 듣도록 주변음 허용을 권장해요'
                : '청취 모드는 에어팟에서, 휴대폰이 허용할 때만 바꿀 수 있어요. 이어폰 버튼으로 바꿔 주세요.',
          ),
          const SizedBox(height: 16),
          const SectionLabel('자동'),
          RowGroup(
            children: [
              _SwitchRow(
                title: '귀에서 빼면 음성 입력 멈춤',
                subtitle: p.wornCount == null
                    ? '착용 감지를 지원하는 이어폰(에어팟)에서 동작해요'
                    : null,
                value: s.earAutoPause,
                onChanged: (v) => store.setEarphone(autoPause: v),
              ),
              _SwitchRow(
                title: '배터리 20% 이하면 알려 주기',
                value: s.earLowBattery,
                onChanged: (v) => store.setEarphone(lowBattery: v),
              ),
              _SwitchRow(
                title: '이어폰 마이크로 말하기',
                subtitle: ear.mic
                    ? '끄면 휴대폰 마이크로 들어요'
                    : '이 이어폰은 마이크가 없어 휴대폰 마이크로 들어요',
                value: s.earMic && ear.mic,
                onChanged: ear.mic ? (v) => store.setEarphone(mic: v) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RowGroup(
            children: [
              ListRow(
                title: '이어폰 정보',
                trailing: '이름 · 펌웨어',
                chevron: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EarphoneInfoScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LineButton(
            label: '연결 해제',
            onPressed: () async {
              final ok = await ear.disconnect();
              if (!ok && context.mounted) {
                toast(context, '이 휴대폰에서는 앱에서 연결을 끊을 수 없어요 · 블루투스 설정에서 끊어 주세요');
                ear.openSettings();
              }
            },
          ),
        ],
      );
    }

    final empty = body is _Empty ? body : null;
    return Scaffold(
      appBar: const TopBar(title: '이어폰'),
      body: body,
      // 빈 상태 버튼도 다른 화면처럼 하단 고정 영역에 둬서 내비게이션 바에 가리지 않게 해요
      bottomNavigationBar: empty == null || empty.action == null
          ? null
          : BottomArea(
              child: PrimaryButton(
                label: empty.action!,
                onPressed: empty.onAction,
              ),
            ),
    );
  }

  String _batteryNote(EarphoneService ear) {
    final w = ear.wornCount;
    final wear = w == null
        ? '착용 상태는 에어팟에서만 보여요'
        : (w == 2
              ? '양쪽 착용 중'
              : w == 1
              ? '한쪽 착용 중'
              : '착용 안 함');
    final unit = ear.aacp == AacpState.connected
        ? '배터리는 1% 단위예요'
        : '배터리는 이어폰이 알려 준 근사치예요';
    return '$wear · $unit';
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 24, gutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.headphones_rounded,
              size: 48,
              color: c.textDisabled,
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: ts(context, 18, w: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            body,
            style: ts(context, 14, color: c.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ListRow(title: title, subtitle: subtitle),
      ),
      Opacity(
        opacity: onChanged == null ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: onChanged == null,
          child: BrandSwitch(value: value, onChanged: onChanged ?? (_) {}),
        ),
      ),
    ],
  );
}

/// 왼쪽 · 오른쪽 · 케이스 배터리 (에어팟) 또는 전체 배터리.
class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.ear});

  final EarphoneService ear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = ear.pods;
    final cells = p.hasBattery
        ? [
            ('L', '왼쪽', p.left, p.leftCharging),
            ('R', '오른쪽', p.right, p.rightCharging),
            ('C', '케이스', p.caseLevel, p.caseCharging),
          ]
        : [('B', '전체', ear.battery, false)];
    return BoxCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          for (final (k, label, v, chg) in cells)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceSelected,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      k,
                      style: ts(
                        context,
                        16,
                        w: FontWeight.w800,
                        color: c.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v == null ? '–' : '$v%${chg ? ' ⚡' : ''}',
                    style: ts(
                      context,
                      16,
                      w: FontWeight.w700,
                      color: v != null && v <= 20 ? c.danger : c.textPrimary,
                    ),
                  ),
                  Text(
                    chg ? '$label · 충전 중' : label,
                    style: ts(context, 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// EP-03 페어링 모드 안내 → EP-04 주변 이어폰 목록.
class PairingSheets {
  static Future<void> open(BuildContext context) async {
    final ear = context.read<EarphoneService>();
    if (!ear.permissionsOk && !await ear.requestPermissions()) return;
    if (!context.mounted) return;
    final next = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PairGuideSheet(),
    );
    if (next != true || !context.mounted) return;
    ear.clearPairLog();
    await ear.loadBonded();
    await ear.startDiscovery();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DeviceListSheet(),
    );
    await ear.stopDiscovery();
    if (ear.pairLog.isEmpty || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PairProgressSheet(),
    );
  }
}

/// 이어폰 연결 중 — 페어링 · 음악 · 통화 연결 상태를 시간과 함께 보여 줘요 (AOS-Pods '에어팟 연결 중').
class _PairProgressSheet extends StatelessWidget {
  const _PairProgressSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ear = context.watch<EarphoneService>();
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            SheetHeader(
              ear.pairDone
                  ? '연결됐어요'
                  : ear.pairFailed
                  ? '연결하지 못했어요'
                  : '이어폰 연결 중',
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ear.pairingName ?? '',
                    style: ts(context, 15, w: FontWeight.w700),
                  ),
                ),
                if (!ear.pairDone && !ear.pairFailed)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.brandPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in ear.pairLog)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hm(l.at),
                            style: ts(context, 12, color: c.textDisabled),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.text,
                              style: ts(
                                context,
                                13,
                                w: l.done || l.failed
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: l.failed
                                    ? c.danger
                                    : l.done
                                    ? c.brandPrimary
                                    : c.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LineButton(
                    label: '블루투스 설정',
                    onPressed: ear.openSettings,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: '닫기',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PairGuideSheet extends StatelessWidget {
  const _PairGuideSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ear = context.read<EarphoneService>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SheetHeader('이어폰 페어링 모드'),
            const SizedBox(height: 8),
            Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bluetooth_searching_rounded,
                size: 40,
                color: c.textDisabled,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '1  충전 케이스에 이어폰을 넣고 뚜껑을 연 채 휴대폰 옆에 두세요\n'
              '2  상태 표시등이 흰색으로 깜빡일 때까지 케이스 뒷면 설정 버튼을 길게 눌러 주세요 '
              '(버튼이 없는 에어팟 4는 케이스 앞면 표시등 부근을 두 번 톡톡)\n'
              '3  깜빡이면 [다음]을 누르고 목록에서 이어폰을 선택하세요',
              style: ts(context, 14, height: 1.6),
            ),
            const SizedBox(height: 8),
            const NoteText('이름을 바꾼 에어팟은 바꾼 이름으로 보여요 · 검색은 10초 정도 걸려요'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: ear.openSettings,
                child: Text(
                  '블루투스 설정 열기 ›',
                  style: ts(
                    context,
                    13,
                    w: FontWeight.w700,
                    color: c.brandPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LineButton(
                    label: '취소',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: '다음',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceListSheet extends StatelessWidget {
  const _DeviceListSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ear = context.watch<EarphoneService>();
    // 에어팟 · 비츠 → 오디오 기기, 같은 묶음 안에서는 페어링된 기기 먼저
    int rank(FoundDevice d) => (d.pods ? 0 : 2) + (d.bonded ? 0 : 1);
    final list = ear.found.values.where((d) => d.audio || d.pods).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SheetHeader('주변 이어폰'),
            Row(
              children: [
                Text(
                  '연결할 이어폰을 선택하세요.',
                  style: ts(context, 14, color: c.textSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  '+${list.length}',
                  style: ts(
                    context,
                    14,
                    w: FontWeight.w700,
                    color: c.brandPrimary,
                  ),
                ),
                const Spacer(),
                if (ear.discovering)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.brandPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          ear.discovering ? '찾는 중…' : '찾은 이어폰이 없어요',
                          style: ts(context, 13, color: c.textSecondary),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: RowGroup(
                        children: [
                          for (final d in list)
                            ListRow(
                              title: '${d.mic ? '🎧' : '🔈'}  ${d.name}',
                              subtitle: [
                                d.bonded ? '페어링됨' : '새 기기',
                                d.mic ? '마이크 ✓' : '마이크 없음 — 음성 입력은 휴대폰 마이크로',
                              ].join(' · '),
                              trailing: ear.bondingAddress == d.address
                                  ? '연결 중…'
                                  : '연결 ›',
                              trailingColor: c.brandPrimary,
                              onTap: () async {
                                // 목록을 닫고 '이어폰 연결 중' 시트에서 진행 상황을 보여 줘요
                                Navigator.pop(context);
                                ear.pair(d);
                              },
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            const NoteText('목록에 없으면 페어링 모드를 다시 켜고 [다시 검색]을 눌러 주세요'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LineButton(
                    label: '취소',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: '다시 검색',
                    onPressed: ear.startDiscovery,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// EP-07 이어폰 정보 · 이름 → EP-08 이름 변경.
class EarphoneInfoScreen extends StatelessWidget {
  const EarphoneInfoScreen({super.key});

  Future<void> _rename(BuildContext context, EarphoneService ear) async {
    final ctl = TextEditingController(text: ear.info?.name ?? ear.name ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => PopupCard(
        title: '이어폰 이름 변경',
        description: '최대 20자까지 쓸 수 있어요.',
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(counterText: ''),
        ),
        cancelLabel: '취소',
        confirmLabel: '저장',
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () => Navigator.pop(ctx, ctl.text),
      ),
    );
    ctl.dispose();
    if (v == null || v.trim().isEmpty || !context.mounted) return;
    final ok = await ear.rename(v);
    if (context.mounted) toast(context, ok ? '이름을 바꿨어요' : '이름을 바꾸지 못했어요');
  }

  @override
  Widget build(BuildContext context) {
    final ear = context.watch<EarphoneService>();
    final i = ear.info;
    String v(String? s) => s == null || s.isEmpty ? '확인 안 됨' : s;
    return Scaffold(
      appBar: const TopBar(title: '이어폰 정보'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          12,
          gutter,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          RowGroup(
            children: [
              ListRow(
                title: '이름',
                trailing: v(i?.name.isNotEmpty == true ? i!.name : ear.name),
                chevron: ear.canRename,
                onTap: ear.canRename ? () => _rename(context, ear) : null,
              ),
              ListRow(title: '모델', trailing: v(i?.model)),
              ListRow(title: '펌웨어', trailing: v(i?.firmware)),
              ListRow(title: '제조사', trailing: v(i?.manufacturer)),
              ListRow(
                title: '일련번호',
                trailing: i == null || i.serial.length < 6
                    ? v(i?.serial)
                    : '${i.serial.substring(0, 4)}····${i.serial.substring(i.serial.length - 2)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (i != null && !ear.infoFresh) ...[
            const NoteText('마지막으로 받은 정보예요 · 에어팟은 연결 직후에만 정보를 보내요'),
            const SizedBox(height: 4),
          ],
          NoteText(
            ear.canRename
                ? '이름을 바꾸면 휴대폰 블루투스 목록에도 바뀐 이름으로 보여요'
                : '모델 · 펌웨어 · 이름 변경은 에어팟에서, 휴대폰이 허용할 때만 확인할 수 있어요',
          ),
        ],
      ),
    );
  }
}

/// 스코어 입력 상단 배지 (🎧 L 80 · R 75).
class EarBadge extends StatelessWidget {
  const EarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ear = context.watch<EarphoneService>();
    if (!ear.connected) return const SizedBox.shrink();
    final c = context.c;
    final low = (ear.lowestBattery ?? 100) <= 20;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: c.surfaceSelected,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EarphoneScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.headphones_rounded,
                  size: 14,
                  color: low ? c.danger : c.brandPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  ear.batteryLabel,
                  style: ts(
                    context,
                    11,
                    w: FontWeight.w700,
                    color: low ? c.danger : c.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
