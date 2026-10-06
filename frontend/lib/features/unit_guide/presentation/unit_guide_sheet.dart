import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

class UnitGuideSheetPage extends StatelessWidget {
  const UnitGuideSheetPage({super.key, required this.unitId});
  final String unitId;
  @override
  Widget build(BuildContext c) => ContentInteractions(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
        child: Material(
          color: QColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: QRadius.sheet),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(QSpace.xl, QSpace.sm, QSpace.xl, QSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: QSizes.sheetHandleWidth,
                      height: QSizes.sheetHandleHeight,
                      margin: const EdgeInsets.only(bottom: QSpace.md),
                      decoration: const BoxDecoration(color: QColors.lineStrong, borderRadius: QRadius.chip),
                    ),
                  ),
                  BlocConsumer<UnitGuideBloc, UnitGuideState>(
                    listener: (c, s) {
                      if (s.guide != null) c.read<ContentBloc>().add(ContentReceived(s.guide!.terms, s.guide!.sources));
                    },
                    builder: (c, s) {
                      if (s.status == GuideStatus.failure) {
                        return QErrorView(
                          kind: failureKind(s.failure!),
                          onRetry: () => c.read<UnitGuideBloc>().add(UnitGuideOpened(unitId)),
                        );
                      }
                      if (s.guide == null) return const QInlineLoading();
                      final g = s.guide!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              UnitArtIcon.fromKey(artKey: g.unit?.artKey ?? '', size: QReview.guideArt),
                              const SizedBox(width: QSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (g.unit != null) Text(c.l10n.journeyUnitN(c.n(g.unit!.index)).toUpperCase(), style: c.qText.eyebrow),
                                    Text(g.unit?.title ?? g.title, style: c.text.headlineSmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: QSpace.lg),
                          for (final section in g.sections) ...[
                            Text(section.title, style: c.text.titleMedium),
                            const SizedBox(height: QSpace.sm),
                            for (final sentence in section.sentences)
                              Padding(
                                padding: const EdgeInsets.only(bottom: QSpace.sm),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: QReview.guideBulletTop),
                                      child: FlameMark(size: QReview.guideBullet, animate: false),
                                    ),
                                    const SizedBox(width: QSpace.sm),
                                    Expanded(child: SentenceText(sentence, style: c.text.bodyLarge)),
                                  ],
                                ),
                              ),
                          ],
                          if (g.sections.isEmpty) Text(c.l10n.unitGuideEmpty, style: c.text.bodyMedium),
                          const SizedBox(height: QSpace.lg),
                          QButton(label: c.l10n.commonGotIt, onPressed: () => c.pop()),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
