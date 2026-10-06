import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_mappers.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/answer_bubble.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Raqeeb welcome, A–H/failed, input/stages/cards/sheets/RTL/resize $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced);
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          for (var i = 3; i <= 10; i++) {
            await mock.fixtures.object('examples/RaqeebCompleted__get_raqeeb_messages_message_id__$i.json');
          }
          await mock.fixtures.example('AssistantFailed');
        });
        final router = GoRouter.of(t.element(find.byType(Scaffold).first));
        router.go('/raqeeb');
        await pumpJourney(t);
        final context = t.element(find.byType(RaqeebPage)), bloc = context.read<RaqeebChatBloc>();
        expect(find.byType(RaqeebWelcome), findsOneWidget);
        expect(Directionality.of(context), language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        await t.enterText(find.byType(TextField), 'saved draft');
        await t.pump();
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull, reason: 'welcome/$size');
          expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'saved draft');
          expect(t.element(find.byType(RaqeebPage)).read<RaqeebChatBloc>(), same(bloc));
          expect(t.getRect(find.byKey(const ValueKey('raqeeb-composer'))).bottom, lessThanOrEqualTo(size.height));
        }
        t.view.physicalSize = const Size(320, 400);
        await t.pump();
        final send = find.byTooltip(context.l10n.commonSendTooltip);
        await t.tap(send);
        await journeyUntil(t, () => bloc.state.status == ChatStatus.processing);
        expect(bloc.state.turns.single.text, 'saved draft');
        expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
        expect(find.byKey(const ValueKey('raqeeb-stage')), findsOneWidget);
        await journeyUntil(t, () => bloc.state.turns.last.assistant is CompletedMessage);
        for (final outcome in [...'ABCDEFGH'.split(''), 'failed']) {
          if (outcome != 'A') {
            await t.tap(find.byKey(const ValueKey('raqeeb-new')));
            await t.pump();
            // The same action used by the developer picker; UI does not choose the response.
            await t.runAsync(() => d.services<DevToolsActions>().change(DevOption.raqeebOutcome, outcome));
            await t.enterText(find.byType(TextField), 'Question $outcome');
            await t.pump();
            await t.pump(const Duration(milliseconds: 300));
            await t.tap(find.byTooltip(context.l10n.commonSendTooltip));
            await journeyUntil(t, () => bloc.state.status == ChatStatus.processing);
            await journeyUntil(t, () => bloc.state.turns.last.assistant is! ProcessingMessage && !bloc.state.busy);
          }
          final turn = bloc.state.turns.last;
          final answer = turn.assistant;
          expect(answer, outcome == 'failed' ? isA<FailedMessage>() : isA<CompletedMessage>());
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(seconds: 1));
            expect(t.takeException(), isNull, reason: '$outcome/$size');
            expect(bloc.state.turns.last, same(turn));
            expect(t.widget<TextField>(find.byType(TextField)).enabled, true);
            expect(t.getRect(find.byKey(const ValueKey('raqeeb-composer'))).bottom, lessThanOrEqualTo(size.height));
          }
          t.view.physicalSize = const Size(320, 400);
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          if (answer is CompletedMessage) {
            final toggle = find.byKey(ValueKey('raqeeb-understood-${answer.messageId}'));
            await t.ensureVisible(toggle);
            await t.pump();
            await t.tap(toggle);
            await t.pump();
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull);
            if (answer.understoodInput.transcript != null) expect(find.text(answer.understoodInput.transcript!), findsOneWidget);
            final rating = find.byKey(ValueKey('raqeeb-rate-${answer.messageId}-up'));
            await t.ensureVisible(rating);
            await t.pump();
            await t.tap(rating);
            await journeyUntil(t, () => bloc.state.ratings[answer.messageId] == AnswerRating.up);
            if (outcome == 'A') {
              final term = answer.terms.values.first;
              t.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
              await t.pump();
              final spans = find
                  .byType(SpanText)
                  .evaluate()
                  .map((e) => e.widget as SpanText)
                  .firstWhere((w) => w.spans.any((s) => s is TermContentSpan));
              final rich = find.descendant(of: find.byWidget(spans), matching: find.byType(RichText));
              final text = t.widget<RichText>(rich.first).text as TextSpan;
              Iterable<TapGestureRecognizer> recognizers(InlineSpan span) sync* {
                if (span is TextSpan) {
                  if (span.recognizer is TapGestureRecognizer) yield span.recognizer! as TapGestureRecognizer;
                  for (final child in span.children ?? <InlineSpan>[]) {
                    yield* recognizers(child);
                  }
                }
              }

              final recognizer = recognizers(text).first;
              recognizer.onTap!();
              await pumpJourney(t);
              expect(find.byType(TermSheet), findsOneWidget);
              expect(find.text(term.transliteration), findsWidgets);
              Navigator.of(t.element(find.byType(TermSheet))).pop();
              await pumpJourney(t);
              // The citation badge activates its numbered source target.
              t.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
              await t.pump();
              final paragraph = find.byWidgetPredicate((w) => w is SpanText && w.spans.any((s) => s is CitationContentSpan)).first;
              final citation = find.descendant(of: paragraph, matching: find.byType(GestureDetector)).first;
              await t.ensureVisible(citation);
              await t.pump();
              await t.tap(citation);
              await t.pump();
              await t.pump(const Duration(milliseconds: 600));
              final card = find.byWidgetPredicate((w) => w is CitationCard && w.citation.ref == 1);
              expect(card, findsOneWidget);
              expect(t.getRect(card).overlaps(t.getRect(find.byType(ListView))), true);
              if (answer.suggestedLessons.isNotEmpty) {
                final lesson = find.byKey(ValueKey('raqeeb-lesson-${answer.suggestedLessons.first.lessonId}'));
                await t.ensureVisible(lesson);
                await t.pump();
                await t.tap(lesson);
                await pumpJourney(t);
                expect(find.byType(LessonIntroPage), findsOneWidget);
                router.pop();
                await pumpJourney(t);
                expect(bloc.state.turns.last, same(turn));
              }
            }
          } else {
            final retry = find.byKey(ValueKey('raqeeb-retry-${turn.key}'));
            await t.ensureVisible(retry);
            await t.pump();
            await t.tap(retry);
            await journeyUntil(t, () => bloc.state.turns.length == 2);
            expect(bloc.state.turns.last.key, isNot(turn.key));
            await journeyUntil(t, () => !bloc.state.busy);
          }
        }
        // Input and character remain stable across mounted tab changes.
        await t.tap(find.byKey(const ValueKey('raqeeb-new')));
        await t.pump();
        await t.enterText(find.byType(TextField), 'tab draft');
        await t.pump();
        router.go('/journey');
        await pumpJourney(t);
        router.go('/raqeeb');
        await pumpJourney(t);
        expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'tab draft');
        t.view.physicalSize = const Size(320, 400);
        t.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(t.view.resetViewInsets);
        await t.enterText(find.byType(TextField), 'Long draft ' * 80);
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(t.takeException(), isNull);
        expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'Long draft ' * 80);
        expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, true);
        expect(t.getRect(find.byKey(const ValueKey('raqeeb-composer'))).bottom, lessThanOrEqualTo(200));
        t.view.viewInsets = const FakeViewPadding();
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.byTooltip(context.l10n.raqeebAttachTitle));
        await pumpJourney(t);
        expect(find.text(context.l10n.raqeebAttachPhoto), findsOneWidget);
        Navigator.of(t.element(find.text(context.l10n.raqeebAttachPhoto))).pop();
        await pumpJourney(t);
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
      });
    }
  }
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('All five verification statuses and all hadith grades have distinct, responsive badges $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced);
        final mock = d.services<MockBackend>();
        final source = await t.runAsync(() => mock.fixtures.object('examples/RaqeebCompleted__get_raqeeb_messages_message_id__4.json'));
        final evidence = (await t.runAsync(() => mock.fixtures.example('Evidence')))!;
        final content = d.contentBloc();
        final items = <VerificationItem>[];
        for (final status in VerificationStatus.values.where((s) => s != VerificationStatus.unknown)) {
          for (final grade
              in status == VerificationStatus.hadithGraded
                  ? HadithGrade.values.where((g) => g != HadithGrade.unknown)
                  : [HadithGrade.other]) {
            // Construct the domain input using the real, already decoded B template.
            final base = (CompletedMessageDto.fromJson(source!).toEntity().blocks.single as VerificationAnswer).items.single;
            items.add(
              VerificationItem(
                itemId: '${status.name}-${grade.name}',
                quoteText: base.quoteText,
                detectedKind: base.detectedKind,
                status: status,
                hadithGrade: QuoteGrade(
                  gradeLabel: grade.name,
                  gradeCategory: grade,
                  grader: 'source grader',
                  sourceBook: 'source book',
                  reference: null,
                ),
                correctText: status == VerificationStatus.quranInexact ? EvidenceDto.fromJson(evidence).toEntity() : null,
                alternative: null,
                note: base.note,
                sourceIds: [],
              ),
            );
          }
        }
        // Use the app's localized theme/scopes by placing the cards on its active route.
        final context = t.element(find.byType(Scaffold).first);
        final unknown = verificationStyle(context, items.firstWhere((v) => v.status == VerificationStatus.notFound));
        final fabricated = verificationStyle(context, items.firstWhere((v) => v.hadithGrade?.gradeCategory == HadithGrade.fabricated));
        expect(unknown.$1, QColors.statusUnknown);
        expect(fabricated.$1, QColors.statusFabricated);
        expect(unknown.$2, isNot(fabricated.$2));
        final sheet = showQSheet<void>(
          context,
          builder: (_) => BlocProvider.value(
            value: content,
            child: Column(children: [for (final item in items) VerificationCard(item: item)]),
          ),
        );
        await pumpJourney(t);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull, reason: 'verification/$size');
        }
        Navigator.of(t.element(find.byType(VerificationCard).first)).pop();
        await pumpJourney(t);
        await sheet;
        await t.runAsync(content.close);
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
      });
    }
  }
  testWidgets('Unsent/503 retry keeps text; loading/error/retry on direct conversation route', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(402, 874);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final d = await mountJourney(t, reduced: true);
    final mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(Scaffold).first));
    router.go('/raqeeb');
    await pumpJourney(t);
    final c = t.element(find.byType(RaqeebPage)), bloc = c.read<RaqeebChatBloc>();
    mock.controls.offline = true;
    await t.enterText(find.byType(TextField), 'Retained question');
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byTooltip(c.l10n.commonSendTooltip));
    await journeyUntil(t, () => bloc.state.turns.isNotEmpty && bloc.state.turns.single.sendFailed);
    final key = bloc.state.turns.single.key;
    expect(find.text('Retained question'), findsOneWidget);
    mock.controls.offline = false;
    bloc.add(RetryRequested(key));
    await journeyUntil(t, () => bloc.state.status == ChatStatus.processing);
    expect(bloc.state.turns.length, 1);
    expect(bloc.state.turns.single.key, key);
    final id = bloc.state.conversation!.conversationId;
    await t.runAsync(() => mock.fixtures.object('examples/RaqeebCompleted__get_raqeeb_messages_message_id__3.json'));
    await journeyUntil(t, () => !bloc.state.busy);
    final gate = Completer<BackendResponse>();
    mock.router.routes.insert(0, MockRoute('GET', '/raqeeb/conversations/{id}', (_, _) => gate.future));
    unawaited(router.push('/raqeeb/c/$id'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(QLoadingView), findsOneWidget);
    gate.complete(BackendResponse.error(404, 'not_found', 'Missing'));
    await journeyUntil(t, () => find.byType(QInlineError).evaluate().isNotEmpty);
    mock.router.routes.removeAt(0);
    final direct = t.element(find.byType(RaqeebPage).last).read<RaqeebChatBloc>();
    direct.add(ConversationOpened(id));
    await journeyUntil(t, () => direct.state.turns.isNotEmpty);
    expect(direct.state.turns.single.text, 'Retained question');
    router.pop();
    await pumpJourney(t);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
  });
}
