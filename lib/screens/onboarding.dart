import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../services/speech.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

/// S-01 스플래시
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1200), _next);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _next() {
    _t?.cancel();
    if (!mounted) return;
    final store = context.read<AppStore>();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            store.onboarded ? const MainShell() : const PermissionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('PARKGOLF',
                style: ts(context, 36, w: FontWeight.w800, height: 1)),
            const SizedBox(height: 4),
            Text('D I A R Y',
                style: ts(context, 22, w: FontWeight.w800, height: 1)),
            const SizedBox(height: 16),
            Text('버튼 · 말로 기록하는 파크골프',
                style: ts(context, 13, color: c.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// S-02 접근 권한 안내 (이번 단계는 휴대폰 마이크만 사용)
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  void _go(BuildContext context) => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NicknameScreen()));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(IconData icon, String t, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: c.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: c.brandPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: ts(context, 14, w: FontWeight.w700)),
                Text(s, style: ts(context, 12, color: c.textSecondary)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('파크골프다이어리가\n사용하는 권한',
                style: ts(context, 22, w: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 10),
            Text('음성 입력에 필요해요. 설정에서 언제든 바꿀 수 있어요.',
                style: ts(context, 13, color: c.textSecondary, height: 1.4)),
            const SizedBox(height: 18),
            BoxCard(
              child: Column(children: [
                item(Icons.mic_none_rounded, '마이크 · 음성 인식',
                    '말로 스코어 입력 (선택)'),
                Divider(height: 1, color: c.borderDefault),
                item(Icons.photo_outlined, '사진',
                    '다이어리에 사진 추가할 때만 물어봐요'),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: BottomArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(
            label: '허용하고 시작하기',
            onPressed: () async {
              await SpeechService.instance.init();
              if (context.mounted) _go(context);
            },
          ),
          TextButton(
            onPressed: () => _go(context),
            child: Text('나중에 설정하기',
                style: ts(context, 13,
                    w: FontWeight.w700, color: c.textSecondary)),
          ),
        ]),
      ),
    );
  }
}

/// S-06 닉네임
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _start() {
    final v = _ctl.text.trim();
    if (v.isEmpty) return;
    context.read<AppStore>().setNickname(v);
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: const TopBar(title: '시작하기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('뭐라고 불러 드릴까요?',
              style: ts(context, 22, w: FontWeight.w700)),
          const SizedBox(height: 18),
          Text('닉네임', style: ts(context, 12, color: c.textSecondary)),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: _ctl,
            builder: (context, v, _) => TextField(
              controller: _ctl,
              autofocus: true,
              maxLength: 12,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _start(),
              style: ts(context, 16),
              decoration: const InputDecoration(hintText: '예) 라이언', counterText: ''),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder(
              valueListenable: _ctl,
              builder: (context, v, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${v.text.length}/12자',
                    style: ts(context, 13, color: c.textSecondary)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('닉네임은 이 휴대폰에만 저장돼요. 계정 · 로그인은 없어요.',
              style: ts(context, 13, color: c.textSecondary)),
        ]),
      ),
      bottomNavigationBar: BottomArea(
        child: ValueListenableBuilder(
          valueListenable: _ctl,
          builder: (context, v, _) => PrimaryButton(
              label: '시작하기',
              onPressed: v.text.trim().isEmpty ? null : _start),
        ),
      ),
    );
  }
}
