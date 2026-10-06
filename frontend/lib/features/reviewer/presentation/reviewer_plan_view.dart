import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_labels.dart';

class ReviewerPlanView extends StatelessWidget {
  const ReviewerPlanView({super.key, required this.plan, required this.onChanged, this.editable = false});
  final ReviewLessonPlan plan;
  final ValueChanged<ReviewLessonPlan> onChanged;
  final bool editable;
  @override
  Widget build(BuildContext c) {
    final p = plan;
    Widget bi(String label, ReviewLocalizedText value, ValueChanged<ReviewLocalizedText> change) =>
        _BilingualField(label: label, value: value, onChanged: change, editable: editable);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: QSpace.md),
      child: QCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: c.text.titleLarge),
            const SizedBox(height: QSpace.sm),
            ...children,
          ],
        ),
      ),
    );
    Widget ids(String label, List<String> values, ValueChanged<List<String>> change) => TextFormField(
      initialValue: values.join(', '),
      readOnly: !editable,
      decoration: InputDecoration(labelText: label, helperText: c.l10n.reviewerCommaIds),
      onChanged: (v) => change(v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
    );
    Widget choice(String label, String value, List<String> values, ValueChanged<String> change) => DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final v in values) DropdownMenuItem(value: v, child: Text(reviewerLabel(v, c.l10n)))],
      onChanged: editable ? (v) => change(v!) : null,
    );
    Widget number(String label, int value, ValueChanged<int> change) => TextFormField(
      initialValue: value.toString(),
      readOnly: !editable,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) change(n);
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(c.l10n.reviewerOutcome, [
          bi(c.l10n.reviewerTitle, p.title, (v) => onChanged(p.copyWith(title: v))),
          bi(c.l10n.reviewerQuestion, p.centralQuestion, (v) => onChanged(p.copyWith(centralQuestion: v))),
          bi(c.l10n.reviewerOutcome, p.primaryLearningOutcome, (v) => onChanged(p.copyWith(primaryLearningOutcome: v))),
          choice(c.l10n.reviewerDepth, p.depthProfile, [
            'foundational',
            'standard',
            'focused',
          ], (v) => onChanged(p.copyWith(depthProfile: v))),
          choice(c.l10n.reviewerLessonType, p.lessonType, ['concept', 'story', 'practice'], (v) => onChanged(p.copyWith(lessonType: v))),
        ]),
        section(c.l10n.reviewerUnderstandings, [
          for (var i = 0; i < p.supportingUnderstandings.length; i++)
            bi(
              c.l10n.reviewerUnderstandings,
              p.supportingUnderstandings[i],
              (v) => onChanged(
                p.copyWith(
                  supportingUnderstandings: [
                    for (var j = 0; j < p.supportingUnderstandings.length; j++) j == i ? v : p.supportingUnderstandings[j],
                  ],
                ),
              ),
            ),
          if (editable)
            QButton(
              label: c.l10n.reviewerAdd,
              silent: true,
              tone: QButtonTone.ghost,
              onPressed: () => onChanged(
                p.copyWith(
                  supportingUnderstandings: [
                    ...p.supportingUnderstandings,
                    const ReviewLocalizedText(ar: '', en: ''),
                  ],
                ),
              ),
            ),
        ]),
        section(c.l10n.reviewerObjectives, [
          for (var i = 0; i < p.objectives.length; i++)
            Column(
              children: [
                bi(
                  c.l10n.reviewerObjectives,
                  p.objectives[i],
                  (v) => onChanged(p.copyWith(objectives: [for (var j = 0; j < p.objectives.length; j++) j == i ? v : p.objectives[j]])),
                ),
                if (editable && p.objectives.length > 1)
                  QButton(
                    label: c.l10n.reviewerRemove,
                    silent: true,
                    tone: QButtonTone.ghost,
                    onPressed: () => onChanged(
                      p.copyWith(
                        objectives: [
                          for (var j = 0; j < p.objectives.length; j++)
                            if (j != i) p.objectives[j],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (editable && p.objectives.length < 3)
            QButton(
              label: c.l10n.reviewerAdd,
              silent: true,
              tone: QButtonTone.ghost,
              onPressed: () => onChanged(
                p.copyWith(
                  objectives: [
                    ...p.objectives,
                    const ReviewLocalizedText(ar: '', en: ''),
                  ],
                ),
              ),
            ),
        ]),
        section(c.l10n.reviewerPrerequisites, [
          ids(c.l10n.reviewerPrerequisites, p.prerequisiteConceptIds, (v) => onChanged(p.copyWith(prerequisiteConceptIds: v))),
          ids(c.l10n.reviewerIntroduced, p.introducedConceptIds, (v) => onChanged(p.copyWith(introducedConceptIds: v))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.l10n.reviewerStandalone),
            value: p.standaloneEligible,
            onChanged: editable ? (v) => onChanged(p.copyWith(standaloneEligible: v)) : null,
          ),
        ]),
        section(c.l10n.reviewerTerms, [
          for (var i = 0; i < p.newTerms.length; i++)
            bi(
              c.l10n.reviewerTerms,
              p.newTerms[i],
              (v) => onChanged(p.copyWith(newTerms: [for (var j = 0; j < p.newTerms.length; j++) j == i ? v : p.newTerms[j]])),
            ),
        ]),
        section(c.l10n.reviewerMisconceptions, [
          for (var i = 0; i < p.targetMisconceptions.length; i++)
            Column(
              children: [
                bi(
                  c.l10n.reviewerTitle,
                  p.targetMisconceptions[i].title,
                  (v) => onChanged(
                    p.copyWith(
                      targetMisconceptions: [
                        for (var j = 0; j < p.targetMisconceptions.length; j++)
                          j == i ? p.targetMisconceptions[j].copyWith(title: v) : p.targetMisconceptions[j],
                      ],
                    ),
                  ),
                ),
                bi(
                  c.l10n.reviewerBrief,
                  p.targetMisconceptions[i].description,
                  (v) => onChanged(
                    p.copyWith(
                      targetMisconceptions: [
                        for (var j = 0; j < p.targetMisconceptions.length; j++)
                          j == i ? p.targetMisconceptions[j].copyWith(description: v) : p.targetMisconceptions[j],
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ]),
        section(c.l10n.reviewerReasoning, [
          for (var i = 0; i < p.reasoningTools.length; i++)
            Column(
              children: [
                choice(
                  c.l10n.reviewerReasoning,
                  p.reasoningTools[i].tool,
                  ['observation', 'inference', 'testimony', 'historical_evidence', 'causal_reasoning', 'comparison'],
                  (v) => onChanged(
                    p.copyWith(
                      reasoningTools: [
                        for (var j = 0; j < p.reasoningTools.length; j++)
                          j == i ? p.reasoningTools[j].copyWith(tool: v) : p.reasoningTools[j],
                      ],
                    ),
                  ),
                ),
                bi(
                  c.l10n.reviewerRationale,
                  p.reasoningTools[i].justification,
                  (v) => onChanged(
                    p.copyWith(
                      reasoningTools: [
                        for (var j = 0; j < p.reasoningTools.length; j++)
                          j == i ? p.reasoningTools[j].copyWith(justification: v) : p.reasoningTools[j],
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ]),
        section(c.l10n.reviewerArc, [
          TextFormField(
            initialValue: p.lessonArc.pattern,
            readOnly: !editable,
            decoration: InputDecoration(labelText: c.l10n.reviewerArc),
            onChanged: (v) => onChanged(p.copyWith(lessonArc: p.lessonArc.copyWith(pattern: v))),
          ),
          bi(c.l10n.reviewerRationale, p.lessonArc.rationale, (v) => onChanged(p.copyWith(lessonArc: p.lessonArc.copyWith(rationale: v)))),
          for (var i = 0; i < p.lessonArc.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: QSpace.md),
              child: Column(
                children: [
                  Text(p.lessonArc.steps[i].stepId, style: c.text.titleMedium),
                  choice(
                    c.l10n.reviewerArc,
                    p.lessonArc.steps[i].technique,
                    [
                      'scenario',
                      'prediction',
                      'example',
                      'story',
                      'demonstration',
                      'explanation',
                      'evidence',
                      'comparison',
                      'practice',
                      'reflection',
                      'takeaway',
                    ],
                    (v) => onChanged(
                      p.copyWith(
                        lessonArc: p.lessonArc.copyWith(
                          steps: [
                            for (var j = 0; j < p.lessonArc.steps.length; j++)
                              j == i ? p.lessonArc.steps[j].copyWith(technique: v) : p.lessonArc.steps[j],
                          ],
                        ),
                      ),
                    ),
                  ),
                  bi(
                    c.l10n.reviewerExperience,
                    p.lessonArc.steps[i].experience,
                    (v) => onChanged(
                      p.copyWith(
                        lessonArc: p.lessonArc.copyWith(
                          steps: [
                            for (var j = 0; j < p.lessonArc.steps.length; j++)
                              j == i ? p.lessonArc.steps[j].copyWith(experience: v) : p.lessonArc.steps[j],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(c.l10n.reviewerInteractive),
                    value: p.lessonArc.steps[i].interactive,
                    onChanged: editable
                        ? (v) => onChanged(
                            p.copyWith(
                              lessonArc: p.lessonArc.copyWith(
                                steps: [
                                  for (var j = 0; j < p.lessonArc.steps.length; j++)
                                    j == i ? p.lessonArc.steps[j].copyWith(interactive: v) : p.lessonArc.steps[j],
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
        ]),
        section(c.l10n.reviewerContentBudget, [
          Text(c.l10n.reviewerTargets, style: c.text.bodyMedium),
          number(c.l10n.reviewerMinutes, p.estimatedMinutes, (v) => onChanged(p.copyWith(estimatedMinutes: v))),
          number(c.l10n.reviewerContentBudget, p.contentBudget, (v) => onChanged(p.copyWith(contentBudget: v))),
          number(c.l10n.reviewerExerciseBudget, p.exerciseBudget, (v) => onChanged(p.copyWith(exerciseBudget: v))),
        ]),
      ],
    );
  }
}

class _BilingualField extends StatelessWidget {
  const _BilingualField({required this.label, required this.value, required this.onChanged, required this.editable});
  final String label;
  final ReviewLocalizedText value;
  final ValueChanged<ReviewLocalizedText> onChanged;
  final bool editable;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: QSpace.md),
    child: LayoutBuilder(
      builder: (c, box) {
        final ar = TextFormField(
          initialValue: value.ar,
          readOnly: !editable,
          minLines: 1,
          maxLines: null,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: '$label · ${c.l10n.commonArabic}'),
          onChanged: (v) => onChanged(value.copyWith(ar: v)),
        );
        final en = TextFormField(
          initialValue: value.en,
          readOnly: !editable,
          minLines: 1,
          maxLines: null,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: '$label · ${c.l10n.commonEnglish}'),
          onChanged: (v) => onChanged(value.copyWith(en: v)),
        );
        return box.maxWidth >= QBreakpoints.readingWidth
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ar),
                  const SizedBox(width: QSpace.md),
                  Expanded(child: en),
                ],
              )
            : Column(
                children: [
                  ar,
                  const SizedBox(height: QSpace.sm),
                  en,
                ],
              );
      },
    ),
  );
}
