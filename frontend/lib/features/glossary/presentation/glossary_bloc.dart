import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/glossary/domain/glossary.dart';
import 'package:qabas/shared/domain/entities/content.dart';

enum GlossaryStatus { initial, loading, ready, failure }

final class GlossaryState extends Equatable {
  GlossaryState({
    this.status = GlossaryStatus.initial,
    this.filter = 'all',
    List<TermCard> items = const [],
    this.cursor,
    this.failure,
    this.paging = false,
  }) : items = List.unmodifiable(items);
  final GlossaryStatus status;
  final String filter;
  final List<TermCard> items;
  final String? cursor;
  final Failure? failure;
  final bool paging;
  @override
  List<Object?> get props => [status, filter, items, cursor, failure, paging];
}

sealed class GlossaryEvent {
  const GlossaryEvent();
}

final class GlossaryOpened extends GlossaryEvent {
  const GlossaryOpened();
}

final class GlossaryFilterSelected extends GlossaryEvent {
  const GlossaryFilterSelected(this.filter);
  final String filter;
}

final class GlossaryPageRequested extends GlossaryEvent {
  const GlossaryPageRequested();
}

final class GlossaryBloc extends Bloc<GlossaryEvent, GlossaryState> {
  GlossaryBloc(this.getGlossary) : super(GlossaryState()) {
    on<GlossaryEvent>(
      (e, emit) async {
        final paging = e is GlossaryPageRequested;
        if (paging && (state.cursor == null || state.paging || state.status != GlossaryStatus.ready)) return;
        final filter = e is GlossaryFilterSelected ? e.filter : state.filter;
        if (!['all', 'new', 'learning', 'mastered'].contains(filter)) return;
        final old = e is GlossaryFilterSelected ? <TermCard>[] : state.items;
        final cursor = state.cursor;
        emit(
          GlossaryState(
            status: paging ? GlossaryStatus.ready : GlossaryStatus.loading,
            filter: filter,
            items: old,
            cursor: paging ? state.cursor : null,
            paging: paging,
          ),
        );
        final result = await getGlossary(filter: filter, cursor: paging ? cursor : null);
        if (emit.isDone) return;
        switch (result) {
          case Ok(:final value):
            emit(
              GlossaryState(
                status: GlossaryStatus.ready,
                filter: filter,
                items:
                    (paging
                            ? {
                                for (final t in [...old, ...value.items]) t.termId: t,
                              }.values
                            : value.items)
                        .toList(),
                cursor: value.nextCursor,
              ),
            );
          case Err(:final failure):
            emit(
              GlossaryState(
                status: old.isEmpty ? GlossaryStatus.failure : GlossaryStatus.ready,
                filter: filter,
                items: old,
                cursor: cursor,
                failure: failure,
              ),
            );
        }
      },
      transformer: (events, mapper) => restartable<GlossaryEvent>()(
        events.where(
          (event) => event is! GlossaryPageRequested || (state.status == GlossaryStatus.ready && !state.paging && state.cursor != null),
        ),
        mapper,
      ),
    );
  }
  final GetGlossary getGlossary;
}
