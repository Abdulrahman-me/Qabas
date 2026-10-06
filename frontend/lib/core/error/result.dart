import 'package:qabas/core/error/failures.dart';

sealed class Result<T> {
  const Result();
  R fold<R>(R Function(Failure failure) err, R Function(T value) ok) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
