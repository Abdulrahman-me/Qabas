import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';

QuestionClass _questionClass(String value) => switch (value) {
  'general_knowledge' => QuestionClass.generalKnowledge,
  'text_explanation' => QuestionClass.textExplanation,
  'verification' => QuestionClass.verification,
  'differing_opinions' => QuestionClass.differingOpinions,
  'personal_fatwa' => QuestionClass.personalFatwa,
  'doubt_or_deep_creed' => QuestionClass.doubtOrDeepCreed,
  'sensitive_human' => QuestionClass.sensitiveHuman,
  'out_of_scope' => QuestionClass.outOfScope,
  _ => QuestionClass.unknown,
};
DetectedKind _detectedKind(String value) => switch (value) {
  'quran' => DetectedKind.quran,
  'hadith' => DetectedKind.hadith,
  'claim' => DetectedKind.claim,
  _ => DetectedKind.unknown,
};
VerificationStatus _verificationStatus(String value) => switch (value) {
  'quran_exact' => VerificationStatus.quranExact,
  'quran_inexact' => VerificationStatus.quranInexact,
  'hadith_graded' => VerificationStatus.hadithGraded,
  'not_found' => VerificationStatus.notFound,
  'needs_specialist' => VerificationStatus.needsSpecialist,
  _ => VerificationStatus.unknown,
};
ReferralType _referralType(String value) => switch (value) {
  'fatwa_authority' => ReferralType.fatwaAuthority,
  'specialist' => ReferralType.specialist,
  'human_support' => ReferralType.humanSupport,
  _ => ReferralType.unknown,
};
AttachmentKind _attachmentKind(String value) => switch (value) {
  'audio' => AttachmentKind.audio,
  'image' => AttachmentKind.image,
  'document' => AttachmentKind.document,
  _ => AttachmentKind.unknown,
};
MessageErrorCode _messageErrorCode(String value) => switch (value) {
  'upstream_unavailable' => MessageErrorCode.upstreamUnavailable,
  'internal_error' => MessageErrorCode.internalError,
  'input_unreadable' => MessageErrorCode.inputUnreadable,
  _ => MessageErrorCode.unknown,
};
AssistantStage _assistantStage(String value) => switch (value) {
  'received' => AssistantStage.received,
  'reading_inputs' => AssistantStage.readingInputs,
  'classifying' => AssistantStage.classifying,
  'retrieving' => AssistantStage.retrieving,
  'verifying' => AssistantStage.verifying,
  'writing' => AssistantStage.writing,
  'adapting' => AssistantStage.adapting,
  'done' => AssistantStage.done,
  _ => AssistantStage.unknown,
};
AnswerRating _answerRating(String value) => switch (value) {
  'up' => AnswerRating.up,
  'down' => AnswerRating.down,
  _ => AnswerRating.unknown,
};
HadithGrade _hadithGrade(String value) => switch (value) {
  'authentic' => HadithGrade.authentic,
  'acceptable' => HadithGrade.acceptable,
  'weak' => HadithGrade.weak,
  'fabricated' => HadithGrade.fabricated,
  'other' => HadithGrade.other,
  _ => HadithGrade.unknown,
};

extension ConversationMapping on ConversationDto {
  Conversation toEntity() => Conversation(
    conversationId: conversationId,
    title: title,
    context: context,
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
  );
}

extension UnderstoodImageMapping on UnderstoodImageDto {
  UnderstoodImage toEntity() => UnderstoodImage(attachmentId: attachmentId, extractedText: extractedText, description: description);
}

extension UnderstoodDocumentMapping on UnderstoodDocumentDto {
  UnderstoodDocument toEntity() => UnderstoodDocument(
    attachmentId: attachmentId,
    filename: filename,
    pagesProcessed: pagesProcessed,
    truncated: truncated,
    summary: summary,
  );
}

extension UnderstoodInputMapping on UnderstoodInputDto {
  UnderstoodInput toEntity() =>
      UnderstoodInput(transcript: transcript, images: images.map((v) => v.toEntity()).toList(), document: document?.toEntity());
}

extension ClassificationMapping on ClassificationDto {
  Classification toEntity() => Classification(questionClass: _questionClass(questionClass), label: label);
}

extension QuoteGradeMapping on QuoteGradeDto {
  QuoteGrade toEntity() => QuoteGrade(
    gradeLabel: gradeLabel,
    gradeCategory: _hadithGrade(gradeCategory),
    grader: grader,
    sourceBook: sourceBook,
    reference: reference,
  );
}

extension VerificationItemMapping on VerificationItemDto {
  VerificationItem toEntity() => VerificationItem(
    itemId: itemId,
    quoteText: quoteText,
    detectedKind: _detectedKind(detectedKind),
    status: _verificationStatus(status),
    hadithGrade: hadithGrade?.toEntity(),
    correctText: correctText?.toEntity(),
    alternative: alternative?.toEntity(),
    note: contentSpans(note),
    sourceIds: sourceIds,
  );
}

extension ReferralTargetMapping on ReferralTargetDto {
  ReferralTarget toEntity() => ReferralTarget(name: name, description: description, url: url, contact: contact);
}

extension ReferralMapping on ReferralDto {
  Referral toEntity() =>
      Referral(referralType: _referralType(referralType), reason: contentSpans(reason), targets: targets.map((v) => v.toEntity()).toList());
}

extension AnswerViewMapping on AnswerViewDto {
  AnswerView toEntity() => AnswerView(holder: holder, spans: contentSpans(spans), sourceIds: sourceIds);
}

extension CitationMapping on CitationDto {
  Citation toEntity() => Citation(ref: ref, source: source.toEntity());
}

extension LessonLinkMapping on LessonLinkDto {
  LessonLink toEntity() => LessonLink(lessonId: lessonId, title: title);
}

extension AttachmentMapping on AttachmentDto {
  Attachment toEntity() => Attachment(
    attachmentId: attachmentId,
    kind: _attachmentKind(kind),
    filename: filename,
    mime: mime,
    sizeBytes: sizeBytes,
    url: url,
    durationMs: durationMs,
    pages: pages,
  );
}

extension MessageErrorMapping on MessageErrorDto {
  MessageError toEntity() => MessageError(code: _messageErrorCode(code), message: message);
}

extension UserMessageMapping on UserMessageDto {
  UserMessage toEntity() => UserMessage(
    messageId: messageId,
    text: text,
    attachments: attachments.map((v) => v.toEntity()).toList(),
    createdAt: DateTime.parse(createdAt),
  );
}

extension ProcessingMessageMapping on ProcessingMessageDto {
  ProcessingMessage toEntity() =>
      ProcessingMessage(messageId: messageId, stage: _assistantStage(stage), createdAt: DateTime.parse(createdAt));
}

extension FailedMessageMapping on FailedMessageDto {
  FailedMessage toEntity() =>
      FailedMessage(messageId: messageId, stage: _assistantStage(stage), createdAt: DateTime.parse(createdAt), error: error.toEntity());
}

extension CompletedMessageMapping on CompletedMessageDto {
  CompletedMessage toEntity() => CompletedMessage(
    messageId: messageId,
    createdAt: DateTime.parse(createdAt),
    completedAt: DateTime.parse(completedAt),
    understoodInput: understoodInput.toEntity(),
    classification: classification.toEntity(),
    abstained: abstained,
    blocks: blocks.map((v) => v.toEntity()).toList(),
    citations: citations.map((v) => v.toEntity()).toList(),
    terms: terms.map((k, v) => MapEntry(k, v.toEntity())),
    suggestedLessons: suggestedLessons.map((v) => v.toEntity()).toList(),
    feedback: feedback == null ? null : _answerRating(feedback!),
  );
}

extension ParagraphAnswerMapping on ParagraphAnswerDto {
  ParagraphAnswer toEntity() => ParagraphAnswer(spans: contentSpans(spans));
}

extension EvidenceAnswerMapping on EvidenceAnswerDto {
  EvidenceAnswer toEntity() => EvidenceAnswer(evidence: evidence.toEntity());
}

extension VerificationAnswerMapping on VerificationAnswerDto {
  VerificationAnswer toEntity() => VerificationAnswer(items: items.map((v) => v.toEntity()).toList());
}

extension ViewsAnswerMapping on ViewsAnswerDto {
  ViewsAnswer toEntity() => ViewsAnswer(intro: contentSpans(intro), views: views.map((v) => v.toEntity()).toList());
}

extension ReferralAnswerMapping on ReferralAnswerDto {
  ReferralAnswer toEntity() => ReferralAnswer(referral: referral.toEntity());
}

extension PostMessageResponseMapping on PostMessageResponseDto {
  PostMessageResponse toEntity() => PostMessageResponse(userMessage: userMessage.toEntity(), assistantMessage: assistantMessage.toEntity());
}

extension ConversationDetailMapping on ConversationDetailDto {
  ConversationDetail toEntity() =>
      ConversationDetail(conversation: conversation.toEntity(), messages: messages.map((v) => v.toEntity()).toList());
}

extension MessageMapping on ChatMessageDto {
  ChatMessage toEntity() => switch (this) {
    final UserMessageDto m => m.toEntity(),
    final AssistantMessageDto m => m.toEntity(),
  };
}

extension AssistantMapping on AssistantMessageDto {
  AssistantMessage toEntity() => switch (this) {
    final ProcessingMessageDto m => m.toEntity(),
    final FailedMessageDto m => m.toEntity(),
    final CompletedMessageDto m => m.toEntity(),
  };
}

extension BlockMapping on AnswerBlockDto {
  AnswerBlock toEntity() => switch (this) {
    final ParagraphAnswerDto b => b.toEntity(),
    final EvidenceAnswerDto b => b.toEntity(),
    final VerificationAnswerDto b => b.toEntity(),
    final ViewsAnswerDto b => b.toEntity(),
    final ReferralAnswerDto b => b.toEntity(),
  };
}
