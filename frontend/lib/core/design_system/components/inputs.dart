import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/buttons.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

class QTextField extends StatelessWidget {
  const QTextField({super.key, required this.controller, required this.hint, this.onSubmitted, this.enabled = true, this.maxLines = 4});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    textInputAction: TextInputAction.send,
    onSubmitted: onSubmitted,
    minLines: 1,
    maxLines: maxLines,
    style: context.text.bodyLarge?.copyWith(fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: context.text.bodyMedium?.copyWith(color: QColors.muted),
      filled: true,
      fillColor: QColors.surfaceSunk,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: QColors.emerald400, width: 1.5),
      ),
    ),
  );
}

class QComposerBar extends StatelessWidget {
  const QComposerBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    this.enabled = true,
    this.attachments = const [],
    this.recordingLabel,
    this.recording = false,
    this.onCancelRecording,
    this.hasAttachments = false,
    this.maxLines = 4,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final VoidCallback? onCancelRecording;
  final bool enabled, recording, hasAttachments;
  final List<Widget> attachments;
  final String? recordingLabel;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: QColors.surface,
      border: Border(top: BorderSide(color: QColors.line, width: 1.5)),
    ),
    padding: const EdgeInsets.all(QSpace.sm),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QBreakpoints.composerMax),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: QSpace.xs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: QMedia.preview),
                  child: SingleChildScrollView(
                    child: Wrap(spacing: QSpace.xs, children: attachments),
                  ),
                ),
              ),
            if (recordingLabel != null)
              Row(
                children: [
                  Expanded(
                    child: Semantics(liveRegion: true, child: Text(recordingLabel!, style: context.text.bodySmall)),
                  ),
                  if (onCancelRecording != null)
                    QIconButton(tooltip: context.l10n.commonClose, icon: Icons.close_rounded, onTap: onCancelRecording),
                ],
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = (value.text.trim().isNotEmpty || hasAttachments) && !recording;
                return Row(
                  children: [
                    QIconButton(
                      onTap: enabled && !recording ? onAttach : null,
                      tooltip: context.l10n.raqeebAttachTitle,
                      icon: Icons.add_circle_outline_rounded,
                      color: QColors.emerald500,
                    ),
                    Expanded(
                      child: QTextField(
                        controller: controller,
                        hint: hint,
                        enabled: enabled && !recording,
                        maxLines: maxLines,
                        onSubmitted: enabled && !recording ? onSend : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: QIconButton(
                        key: ValueKey(hasText),
                        tooltip: recording
                            ? context.l10n.mediaStopRecording
                            : hasText
                            ? context.l10n.commonSendTooltip
                            : context.l10n.commonRecordTooltip,
                        background: hasText ? QColors.emerald500 : QColors.emerald50,
                        onTap: enabled ? (hasText ? () => onSend(value.text) : onRecord) : null,
                        icon: recording
                            ? Icons.stop_rounded
                            : hasText
                            ? Icons.arrow_upward_rounded
                            : Icons.mic_none_rounded,
                        color: hasText ? QColors.surface : QColors.emerald500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class QSegmentedChips<T> extends StatelessWidget {
  const QSegmentedChips({super.key, required this.options, required this.selected, required this.onSelected});
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: QSpace.xs,
    runSpacing: QSpace.xs,
    children: [
      for (final option in options.entries)
        Semantics(
          selected: option.key == selected,
          child: Pressable(
            onTap: () => onSelected(option.key),
            semanticLabel: option.value,
            child: Container(
              constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
              padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
              decoration: BoxDecoration(
                borderRadius: QRadius.chip,
                color: option.key == selected ? QColors.emerald50 : QColors.surface,
                border: Border.all(color: option.key == selected ? QColors.emerald400 : QColors.line, width: 1.5),
              ),
              child: Text(option.value, style: context.text.labelMedium?.copyWith(color: QColors.emerald700)),
            ),
          ),
        ),
    ],
  );
}
