import 'package:flutter/material.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/components/common.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

// Extracted from the prototype settings groups; rows keep their original sizes.
class QSettingsSection extends StatelessWidget {
  const QSettingsSection(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: QSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: QSpace.xs),
          child: Text(title.toUpperCase(), style: context.qText.eyebrow.copyWith(color: QColors.slate)),
        ),
        QCard(
          padding: EdgeInsets.zero,
          shadow: false,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: QSpace.huge), children[i]],
            ],
          ),
        ),
      ],
    ),
  );
}

class QSettingsRow extends StatelessWidget {
  const QSettingsRow({super.key, required this.icon, required this.title, this.subtitle, this.value, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < QProfile.scaledRowWidth || MediaQuery.textScalerOf(context).scale(1) > 1;
      final subtitleStyle = context.text.labelMedium?.copyWith(color: QColors.slate);
      return ListTile(
        onTap: onTap,
        leading: Icon(icon, color: QColors.emerald500),
        title: Text(title, style: context.text.titleSmall),
        subtitle: stacked && value != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value!, style: subtitleStyle),
                  if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                ],
              )
            : subtitle == null
            ? null
            : Text(subtitle!, style: context.text.bodySmall),
        trailing: stacked || value == null
            ? const Icon(Icons.chevron_right_rounded, color: QColors.muted)
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(value!, style: subtitleStyle)),
                    const Icon(Icons.chevron_right_rounded, color: QColors.muted),
                  ],
                ),
              ),
      );
    },
  );
}

class QSettingsToggle extends StatelessWidget {
  const QSettingsToggle({super.key, required this.icon, required this.title, required this.value, required this.onChanged, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged == null
        ? null
        : (value) {
            SensoryScope.of(context).select();
            onChanged!(value);
          },
    secondary: Icon(icon, color: QColors.emerald500),
    title: Text(title, style: context.text.titleSmall),
    subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
  );
}
