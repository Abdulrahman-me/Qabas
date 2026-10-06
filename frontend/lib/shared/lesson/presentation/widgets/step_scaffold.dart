import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';

class StepScroll extends StatelessWidget {
  const StepScroll({super.key, required this.children, this.padding, this.controller});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: controller,
    padding: padding ?? const EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.xl),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}

class KindChip extends StatelessWidget {
  const KindChip(this.label, {super.key, this.icon = Icons.auto_awesome_rounded, this.color = QColors.emerald500});
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Reveal(
      child: Tag(label.toUpperCase(), icon: icon, color: color),
    ),
  );
}
