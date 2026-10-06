// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raqeeb_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationDto _$ConversationDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ConversationDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['title', 'context']);
  final val = ConversationDto(
    conversationId: $checkedConvert('conversation_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String?),
    context: $checkedConvert('context', (v) => (v as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String?))),
    createdAt: $checkedConvert('created_at', (v) => v as String),
    updatedAt: $checkedConvert('updated_at', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'conversationId': 'conversation_id', 'createdAt': 'created_at', 'updatedAt': 'updated_at'});

UnderstoodImageDto _$UnderstoodImageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('UnderstoodImageDto', json, ($checkedConvert) {
  final val = UnderstoodImageDto(
    attachmentId: $checkedConvert('attachment_id', (v) => v as String),
    extractedText: $checkedConvert('extracted_text', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'attachmentId': 'attachment_id', 'extractedText': 'extracted_text'});

UnderstoodDocumentDto _$UnderstoodDocumentDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UnderstoodDocumentDto', json, ($checkedConvert) {
      final val = UnderstoodDocumentDto(
        attachmentId: $checkedConvert('attachment_id', (v) => v as String),
        filename: $checkedConvert('filename', (v) => v as String),
        pagesProcessed: $checkedConvert('pages_processed', (v) => (v as num).toInt()),
        truncated: $checkedConvert('truncated', (v) => v as bool),
        summary: $checkedConvert('summary', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'attachmentId': 'attachment_id', 'pagesProcessed': 'pages_processed'});

UnderstoodInputDto _$UnderstoodInputDtoFromJson(Map<String, dynamic> json) => $checkedCreate('UnderstoodInputDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['transcript', 'document']);
  final val = UnderstoodInputDto(
    transcript: $checkedConvert('transcript', (v) => v as String?),
    images: $checkedConvert(
      'images',
      (v) => (v as List<dynamic>).map((e) => UnderstoodImageDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    document: $checkedConvert('document', (v) => v == null ? null : UnderstoodDocumentDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

ClassificationDto _$ClassificationDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ClassificationDto', json, ($checkedConvert) {
  final val = ClassificationDto(
    questionClass: $checkedConvert('question_class', (v) => v as String),
    label: $checkedConvert('label', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'questionClass': 'question_class'});

QuoteGradeDto _$QuoteGradeDtoFromJson(Map<String, dynamic> json) => $checkedCreate('QuoteGradeDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['reference']);
  final val = QuoteGradeDto(
    gradeLabel: $checkedConvert('grade_label', (v) => v as String),
    gradeCategory: $checkedConvert('grade_category', (v) => v as String),
    grader: $checkedConvert('grader', (v) => v as String),
    sourceBook: $checkedConvert('source_book', (v) => v as String),
    reference: $checkedConvert('reference', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'gradeLabel': 'grade_label', 'gradeCategory': 'grade_category', 'sourceBook': 'source_book'});

VerificationItemDto _$VerificationItemDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'VerificationItemDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['hadith_grade', 'correct_text', 'alternative']);
    final val = VerificationItemDto(
      itemId: $checkedConvert('item_id', (v) => v as String),
      quoteText: $checkedConvert('quote_text', (v) => v as String),
      detectedKind: $checkedConvert('detected_kind', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      hadithGrade: $checkedConvert('hadith_grade', (v) => v == null ? null : QuoteGradeDto.fromJson(v as Map<String, dynamic>)),
      correctText: $checkedConvert('correct_text', (v) => v == null ? null : EvidenceDto.fromJson(v as Map<String, dynamic>)),
      alternative: $checkedConvert('alternative', (v) => v == null ? null : EvidenceDto.fromJson(v as Map<String, dynamic>)),
      note: $checkedConvert('note', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
      sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    );
    return val;
  },
  fieldKeyMap: const {
    'itemId': 'item_id',
    'quoteText': 'quote_text',
    'detectedKind': 'detected_kind',
    'hadithGrade': 'hadith_grade',
    'correctText': 'correct_text',
    'sourceIds': 'source_ids',
  },
);

ReferralTargetDto _$ReferralTargetDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReferralTargetDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['url', 'contact']);
  final val = ReferralTargetDto(
    name: $checkedConvert('name', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    url: $checkedConvert('url', (v) => v as String?),
    contact: $checkedConvert('contact', (v) => v as String?),
  );
  return val;
});

ReferralDto _$ReferralDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReferralDto', json, ($checkedConvert) {
  final val = ReferralDto(
    referralType: $checkedConvert('referral_type', (v) => v as String),
    reason: $checkedConvert('reason', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    targets: $checkedConvert(
      'targets',
      (v) => (v as List<dynamic>).map((e) => ReferralTargetDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'referralType': 'referral_type'});

AnswerViewDto _$AnswerViewDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AnswerViewDto', json, ($checkedConvert) {
  final val = AnswerViewDto(
    holder: $checkedConvert('holder', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
  );
  return val;
}, fieldKeyMap: const {'sourceIds': 'source_ids'});

CitationDto _$CitationDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CitationDto', json, ($checkedConvert) {
  final val = CitationDto(
    ref: $checkedConvert('ref', (v) => (v as num).toInt()),
    source: $checkedConvert('source', (v) => SourceDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

LessonLinkDto _$LessonLinkDtoFromJson(Map<String, dynamic> json) => $checkedCreate('LessonLinkDto', json, ($checkedConvert) {
  final val = LessonLinkDto(
    lessonId: $checkedConvert('lesson_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'lessonId': 'lesson_id'});

AttachmentDto _$AttachmentDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AttachmentDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['url', 'duration_ms', 'pages']);
  final val = AttachmentDto(
    attachmentId: $checkedConvert('attachment_id', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    filename: $checkedConvert('filename', (v) => v as String),
    mime: $checkedConvert('mime', (v) => v as String),
    sizeBytes: $checkedConvert('size_bytes', (v) => (v as num).toInt()),
    url: $checkedConvert('url', (v) => v as String?),
    durationMs: $checkedConvert('duration_ms', (v) => (v as num?)?.toInt()),
    pages: $checkedConvert('pages', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'attachmentId': 'attachment_id', 'sizeBytes': 'size_bytes', 'durationMs': 'duration_ms'});

MessageErrorDto _$MessageErrorDtoFromJson(Map<String, dynamic> json) => $checkedCreate('MessageErrorDto', json, ($checkedConvert) {
  final val = MessageErrorDto(code: $checkedConvert('code', (v) => v as String), message: $checkedConvert('message', (v) => v as String));
  return val;
});

UserMessageDto _$UserMessageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('UserMessageDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['text']);
  final val = UserMessageDto(
    messageId: $checkedConvert('message_id', (v) => v as String),
    text: $checkedConvert('text', (v) => v as String?),
    attachments: $checkedConvert(
      'attachments',
      (v) => (v as List<dynamic>).map((e) => AttachmentDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    createdAt: $checkedConvert('created_at', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'messageId': 'message_id', 'createdAt': 'created_at'});

ProcessingMessageDto _$ProcessingMessageDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProcessingMessageDto', json, ($checkedConvert) {
      final val = ProcessingMessageDto(
        messageId: $checkedConvert('message_id', (v) => v as String),
        stage: $checkedConvert('stage', (v) => v as String),
        createdAt: $checkedConvert('created_at', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'messageId': 'message_id', 'createdAt': 'created_at'});

FailedMessageDto _$FailedMessageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FailedMessageDto', json, ($checkedConvert) {
  final val = FailedMessageDto(
    messageId: $checkedConvert('message_id', (v) => v as String),
    stage: $checkedConvert('stage', (v) => v as String),
    createdAt: $checkedConvert('created_at', (v) => v as String),
    error: $checkedConvert('error', (v) => MessageErrorDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'messageId': 'message_id', 'createdAt': 'created_at'});

CompletedMessageDto _$CompletedMessageDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CompletedMessageDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['feedback']);
    final val = CompletedMessageDto(
      messageId: $checkedConvert('message_id', (v) => v as String),
      createdAt: $checkedConvert('created_at', (v) => v as String),
      completedAt: $checkedConvert('completed_at', (v) => v as String),
      understoodInput: $checkedConvert('understood_input', (v) => UnderstoodInputDto.fromJson(v as Map<String, dynamic>)),
      classification: $checkedConvert('classification', (v) => ClassificationDto.fromJson(v as Map<String, dynamic>)),
      abstained: $checkedConvert('abstained', (v) => v as bool),
      blocks: $checkedConvert(
        'blocks',
        (v) => (v as List<dynamic>).map((e) => AnswerBlockDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      citations: $checkedConvert(
        'citations',
        (v) => (v as List<dynamic>).map((e) => CitationDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      terms: $checkedConvert(
        'terms',
        (v) => (v as Map<String, dynamic>).map((k, e) => MapEntry(k, TermCardDto.fromJson(e as Map<String, dynamic>))),
      ),
      suggestedLessons: $checkedConvert(
        'suggested_lessons',
        (v) => (v as List<dynamic>).map((e) => LessonLinkDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      feedback: $checkedConvert('feedback', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'messageId': 'message_id',
    'createdAt': 'created_at',
    'completedAt': 'completed_at',
    'understoodInput': 'understood_input',
    'suggestedLessons': 'suggested_lessons',
  },
);

ParagraphAnswerDto _$ParagraphAnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ParagraphAnswerDto', json, ($checkedConvert) {
  final val = ParagraphAnswerDto(
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

EvidenceAnswerDto _$EvidenceAnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate('EvidenceAnswerDto', json, ($checkedConvert) {
  final val = EvidenceAnswerDto(evidence: $checkedConvert('evidence', (v) => EvidenceDto.fromJson(v as Map<String, dynamic>)));
  return val;
});

VerificationAnswerDto _$VerificationAnswerDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('VerificationAnswerDto', json, ($checkedConvert) {
      final val = VerificationAnswerDto(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>).map((e) => VerificationItemDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    });

ViewsAnswerDto _$ViewsAnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ViewsAnswerDto', json, ($checkedConvert) {
  final val = ViewsAnswerDto(
    intro: $checkedConvert('intro', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    views: $checkedConvert('views', (v) => (v as List<dynamic>).map((e) => AnswerViewDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

ReferralAnswerDto _$ReferralAnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReferralAnswerDto', json, ($checkedConvert) {
  final val = ReferralAnswerDto(referral: $checkedConvert('referral', (v) => ReferralDto.fromJson(v as Map<String, dynamic>)));
  return val;
});

PostMessageResponseDto _$PostMessageResponseDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PostMessageResponseDto', json, ($checkedConvert) {
      final val = PostMessageResponseDto(
        userMessage: $checkedConvert('user_message', (v) => UserMessageDto.fromJson(v as Map<String, dynamic>)),
        assistantMessage: $checkedConvert('assistant_message', (v) => ProcessingMessageDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'userMessage': 'user_message', 'assistantMessage': 'assistant_message'});

ConversationDetailDto _$ConversationDetailDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConversationDetailDto', json, ($checkedConvert) {
      final val = ConversationDetailDto(
        conversation: $checkedConvert('conversation', (v) => ConversationDto.fromJson(v as Map<String, dynamic>)),
        messages: $checkedConvert(
          'messages',
          (v) => (v as List<dynamic>).map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    });

ConversationCreateDto _$ConversationCreateDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConversationCreateDto', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['context']);
      final val = ConversationCreateDto(
        context: $checkedConvert('context', (v) => (v as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String?))),
      );
      return val;
    });

AnswerFeedbackDto _$AnswerFeedbackDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AnswerFeedbackDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['reason', 'comment']);
  final val = AnswerFeedbackDto(
    rating: $checkedConvert('rating', (v) => v as String),
    reason: $checkedConvert('reason', (v) => v as String?),
    comment: $checkedConvert('comment', (v) => v as String?),
  );
  return val;
});
