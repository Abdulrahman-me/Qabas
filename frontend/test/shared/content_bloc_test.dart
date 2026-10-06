import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/shared/data/repositories/term_state_store_impl.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/repositories/content_repository.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';

import '../features/session/session_data_test.dart' show lesson;

class ContentProbe implements ContentRepository {
  final opened = <String>[];
  String? audio, source;
  bool failAudio = false, failSource = false, disposed = false;
  @override
  Future<Result<void>> markTermOpened(String id) async {
    opened.add(id);
    return const Err(NetworkFailure());
  }

  @override
  Future<Result<void>> playAudio(String url) async {
    audio = url;
    return failAudio ? const Err(NetworkFailure()) : const Ok(null);
  }

  @override
  Future<Result<void>> openSource(String url) async {
    source = url;
    return failSource ? const Err(NetworkFailure()) : const Ok(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
Source source(String id, bool displayed) => Source(
  sourceId: id,
  kind: SourceKind.hadith,
  provider: SourceProvider.hadeethenc,
  title: id,
  reference: id,
  excerpt: '',
  url: null,
  displayed: displayed,
  displayRole: DisplayRole.content,
);
void main() {
  final session = lesson('assets/mocks/salah/session_salah_en_explorer.json');
  late AppEventBus events;
  late TermStateStoreImpl store;
  late ContentProbe repo;
  late ContentBloc bloc;
  setUp(() {
    events = AppEventBus();
    store = TermStateStoreImpl(events);
    repo = ContentProbe();
    bloc = ContentBloc(store, repo);
    store.merge(session.terms);
    bloc.add(ContentReceived(session.terms, session.sources));
  });
  tearDown(() async {
    await bloc.close();
    expect(repo.disposed, true);
    await store.dispose();
    await events.dispose();
  });
  test('reviewer inspection opens terms without learner writes or lesson navigation', () async {
    final readonlyRepo = ContentProbe();
    final preview = ContentBloc(store, readonlyRepo, readOnly: true);
    final term = session.terms.values.first;
    preview.add(ContentReceived(session.terms, session.sources));
    await tick();
    preview.add(TermOpened(term.termId));
    await tick();
    expect(preview.state.selectedTerm, term);
    preview.add(TermCardOpened(term));
    preview.add(const TermLessonOpened('les_u0_l1'));
    await tick();
    expect(readonlyRepo.opened, isEmpty);
    expect(preview.state.lessonToOpen, isNull);
    await preview.close();
    expect(readonlyRepo.disposed, true);
  });
  test('term opens immediately; opened POST failure is best effort; mastery and logout propagate', () async {
    await tick();
    final term = session.terms.values.first;
    bloc.add(TermOpened(term.termId));
    await tick();
    expect(bloc.state.selectedTerm, term);
    expect(repo.opened, [term.termId]);
    expect(bloc.state.status, ContentStatus.ready);
    events.publish(TermsMastered({term.termId}));
    await tick();
    expect(bloc.state.termStates[term.termId], TermState.mastered);
    store.merge(session.terms);
    await tick();
    expect(bloc.state.termStates[term.termId], TermState.mastered);
    events.publish(const GuestSessionCleared());
    await tick();
    expect(bloc.state.termStates, isEmpty);
  });
  test('sources filter known sentence IDs; displayed first with stable server order', () async {
    bloc.add(ContentReceived(session.terms, [source('a', false), source('b', true), source('c', true), source('d', false)]));
    await tick();
    bloc.add(const SentenceSourcesOpened(null));
    await tick();
    expect(bloc.state.selectedSources!.map((s) => s.sourceId), ['b', 'c', 'a', 'd']);
    bloc.add(const SentenceSourcesOpened(['d', 'c', 'unknown']));
    await tick();
    expect(bloc.state.selectedSources!.map((s) => s.sourceId), ['c', 'd']);
    final serial = bloc.state.serial;
    bloc.add(const SentenceSourcesOpened(['missing']));
    await tick();
    expect(bloc.state.serial, serial);
  });
  test('audio and links use exact server URLs; failure and retry have explicit status', () async {
    repo.failAudio = true;
    bloc.add(const ContentAudioPlayed('https://example.invalid/a.mp3'));
    await tick();
    expect(repo.audio, 'https://example.invalid/a.mp3');
    expect(bloc.state.status, ContentStatus.failure);
    expect(bloc.state.operation, ContentOperation.audio);
    final term = session.terms.values.first;
    bloc.add(TermOpened(term.termId));
    await tick();
    expect(bloc.state.selectedTerm, term);
    expect(bloc.state.status, ContentStatus.ready);
    repo.failAudio = false;
    bloc.add(const ContentAudioPlayed('https://example.invalid/a.mp3'));
    await tick();
    expect(bloc.state.status, ContentStatus.ready);
    bloc.add(const SourceLinkOpened('https://example.invalid/source'));
    await tick();
    expect(repo.source, 'https://example.invalid/source');
    repo.failSource = true;
    bloc.add(const SourceLinkOpened('https://example.invalid/source'));
    await tick();
    expect(bloc.state.status, ContentStatus.failure);
    expect(bloc.state.operation, ContentOperation.source);
    bloc.add(const SentenceSourcesOpened(null));
    await tick();
    expect(bloc.state.status, ContentStatus.ready);
    expect(bloc.state.selectedSources, isNotEmpty);
    bloc.add(const TermLessonOpened('opaque-id'));
    await tick();
    expect(bloc.state.lessonToOpen, 'opaque-id');
  });
}
