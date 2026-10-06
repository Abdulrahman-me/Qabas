import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/repositories/content_repository.dart';
import 'package:qabas/shared/domain/term_state_store.dart';

enum ContentStatus { ready, working, failure }

enum ContentOperation { audio, source }

final class ContentState extends Equatable {
  ContentState({
    this.status = ContentStatus.ready,
    this.operation,
    Map<String, TermCard> terms = const {},
    Map<String, TermState> termStates = const {},
    List<Source> sources = const [],
    this.selectedTerm,
    List<Source>? selectedSources,
    this.lessonToOpen,
    this.serial = 0,
  }) : terms = Map.unmodifiable(terms),
       termStates = Map.unmodifiable(termStates),
       sources = List.unmodifiable(sources),
       selectedSources = selectedSources == null ? null : List.unmodifiable(selectedSources);
  final ContentStatus status;
  final ContentOperation? operation;
  final Map<String, TermCard> terms;
  final Map<String, TermState> termStates;
  final List<Source> sources;
  final TermCard? selectedTerm;
  final List<Source>? selectedSources;
  final String? lessonToOpen;
  final int serial;
  ContentState changed({
    ContentStatus? status,
    ContentOperation? operation,
    Map<String, TermCard>? terms,
    Map<String, TermState>? states,
    List<Source>? sources,
    TermCard? term,
    List<Source>? selection,
    String? lessonId,
    bool action = false,
  }) => ContentState(
    status: status ?? this.status,
    operation: operation ?? this.operation,
    terms: terms ?? this.terms,
    termStates: states ?? termStates,
    sources: sources ?? this.sources,
    selectedTerm: term,
    selectedSources: selection,
    lessonToOpen: lessonId,
    serial: serial + (action ? 1 : 0),
  );
  @override
  List<Object?> get props => [status, operation, terms, termStates, sources, selectedTerm, selectedSources, lessonToOpen, serial];
}

sealed class ContentEvent {
  const ContentEvent();
}

final class ContentReceived extends ContentEvent {
  const ContentReceived(this.terms, this.sources);
  final Map<String, TermCard> terms;
  final List<Source> sources;
}

final class TermStatesReceived extends ContentEvent {
  const TermStatesReceived(this.states);
  final Map<String, TermState> states;
}

final class TermCardOpened extends ContentEvent {
  const TermCardOpened(this.term);
  final TermCard term;
}

final class TermOpened extends ContentEvent {
  const TermOpened(this.id);
  final String id;
}

final class SentenceSourcesOpened extends ContentEvent {
  const SentenceSourcesOpened(this.ids);
  final List<String>? ids;
}

final class ContentAudioPlayed extends ContentEvent {
  const ContentAudioPlayed(this.url);
  final String url;
}

final class SourceLinkOpened extends ContentEvent {
  const SourceLinkOpened(this.url);
  final String url;
}

final class TermLessonOpened extends ContentEvent {
  const TermLessonOpened(this.id);
  final String id;
}

final class ContentBloc extends Bloc<ContentEvent, ContentState> {
  ContentBloc(this.store, this.repository, {this.readOnly = false}) : super(ContentState()) {
    on<ContentReceived>(
      (e, emit) => emit(state.changed(status: ContentStatus.ready, terms: e.terms, sources: e.sources, states: store.states)),
    );
    on<TermStatesReceived>((e, emit) => emit(state.changed(states: e.states)));
    on<TermCardOpened>((e, emit) {
      emit(state.changed(status: ContentStatus.ready, term: e.term, action: true));
      if (!readOnly) unawaited(repository.markTermOpened(e.term.termId));
    });
    on<TermOpened>((e, emit) {
      final term = state.terms[e.id];
      if (term == null) return;
      emit(state.changed(status: ContentStatus.ready, term: term, action: true));
      if (!readOnly) unawaited(repository.markTermOpened(e.id));
    });
    on<SentenceSourcesOpened>((e, emit) {
      final matching = state.sources.where((s) => e.ids == null || e.ids!.contains(s.sourceId));
      // Displayed evidence first, preserving server order within each group.
      final sources = [...matching.where((s) => s.displayed), ...matching.where((s) => !s.displayed)];
      if (sources.isNotEmpty) emit(state.changed(status: ContentStatus.ready, selection: sources, action: true));
    });
    on<ContentAudioPlayed>((e, emit) => _action(ContentOperation.audio, () => repository.playAudio(e.url), emit));
    on<SourceLinkOpened>((e, emit) => _action(ContentOperation.source, () => repository.openSource(e.url), emit));
    on<TermLessonOpened>((e, emit) {
      if (!readOnly) emit(state.changed(status: ContentStatus.ready, lessonId: e.id, action: true));
    });
    _subscription = store.changes.listen((states) {
      if (!isClosed) add(TermStatesReceived(states));
    });
  }
  final bool readOnly;
  final TermStateStore store;
  final ContentRepository repository;
  late final StreamSubscription<Map<String, TermState>> _subscription;
  Future<void> _action(ContentOperation operation, Future<Result<void>> Function() action, Emitter<ContentState> emit) async {
    emit(state.changed(status: ContentStatus.working, operation: operation));
    final result = await action();
    if (!emit.isDone) emit(state.changed(status: result is Err<void> ? ContentStatus.failure : ContentStatus.ready));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
    await repository.dispose();
  }
}
