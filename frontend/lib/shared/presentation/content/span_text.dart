import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';

/// Port of TermText: typed spans replace prototype markup parsing.
class SpanText extends StatefulWidget {
  const SpanText(this.spans, {super.key, this.style, this.textAlign, this.onCitation, this.citationBadge = false, this.terms});
  final List<ContentSpan> spans;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ValueChanged<int>? onCitation;
  final bool citationBadge;
  final Map<String, TermCard>? terms;
  @override
  State<SpanText> createState() => _SpanTextState();
}

class _SpanTextState extends State<SpanText> {
  final _recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final content = context.watch<ContentBloc>();
    final base = widget.style ?? context.text.bodyLarge!;
    final spans = <InlineSpan>[];
    for (final span in widget.spans) {
      switch (span) {
        case TextContentSpan(:final text) || UnknownContentSpan(:final text):
          spans.add(TextSpan(text: text));
        case StrongContentSpan(:final text):
          spans.add(
            TextSpan(
              text: text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        case TermContentSpan(:final text, :final termId):
          final cards = widget.terms ?? content.state.terms;
          final state = content.state.termStates[termId] ?? cards[termId]?.state;
          final linked = cards.containsKey(termId) && (state == TermState.newTerm || state == TermState.learning);
          if (!linked) {
            spans.add(TextSpan(text: text));
            break;
          }
          final r = TapGestureRecognizer()..onTap = () => content.add(TermCardOpened(cards[termId]!));
          _recognizers.add(r);
          spans.add(
            TextSpan(
              text: text,
              recognizer: r,
              mouseCursor: SystemMouseCursors.click,
              style: const TextStyle(
                color: QColors.emerald500,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: QColors.emerald400,
                decorationThickness: 2.2,
              ),
            ),
          );
        case CitationContentSpan(:final ref):
          final citationLabel = '${context.l10n.contentViewSource} ${context.n(ref)}';
          final r = TapGestureRecognizer()..onTap = widget.onCitation == null ? null : () => widget.onCitation!(ref);
          _recognizers.add(r);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: GestureDetector(
                onTap: r.onTap,
                child: Semantics(
                  button: widget.onCitation != null,
                  label: citationLabel,
                  child: widget.citationBadge
                      ? Container(
                          margin: const EdgeInsets.symmetric(horizontal: QRaqeeb.citationMargin),
                          padding: const EdgeInsets.symmetric(horizontal: QRaqeeb.citationHorizontal, vertical: QRaqeeb.citationVertical),
                          decoration: BoxDecoration(color: QColors.gold100, borderRadius: BorderRadius.circular(QRaqeeb.citationRadius)),
                          child: Text(context.n(ref), style: context.text.labelSmall?.copyWith(color: QColors.gold800, letterSpacing: 0)),
                        )
                      : Text(
                          '[${context.n(ref)}]',
                          style: base.copyWith(fontSize: base.fontSize! * 0.7, color: QColors.emerald500),
                        ),
                ),
              ),
            ),
          );
      }
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: widget.textAlign,
    );
  }
}

class SentenceText extends StatelessWidget {
  const SentenceText(this.sentence, {super.key, this.style});
  final Sentence sentence;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: sentence.sourceIds.isEmpty ? null : () => context.read<ContentBloc>().add(SentenceSourcesOpened(sentence.sourceIds)),
    child: SpanText(sentence.spans, style: style),
  );
}
