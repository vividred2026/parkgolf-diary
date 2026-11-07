import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// 2027 Friends Screen Library 컴포넌트를 앱 위젯으로 옮긴 것.
/// 모양 · 치수는 라이브러리를 따르고, 색은 Theme 토큰(라이트 / 다크)을 써요.

/// common/note — 점 + 작은 안내 글.
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7.5),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: c.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: ts(context, 12, color: c.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// sort — 둥근 정렬 칩 (글자 + 아래 화살표).
class SortChip extends StatelessWidget {
  const SortChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surfaceDefault,
      shape: StadiumBorder(
        side: BorderSide(color: c.borderDefault, width: 0.5),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: ts(
                  context,
                  14,
                  w: FontWeight.w400,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// labelSort — "제목 N개 ······ 정렬 ⌄".
class LabelSort extends StatelessWidget {
  const LabelSort({
    super.key,
    required this.title,
    this.count,
    this.unit = '',
    this.sortText,
    this.onSort,
  });

  final String title;
  final int? count;
  final String unit;
  final String? sortText;
  final VoidCallback? onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ts(context, 14, w: FontWeight.w400, color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Text(title, style: s),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text('$count$unit', style: s),
          ],
          const Spacer(),
          if (sortText != null)
            InkWell(
              onTap: onSort,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sortText!, style: s),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: c.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// labelContents — 큰 제목 + 브랜드색 개수.
class LabelContents extends StatelessWidget {
  const LabelContents({
    super.key,
    required this.title,
    this.count,
    this.unit = '',
  });

  final String title;
  final int? count;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: ts(context, 18, w: FontWeight.w700)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count$unit',
              style: ts(context, 18, w: FontWeight.w400, color: c.brandPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

/// badge — 작은 사각 뱃지 (radius 4, 10 Bold).
class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color, this.bg});

  final String text;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? c.brandPrimary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: ts(
          context,
          10,
          w: FontWeight.w700,
          color: color ?? c.brandOnPrimary,
          height: 1.3,
        ),
      ),
    );
  }
}

/// courseInfo — 파크골프장 이름 + 뱃지 + "코스 | 코스".
class CourseInfo extends StatelessWidget {
  const CourseInfo({
    super.key,
    required this.name,
    required this.badge,
    required this.courses,
  });

  final String name;
  final String badge;
  final List<String> courses;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final names = <Widget>[];
    for (var i = 0; i < courses.length; i++) {
      if (i > 0) {
        names.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '|',
              style: ts(context, 10, w: FontWeight.w400, color: c.textDisabled),
            ),
          ),
        );
      }
      names.add(
        Text(courses[i], style: ts(context, 14, color: c.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: ts(context, 18, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Badge2(badge),
            const SizedBox(width: 10),
            Flexible(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: names,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// report/screenList — 라운드 한 줄 카드.
class RoundListItem extends StatelessWidget {
  const RoundListItem({
    super.key,
    required this.date,
    required this.title,
    required this.score,
    required this.people,
    required this.holes,
    this.onTap,
  });

  final String date;
  final String title;
  final String score;
  final int people;
  final int holes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meta = ts(context, 14, color: c.textSecondary);
    return Material(
      color: c.surfaceSubtle,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(date, style: meta)),
                  Icon(
                    Icons.people_alt_rounded,
                    size: 16,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text('$people인', style: meta),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 1,
                    height: 9,
                    color: c.borderDefault,
                  ),
                  Text('${holes}H', style: meta),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(context, 16, w: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    score,
                    style: ts(context, 24, w: FontWeight.w700, height: 1.2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// tabCombination(Normal) — 밑줄 탭. 선택: 굵게 + 2px 밑줄.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: i == index
                            ? BorderSide(color: c.textPrimary, width: 2)
                            : BorderSide(color: c.borderDefault, width: 1),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: ts(
                        context,
                        16,
                        w: i == index ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// popupDefault — 제목 · 설명 · (내용) · 버튼 2개.
class PopupCard extends StatelessWidget {
  const PopupCard({
    super.key,
    required this.title,
    this.description,
    this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.danger = false,
  });

  final String title;
  final String? description;
  final Widget? content;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget btn(String label, Color bg, Color fg, VoidCallback? onTap) =>
        SizedBox(
          height: 42,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: c.surfaceSubtle,
              disabledForegroundColor: c.textDisabled,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontFamily: kFont,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onTap,
            child: Text(label),
          ),
        );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: c.surfaceDefault,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 324),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ts(
                        context,
                        18,
                        w: FontWeight.w700,
                        color: danger ? c.danger : c.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        description!,
                        style: ts(
                          context,
                          14,
                          w: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 20),
                      content!,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: btn(
                      cancelLabel,
                      c.surfaceSubtle,
                      c.textSecondary,
                      onCancel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: btn(
                      confirmLabel,
                      danger ? c.danger : c.brandPrimary,
                      c.brandOnPrimary,
                      onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// bottomsheet/header — 왼쪽 정렬 시트 제목 (높이 56).
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: ts(context, 18, w: FontWeight.w700)),
    ),
  );
}
