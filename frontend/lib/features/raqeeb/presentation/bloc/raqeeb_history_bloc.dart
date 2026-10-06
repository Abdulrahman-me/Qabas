import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';

enum HistoryStatus { initial, loading, ready, paging, failure }

final class RaqeebHistoryState extends Equatable {
  RaqeebHistoryState({this.status = HistoryStatus.initial, List<ConversationSummary> items = const [], this.cursor, this.failure})
    : items = List.unmodifiable(items);
  final HistoryStatus status;
  final List<ConversationSummary> items;
  final String? cursor;
  final Failure? failure;
  @override
  List<Object?> get props => [status, items, cursor, failure];
}

final class RaqeebHistoryOpened {
  const RaqeebHistoryOpened({this.more = false});
  final bool more;
}

final class RaqeebHistoryBloc extends Bloc<RaqeebHistoryOpened, RaqeebHistoryState> {
  RaqeebHistoryBloc(this.actions) : super(RaqeebHistoryState()) {
    on<RaqeebHistoryOpened>((e, emit) async {
      if (e.more && (state.cursor == null || state.status == HistoryStatus.paging)) return;
      emit(RaqeebHistoryState(status: e.more ? HistoryStatus.paging : HistoryStatus.loading, items: state.items, cursor: state.cursor));
      final result = await actions.history(e.more ? state.cursor : null);
      if (emit.isDone) return;
      if (result case Err(:final failure)) {
        emit(RaqeebHistoryState(status: HistoryStatus.failure, items: state.items, cursor: state.cursor, failure: failure));
      } else {
        final p = (result as Ok<ConversationPage>).value;
        emit(
          RaqeebHistoryState(
            status: HistoryStatus.ready,
            items: [if (e.more) ...state.items, ...p.items.where((i) => !e.more || !state.items.any((old) => old.id == i.id))],
            cursor: p.cursor,
          ),
        );
      }
    }, transformer: droppable());
  }
  final RaqeebMediaActions actions;
}
