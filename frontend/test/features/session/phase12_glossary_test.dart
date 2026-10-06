import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/glossary/domain/glossary.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';

class Pages implements GlossaryRepository {
  final calls = <({String filter, String? cursor, Completer<Result<WordsPage>> result})>[];
  @override
  Future<Result<WordsPage>> load({required String filter, String? cursor}) {
    final c = Completer<Result<WordsPage>>();
    calls.add((filter: filter, cursor: cursor, result: c));
    return c.future;
  }
}

Future<void> waitFor(bool Function() ready) async {
  for (var n = 0; n < 100 && !ready(); n++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(ready(), true);
}

void main() {
  late Pages repo;
  late GlossaryBloc b;
  late TermCard term;
  setUp(() {
    final j = jsonDecode(File('assets/mocks/examples/TermCard__5_4_termcard__0.json').readAsStringSync()) as Map<String, dynamic>;
    term = TermCardDto.fromJson(j).toEntity();
    repo = Pages();
    b = GlossaryBloc(GetGlossary(repo));
  });
  tearDown(() => b.close());
  test('paging uses opaque cursor, ignores duplicate requests and merges identities', () async {
    b.add(const GlossaryOpened());
    await waitFor(() => repo.calls.length == 1);
    repo.calls[0].result.complete(Ok(WordsPage([term], 'opaque-page')));
    await waitFor(() => b.state.status == GlossaryStatus.ready);
    b.add(const GlossaryPageRequested());
    await waitFor(() => repo.calls.length == 2);
    b.add(const GlossaryPageRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.calls.length, 2);
    expect(repo.calls[1].cursor, 'opaque-page');
    repo.calls[1].result.complete(Ok(WordsPage([term], null)));
    await waitFor(() => !b.state.paging);
    expect(b.state.items, [term]);
    expect(b.state.cursor, isNull);
  });
  test('a changed filter wins over an outstanding page response', () async {
    b.add(const GlossaryOpened());
    await waitFor(() => repo.calls.length == 1);
    repo.calls[0].result.complete(Ok(WordsPage([term], 'more')));
    await waitFor(() => b.state.status == GlossaryStatus.ready);
    b.add(const GlossaryPageRequested());
    await waitFor(() => repo.calls.length == 2);
    b.add(const GlossaryFilterSelected('new'));
    await waitFor(() => repo.calls.length == 3);
    repo.calls[2].result.complete(Ok(WordsPage([], null)));
    await waitFor(() => b.state.status == GlossaryStatus.ready);
    repo.calls[1].result.complete(Ok(WordsPage([term], 'stale')));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(b.state.filter, 'new');
    expect(b.state.items, isEmpty);
    expect(b.state.cursor, isNull);
  });
  test('page failure keeps the list and cursor and retries the same page', () async {
    b.add(const GlossaryOpened());
    await waitFor(() => repo.calls.length == 1);
    repo.calls[0].result.complete(Ok(WordsPage([term], 'same-page')));
    await waitFor(() => b.state.status == GlossaryStatus.ready);
    b.add(const GlossaryPageRequested());
    await waitFor(() => repo.calls.length == 2);
    repo.calls[1].result.complete(const Err(NetworkFailure()));
    await waitFor(() => b.state.failure != null);
    expect(b.state.items, [term]);
    expect(b.state.cursor, 'same-page');
    b.add(const GlossaryPageRequested());
    await waitFor(() => repo.calls.length == 3);
    expect(repo.calls[2].cursor, 'same-page');
    repo.calls[2].result.complete(Ok(WordsPage([], null)));
    await waitFor(() => !b.state.paging);
    expect(b.state.failure, isNull);
  });
  test('initial failure retries and empty results remain ready', () async {
    b.add(const GlossaryOpened());
    await waitFor(() => repo.calls.length == 1);
    repo.calls[0].result.complete(const Err(NetworkFailure()));
    await waitFor(() => b.state.status == GlossaryStatus.failure);
    b.add(const GlossaryOpened());
    await waitFor(() => repo.calls.length == 2);
    repo.calls[1].result.complete(Ok(WordsPage([], null)));
    await waitFor(() => b.state.status == GlossaryStatus.ready);
    expect(b.state.items, isEmpty);
  });
}
