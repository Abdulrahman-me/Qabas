import 'dart:async';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import 'package:qabas/core/network/polling.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_mappers.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_remote_data_source.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_repository.dart';

final class RaqeebRepositoryImpl implements RaqeebRepository {
  const RaqeebRepositoryImpl(this.remote, {this.interval = PollTiming.interval, this.timeout = PollTiming.timeout});
  final RaqeebRemoteDataSource remote;
  final Duration interval, timeout;
  @override
  String newActionId() => newIdempotencyKey();
  @override
  Future<Result<Conversation>> start(String actionId, {Map<String, String?>? context}) =>
      guard(() async => (await remote.start(actionId, context)).toEntity());
  @override
  Future<Result<ConversationDetail>> open(String id) => guard(() async => (await remote.open(id)).toEntity());
  @override
  Future<Result<PostMessageResponse>> send(String id, String text, String actionId) =>
      guard(() async => (await remote.send(id, text, actionId)).toEntity());
  @override
  Future<Result<void>> rate(String id, AnswerRating rating) => guard(() => remote.rate(id, rating.name));
  @override
  Stream<Result<AssistantMessage>> watch(String id) {
    final cancel = PollCancellation();
    late final StreamController<Result<AssistantMessage>> controller;
    Future<void> run() async {
      try {
        await for (final m in pollUntil(
          fetch: () async => (await remote.message(id)).toEntity(),
          isDone: (m) => m is! ProcessingMessage,
          interval: interval,
          timeout: timeout,
          cancellation: cancel,
        )) {
          if (!cancel.isCancelled) controller.add(Ok(m));
        }
      } on PollTimeout {
        if (!cancel.isCancelled) controller.add(const Err(RaqeebTimeoutFailure()));
      } on FailureSource catch (error) {
        if (!cancel.isCancelled) controller.add(Err(error.toFailure()));
      } catch (_) {
        if (!cancel.isCancelled) controller.add(const Err(UnexpectedFailure('Assistant response unavailable')));
      }
      if (!controller.isClosed) unawaited(controller.close());
    }

    controller = StreamController<Result<AssistantMessage>>(onListen: run, onCancel: cancel.cancel);
    return controller.stream;
  }
}
