import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/lesson/domain/entities/recitation.dart';
import 'package:qabas/shared/lesson/domain/logic/answer_drafts.dart';

enum ExerciseStepStatus { editing, ready, submitted }

final class ExerciseStepState extends Equatable {
  ExerciseStepState({
    required this.draft,
    this.status = ExerciseStepStatus.editing,
    this.selected,
    this.meaning = false,
    this.transliteration = false,
    this.submitSerial = 0,
    this.audioStatus = RecitationPlaybackStatus.unavailable,
    this.position = Duration.zero,
    this.mapAvailable = false,
    this.recitationStatus = RecitationStatus.unavailable,
    this.recordingElapsed = Duration.zero,
    this.check,
    this.recitationFailure,
    Map<String, Object?> visualParams = const {},
  }) : visualParams = Map.unmodifiable(visualParams);
  final AnswerDraft draft;
  final ExerciseStepStatus status;
  final String? selected;
  final bool meaning, transliteration;
  final int submitSerial;
  final RecitationPlaybackStatus audioStatus;
  final Duration position;
  final bool mapAvailable;
  final RecitationStatus recitationStatus;
  final Duration recordingElapsed;
  final RecitationCheck? check;
  final Failure? recitationFailure;
  final Map<String, Object?> visualParams;
  ExerciseStepState copy({
    AnswerDraft? draft,
    String? selected,
    bool? meaning,
    bool? transliteration,
    int? submitSerial,
    RecitationPlaybackStatus? audioStatus,
    Duration? position,
    bool? mapAvailable,
    RecitationStatus? recitationStatus,
    Duration? recordingElapsed,
    RecitationCheck? check,
    Failure? recitationFailure,
    bool clearCheck = false,
    Map<String, Object?>? visualParams,
  }) => ExerciseStepState(
    draft: draft ?? this.draft,
    status: (draft ?? this.draft).isComplete ? ExerciseStepStatus.ready : ExerciseStepStatus.editing,
    selected: selected,
    meaning: meaning ?? this.meaning,
    transliteration: transliteration ?? this.transliteration,
    submitSerial: submitSerial ?? this.submitSerial,
    audioStatus: audioStatus ?? this.audioStatus,
    position: position ?? this.position,
    mapAvailable: mapAvailable ?? this.mapAvailable,
    recitationStatus: recitationStatus ?? this.recitationStatus,
    recordingElapsed: recordingElapsed ?? this.recordingElapsed,
    check: clearCheck ? null : check ?? this.check,
    recitationFailure: recitationFailure,
    visualParams: visualParams ?? this.visualParams,
  );
  @override
  List<Object?> get props => [
    draft,
    status,
    selected,
    meaning,
    transliteration,
    submitSerial,
    audioStatus,
    position,
    mapAvailable,
    recitationStatus,
    recordingElapsed,
    check,
    recitationFailure,
    visualParams,
  ];
}

sealed class ExerciseStepEvent {
  const ExerciseStepEvent();
}

final class ExerciseOptionSelected extends ExerciseStepEvent {
  const ExerciseOptionSelected(this.id);
  final String id;
}

final class TruthSelected extends ExerciseStepEvent {
  const TruthSelected(this.value);
  final bool value;
}

final class ReasonSelected extends ExerciseStepEvent {
  const ReasonSelected(this.id);
  final String id;
}

final class TokenSelected extends ExerciseStepEvent {
  const TokenSelected(this.id);
  final String id;
}

final class TokenPlaced extends ExerciseStepEvent {
  const TokenPlaced(this.item, this.category);
  final String item, category;
}

final class TokenRemoved extends ExerciseStepEvent {
  const TokenRemoved(this.id);
  final String id;
}

final class PairRightSelected extends ExerciseStepEvent {
  const PairRightSelected(this.id);
  final String id;
}

final class OrderTokenSelected extends ExerciseStepEvent {
  const OrderTokenSelected(this.id);
  final String id;
}

final class AnswerDraftRestored extends ExerciseStepEvent {
  const AnswerDraftRestored(this.answer);
  final AnswerPayload answer;
}

final class CardFlipped extends ExerciseStepEvent {
  const CardFlipped();
}

final class RecallRated extends ExerciseStepEvent {
  const RecallRated(this.rating);
  final String rating;
}

final class BlankSelected extends ExerciseStepEvent {
  const BlankSelected(this.id);
  final String id;
}

final class BlankFilled extends ExerciseStepEvent {
  const BlankFilled(this.word);
  final String word;
}

final class MeaningToggled extends ExerciseStepEvent {
  const MeaningToggled();
}

final class TransliterationToggled extends ExerciseStepEvent {
  const TransliterationToggled();
}

final class RecitationSkipped extends ExerciseStepEvent {
  const RecitationSkipped();
}

final class AnswerCheckPressed extends ExerciseStepEvent {
  const AnswerCheckPressed();
}

final class AudioListenPressed extends ExerciseStepEvent {
  const AudioListenPressed();
}

final class AudioPositionChanged extends ExerciseStepEvent {
  const AudioPositionChanged(this.position);
  final Duration position;
}

final class AudioPlaybackChanged extends ExerciseStepEvent {
  const AudioPlaybackChanged(this.status);
  final RecitationPlaybackStatus status;
}

final class MapAvailabilityChanged extends ExerciseStepEvent {
  const MapAvailabilityChanged(this.available);
  final bool available;
}

final class RecitationRecordPressed extends ExerciseStepEvent {
  const RecitationRecordPressed();
}

final class RecitationRecordingStopped extends ExerciseStepEvent {
  const RecitationRecordingStopped();
}

final class RecitationAccepted extends ExerciseStepEvent {
  const RecitationAccepted();
}

final class RecitationSettingsOpened extends ExerciseStepEvent {
  const RecitationSettingsOpened();
}

final class RecitationWordPressed extends ExerciseStepEvent {
  const RecitationWordPressed(this.index);
  final int index;
}

final class _RecitationTicked extends ExerciseStepEvent {
  const _RecitationTicked();
}

class ExerciseStepBloc extends Bloc<ExerciseStepEvent, ExerciseStepState> {
  ExerciseStepBloc(this.exercise, {this.playback, this.capture, this.recitation, AnswerPayload? restoredAnswer})
    : super(
        ExerciseStepState(
          draft: AnswerDraft.restored(exercise.payload, restoredAnswer),
          recitationStatus: recitation?.enabled == true ? RecitationStatus.idle : RecitationStatus.unavailable,
          audioStatus: playback?.available == true ? RecitationPlaybackStatus.idle : RecitationPlaybackStatus.unavailable,
        ),
      ) {
    on<RecitationRecordPressed>(_record);
    on<RecitationRecordingStopped>(_stopRecord);
    on<RecitationAccepted>((_, emit) {
      if (state.check != null && !state.check!.unclear) emit(state.copy(draft: RecitationDraft(checkId: state.check!.id)));
    });
    on<RecitationSettingsOpened>((_, emit) async => capture?.openSettings());
    on<_RecitationTicked>((_, emit) {
      if (state.recitationStatus != RecitationStatus.recording) return;
      final elapsed = DateTime.now().difference(_recordingStart!);
      emit(state.copy(recordingElapsed: elapsed));
      if (elapsed >= _recordLimit) {
        _recordTimer?.cancel();
        add(const RecitationRecordingStopped());
      }
    });
    on<RecitationWordPressed>((event, emit) async {
      final word = state.check?.words.where((w) => w.index == event.index).firstOrNull;
      if (word?.segment != null && playback is RecitationSegmentPlayback) {
        try {
          await (playback as RecitationSegmentPlayback).playSegment(word!.segment!, (status) {
            if (!isClosed) add(AudioPlaybackChanged(status));
          });
        } catch (_) {
          if (!emit.isDone) emit(state.copy(audioStatus: RecitationPlaybackStatus.failure));
        }
      } else {
        add(const AudioListenPressed());
      }
    });
    on<AnswerDraftRestored>((e, emit) => emit(state.copy(draft: AnswerDraft.restored(exercise.payload, e.answer))));
    on<CardFlipped>((e, emit) => emit(state.copy(draft: RatingDraft(flipped: !(state.draft as RatingDraft).flipped))));
    on<RecallRated>((e, emit) {
      if (!(state.draft as RatingDraft).flipped || !['again', 'hard', 'good', 'easy'].contains(e.rating)) return;
      emit(
        state.copy(
          draft: RatingDraft(flipped: true, rating: e.rating),
          submitSerial: state.submitSerial + 1,
        ),
      );
    });
    on<BlankSelected>((e, emit) {
      final d = state.draft as FillsDraft;
      emit(state.copy(draft: d.remove(e.id), selected: e.id));
    });
    on<BlankFilled>((e, emit) {
      final d = state.draft as FillsDraft;
      final blank = state.selected ?? d.payload.blanks.where((id) => !d.fills.containsKey(id)).firstOrNull;
      if (blank != null) emit(state.copy(draft: d.place(blank, e.word)));
    });
    on<MapAvailabilityChanged>((e, emit) {
      final d = state.draft as PinDraft;
      emit(state.copy(mapAvailable: e.available, draft: PinDraft(e.available ? d.selected : null, !e.available), selected: state.selected));
    });
    on<ExerciseOptionSelected>((e, emit) {
      if (state.draft is PinDraft) {
        if (!state.mapAvailable) return;
        final p = exercise.payload as MapPayload;
        if (!p.pins.any((pin) => pin.id == e.id)) return;
        final id = (state.draft as PinDraft).selected == e.id ? null : e.id;
        emit(
          state.copy(
            draft: PinDraft(id),
            visualParams: {
              if (p.interaction?.resetOnDeselect != true) ...state.visualParams,
              if (id != null) ...?p.interaction?.bindings[id],
            },
          ),
        );
        return;
      }
      emit(
        state.copy(
          draft: switch (state.draft) {
            OptionDraft() => OptionDraft(e.id),
            SegmentDraft() => SegmentDraft(e.id),
            PinDraft() => PinDraft((state.draft as PinDraft).selected == e.id ? null : e.id),
            _ => state.draft,
          },
        ),
      );
    });
    on<TruthSelected>((e, emit) => emit(state.copy(draft: ReasonDraft(value: e.value))));
    on<ReasonSelected>(
      (e, emit) => emit(
        state.copy(
          draft: ReasonDraft(value: (state.draft as ReasonDraft).value, reason: e.id),
        ),
      ),
    );
    on<TokenSelected>((e, emit) {
      final draft = state.draft;
      if (draft is PairsDraft && draft.pairs.containsKey(e.id)) {
        emit(state.copy(draft: draft.remove(e.id)));
      } else {
        emit(state.copy(selected: state.selected == e.id ? null : e.id));
      }
    });
    on<TokenPlaced>((e, emit) => emit(state.copy(draft: (state.draft as AssignmentsDraft).place(e.item, e.category))));
    on<TokenRemoved>(
      (e, emit) => emit(
        state.copy(
          draft: switch (state.draft) {
            final AssignmentsDraft d => d.remove(e.id),
            final OrderDraft d => d.remove(e.id),
            _ => state.draft,
          },
        ),
      ),
    );
    on<PairRightSelected>((e, emit) {
      if (state.selected != null) emit(state.copy(draft: (state.draft as PairsDraft).pair(state.selected!, e.id)));
    });
    on<OrderTokenSelected>((e, emit) => emit(state.copy(draft: (state.draft as OrderDraft).add(e.id))));
    on<MeaningToggled>((e, emit) => emit(state.copy(meaning: !state.meaning, selected: state.selected)));
    on<TransliterationToggled>((e, emit) => emit(state.copy(transliteration: !state.transliteration)));
    on<RecitationSkipped>((e, emit) async {
      _recordEpoch++;
      _recordTimer?.cancel();
      await capture?.cancelRecording();
      if ((exercise.payload as RecitePayload).skippable) {
        emit(
          state.copy(
            draft: const RecitationDraft(skipped: true),
            clearCheck: true,
            recitationStatus: recitation?.enabled == true ? RecitationStatus.idle : RecitationStatus.unavailable,
          ),
        );
      }
    });
    on<AnswerCheckPressed>((e, emit) {
      if (state.draft.isComplete) emit(state.copy(submitSerial: state.submitSerial + 1));
    });
    on<AudioListenPressed>((e, emit) async {
      if ([RecitationStatus.requesting, RecitationStatus.recording, RecitationStatus.checking].contains(state.recitationStatus) ||
          playback?.available != true ||
          state.audioStatus == RecitationPlaybackStatus.playing) {
        return;
      }
      emit(state.copy(audioStatus: RecitationPlaybackStatus.playing));
      try {
        await playback!.play(
          (p) {
            if (!isClosed) add(AudioPositionChanged(p));
          },
          (status) {
            if (!isClosed) add(AudioPlaybackChanged(status));
          },
        );
      } catch (_) {
        if (!emit.isDone) emit(state.copy(audioStatus: RecitationPlaybackStatus.failure));
      }
    });
    on<AudioPositionChanged>((e, emit) => emit(state.copy(position: e.position)));
    on<AudioPlaybackChanged>((e, emit) => emit(state.copy(audioStatus: e.status)));
  }
  final Exercise exercise;
  final RecitationPlayback? playback;
  final MediaCapture? capture;
  final RecitationRepository? recitation;
  Timer? _recordTimer;
  DateTime? _recordingStart;
  bool _closing = false;
  int _recordEpoch = 0;
  Duration get _recordLimit {
    final limit = (exercise.payload as RecitePayload).maxDuration;
    return limit < QMedia.recitationLimit ? limit : QMedia.recitationLimit;
  }

  Future<void> _record(RecitationRecordPressed event, Emitter<ExerciseStepState> emit) async {
    if (state.recitationStatus == RecitationStatus.recording) {
      add(const RecitationRecordingStopped());
      return;
    }
    if (recitation?.enabled != true ||
        capture == null ||
        [RecitationStatus.requesting, RecitationStatus.checking].contains(state.recitationStatus)) {
      return;
    }
    final epoch = ++_recordEpoch;
    if (playback case final RecitationSegmentPlayback p) await p.stop();
    emit(
      state.copy(
        audioStatus: RecitationPlaybackStatus.idle,
        recitationStatus: RecitationStatus.requesting,
        clearCheck: true,
        draft: const RecitationDraft(),
      ),
    );
    final result = await capture!.startRecording();
    if (emit.isDone || _closing || epoch != _recordEpoch) {
      await capture!.cancelRecording();
      return;
    }
    if (result case Err(:final failure)) {
      emit(state.copy(recitationStatus: RecitationStatus.failure, recitationFailure: failure));
      return;
    }
    _recordingStart = DateTime.now();
    emit(state.copy(recitationStatus: RecitationStatus.recording, recordingElapsed: Duration.zero));
    _recordTimer = Timer.periodic(QMedia.tick, (_) {
      if (!isClosed) add(const _RecitationTicked());
    });
  }

  Future<void> _stopRecord(RecitationRecordingStopped event, Emitter<ExerciseStepState> emit) async {
    if (state.recitationStatus != RecitationStatus.recording || capture == null) return;
    final epoch = _recordEpoch;
    _recordTimer?.cancel();
    emit(state.copy(recitationStatus: RecitationStatus.checking));
    final duration = Duration(
      microseconds: DateTime.now().difference(_recordingStart!).inMicroseconds.clamp(1, _recordLimit.inMicroseconds),
    );
    final recorded = await capture!.stopRecording(duration);
    if (emit.isDone || _closing || epoch != _recordEpoch) return;
    if (recorded case Err(:final failure)) {
      emit(state.copy(recitationStatus: RecitationStatus.failure, recitationFailure: failure));
      return;
    }
    final result = await recitation!.check(exercise, (recorded as Ok<MediaFile>).value, recitation!.newActionId());
    if (emit.isDone || _closing || epoch != _recordEpoch) return;
    if (result case Err(:final failure)) {
      emit(state.copy(recitationStatus: RecitationStatus.failure, recitationFailure: failure));
      return;
    }
    final check = (result as Ok<RecitationCheck>).value;
    emit(
      state.copy(
        recitationStatus: check.unclear ? RecitationStatus.unclear : RecitationStatus.evaluated,
        check: check,
        draft: check.passed && !check.unclear ? RecitationDraft(checkId: check.id) : const RecitationDraft(),
      ),
    );
  }

  final DateTime startedAt = DateTime.now();
  Duration get elapsed => DateTime.now().difference(startedAt);
  @override
  Future<void> close() async {
    _closing = true;
    _recordTimer?.cancel();
    await capture?.dispose();
    await playback?.dispose();
    return super.close();
  }
}
