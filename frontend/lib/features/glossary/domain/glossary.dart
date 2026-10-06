import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/content.dart';

final class WordsPage extends Equatable {
  WordsPage(List<TermCard> items, this.nextCursor) : items = List.unmodifiable(items);
  final List<TermCard> items;
  final String? nextCursor;
  @override
  List<Object?> get props => [items, nextCursor];
}

abstract interface class GlossaryRepository {
  Future<Result<WordsPage>> load({required String filter, String? cursor});
}

final class GetGlossary {
  const GetGlossary(this.repository);
  final GlossaryRepository repository;
  Future<Result<WordsPage>> call({required String filter, String? cursor}) => repository.load(filter: filter, cursor: cursor);
}
