import 'package:flutter/material.dart';

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
        child: IndexedStack(index: tab, children: const [
          HomeScreen(),
          RecordsScreen(),
          MyScreen(),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 14, top: 6),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: c.bgScreen,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.borderDefault),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < labels.length; i++)
                Semantics(
                  selected: i == tab,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(labels[i],
                          style: ts(context, 16,
                              w: FontWeight.w700,
                              color: i == tab
                                  ? c.textPrimary
                                  : c.textSecondary)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
