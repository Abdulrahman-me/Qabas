// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glossary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GlossaryPageDto _$GlossaryPageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('GlossaryPageDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['next_cursor']);
  final val = GlossaryPageDto(
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => TermCardDto.fromJson(e as Map<String, dynamic>)).toList()),
    nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'nextCursor': 'next_cursor'});
