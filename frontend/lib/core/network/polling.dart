import 'dart:async';

abstract final class PollTiming {
  static const interval = Duration(seconds: 1), timeout = Duration(seconds: 90);
}

final class PollTimeout implements Exception {
  const PollTimeout();
}

final class _PollCancelled implements Exception {
  const _PollCancelled();
}

final class PollCancellation {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  Future<void> wait(Duration interval) => Future.any([Future<void>.delayed(interval), _cancelled.future]);
}

Stream<T> pollUntil<T>({
  required Future<T> Function() fetch,
  required bool Function(T) isDone,
  Duration interval = const Duration(seconds: 1),
  Duration timeout = const Duration(seconds: 90),
  PollCancellation? cancellation,
  DateTime Function()? now,
}) async* {
  final clock = now ?? DateTime.now;
  final deadline = clock().add(timeout);
  while (cancellation?.isCancelled != true) {
    if (!clock().isBefore(deadline)) throw const PollTimeout();
    T value;
    try {
      value = await Future.any<T>([
        fetch(),
        if (cancellation != null) cancellation._cancelled.future.then<T>((_) => throw const _PollCancelled()),
      ]).timeout(deadline.difference(clock()));
    } on _PollCancelled {
      return;
    } on TimeoutException {
      throw const PollTimeout();
    }
    if (cancellation?.isCancelled == true) return;
    yield value;
    if (isDone(value)) return;
    if (!clock().isBefore(deadline)) throw const PollTimeout();
    if (cancellation != null) {
      await cancellation.wait(interval);
    } else {
      await Future<void>.delayed(interval);
    }
  }
}
