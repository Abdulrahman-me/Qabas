import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';

enum RecitationStatus { unavailable, idle, requesting, recording, checking, evaluated, unclear, failure }

enum RecitationWordResult { correct, missing, substituted, extra }

final class RecitationSegment extends Equatable {
  const RecitationSegment(this.url, this.start, this.end);
  final String url;
  final Duration start, end;
  @override
  List<Object?> get props => [url, start, end];
}

final class RecitationWord extends Equatable {
  const RecitationWord(this.index, this.result, this.segment);
  final int index;
  final RecitationWordResult result;
  final RecitationSegment? segment;
  @override
  List<Object?> get props => [index, result, segment];
}

final class RecitationCheck extends Equatable {
  RecitationCheck(this.id, this.unclear, this.passed, List<RecitationWord> words, List<ContentSpan> message)
    : words = List.unmodifiable(words),
      message = List.unmodifiable(message);
  final String id;
  final bool unclear, passed;
  final List<RecitationWord> words;
  final List<ContentSpan> message;
  @override
  List<Object?> get props => [id, unclear, passed, words, message];
}

abstract interface class RecitationRepository {
  bool get enabled;
  Future<Result<RecitationCheck>> check(Exercise exercise, MediaFile audio, String key);
  String newActionId();
}

abstract interface class RecitationSegmentPlayback implements RecitationPlayback {
  Future<void> stop();
  Future<void> playSegment(RecitationSegment segment, void Function(RecitationPlaybackStatus) status);
}
