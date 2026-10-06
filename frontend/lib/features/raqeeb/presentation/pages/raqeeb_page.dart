import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/media_failure_messages.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/answer_bubble.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';

class RaqeebPage extends StatefulWidget {
  const RaqeebPage({super.key, this.conversationId});
  final String? conversationId;
  @override
  State<RaqeebPage> createState() => _RaqeebPageState();
}

class _RaqeebPageState extends State<RaqeebPage> {
  final _input = TextEditingController(), _scroll = ScrollController(), _lantern = CharacterController();
  Timer? _speaking;
  bool _syncing = false;
  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
  }

  void _changed() {
    if (!_syncing) context.read<RaqeebChatBloc>().add(ComposerChanged(_input.text));
  }

  @override
  void dispose() {
    _speaking?.cancel();
    _input.dispose();
    _scroll.dispose();
    _lantern.dispose();
    super.dispose();
  }

  void _ask(String text) {
    FocusScope.of(context).unfocus();
    context.read<RaqeebChatBloc>().add(MessageSent(text));
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (context.reduceMotion) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        unawaited(_scroll.animateTo(_scroll.position.maxScrollExtent, duration: QMotion.slow, curve: QMotion.emphasized));
      }
    });
  }

  void _receive(BuildContext context, RaqeebChatState state) {
    if (_input.text != state.draft) {
      _syncing = true;
      _input.value = TextEditingValue(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
      _syncing = false;
    }
    final completed = state.turns.map((t) => t.assistant).whereType<CompletedMessage>();
    context.read<ContentBloc>().add(
      ContentReceived({for (final m in completed) ...m.terms}, [for (final m in completed) ...m.citations.map((c) => c.source)]),
    );
    _speaking?.cancel();
    if (state.mediaStatus == MediaComposerStatus.recording) {
      _lantern.mood = CharacterMood.listening;
    } else if (state.busy) {
      _lantern.mood = CharacterMood.thinking;
    } else if (state.turns.lastOrNull?.assistant is CompletedMessage) {
      _lantern.mood = CharacterMood.speaking;
      _speaking = Timer(QRaqeeb.speak, () => _lantern.mood = CharacterMood.idle);
    } else {
      _lantern.mood = CharacterMood.idle;
    }
    if (state.turns.isNotEmpty) _bottom();
  }

  void _attachments() {
    final bloc = context.read<RaqeebChatBloc>();
    showQSheet<void>(
      context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.l10n.raqeebAttachTitle, style: c.text.headlineSmall),
          const SizedBox(height: QSpace.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_rounded, color: QColors.gold800),
            title: Text(c.l10n.raqeebAttachPhoto),
            subtitle: Text(c.l10n.raqeebAttachPhotoBody),
            onTap: () {
              Navigator.pop(c);
              bloc.add(const AttachmentPicked(MediaKind.image));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_rounded, color: QColors.gold800),
            title: Text(c.l10n.mediaCamera),
            onTap: () {
              Navigator.pop(c);
              bloc.add(const AttachmentPicked(MediaKind.image, camera: true));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_rounded, color: QColors.gold800),
            title: Text(c.l10n.raqeebAttachDoc),
            subtitle: Text(c.l10n.raqeebAttachDocBody),
            onTap: () {
              Navigator.pop(c);
              bloc.add(const AttachmentPicked(MediaKind.document));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mic_rounded, color: QColors.gold800),
            title: Text(c.l10n.raqeebAttachVoice),
            subtitle: Text(c.l10n.raqeebAttachVoiceBody),
            onTap: () {
              Navigator.pop(c);
              bloc.add(const VoiceRecordingStarted());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ContentInteractions(
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<RaqeebChatBloc, RaqeebChatState>(
            listenWhen: (a, b) => a.turns != b.turns || a.status != b.status || a.epoch != b.epoch || a.mediaStatus != b.mediaStatus,
            listener: _receive,
            builder: (context, state) {
              final bloc = context.read<RaqeebChatBloc>();
              final suggestions = raqeebSuggestions(context).where((q) => !state.turns.any((t) => t.text == q)).toList();
              return LayoutBuilder(
                builder: (context, box) {
                  final compact =
                      box.maxHeight <
                      QRaqeeb.shortHeight +
                          (state.attachments.isEmpty ? 0 : QMedia.preview) +
                          (state.mediaStatus == MediaComposerStatus.recording ? QSizes.tapTarget : 0);
                  return Column(
                    children: [
                      if (!compact)
                        RaqeebHeader(
                          controller: _lantern,
                          onHistory: () => context.push('/raqeeb/history'),
                          onBack: widget.conversationId == null
                              ? null
                              : () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/raqeeb');
                                  }
                                },
                          onNew: state.turns.isEmpty || state.busy ? null : () => bloc.add(const NewConversationRequested()),
                        ),
                      if (state.failure != null)
                        QInlineError(
                          message: state.failure is RaqeebTextLimitFailure
                              ? context.l10n.raqeebTextLimit
                              : mediaFailureBody(state.failure!, context),
                          onRetry: widget.conversationId == null ? null : () => bloc.add(ConversationOpened(widget.conversationId!)),
                        ),
                      if (state.failure is MicrophoneDeniedFailure)
                        TextButton(
                          onPressed: () => bloc.add(const MicrophoneSettingsOpened()),
                          child: Text(context.l10n.mediaOpenSettings),
                        ),
                      Expanded(
                        key: const ValueKey('raqeeb-messages'),
                        child: state.status == ChatStatus.loading
                            ? QLoadingView(label: context.l10n.raqeebRaqeebThinking)
                            : state.turns.isEmpty
                            ? RaqeebWelcome(suggestions: suggestions, onAsk: _ask)
                            : ListView(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.lg),
                                children: [
                                  for (final turn in state.turns)
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: QBreakpoints.composerMax),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            RaqeebUserBubble(
                                              key: ValueKey('user-${turn.key}'),
                                              turn: turn,
                                              onRetry: () => bloc.add(RetryRequested(turn.key)),
                                            ),
                                            if (turn.assistant != null || turn.failure != null && !turn.sendFailed)
                                              AnswerBubble(
                                                key: ValueKey('assistant-${turn.key}'),
                                                turn: turn,
                                                controller: _lantern,
                                                rating: state.ratings[turn.assistant?.messageId],
                                                ratingBusy: state.ratingId == turn.assistant?.messageId,
                                                ratingFailure: state.ratingFailure,
                                                onRetry: () => bloc.add(RetryRequested(turn.key)),
                                                onRate: (rating) => bloc.add(AnswerRated(turn.assistant!.messageId, rating)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!state.busy && suggestions.isNotEmpty)
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: QBreakpoints.composerMax),
                                        child: Wrap(
                                          spacing: QSpace.xs,
                                          runSpacing: QSpace.xs,
                                          children: [for (final q in suggestions.take(2)) SuggestionChip(text: q, onTap: () => _ask(q))],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      QComposerBar(
                        key: const ValueKey('raqeeb-composer'),
                        controller: _input,
                        hint: state.busy ? context.l10n.raqeebProcessing : context.l10n.raqeebAskAnything,
                        onSend: _ask,
                        onAttach: _attachments,
                        onRecord: () => bloc.add(
                          state.mediaStatus == MediaComposerStatus.recording
                              ? const VoiceRecordingStopped()
                              : const VoiceRecordingStarted(),
                        ),
                        recording: state.mediaStatus == MediaComposerStatus.recording,
                        onCancelRecording: state.mediaStatus == MediaComposerStatus.recording
                            ? () => bloc.add(const VoiceRecordingCancelled())
                            : null,
                        attachments: [
                          for (var i = 0; i < state.attachments.length; i++)
                            InputChip(
                              label: Text(state.attachments[i].name),
                              onDeleted: state.busy ? null : () => bloc.add(AttachmentRemoved(i)),
                            ),
                        ],
                        hasAttachments: state.attachments.isNotEmpty,
                        recordingLabel: state.mediaStatus == MediaComposerStatus.recording
                            ? context.l10n.mediaRecordingTime(context.n(state.recordingElapsed.inSeconds), context.n(60))
                            : null,
                        enabled: !state.busy || state.mediaStatus == MediaComposerStatus.recording,
                        maxLines: compact ? 1 : 4,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}
