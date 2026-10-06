import 'dart:async';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/term_state_store.dart';

final class TermStateStoreImpl implements TermStateStore {
  TermStateStoreImpl(AppEventBus events) {
    _subscription = events.on<AppEvent>().listen((event) {
      if (event is GuestSessionCleared) _states.clear();
      if (event is TermsMastered) {
        for (final id in event.termIds) {
          _states[id] = TermState.mastered;
        }
      }
      if (event is GuestSessionCleared || event is TermsMastered) _changes.add(states);
    });
  }
  final _states = <String, TermState>{};
  final _changes = StreamController<Map<String, TermState>>.broadcast();
  late final StreamSubscription<AppEvent> _subscription;
  @override
  Map<String, TermState> get states => Map.unmodifiable(_states);
  @override
  Stream<Map<String, TermState>> get changes => _changes.stream;
  @override
  void merge(Map<String, TermCard> terms) {
    for (final term in terms.values) {
      // A-13: a stale pinned session must not undo mastery learned at finish.
      if (_states[term.termId] != TermState.mastered) _states[term.termId] = term.state;
    }
    _changes.add(states);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
