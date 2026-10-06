import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';

final class ConversationSummary extends Equatable {
  const ConversationSummary(this.id, this.title, this.preview, this.updatedAt);
  final String id;
  final String? title, preview;
  final DateTime updatedAt;
  @override
  List<Object?> get props => [id, title, preview, updatedAt];
}

final class ConversationPage extends Equatable {
  ConversationPage(List<ConversationSummary> items, this.cursor) : items = List.unmodifiable(items);
  final List<ConversationSummary> items;
  final String? cursor;
  @override
  List<Object?> get props => [items, cursor];
}

abstract interface class RaqeebMediaRepository {
  Future<Result<PostMessageResponse>> send(String id, String text, List<MediaFile> files, String key);
  Future<Result<ConversationPage>> history(String? cursor);
}

final class RaqeebMediaActions {
  const RaqeebMediaActions(this.repository);
  final RaqeebMediaRepository repository;
  Future<Result<PostMessageResponse>> send(String id, String text, List<MediaFile> files, String key) =>
      repository.send(id, text, files, key);
  Future<Result<ConversationPage>> history(String? cursor) => repository.history(cursor);
}
