import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
part 'raqeeb_dto.g.dart';

sealed class ChatMessageDto {
  const ChatMessageDto();
  factory ChatMessageDto.fromJson(Map<String, dynamic> json) =>
      json['status'] == 'received' ? UserMessageDto.fromJson(json) : AssistantMessageDto.fromJson(json);
}

sealed class AssistantMessageDto extends ChatMessageDto {
  const AssistantMessageDto();
  factory AssistantMessageDto.fromJson(Map<String, dynamic> json) => switch (json['status']) {
    'processing' => ProcessingMessageDto.fromJson(json),
    'failed' => FailedMessageDto.fromJson(json),
    'completed' => CompletedMessageDto.fromJson(json),
    _ => throw const FormatException('Unsupported assistant status'),
  };
}

sealed class AnswerBlockDto {
  const AnswerBlockDto();
  factory AnswerBlockDto.fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'paragraph' => ParagraphAnswerDto.fromJson(json),
    'evidence' => EvidenceAnswerDto.fromJson(json),
    'verification' => VerificationAnswerDto.fromJson(json),
    'differing_views' => ViewsAnswerDto.fromJson(json),
    'referral' => ReferralAnswerDto.fromJson(json),
    _ => throw const FormatException('Unsupported answer block'),
  };
}

@JsonSerializable()
final class ConversationDto {
  const ConversationDto({
    required this.conversationId,
    required this.title,
    required this.context,
    required this.createdAt,
    required this.updatedAt,
  });
  factory ConversationDto.fromJson(Map<String, dynamic> json) => _$ConversationDtoFromJson(json);
  final String conversationId;
  @JsonKey(required: true)
  final String? title;
  @JsonKey(required: true)
  final Map<String, String?>? context;
  final String createdAt;
  final String updatedAt;
}

@JsonSerializable()
final class UnderstoodImageDto {
  const UnderstoodImageDto({required this.attachmentId, required this.extractedText, required this.description});
  factory UnderstoodImageDto.fromJson(Map<String, dynamic> json) => _$UnderstoodImageDtoFromJson(json);
  final String attachmentId;
  final String extractedText;
  final String description;
}

@JsonSerializable()
final class UnderstoodDocumentDto {
  const UnderstoodDocumentDto({
    required this.attachmentId,
    required this.filename,
    required this.pagesProcessed,
    required this.truncated,
    required this.summary,
  });
  factory UnderstoodDocumentDto.fromJson(Map<String, dynamic> json) => _$UnderstoodDocumentDtoFromJson(json);
  final String attachmentId;
  final String filename;
  final int pagesProcessed;
  final bool truncated;
  final String summary;
}

@JsonSerializable()
final class UnderstoodInputDto {
  const UnderstoodInputDto({required this.transcript, required this.images, required this.document});
  factory UnderstoodInputDto.fromJson(Map<String, dynamic> json) => _$UnderstoodInputDtoFromJson(json);
  @JsonKey(required: true)
  final String? transcript;
  final List<UnderstoodImageDto> images;
  @JsonKey(required: true)
  final UnderstoodDocumentDto? document;
}

@JsonSerializable()
final class ClassificationDto {
  const ClassificationDto({required this.questionClass, required this.label});
  factory ClassificationDto.fromJson(Map<String, dynamic> json) => _$ClassificationDtoFromJson(json);
  final String questionClass;
  final String label;
}

@JsonSerializable()
final class QuoteGradeDto {
  const QuoteGradeDto({
    required this.gradeLabel,
    required this.gradeCategory,
    required this.grader,
    required this.sourceBook,
    required this.reference,
  });
  factory QuoteGradeDto.fromJson(Map<String, dynamic> json) => _$QuoteGradeDtoFromJson(json);
  final String gradeLabel;
  final String gradeCategory;
  final String grader;
  final String sourceBook;
  @JsonKey(required: true)
  final String? reference;
}

@JsonSerializable()
final class VerificationItemDto {
  const VerificationItemDto({
    required this.itemId,
    required this.quoteText,
    required this.detectedKind,
    required this.status,
    required this.hadithGrade,
    required this.correctText,
    required this.alternative,
    required this.note,
    required this.sourceIds,
  });
  factory VerificationItemDto.fromJson(Map<String, dynamic> json) => _$VerificationItemDtoFromJson(json);
  final String itemId;
  final String quoteText;
  final String detectedKind;
  final String status;
  @JsonKey(required: true)
  final QuoteGradeDto? hadithGrade;
  @JsonKey(required: true)
  final EvidenceDto? correctText;
  @JsonKey(required: true)
  final EvidenceDto? alternative;
  final List<SpanDto> note;
  final List<String> sourceIds;
}

@JsonSerializable()
final class ReferralTargetDto {
  const ReferralTargetDto({required this.name, required this.description, required this.url, required this.contact});
  factory ReferralTargetDto.fromJson(Map<String, dynamic> json) => _$ReferralTargetDtoFromJson(json);
  final String name;
  final String description;
  @JsonKey(required: true)
  final String? url;
  @JsonKey(required: true)
  final String? contact;
}

@JsonSerializable()
final class ReferralDto {
  const ReferralDto({required this.referralType, required this.reason, required this.targets});
  factory ReferralDto.fromJson(Map<String, dynamic> json) => _$ReferralDtoFromJson(json);
  final String referralType;
  final List<SpanDto> reason;
  final List<ReferralTargetDto> targets;
}

@JsonSerializable()
final class AnswerViewDto {
  const AnswerViewDto({required this.holder, required this.spans, required this.sourceIds});
  factory AnswerViewDto.fromJson(Map<String, dynamic> json) => _$AnswerViewDtoFromJson(json);
  final String holder;
  final List<SpanDto> spans;
  final List<String> sourceIds;
}

@JsonSerializable()
final class CitationDto {
  const CitationDto({required this.ref, required this.source});
  factory CitationDto.fromJson(Map<String, dynamic> json) => _$CitationDtoFromJson(json);
  final int ref;
  final SourceDto source;
}

@JsonSerializable()
final class LessonLinkDto {
  const LessonLinkDto({required this.lessonId, required this.title});
  factory LessonLinkDto.fromJson(Map<String, dynamic> json) => _$LessonLinkDtoFromJson(json);
  final String lessonId;
  final String title;
}

@JsonSerializable()
final class AttachmentDto {
  const AttachmentDto({
    required this.attachmentId,
    required this.kind,
    required this.filename,
    required this.mime,
    required this.sizeBytes,
    required this.url,
    required this.durationMs,
    required this.pages,
  });
  factory AttachmentDto.fromJson(Map<String, dynamic> json) => _$AttachmentDtoFromJson(json);
  final String attachmentId;
  final String kind;
  final String filename;
  final String mime;
  final int sizeBytes;
  @JsonKey(required: true)
  final String? url;
  @JsonKey(required: true)
  final int? durationMs;
  @JsonKey(required: true)
  final int? pages;
}

@JsonSerializable()
final class MessageErrorDto {
  const MessageErrorDto({required this.code, required this.message});
  factory MessageErrorDto.fromJson(Map<String, dynamic> json) => _$MessageErrorDtoFromJson(json);
  final String code;
  final String message;
}

@JsonSerializable()
final class UserMessageDto extends ChatMessageDto {
  const UserMessageDto({required this.messageId, required this.text, required this.attachments, required this.createdAt});
  factory UserMessageDto.fromJson(Map<String, dynamic> json) => _message(json, 'user', 'received', _$UserMessageDtoFromJson);
  final String messageId;
  @JsonKey(required: true)
  final String? text;
  final List<AttachmentDto> attachments;
  final String createdAt;
}

@JsonSerializable()
final class ProcessingMessageDto extends AssistantMessageDto {
  const ProcessingMessageDto({required this.messageId, required this.stage, required this.createdAt});
  factory ProcessingMessageDto.fromJson(Map<String, dynamic> json) =>
      _message(json, 'assistant', 'processing', _$ProcessingMessageDtoFromJson);
  final String messageId;
  final String stage;
  final String createdAt;
}

@JsonSerializable()
final class FailedMessageDto extends AssistantMessageDto {
  const FailedMessageDto({required this.messageId, required this.stage, required this.createdAt, required this.error});
  factory FailedMessageDto.fromJson(Map<String, dynamic> json) => _message(json, 'assistant', 'failed', _$FailedMessageDtoFromJson);
  final String messageId;
  final String stage;
  final String createdAt;
  final MessageErrorDto error;
}

@JsonSerializable()
final class CompletedMessageDto extends AssistantMessageDto {
  const CompletedMessageDto({
    required this.messageId,
    required this.createdAt,
    required this.completedAt,
    required this.understoodInput,
    required this.classification,
    required this.abstained,
    required this.blocks,
    required this.citations,
    required this.terms,
    required this.suggestedLessons,
    required this.feedback,
  });
  factory CompletedMessageDto.fromJson(Map<String, dynamic> json) =>
      _message(json, 'assistant', 'completed', _$CompletedMessageDtoFromJson);
  final String messageId;
  final String createdAt;
  final String completedAt;
  final UnderstoodInputDto understoodInput;
  final ClassificationDto classification;
  final bool abstained;
  final List<AnswerBlockDto> blocks;
  final List<CitationDto> citations;
  final Map<String, TermCardDto> terms;
  final List<LessonLinkDto> suggestedLessons;
  @JsonKey(required: true)
  final String? feedback;
}

@JsonSerializable()
final class ParagraphAnswerDto extends AnswerBlockDto {
  const ParagraphAnswerDto({required this.spans});
  factory ParagraphAnswerDto.fromJson(Map<String, dynamic> json) => _$ParagraphAnswerDtoFromJson(json);
  final List<SpanDto> spans;
}

@JsonSerializable()
final class EvidenceAnswerDto extends AnswerBlockDto {
  const EvidenceAnswerDto({required this.evidence});
  factory EvidenceAnswerDto.fromJson(Map<String, dynamic> json) => _$EvidenceAnswerDtoFromJson(json);
  final EvidenceDto evidence;
}

@JsonSerializable()
final class VerificationAnswerDto extends AnswerBlockDto {
  const VerificationAnswerDto({required this.items});
  factory VerificationAnswerDto.fromJson(Map<String, dynamic> json) => _$VerificationAnswerDtoFromJson(json);
  final List<VerificationItemDto> items;
}

@JsonSerializable()
final class ViewsAnswerDto extends AnswerBlockDto {
  const ViewsAnswerDto({required this.intro, required this.views});
  factory ViewsAnswerDto.fromJson(Map<String, dynamic> json) => _$ViewsAnswerDtoFromJson(json);
  final List<SpanDto> intro;
  final List<AnswerViewDto> views;
}

@JsonSerializable()
final class ReferralAnswerDto extends AnswerBlockDto {
  const ReferralAnswerDto({required this.referral});
  factory ReferralAnswerDto.fromJson(Map<String, dynamic> json) => _$ReferralAnswerDtoFromJson(json);
  final ReferralDto referral;
}

@JsonSerializable()
final class PostMessageResponseDto {
  const PostMessageResponseDto({required this.userMessage, required this.assistantMessage});
  factory PostMessageResponseDto.fromJson(Map<String, dynamic> json) => _$PostMessageResponseDtoFromJson(json);
  final UserMessageDto userMessage;
  final ProcessingMessageDto assistantMessage;
}

@JsonSerializable()
final class ConversationDetailDto {
  const ConversationDetailDto({required this.conversation, required this.messages});
  factory ConversationDetailDto.fromJson(Map<String, dynamic> json) => _$ConversationDetailDtoFromJson(json);
  final ConversationDto conversation;
  final List<ChatMessageDto> messages;
}

T _message<T>(Map<String, dynamic> json, String role, String status, T Function(Map<String, dynamic>) decode) {
  if (json['role'] != role || json['status'] != status || (status == 'completed' && json['stage'] != 'done')) {
    throw const FormatException('Invalid message discriminator');
  }
  return decode(json);
}

@JsonSerializable()
final class ConversationCreateDto {
  const ConversationCreateDto({required this.context});
  factory ConversationCreateDto.fromJson(Map<String, dynamic> json) => _$ConversationCreateDtoFromJson(json);
  @JsonKey(required: true)
  final Map<String, String?>? context;
}

@JsonSerializable()
final class AnswerFeedbackDto {
  const AnswerFeedbackDto({required this.rating, required this.reason, required this.comment});
  factory AnswerFeedbackDto.fromJson(Map<String, dynamic> json) => _$AnswerFeedbackDtoFromJson(json);
  final String rating;
  @JsonKey(required: true)
  final String? reason;
  @JsonKey(required: true)
  final String? comment;
}
