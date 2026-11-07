import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home.dart';
import 'my/my_screen.dart';
import 'records/records_screen.dart';

/// 하단 탭: 홈 · 기록 · MY
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int tab = widget.initialTab;

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const labels = ['홈', '기록', 'MY'];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: const [HomeScreen(), RecordsScreen(), MyScreen()],
        ),
      ),
      // Figma BOTTOM (2144:12340): 알약 탭바 194×50 · 아래 여백 34 · 그림자 없음
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 34),
        child: Center(
          heightFactor: 1,
          child: Container(
            height: 50,
            // 항목 24 + 간격 16 → 터치 영역 40 으로 넓히고 좌우 여백 24 − 8
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.bgScreen,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < labels.length; i++)
                  _TabItem(
                    label: labels[i],
                    selected: i == tab,
                    onTap: () => go(i),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: ts(
                        context,
                        16,
                        w: FontWeight.w700,
                        color: i == tab ? c.textPrimary : c.textSecondary,
                      ).copyWith(letterSpacing: 0),
                    ),
                  ),
                // nav:S-60 (더보기 → MY)
                _TabItem(
                  label: '더보기',
                  selected: false,
                  onTap: () => go(2),
                  child: SvgPicture.asset(
                    'assets/icons/more.svg',
                    width: 17.461,
                    height: 3.914,
                    colorFilter: ColorFilter.mode(
                      c.textSecondary,
                      BlendMode.srcIn,
                    ),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: selected,
    button: true,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}
