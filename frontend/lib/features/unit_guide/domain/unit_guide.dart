import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/journey.dart';

final class GuideSection extends Equatable {
  GuideSection(this.title, List<Sentence> sentences) : sentences = List.unmodifiable(sentences);
  final String title;
  final List<Sentence> sentences;
  @override
  List<Object?> get props => [title, sentences];
}

final class UnitGuide extends Equatable {
  UnitGuide({
    required this.title,
    required List<GuideSection> sections,
    required List<Source> sources,
    required Map<String, TermCard> terms,
    this.unit,
  }) : sections = List.unmodifiable(sections),
       sources = List.unmodifiable(sources),
       terms = Map.unmodifiable(terms);
  final String title;
  final List<GuideSection> sections;
  final List<Source> sources;
  final Map<String, TermCard> terms;
  final JourneyUnit? unit;
  @override
  List<Object?> get props => [title, sections, sources, terms, unit];
}

abstract interface class UnitGuideRepository {
  Future<Result<UnitGuide>> load(String id);
}

final class GetUnitGuide {
  const GetUnitGuide(this.repository);
  final UnitGuideRepository repository;
  Future<Result<UnitGuide>> call(String id) => repository.load(id);
}
