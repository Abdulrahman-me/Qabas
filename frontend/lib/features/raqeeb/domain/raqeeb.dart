import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/content.dart';

enum QuestionClass {
  generalKnowledge,
  textExplanation,
  verification,
  differingOpinions,
  personalFatwa,
  doubtOrDeepCreed,
  sensitiveHuman,
  outOfScope,
  unknown,
}

enum DetectedKind { quran, hadith, claim, unknown }

enum VerificationStatus { quranExact, quranInexact, hadithGraded, notFound, needsSpecialist, unknown }

enum ReferralType { fatwaAuthority, specialist, humanSupport, unknown }

enum AttachmentKind { audio, image, document, unknown }

enum MessageErrorCode { upstreamUnavailable, internalError, inputUnreadable, unknown }

enum AssistantStage { received, readingInputs, classifying, retrieving, verifying, writing, adapting, done, unknown }

enum AnswerRating { up, down, unknown }

sealed class ChatMessage extends Equatable {
  const ChatMessage();
  String get messageId;
  DateTime get createdAt;
}

sealed class AssistantMessage extends ChatMessage {
  const AssistantMessage();
}

sealed class AnswerBlock extends Equatable {
  const AnswerBlock();
}

final class Conversation extends Equatable {
  Conversation({
    required this.conversationId,
    required this.title,
    required Map<String, String?>? context,
    required this.createdAt,
    required this.updatedAt,
  }) : context = (context == null ? null : Map.unmodifiable(context));
  final String conversationId;
  final String? title;
  final Map<String, String?>? context;
  final DateTime createdAt;
  final DateTime updatedAt;
  @override
  List<Object?> get props => [conversationId, title, context, createdAt, updatedAt];
}

final class UnderstoodImage extends Equatable {
  const UnderstoodImage({required this.attachmentId, required this.extractedText, required this.description});
  final String attachmentId;
  final String extractedText;
  final String description;
  @override
  List<Object?> get props => [attachmentId, extractedText, description];
}

final class UnderstoodDocument extends Equatable {
  const UnderstoodDocument({
    required this.attachmentId,
    required this.filename,
    required this.pagesProcessed,
    required this.truncated,
    required this.summary,
  });
  final String attachmentId;
  final String filename;
  final int pagesProcessed;
  final bool truncated;
  final String summary;
  @override
  List<Object?> get props => [attachmentId, filename, pagesProcessed, truncated, summary];
}

final class UnderstoodInput extends Equatable {
  UnderstoodInput({required this.transcript, required List<UnderstoodImage> images, required this.document})
    : images = List.unmodifiable(images);
  final String? transcript;
  final List<UnderstoodImage> images;
  final UnderstoodDocument? document;
  @override
  List<Object?> get props => [transcript, images, document];
}

final class Classification extends Equatable {
  const Classification({required this.questionClass, required this.label});
  final QuestionClass questionClass;
  final String label;
  @override
  List<Object?> get props => [questionClass, label];
}

final class QuoteGrade extends Equatable {
  const QuoteGrade({
    required this.gradeLabel,
    required this.gradeCategory,
    required this.grader,
    required this.sourceBook,
    required this.reference,
  });
  final String gradeLabel;
  final HadithGrade gradeCategory;
  final String grader;
  final String sourceBook;
  final String? reference;
  @override
  List<Object?> get props => [gradeLabel, gradeCategory, grader, sourceBook, reference];
}

final class VerificationItem extends Equatable {
  VerificationItem({
    required this.itemId,
    required this.quoteText,
    required this.detectedKind,
    required this.status,
    required this.hadithGrade,
    required this.correctText,
    required this.alternative,
    required List<ContentSpan> note,
    required List<String> sourceIds,
  }) : note = List.unmodifiable(note),
       sourceIds = List.unmodifiable(sourceIds);
  final String itemId;
  final String quoteText;
  final DetectedKind detectedKind;
  final VerificationStatus status;
  final QuoteGrade? hadithGrade;
  final Evidence? correctText;
  final Evidence? alternative;
  final List<ContentSpan> note;
  final List<String> sourceIds;
  @override
  List<Object?> get props => [itemId, quoteText, detectedKind, status, hadithGrade, correctText, alternative, note, sourceIds];
}

final class ReferralTarget extends Equatable {
  const ReferralTarget({required this.name, required this.description, required this.url, required this.contact});
  final String name;
  final String description;
  final String? url;
  final String? contact;
  @override
  List<Object?> get props => [name, description, url, contact];
}

final class Referral extends Equatable {
  Referral({required this.referralType, required List<ContentSpan> reason, required List<ReferralTarget> targets})
    : reason = List.unmodifiable(reason),
      targets = List.unmodifiable(targets);
  final ReferralType referralType;
  final List<ContentSpan> reason;
  final List<ReferralTarget> targets;
  @override
  List<Object?> get props => [referralType, reason, targets];
}

final class AnswerView extends Equatable {
  AnswerView({required this.holder, required List<ContentSpan> spans, required List<String> sourceIds})
    : spans = List.unmodifiable(spans),
      sourceIds = List.unmodifiable(sourceIds);
  final String holder;
  final List<ContentSpan> spans;
  final List<String> sourceIds;
  @override
  List<Object?> get props => [holder, spans, sourceIds];
}

final class Citation extends Equatable {
  const Citation({required this.ref, required this.source});
  final int ref;
  final Source source;
  @override
  List<Object?> get props => [ref, source];
}

final class LessonLink extends Equatable {
  const LessonLink({required this.lessonId, required this.title});
  final String lessonId;
  final String title;
  @override
  List<Object?> get props => [lessonId, title];
}

final class Attachment extends Equatable {
  const Attachment({
    required this.attachmentId,
    required this.kind,
    required this.filename,
    required this.mime,
    required this.sizeBytes,
    required this.url,
    required this.durationMs,
    required this.pages,
  });
  final String attachmentId;
  final AttachmentKind kind;
  final String filename;
  final String mime;
  final int sizeBytes;
  final String? url;
  final int? durationMs;
  final int? pages;
  @override
  List<Object?> get props => [attachmentId, kind, filename, mime, sizeBytes, url, durationMs, pages];
}

final class MessageError extends Equatable {
  const MessageError({required this.code, required this.message});
  final MessageErrorCode code;
  final String message;
  @override
  List<Object?> get props => [code, message];
}

final class UserMessage extends ChatMessage {
  UserMessage({required this.messageId, required this.text, required List<Attachment> attachments, required this.createdAt})
    : attachments = List.unmodifiable(attachments);
  @override
  final String messageId;
  final String? text;
  final List<Attachment> attachments;
  @override
  final DateTime createdAt;
  @override
  List<Object?> get props => [messageId, text, attachments, createdAt];
}

final class ProcessingMessage extends AssistantMessage {
  const ProcessingMessage({required this.messageId, required this.stage, required this.createdAt});
  @override
  final String messageId;
  final AssistantStage stage;
  @override
  final DateTime createdAt;
  @override
  List<Object?> get props => [messageId, stage, createdAt];
}

final class FailedMessage extends AssistantMessage {
  const FailedMessage({required this.messageId, required this.stage, required this.createdAt, required this.error});
  @override
  final String messageId;
  final AssistantStage stage;
  @override
  final DateTime createdAt;
  final MessageError error;
  @override
  List<Object?> get props => [messageId, stage, createdAt, error];
}

final class CompletedMessage extends AssistantMessage {
  CompletedMessage({
    required this.messageId,
    required this.createdAt,
    required this.completedAt,
    required this.understoodInput,
    required this.classification,
    required this.abstained,
    required List<AnswerBlock> blocks,
    required List<Citation> citations,
    required Map<String, TermCard> terms,
    required List<LessonLink> suggestedLessons,
    required this.feedback,
  }) : blocks = List.unmodifiable(blocks),
       citations = List.unmodifiable(citations),
       terms = Map.unmodifiable(terms),
       suggestedLessons = List.unmodifiable(suggestedLessons);
  @override
  final String messageId;
  @override
  final DateTime createdAt;
  final DateTime completedAt;
  final UnderstoodInput understoodInput;
  final Classification classification;
  final bool abstained;
  final List<AnswerBlock> blocks;
  final List<Citation> citations;
  final Map<String, TermCard> terms;
  final List<LessonLink> suggestedLessons;
  final AnswerRating? feedback;
  @override
  List<Object?> get props => [
    messageId,
    createdAt,
    completedAt,
    understoodInput,
    classification,
    abstained,
    blocks,
    citations,
    terms,
    suggestedLessons,
    feedback,
  ];
}

final class ParagraphAnswer extends AnswerBlock {
  ParagraphAnswer({required List<ContentSpan> spans}) : spans = List.unmodifiable(spans);
  final List<ContentSpan> spans;
  @override
  List<Object?> get props => [spans];
}

final class EvidenceAnswer extends AnswerBlock {
  const EvidenceAnswer({required this.evidence});
  final Evidence evidence;
  @override
  List<Object?> get props => [evidence];
}

final class VerificationAnswer extends AnswerBlock {
  VerificationAnswer({required List<VerificationItem> items}) : items = List.unmodifiable(items);
  final List<VerificationItem> items;
  @override
  List<Object?> get props => [items];
}

final class ViewsAnswer extends AnswerBlock {
  ViewsAnswer({required List<ContentSpan> intro, required List<AnswerView> views})
    : intro = List.unmodifiable(intro),
      views = List.unmodifiable(views);
  final List<ContentSpan> intro;
  final List<AnswerView> views;
  @override
  List<Object?> get props => [intro, views];
}

final class ReferralAnswer extends AnswerBlock {
  const ReferralAnswer({required this.referral});
  final Referral referral;
  @override
  List<Object?> get props => [referral];
}

final class PostMessageResponse extends Equatable {
  const PostMessageResponse({required this.userMessage, required this.assistantMessage});
  final UserMessage userMessage;
  final ProcessingMessage assistantMessage;
  @override
  List<Object?> get props => [userMessage, assistantMessage];
}

final class ConversationDetail extends Equatable {
  ConversationDetail({required this.conversation, required List<ChatMessage> messages}) : messages = List.unmodifiable(messages);
  final Conversation conversation;
  final List<ChatMessage> messages;
  @override
  List<Object?> get props => [conversation, messages];
}
