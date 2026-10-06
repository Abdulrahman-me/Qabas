import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/components/buttons.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

enum ContentStepStatus { ready, feedback, completed }

enum StepIntent { none, completed, predictionChecked, placeholderContinued }

final class StepCta extends Equatable {
  const StepCta({required this.labelKey, required this.enabled, this.tone = QButtonTone.emerald, this.serverLabel});
  final String labelKey;
  final String? serverLabel;
  final bool enabled;
  final QButtonTone tone;
  @override
  List<Object?> get props => [labelKey, enabled, tone, serverLabel];
}

final class ContentStepState extends Equatable {
  const ContentStepState({
    this.status = ContentStepStatus.ready,
    this.beat = 0,
    this.shown = 1,
    this.selectedOptionId,
    this.originShown = false,
    this.intent = StepIntent.none,
    this.serial = 0,
  });
  final ContentStepStatus status;
  final int beat, shown, serial;
  final String? selectedOptionId;
  final bool originShown;
  final StepIntent intent;
  ContentStepState changed({
    ContentStepStatus? status,
    int? beat,
    int? shown,
    String? selected,
    bool? originShown,
    StepIntent intent = StepIntent.none,
  }) => ContentStepState(
    status: status ?? this.status,
    beat: beat ?? this.beat,
    shown: shown ?? this.shown,
    selectedOptionId: selected ?? selectedOptionId,
    originShown: originShown ?? this.originShown,
    intent: intent,
    serial: serial + 1,
  );
  @override
  List<Object?> get props => [status, beat, shown, selectedOptionId, originShown, intent, serial];
}

sealed class ContentStepEvent {
  const ContentStepEvent();
}

final class CtaPressed extends ContentStepEvent {
  const CtaPressed();
}

final class PredictionOptionPicked extends ContentStepEvent {
  const PredictionOptionPicked(this.id);
  final String id;
}

final class AllTeachPointsShown extends ContentStepEvent {
  const AllTeachPointsShown();
}

/// One independently owned BLoC per mounted top-level item. No notifier logic in views.
class ContentStepBloc extends Bloc<ContentStepEvent, ContentStepState> {
  ContentStepBloc(this.item, {ContentStepState? initial})
    : super(initial ?? ContentStepState(shown: item is TeachItem && item.style == TeachStyle.summary ? item.points.length : 1)) {
    on<PredictionOptionPicked>((e, emit) {
      if (item is PredictItem && state.status == ContentStepStatus.ready && (item as PredictItem).options.any((o) => o.optionId == e.id)) {
        emit(state.changed(selected: e.id));
      }
    });
    on<AllTeachPointsShown>((e, emit) {
      if (item case final TeachItem t) emit(state.changed(shown: t.points.length));
    });
    on<CtaPressed>((e, emit) {
      if (!cta.enabled || state.status == ContentStepStatus.completed) return;
      switch (item) {
        case PredictItem():
          emit(
            state.status == ContentStepStatus.ready
                ? state.changed(status: ContentStepStatus.feedback, intent: StepIntent.predictionChecked)
                : state.changed(status: ContentStepStatus.completed, intent: StepIntent.completed),
          );
        case final StoryItem s:
          if (state.beat < s.beats.length - 1) {
            emit(state.changed(beat: state.beat + 1));
          } else if (s.origin?.showCard == true && !state.originShown) {
            emit(state.changed(originShown: true));
          } else {
            emit(state.changed(status: ContentStepStatus.completed, intent: StepIntent.completed));
          }
        case final TeachItem t:
          if (state.shown < t.points.length) {
            emit(state.changed(shown: state.shown + 1));
          } else {
            emit(state.changed(status: ContentStepStatus.completed, intent: StepIntent.completed));
          }
        case ExerciseItem():
          emit(state.changed(status: ContentStepStatus.completed, intent: StepIntent.placeholderContinued));
        default:
          emit(state.changed(status: ContentStepStatus.completed, intent: StepIntent.completed));
      }
    });
  }
  final SessionItem item;
  StepCta get cta => switch (item) {
    HookItem(:final cta) => StepCta(labelKey: 'sessionFindOut', enabled: state.status != ContentStepStatus.completed, serverLabel: cta),
    PredictItem() => StepCta(
      labelKey: state.status == ContentStepStatus.ready ? 'commonCheck' : 'commonContinue',
      enabled: state.selectedOptionId != null,
      tone: state.status == ContentStepStatus.feedback ? QButtonTone.gold : QButtonTone.emerald,
    ),
    final StoryItem s => StepCta(
      labelKey: state.beat < s.beats.length - 1 || (s.origin?.showCard == true && !state.originShown) ? 'commonNext' : 'commonContinue',
      enabled: true,
    ),
    final TeachItem t => StepCta(labelKey: state.shown < t.points.length ? 'sessionShowMore' : 'commonContinue', enabled: true),
    _ => const StepCta(labelKey: 'commonContinue', enabled: true),
  };
}

final class HookStepBloc extends ContentStepBloc {
  HookStepBloc(HookItem super.item);
}

final class PredictStepBloc extends ContentStepBloc {
  PredictStepBloc(PredictItem super.item);
}

final class StoryStepBloc extends ContentStepBloc {
  StoryStepBloc(StoryItem super.item);
}

final class TeachStepBloc extends ContentStepBloc {
  TeachStepBloc(TeachItem super.item);
}

final class ParagraphStepBloc extends ContentStepBloc {
  ParagraphStepBloc(ParagraphItem super.item);
}

final class EvidenceStepBloc extends ContentStepBloc {
  EvidenceStepBloc(EvidenceItem super.item);
}

final class VisualStepBloc extends ContentStepBloc {
  VisualStepBloc(VisualItem super.item);
}

final class CalloutStepBloc extends ContentStepBloc {
  CalloutStepBloc(CalloutItem super.item);
}

ContentStepBloc stepBloc(SessionItem item) => switch (item) {
  final HookItem i => HookStepBloc(i),
  final PredictItem i => PredictStepBloc(i),
  final StoryItem i => StoryStepBloc(i),
  final TeachItem i => TeachStepBloc(i),
  final ParagraphItem i => ParagraphStepBloc(i),
  final EvidenceItem i => EvidenceStepBloc(i),
  final VisualItem i => VisualStepBloc(i),
  final CalloutItem i => CalloutStepBloc(i),
  _ => ContentStepBloc(item),
};
