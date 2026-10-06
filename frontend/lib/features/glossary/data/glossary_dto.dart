import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
part 'glossary_dto.g.dart';

@JsonSerializable()
final class GlossaryPageDto {
  const GlossaryPageDto({required this.items, required this.nextCursor});
  factory GlossaryPageDto.fromJson(Map<String, dynamic> j) => _$GlossaryPageDtoFromJson(j);
  final List<TermCardDto> items;
  @JsonKey(required: true)
  final String? nextCursor;
}
