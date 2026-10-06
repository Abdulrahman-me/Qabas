import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_actions.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';

enum MediaComposerStatus { idle, picking, recording, stopping }

enum ChatStatus { welcome, loading, ready, sending, processing, failure }

final class ChatTurn extends Equatable {
  ChatTurn({
    required this.key,
    required this.text,
    this.user,
    this.assistant,
    this.failure,
    this.sendFailed = false,
    List<MediaFile> files = const [],
  }) : files = List.unmodifiable(files);
  final String key, text;
  final List<MediaFile> files;
  final UserMessage? user;
  final AssistantMessage? assistant;
  final Failure? failure;
  final bool sendFailed;
  ChatTurn changed({UserMessage? user, AssistantMessage? assistant, Failure? failure, bool sendFailed = false}) => ChatTurn(
    key: key,
    text: text,
    files: files,
    user: user ?? this.user,
    assistant: assistant ?? this.assistant,
    failure: failure,
    sendFailed: sendFailed,
  );
  @override
  List<Object?> get props => [key, text, user, assistant, failure, sendFailed, files];
}

final class RaqeebChatState extends Equatable {
  RaqeebChatState({
    this.status = ChatStatus.welcome,
    this.conversation,
    List<ChatTurn> turns = const [],
    this.failure,
    Map<String, AnswerRating> ratings = const {},
    this.ratingId,
    this.ratingFailure,
    this.draft = '',
    this.epoch = 0,
    List<MediaFile> attachments = const [],
    this.mediaStatus = MediaComposerStatus.idle,
    this.recordingElapsed = Duration.zero,
  }) : attachments = List.unmodifiable(attachments),
       turns = List.unmodifiable(turns),
       ratings = Map.unmodifiable(ratings);
  final ChatStatus status;
  final Conversation? conversation;
  final List<ChatTurn> turns;
  final Failure? failure, ratingFailure;
  final Map<String, AnswerRating> ratings;
  final String? ratingId;
  final String draft;
  final int epoch;
  final List<MediaFile> attachments;
  final MediaComposerStatus mediaStatus;
  final Duration recordingElapsed;
  bool get busy =>
      [ChatStatus.loading, ChatStatus.sending, ChatStatus.processing].contains(status) || mediaStatus != MediaComposerStatus.idle;
  RaqeebChatState changed({
    ChatStatus? status,
    Conversation? conversation,
    List<ChatTurn>? turns,
    Failure? failure,
    Map<String, AnswerRating>? ratings,
    String? ratingId,
    Failure? ratingFailure,
    String? draft,
    List<MediaFile>? attachments,
    MediaComposerStatus? mediaStatus,
    Duration? recordingElapsed,
  }) => RaqeebChatState(
    status: status ?? this.status,
    conversation: conversation ?? this.conversation,
    turns: turns ?? this.turns,
    failure: failure,
    ratings: ratings ?? this.ratings,
    ratingId: ratingId,
    ratingFailure: ratingFailure,
    draft: draft ?? this.draft,
    epoch: epoch,
    attachments: attachments ?? this.attachments,
    mediaStatus: mediaStatus ?? this.mediaStatus,
    recordingElapsed: recordingElapsed ?? this.recordingElapsed,
  );
  @override
  List<Object?> get props => [
    status,
    conversation,
    turns,
    failure,
    ratings,
    ratingId,
    ratingFailure,
    draft,
    epoch,
    attachments,
    mediaStatus,
    recordingElapsed,
  ];
}

sealed class RaqeebChatEvent {
  const RaqeebChatEvent();
}

final class ComposerChanged extends RaqeebChatEvent {
  const ComposerChanged(this.text);
  final String text;
}

final class MessageSent extends RaqeebChatEvent {
  const MessageSent(this.text);
  final String text;
}

final class RetryRequested extends RaqeebChatEvent {
  const RetryRequested(this.key);
  final String key;
}

final class ConversationOpened extends RaqeebChatEvent {
  const ConversationOpened(this.id);
  final String id;
}

final class AttachmentUrlFailed extends RaqeebChatEvent {
  const AttachmentUrlFailed(this.id);
  final String id;
}

final class NewConversationRequested extends RaqeebChatEvent {
  const NewConversationRequested();
}

final class AnswerRated extends RaqeebChatEvent {
  const AnswerRated(this.id, this.rating);
  final String id;
  final AnswerRating rating;
}

final class AttachmentPicked extends RaqeebChatEvent {
  const AttachmentPicked(this.kind, {this.camera = false});
  final MediaKind kind;
  final bool camera;
}

final class AttachmentRemoved extends RaqeebChatEvent {
  const AttachmentRemoved(this.index);
  final int index;
}

final class VoiceRecordingStarted extends RaqeebChatEvent {
  const VoiceRecordingStarted();
}

final class VoiceRecordingStopped extends RaqeebChatEvent {
  const VoiceRecordingStopped();
}

final class VoiceRecordingCancelled extends RaqeebChatEvent {
  const VoiceRecordingCancelled();
}

final class MicrophoneSettingsOpened extends RaqeebChatEvent {
  const MicrophoneSettingsOpened();
}

final class _RecordingTicked extends RaqeebChatEvent {
  const _RecordingTicked();
}

final class _AssistantReceived extends RaqeebChatEvent {
  const _AssistantReceived(this.key, this.value, this.epoch);
  final String key;
  final Result<AssistantMessage> value;
  final int epoch;
}

final class _AccountReset extends RaqeebChatEvent {
  const _AccountReset();
}

final class RaqeebChatBloc extends Bloc<RaqeebChatEvent, RaqeebChatState> {
  RaqeebChatBloc({
    required this._start,
    required this._open,
    required this._send,
    required this._watch,
    required this._rate,
    AppEventBus? events,
    this._capture,
    this._media,
  }) : super(RaqeebChatState()) {
    on<RaqeebChatEvent>((event, emit) async {
      switch (event) {
        case AttachmentPicked():
          await _pick(event, emit);
        case AttachmentRemoved(:final index):
          if (!state.busy && index >= 0 && index < state.attachments.length) {
            emit(
              state.changed(
                attachments: [
                  for (var i = 0; i < state.attachments.length; i++)
                    if (i != index) state.attachments[i],
                ],
              ),
            );
          }
        case VoiceRecordingStarted():
          await _record(emit);
        case VoiceRecordingStopped():
          await _stop(emit);
        case VoiceRecordingCancelled():
          _recordingTick?.cancel();
          await _capture?.cancelRecording();
          emit(state.changed(mediaStatus: MediaComposerStatus.idle, recordingElapsed: Duration.zero));
        case MicrophoneSettingsOpened():
          await _capture?.openSettings();
        case _RecordingTicked():
          if (state.mediaStatus == MediaComposerStatus.recording) {
            final elapsed = DateTime.now().difference(_recordingStart!);
            emit(state.changed(recordingElapsed: elapsed));
            if (elapsed >= QMedia.voiceLimit) {
              _recordingTick?.cancel();
              add(const VoiceRecordingStopped());
            }
          }

        case ComposerChanged(:final text):
          if (!state.busy) emit(state.changed(draft: text));
        case MessageSent(:final text):
          if (!state.busy && (text.trim().isNotEmpty || state.attachments.isNotEmpty)) await _submit(text.trim(), emit);
        case RetryRequested(:final key):
          if (state.busy) return;
          final turn = state.turns.where((t) => t.key == key).firstOrNull;
          if (turn == null) return;
          if (turn.sendFailed) {
            await _submit(turn.text, emit, retry: turn);
          } else if (turn.assistant is FailedMessage || turn.failure is RaqeebTimeoutFailure) {
            await _submit(turn.text, emit, files: turn.files);
          } else if (turn.assistant is ProcessingMessage) {
            emit(state.changed(status: ChatStatus.processing, turns: _replace(turn.changed())));
            _observe(turn.key, turn.assistant!.messageId);
          }
        case AttachmentUrlFailed(:final id):
          final conversation = state.conversation;
          if (conversation == null || !_refreshedUrls.add(id)) return;
          final epoch = _epoch;
          final refreshed = await _open(conversation.conversationId);
          if (emit.isDone || epoch != _epoch) return;
          if (refreshed case Ok(:final value)) {
            final users = {for (final message in value.messages.whereType<UserMessage>()) message.messageId: message};
            emit(
              state.changed(
                turns: [
                  for (final turn in state.turns)
                    turn.user != null && users.containsKey(turn.user!.messageId) ? turn.changed(user: users[turn.user!.messageId]) : turn,
                ],
              ),
            );
          }
        case ConversationOpened(:final id):
          await _load(id, emit);
        case NewConversationRequested():
          if (!state.busy) await _reset(emit);
        case _AccountReset():
          await _reset(emit);
        case _AssistantReceived():
          _received(event, emit);
        case AnswerRated():
          await _rating(event, emit);
      }
    }, transformer: sequential());
    _events = events?.on<GuestSessionCleared>().listen((_) {
      _epoch++;
      if (!isClosed) add(const _AccountReset());
    });
  }
  final MediaCapture? _capture;
  final RaqeebMediaActions? _media;
  Timer? _recordingTick;
  DateTime? _recordingStart;
  final StartConversation _start;
  final OpenConversation _open;
  final SendRaqeebMessage _send;
  final WatchAssistantMessage _watch;
  final RateAnswer _rate;
  StreamSubscription<Result<AssistantMessage>>? _poll;
  StreamSubscription<GuestSessionCleared>? _events;
  final Set<String> _refreshedUrls = {};
  String? _createKey;
  int _epoch = 0;
  List<ChatTurn> _replace(ChatTurn turn) => [for (final old in state.turns) old.key == turn.key ? turn : old];
  Future<void> _reset(Emitter<RaqeebChatState> emit) async {
    _epoch++;
    _recordingTick?.cancel();
    await _capture?.cancelRecording();
    final previous = _poll;
    _poll = null;
    _createKey = null;
    _refreshedUrls.clear();
    emit(RaqeebChatState(epoch: _epoch));
    await previous?.cancel();
  }

  Future<void> _pick(AttachmentPicked event, Emitter<RaqeebChatState> emit) async {
    if (state.busy || _capture == null) return;
    final kind = event.kind, count = state.attachments.where((f) => f.kind == kind).length;
    if (count >= (kind == MediaKind.image ? 3 : 1)) {
      emit(state.changed(failure: MediaLimitFailure(kind, count: true)));
      return;
    }
    final epoch = _epoch;
    emit(state.changed(mediaStatus: MediaComposerStatus.picking));
    final result = kind == MediaKind.image ? await _capture.image(camera: event.camera) : await _capture.document();
    if (emit.isDone || epoch != _epoch) return;
    if (result case Err(:final failure)) {
      emit(state.changed(mediaStatus: MediaComposerStatus.idle, failure: failure));
      return;
    }
    final file = (result as Ok<MediaFile?>).value;
    final failure = file == null ? null : validateMedia(file);
    emit(
      state.changed(
        mediaStatus: MediaComposerStatus.idle,
        attachments: file == null || failure != null ? state.attachments : [...state.attachments, file],
        failure: failure,
      ),
    );
  }

  Future<void> _record(Emitter<RaqeebChatState> emit) async {
    if (state.busy || _capture == null) return;
    if (state.attachments.any((f) => f.kind == MediaKind.audio)) {
      emit(state.changed(failure: const MediaLimitFailure(MediaKind.audio, count: true)));
      return;
    }
    final epoch = _epoch;
    emit(state.changed(mediaStatus: MediaComposerStatus.picking));
    final result = await _capture.startRecording();
    if (emit.isDone || epoch != _epoch) {
      await _capture.cancelRecording();
      return;
    }
    if (result case Err(:final failure)) {
      emit(state.changed(mediaStatus: MediaComposerStatus.idle, failure: failure));
      return;
    }
    _recordingStart = DateTime.now();
    emit(state.changed(mediaStatus: MediaComposerStatus.recording, recordingElapsed: Duration.zero));
    _recordingTick = Timer.periodic(QMedia.tick, (_) {
      if (!isClosed) add(const _RecordingTicked());
    });
  }

  Future<void> _stop(Emitter<RaqeebChatState> emit) async {
    if (state.mediaStatus != MediaComposerStatus.recording || _capture == null) return;
    _recordingTick?.cancel();
    final epoch = _epoch,
        duration = Duration(
          microseconds: DateTime.now().difference(_recordingStart!).inMicroseconds.clamp(1, QMedia.voiceLimit.inMicroseconds),
        );
    emit(state.changed(mediaStatus: MediaComposerStatus.stopping));
    final result = await _capture.stopRecording(duration);
    if (emit.isDone || epoch != _epoch) return;
    if (result case Err(:final failure)) {
      emit(state.changed(mediaStatus: MediaComposerStatus.idle, failure: failure));
      return;
    }
    final file = (result as Ok<MediaFile>).value, failure = validateMedia(file);
    emit(
      state.changed(
        mediaStatus: MediaComposerStatus.idle,
        recordingElapsed: Duration.zero,
        attachments: failure == null ? [...state.attachments, file] : state.attachments,
        failure: failure,
      ),
    );
  }

  Future<void> _submit(String text, Emitter<RaqeebChatState> emit, {ChatTurn? retry, List<MediaFile>? files}) async {
    if (text.runes.length > 2000) {
      emit(state.changed(failure: const RaqeebTextLimitFailure()));
      return;
    }
    final epoch = _epoch;
    final upload = retry?.files ?? files ?? state.attachments;
    var turn = retry?.changed() ?? ChatTurn(key: _start.newActionId(), text: text, files: upload);
    emit(
      state.changed(
        status: ChatStatus.sending,
        turns: retry == null ? [...state.turns, turn] : _replace(turn),
        draft: '',
        attachments: const [],
      ),
    );
    if (state.conversation == null) {
      _createKey ??= _start.newActionId();
      final created = await _start(_createKey!);
      if (emit.isDone || epoch != _epoch) return;
      switch (created) {
        case Err(:final failure):
          emit(
            state.changed(
              status: ChatStatus.failure,
              turns: _replace(turn.changed(failure: failure, sendFailed: true)),
            ),
          );
          return;
        case Ok(:final value):
          emit(state.changed(conversation: value));
      }
    }
    final sent = upload.isNotEmpty && _media != null
        ? await _media.send(state.conversation!.conversationId, text, upload, turn.key)
        : await _send(state.conversation!.conversationId, text, turn.key);
    if (emit.isDone || epoch != _epoch) return;
    switch (sent) {
      case Err(:final failure):
        if (failure is ConflictFailure && failure.code == 'answer_in_progress') {
          // Recover the accepted answer after a timeout or another client send.
          final recovered = await _open(state.conversation!.conversationId);
          if (emit.isDone || epoch != _epoch) return;
          if (recovered case Ok(value: final detail)) {
            _adopt(detail, emit);
            return;
          }
        }
        emit(
          state.changed(
            status: ChatStatus.failure,
            turns: _replace(turn.changed(failure: failure, sendFailed: true)),
          ),
        );
      case Ok(:final value):
        turn = turn.changed(user: value.userMessage, assistant: value.assistantMessage);
        emit(state.changed(status: ChatStatus.processing, turns: _replace(turn)));
        _observe(turn.key, value.assistantMessage.messageId);
    }
  }

  void _observe(String key, String id) {
    unawaited(_poll?.cancel());
    final epoch = _epoch;
    _poll = _watch(id).listen(
      (value) {
        if (!isClosed && epoch == _epoch) add(_AssistantReceived(key, value, epoch));
      },
      onError: (Object _) {
        if (!isClosed && epoch == _epoch) add(_AssistantReceived(key, const Err(NetworkFailure()), epoch));
      },
    );
  }

  void _received(_AssistantReceived event, Emitter<RaqeebChatState> emit) {
    if (event.epoch != _epoch) return;
    final turn = state.turns.where((t) => t.key == event.key).firstOrNull;
    if (turn == null) return;
    switch (event.value) {
      case Err(:final failure):
        emit(
          state.changed(
            status: ChatStatus.failure,
            turns: _replace(turn.changed(failure: failure)),
          ),
        );
      case Ok(:final value):
        emit(
          state.changed(
            status: value is ProcessingMessage ? ChatStatus.processing : ChatStatus.ready,
            turns: _replace(turn.changed(assistant: value)),
          ),
        );
    }
  }

  Future<void> _load(String id, Emitter<RaqeebChatState> emit) async {
    _epoch++;
    final epoch = _epoch;
    await _poll?.cancel();
    emit(state.changed(status: ChatStatus.loading));
    final result = await _open(id);
    if (emit.isDone || epoch != _epoch) return;
    switch (result) {
      case Err(:final failure):
        emit(state.changed(status: ChatStatus.failure, failure: failure));
      case Ok(:final value):
        _adopt(value, emit);
    }
  }

  void _adopt(ConversationDetail detail, Emitter<RaqeebChatState> emit) {
    final turns = <ChatTurn>[];
    for (final m in detail.messages) {
      if (m is UserMessage) turns.add(ChatTurn(key: m.messageId, text: m.text ?? '', user: m));
      if (m is AssistantMessage) {
        if (turns.isEmpty || turns.last.assistant != null) turns.add(ChatTurn(key: m.messageId, text: ''));
        turns[turns.length - 1] = turns.last.changed(assistant: m);
      }
    }
    emit(
      RaqeebChatState(
        status: turns.any((t) => t.assistant is ProcessingMessage)
            ? ChatStatus.processing
            : turns.isEmpty
            ? ChatStatus.welcome
            : ChatStatus.ready,
        conversation: detail.conversation,
        turns: turns,
        epoch: _epoch,
      ),
    );
    final pending = turns.where((t) => t.assistant is ProcessingMessage).firstOrNull;
    if (pending != null) _observe(pending.key, pending.assistant!.messageId);
  }

  Future<void> _rating(AnswerRated event, Emitter<RaqeebChatState> emit) async {
    if (state.ratingId != null || !state.turns.any((t) => t.assistant is CompletedMessage && t.assistant!.messageId == event.id)) return;
    final epoch = _epoch;
    emit(state.changed(ratingId: event.id));
    final result = await _rate(event.id, event.rating);
    if (emit.isDone || epoch != _epoch) return;
    switch (result) {
      case Err(:final failure):
        emit(state.changed(ratingFailure: failure));
      case Ok():
        emit(state.changed(ratings: {...state.ratings, event.id: event.rating}));
    }
  }

  @override
  Future<void> close() async {
    _epoch++;
    _recordingTick?.cancel();
    await _capture?.dispose();
    await _events?.cancel();
    await _poll?.cancel();
    return super.close();
  }
}
