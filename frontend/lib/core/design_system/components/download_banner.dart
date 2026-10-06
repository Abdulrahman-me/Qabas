import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';

/// Web-only promotion, using the Journey's emerald surfaces and gold accents.
/// The bounded scroll area keeps its actions reachable in short windows.
class QDownloadBannerFrame extends StatelessWidget {
  const QDownloadBannerFrame({
    super.key,
    required this.visible,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    required this.dismissLabel,
    required this.onDownload,
    required this.onDismiss,
    required this.child,
  });

  final bool visible;
  final String eyebrow, title, body, action, dismissLabel;
  final VoidCallback onDownload, onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (constraints.maxHeight < 400)
            Material(
              color: QColors.night900,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: QSpace.xs),
                child: Row(
                  children: [
                    Tooltip(
                      message: body,
                      child: const Icon(Icons.devices_rounded, color: QColors.gold300, size: QSizes.buttonIcon),
                    ),
                    const SizedBox(width: QSpace.xs),
                    Expanded(
                      child: QButton(
                        key: const ValueKey('android-download-action'),
                        label: action,
                        tone: QButtonTone.gold,
                        icon: Icons.android_rounded,
                        onPressed: onDownload,
                        height: QSizes.tapTarget,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('android-download-dismiss'),
                      tooltip: dismissLabel,
                      onPressed: onDismiss,
                      color: QColors.emerald200,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.min(constraints.maxHeight * .45, 240)),
              child: Material(
                color: QColors.night900,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: QColors.nightLine)),
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('android-download-banner-scroll'),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: QBreakpoints.composerMax * 2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final close = IconButton(
                                key: const ValueKey('android-download-dismiss'),
                                tooltip: dismissLabel,
                                onPressed: onDismiss,
                                color: QColors.emerald200,
                                icon: const Icon(Icons.close_rounded),
                              );
                              final heading = Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(QSpace.sm),
                                    decoration: BoxDecoration(color: QColors.night800, borderRadius: BorderRadius.circular(QRadius.md)),
                                    child: const Icon(Icons.devices_rounded, color: QColors.gold300, size: QSizes.buttonIcon),
                                  ),
                                  const SizedBox(width: QSpace.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(eyebrow, style: context.text.labelSmall?.copyWith(color: QColors.gold300)),
                                        const SizedBox(height: QSpace.xxs),
                                        Text(title, style: context.text.titleMedium?.copyWith(color: QColors.softEmber)),
                                      ],
                                    ),
                                  ),
                                  if (box.maxWidth < QBreakpoints.rail) close,
                                ],
                              );
                              final copy = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  heading,
                                  const SizedBox(height: QSpace.xs),
                                  Text(body, style: context.text.bodySmall?.copyWith(color: QColors.emerald200)),
                                ],
                              );
                              final download = QButton(
                                key: const ValueKey('android-download-action'),
                                label: action,
                                icon: Icons.android_rounded,
                                trailingIcon: Icons.file_download_outlined,
                                tone: QButtonTone.gold,
                                onPressed: onDownload,
                                height: QSizes.tapTarget,
                              );
                              if (box.maxWidth >= QBreakpoints.rail) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: copy),
                                    const SizedBox(width: QSpace.xxl),
                                    Padding(
                                      padding: const EdgeInsets.only(top: QSpace.sm),
                                      child: SizedBox(width: QBreakpoints.readingWidth / 2, child: download),
                                    ),
                                    const SizedBox(width: QSpace.sm),
                                    close,
                                  ],
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  copy,
                                  const SizedBox(height: QSpace.sm),
                                  download,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
