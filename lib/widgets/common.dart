import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'library.dart';

/// 와이어프레임 공통 요소 (2027 Friends Screen Library 기반, 색은 Theme 변수).

TextStyle ts(
  BuildContext context,
  double size, {
  FontWeight w = FontWeight.w500,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: kFont,
  fontSize: size,
  fontWeight: w,
  color: color ?? context.c.textPrimary,
  height: height,
  letterSpacing: -0.2,
);

const gutter = 18.0;

/// 뒤로가기 + 제목 앱바.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.title, this.actions, this.onBack});

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: '뒤로',
      onPressed: onBack ?? () => Navigator.maybePop(context),
    ),
    title: Text(title),
    actions: [...?actions, const SizedBox(width: 8)],
  );
}

/// 채운 버튼 (brand/primary).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 54,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? c.brandPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: c.brandOnPrimary,
          disabledBackgroundColor: c.surfaceSubtle,
          disabledForegroundColor: c.textDisabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: kFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// 선 버튼 (Line · White).
class LineButton extends StatelessWidget {
  const LineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 54,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surfaceDefault,
          foregroundColor: color ?? c.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: c.borderDefault),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: kFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// 테두리 카드.
class BoxCard extends StatelessWidget {
  const BoxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.onTap,
    this.selected = false,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: color ?? (selected ? c.surfaceSelected : c.surfaceDefault),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor ?? (selected ? c.brandPrimary : c.borderDefault),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 연한 배경 안내 박스.
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.title,
    this.body,
    this.warning = false,
  });

  final String title;
  final String? body;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = warning ? c.warningText : c.brandPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: warning ? c.warningBg : c.surfaceSelected,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warning ? c.warningBorder : fg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ts(context, 13, w: FontWeight.w700, color: fg),
          ),
          if (body != null) ...[
            const SizedBox(height: 3),
            Text(
              body!,
              style: ts(context, 12, color: c.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// 둥근 필터 칩 (filter).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.surfaceSelected : c.surfaceDefault,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? c.brandPrimary : c.borderDefault),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Text(
                label,
                style: ts(
                  context,
                  14,
                  w: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? c.brandPrimary : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 두 칸 세그먼트 (한 홀씩 | 표).
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  // 라이브러리 tabCombination(Normal) 모양의 밑줄 탭으로 그려요.
  @override
  Widget build(BuildContext context) =>
      UnderlineTabs(labels: labels, index: index, onChanged: onChanged);
}

/// 섹션 제목.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: ts(
              context,
              13,
              w: FontWeight.w700,
              color: context.c.textSecondary,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 두 줄 리스트 행 (제목 · 설명 · 오른쪽 값).
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.trailingColor,
    this.chevron = false,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? trailingColor;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ts(
                      context,
                      15,
                      w: subtitle == null ? FontWeight.w500 : FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: ts(context, 12, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                ),
                child: Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  style: ts(
                    context,
                    14,
                    w: FontWeight.w700,
                    color: trailingColor ?? c.textSecondary,
                  ),
                ),
              ),
            ],
            if (chevron)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 카드 안에 줄 사이 구분선을 넣어 행을 쌓아요.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BoxCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.c.borderDefault),
          children[i],
        ],
      ],
    ),
  );
}

/// 시트 손잡이.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 18),
      width: 54,
      height: 4,
      decoration: BoxDecoration(
        color: context.c.borderDefault,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// 작은 뱃지 (필드 · 확실 · 확인 필요 등).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.bg});

  final String text;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      // 라이브러리 badge: radius 4 · 10 Bold
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? c.surfaceSelected,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: ts(
          context,
          10,
          w: FontWeight.w700,
          color: color ?? c.brandPrimary,
          height: 1.3,
        ),
      ),
    );
  }
}

/// 원형 −/+ 버튼.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.size = 56,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? c.brandPrimary : c.surfaceDefault,
        shape: CircleBorder(
          side: filled ? BorderSide.none : BorderSide(color: c.borderDefault),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.4,
              color: filled ? c.brandOnPrimary : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 켜고 끄는 스위치 (Theme brand).
class BrandSwitch extends StatelessWidget {
  const BrandSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.brandPrimary
            : c.surfacePlaceholder,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// 원형 라디오 표시.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.brandPrimary : c.surfaceDefault,
        border: Border.all(
          color: selected ? c.brandPrimary : c.borderDefault,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}

/// 하단 고정 버튼 영역.
class BottomArea extends StatelessWidget {
  const BottomArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(gutter, 8, gutter, 14),
    child: child,
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirm,
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => PopupCard(
      title: title,
      description: body,
      cancelLabel: '취소',
      confirmLabel: confirm,
      danger: danger,
      onCancel: () => Navigator.pop(ctx, false),
      onConfirm: () => Navigator.pop(ctx, true),
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

String weekday(DateTime d) =>
    const ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
String mdw(DateTime d) => '${md(d)} (${weekday(d)})';
String ymd(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
String fullDate(DateTime d) =>
    '${d.month}월 ${d.day}일 (${weekday(d)}) '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
