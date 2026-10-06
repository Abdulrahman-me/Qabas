import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

List<String> raqeebSuggestions(BuildContext c) => [
  c.l10n.raqeebSuggestionPrayer,
  c.l10n.raqeebSuggestionHadith,
  c.l10n.raqeebSuggestionArabic,
  c.l10n.raqeebSuggestionIslam,
];
String stageLabel(BuildContext c, AssistantStage stage) => switch (stage) {
  AssistantStage.received => c.l10n.raqeebStageReceived,
  AssistantStage.readingInputs => c.l10n.raqeebStageReading,
  AssistantStage.classifying => c.l10n.raqeebStageClassifying,
  AssistantStage.retrieving => c.l10n.raqeebStageRetrieving,
  AssistantStage.verifying => c.l10n.raqeebStageVerifying,
  AssistantStage.writing => c.l10n.raqeebStageWriting,
  AssistantStage.adapting => c.l10n.raqeebStageAdapting,
  _ => c.l10n.raqeebRaqeebThinking,
};

class RaqeebHeader extends StatelessWidget {
  const RaqeebHeader({super.key, required this.controller, this.onNew, this.onBack, this.onHistory});
  final CharacterController controller;
  final VoidCallback? onNew, onBack, onHistory;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.sm, QSpace.sm, QSpace.sm),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: QColors.line, width: QRaqeeb.border),
      ),
    ),
    child: Row(
      children: [
        if (onBack != null) QIconButton(icon: Icons.arrow_back_rounded, tooltip: c.l10n.commonBack, onTap: onBack),
        Container(
          width: QRaqeeb.headerAvatar,
          height: QRaqeeb.headerAvatar,
          decoration: BoxDecoration(
            color: QColors.nightEmerald,
            shape: BoxShape.circle,
            boxShadow: QShadows.glow(QColors.flameGold, strength: QRaqeeb.dotMinAlpha),
          ),
          child: Center(
            child: CharacterView(role: CharacterRole.assistant, size: QRaqeeb.headerGlyph, tint: QColors.softEmber, controller: controller),
          ),
        ),
        const SizedBox(width: QSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.l10n.raqeebRaqeebName, style: c.text.titleLarge),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: QRaqeeb.headerIcon, color: QColors.emerald500),
                  const SizedBox(width: QSpace.xxs),
                  Flexible(
                    child: Text(c.l10n.raqeebRaqeebTagline, style: c.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onHistory != null)
          QIconButton(key: const ValueKey('raqeeb-history'), icon: Icons.history_rounded, tooltip: c.l10n.raqeebHistory, onTap: onHistory),
        if (onNew != null)
          QIconButton(
            key: const ValueKey('raqeeb-new'),
            icon: Icons.edit_note_rounded,
            tooltip: c.l10n.raqeebNewChat,
            color: QColors.emerald500,
            onTap: onNew,
          ),
      ],
    ),
  );
}

class RaqeebWelcome extends StatelessWidget {
  const RaqeebWelcome({super.key, required this.suggestions, required this.onAsk});
  final List<String> suggestions;
  final ValueChanged<String> onAsk;
  @override
  Widget build(BuildContext c) {
    final trust = [
      (Icons.library_books_rounded, c.l10n.raqeebRaqeebTrust1),
      (Icons.link_rounded, c.l10n.raqeebRaqeebTrust2),
      (Icons.fact_check_rounded, c.l10n.raqeebRaqeebTrust3),
      (Icons.school_rounded, c.l10n.raqeebRaqeebTrust4),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(QSpace.page),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(QRadius.xl),
                  child: SizedBox(
                    height: QRaqeeb.heroHeight,
                    child: NightSky(
                      density: QRaqeeb.skyDensity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Glow(size: QRaqeeb.heroGlow, opacity: QRaqeeb.glowOpacity),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Breathe(
                                amount: 0.03,
                                child: LanternGlyph(color: QColors.softEmber, lit: true, size: QRaqeeb.heroGlyph),
                              ),
                              const SizedBox(height: QSpace.sm),
                              Text(
                                c.l10n.raqeebRaqeebName,
                                style: c.qText.display.copyWith(color: QColors.softEmber, fontSize: QRaqeeb.heroTitle),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: QSpace.lg),
              for (var i = 0; i < trust.length; i++)
                Reveal(
                  delay: QRaqeeb.trustStart + QRaqeeb.stagger * i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: QSpace.sm),
                    child: Row(
                      children: [
                        Container(
                          width: QRaqeeb.trustBadge,
                          height: QRaqeeb.trustBadge,
                          decoration: BoxDecoration(color: QColors.emerald50, borderRadius: BorderRadius.circular(QRadius.sm)),
                          child: Icon(trust[i].$1, size: QRaqeeb.trustIcon, color: QColors.emerald500),
                        ),
                        const SizedBox(width: QSpace.sm),
                        Expanded(
                          child: Text(trust[i].$2, style: c.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: QSpace.md),
              Text(c.l10n.raqeebTryAsking, style: c.text.titleMedium),
              const SizedBox(height: QSpace.sm),
              for (var i = 0; i < suggestions.length; i++)
                Reveal(
                  delay: QRaqeeb.suggestionsStart + QRaqeeb.stagger * i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: QSpace.xs),
                    child: SuggestionChip(text: suggestions[i], onTap: () => onAsk(suggestions[i]), wide: true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({super.key, required this.text, required this.onTap, this.wide = false});
  final String text;
  final VoidCallback onTap;
  final bool wide;
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    scale: 0.98,
    child: Container(
      width: wide ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: QRaqeeb.suggestionHorizontal, vertical: QRaqeeb.suggestionVertical),
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: BorderRadius.circular(QRadius.md),
        border: Border.all(color: QColors.line, width: QRaqeeb.border),
      ),
      child: Row(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: QRaqeeb.suggestionIcon, color: QColors.emerald500),
          const SizedBox(width: QSpace.xs),
          Flexible(
            child: Text(text, style: c.text.labelMedium?.copyWith(color: QColors.deepInk)),
          ),
        ],
      ),
    ),
  );
}

class RaqeebUserBubble extends StatelessWidget {
  const RaqeebUserBubble({super.key, required this.turn, required this.onRetry});
  final ChatTurn turn;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext c) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Reveal(
      offset: const Offset(0, QRaqeeb.thinkingGap),
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: QSpace.md, start: QRaqeeb.userIndent),
        padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
        decoration: const BoxDecoration(
          color: QColors.emerald500,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(QRadius.lg),
            topEnd: Radius.circular(QRadius.lg),
            bottomStart: Radius.circular(QRadius.lg),
            bottomEnd: Radius.circular(QRaqeeb.tail),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (turn.text.isNotEmpty)
              Text(
                turn.text,
                style: c.text.bodyLarge?.copyWith(color: QColors.surface, fontSize: QRaqeeb.userFont),
              ),
            if (turn.user == null)
              for (final file in turn.files)
                Padding(
                  padding: const EdgeInsets.only(top: QSpace.xs),
                  child: Text(file.name, style: c.text.bodyMedium?.copyWith(color: QColors.surface)),
                ),
            for (final a in turn.user?.attachments ?? <Attachment>[])
              Padding(
                padding: const EdgeInsets.only(top: QSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (a.kind == AttachmentKind.image && a.url != null) _AttachmentImage(attachment: a),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          a.kind == AttachmentKind.image
                              ? Icons.photo_rounded
                              : a.kind == AttachmentKind.document
                              ? Icons.description_rounded
                              : Icons.mic_rounded,
                          color: QColors.softEmber,
                        ),
                        const SizedBox(width: QSpace.xs),
                        Flexible(
                          child: Text(a.filename, style: c.text.bodyMedium?.copyWith(color: QColors.surface)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (turn.sendFailed) ...[
              const SizedBox(height: QSpace.xs),
              Text(c.l10n.raqeebNotSent, style: c.text.labelMedium?.copyWith(color: QColors.surface)),
              Text(failureBody(turn.failure!, c.l10n), style: c.text.bodySmall?.copyWith(color: QColors.surface)),
              TextButton(
                onPressed: onRetry,
                child: Text(c.l10n.commonRetry, style: c.text.labelMedium?.copyWith(color: QColors.softEmber)),
              ),
            ] else if (turn.user == null)
              Semantics(
                liveRegion: true,
                child: Text(c.l10n.raqeebSending, style: c.text.bodySmall?.copyWith(color: QColors.softEmber)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({required this.attachment});
  final Attachment attachment;
  @override
  Widget build(BuildContext context) {
    ResolvedMedia media;
    try {
      media = VisualMediaScope.resolveOf(context, attachment.url!);
    } catch (_) {
      media = const UnavailableMedia();
    }
    Widget failed(BuildContext c, Object error, StackTrace? stack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.mounted) c.read<RaqeebChatBloc>().add(AttachmentUrlFailed(attachment.attachmentId));
      });
      return const Icon(Icons.broken_image_outlined, color: QColors.softEmber);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: QSpace.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(QRadius.sm),
        child: SizedBox(
          height: QRaqeeb.heroHeight,
          width: double.infinity,
          child: switch (media) {
            MemoryMedia(:final bytes) => Image.memory(bytes, fit: BoxFit.cover, semanticLabel: attachment.filename, errorBuilder: failed),
            AssetMedia(:final path) => Image.asset(path, fit: BoxFit.cover, semanticLabel: attachment.filename, errorBuilder: failed),
            RemoteMedia(:final uri) => Image.network(
              uri.toString(),
              fit: BoxFit.cover,
              semanticLabel: attachment.filename,
              errorBuilder: failed,
            ),
            _ => const Icon(Icons.photo_rounded, color: QColors.softEmber),
          },
        ),
      ),
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: QRaqeeb.dotsMotion);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (calm) {
      _c.stop();
    } else {
      _c.repeat();
    }
  }

  bool get calm => context.reduceMotion || !TickerMode.valuesOf(context).enabled;
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _pulse(int i) {
    final phase = (_c.value * 3 - i) % 3;
    return phase < 1 ? math.sin(phase * math.pi) : 0;
  }

  @override
  Widget build(BuildContext c) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: QRaqeeb.dotMargin),
              width: QRaqeeb.dot,
              height: QRaqeeb.dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QColors.flameGold.withValues(alpha: QRaqeeb.dotMinAlpha + QRaqeeb.dotAmplitude * (calm ? 0 : _pulse(i))),
              ),
            ),
        ],
      ),
    ),
  );
}
