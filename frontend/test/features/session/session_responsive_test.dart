import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_views.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;

SessionPlayerBloc player(WidgetTester t) => t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
ContentStepBloc step(WidgetTester t) => t
    .element(
      find.byType(HookStepView).evaluate().isNotEmpty
          ? find.byType(HookStepView)
          : find.byType(PredictStepView).evaluate().isNotEmpty
          ? find.byType(PredictStepView)
          : find.byType(StoryStepView).evaluate().isNotEmpty
          ? find.byType(StoryStepView)
          : find.byType(TeachStepView),
    )
    .read<ContentStepBloc>();
Future<void> select(WidgetTester t, int index) async {
  final tile = find.byKey(ValueKey('predict-option-$index'));
  await t.ensureVisible(tile);
  await t.pump();
  await t.tap(tile);
  await pumpJourney(t);
}

Future<void> cta(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('step-cta')));
  await pumpJourney(t);
}

// These checks isolate content from exercise/finish flows covered separately.
void isolateContent(AppDependencies d) {
  d.services.unregister<SessionPlayerBloc>();
  d.services.registerFactory<SessionPlayerBloc>(() => SessionPlayerBloc(LoadSession(d.services<SessionRepository>())));
}

void contentOnly(Map<String, dynamic> fixture) {
  fixture['items'] = (fixture['items'] as List).cast<Map>().where((b) => b['type'] != 'exercise').toList();
}

void main() {
  for (final lang in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('lesson content and selected/revealed state survive all mounted resizes: $lang/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: lang, reduced: reduced);
        isolateContent(d);
        final mock = d.services<MockBackend>();
        isolateContent(d);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        unawaited(router.push('/lesson/les_u0_l1/intro'));
        await journeyUntil(
          t,
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
        );
        final intro = t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>();
        expect(intro.state.start!.session.sourceCount, 0);
        expect(intro.state.start!.session.reviewedBy, isNull);
        expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
        expect(find.byIcon(Icons.verified_user_rounded), findsNothing);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(milliseconds: 600));
          final rect = t.getRect(find.byKey(const ValueKey('lesson-start')));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(t.takeException(), isNull, reason: 'Intro/$size/$lang/$reduced');
        }
        await t.tap(find.byKey(const ValueKey('intro-close')));
        await pumpJourney(t);
        final fixture = (await t.runAsync(() => mock.fixtures.object('salah/session_salah_${lang}_explorer.json')))!;
        contentOnly(fixture);
        final session = SessionDto.fromJson(fixture).toEntity();
        mock.db.sessions[session.sessionId] = fixture;
        unawaited(GoRouter.of(t.element(find.byType(JourneyPage))).push('/session/${session.sessionId}'));
        await journeyUntil(t, () => find.byType(HookStepView).evaluate().isNotEmpty);
        final p = player(t);
        var checked = false;
        var safety = 0;
        while (p.state.status != PlayerStatus.previewEnded && safety++ < 60) {
          final item = p.state.item!;
          if (item is PredictItem && !checked) {
            await select(t, 1);
            checked = true;
          }
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull, reason: '$lang/$reduced/${item.runtimeType}/$size');
            final action = find.byKey(ValueKey(p.state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta'));
            expect(action, findsOneWidget);
            final rect = t.getRect(action);
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(rect.top, greaterThanOrEqualTo(0));
            if (item is PredictItem) expect(step(t).state.selectedOptionId, item.options[1].optionId);
          }
          if (p.state.status == PlayerStatus.feedback) {
            await t.tap(find.byKey(const ValueKey('predict-continue')));
            await pumpJourney(t);
          } else {
            await cta(t);
          }
        }
        expect(p.state.status, PlayerStatus.previewEnded);
        expect(p.state.progress, 1);
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
        await pumpJourney(t);
      });
    }
  }
  testWidgets('sources on long press, terms open and canonical Arabic/null display', (t) async {
    final d = await mountJourney(t, reduced: true);
    final mock = d.services<MockBackend>();
    final fixture = (await t.runAsync(() => mock.fixtures.object('salah/session_salah_en_explorer.json')))!;
    final session = SessionDto.fromJson(fixture).toEntity();
    mock.db.sessions[session.sessionId] = fixture;
    unawaited(GoRouter.of(t.element(find.byType(JourneyPage))).push('/session/${session.sessionId}'));
    await journeyUntil(t, () => find.byType(HookStepView).evaluate().isNotEmpty);
    await cta(t);
    await select(t, 0);
    await cta(t);
    await t.tap(find.byKey(const ValueKey('predict-continue')));
    await pumpJourney(t);
    final sentence = find.byType(SentenceText).first;
    await t.ensureVisible(sentence);
    await t.pump();
    await t.longPress(sentence);
    await pumpJourney(t);
    expect(find.byType(SourcesSheet), findsOneWidget);
    expect(find.text(session.sources.first.title), findsWidgets);
    Navigator.of(t.element(find.byType(SourcesSheet))).pop();
    await pumpJourney(t);
    final span = t.widget<SpanText>(find.descendant(of: sentence, matching: find.byType(SpanText)).first);
    final termSpan = span.spans.whereType<TermContentSpan>().first;
    final paragraph = t.renderObject<RenderParagraph>(find.descendant(of: sentence, matching: find.byType(RichText)).first);
    final offset = paragraph.text.toPlainText().indexOf(termSpan.text);
    final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + termSpan.text.length));
    await t.tapAt(paragraph.localToGlobal(boxes.first.toRect().center));
    await pumpJourney(t);
    expect(find.byType(TermSheet), findsOneWidget);
    expect(find.text(session.terms[termSpan.termId]!.arabic!), findsOneWidget);
    expect(mock.lastRequest!.path, '/glossary/${termSpan.termId}/opened');
    Navigator.of(t.element(find.byType(TermSheet))).pop();
    await pumpJourney(t);
    final content = t.element(find.byType(SessionPlayerPage)).read<ContentBloc>();
    final rawTerm = Map<String, dynamic>.from((fixture['terms'] as Map)[termSpan.termId] as Map)..['arabic'] = null;
    final nullArabic = TermCardDto.fromJson(rawTerm).toEntity();
    content.add(ContentReceived({...session.terms, termSpan.termId: nullArabic}, session.sources));
    await pumpJourney(t);
    content.add(const ContentAudioPlayed('https://cdn.example.com/unavailable.mp3'));
    await pumpJourney(t);
    expect(content.state.status, ContentStatus.failure);
    content.add(TermOpened(termSpan.termId));
    await pumpJourney(t);
    expect(find.byType(TermSheet), findsOneWidget);
    expect(find.text(session.terms[termSpan.termId]!.arabic!), findsNothing);
    expect(find.text(nullArabic.transliteration), findsOneWidget);
    Navigator.of(t.element(find.byType(TermSheet))).pop();
    await pumpJourney(t);
    d.services<AppEventBus>().publish(TermsMastered({termSpan.termId}));
    await pumpJourney(t);
    final updated = t.renderObject<RenderParagraph>(find.descendant(of: sentence, matching: find.byType(RichText)).first);
    final spans = (updated.text as TextSpan).children!.whereType<TextSpan>().where((s) => s.text == termSpan.text);
    expect(spans.every((s) => s.recognizer == null && s.style?.decoration != TextDecoration.underline), true);
    await t.tap(find.byKey(const ValueKey('player-close')));
    await pumpJourney(t);
    expect(find.byKey(const ValueKey('keep-learning')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('keep-learning')));
    await pumpJourney(t);
    expect(player(t).state.cursor, 2);
    await t.tap(find.byKey(const ValueKey('player-close')));
    await pumpJourney(t);
    await t.tap(find.byKey(const ValueKey('leave-lesson')));
    await pumpJourney(t);
    expect(find.byType(JourneyPage), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
  testWidgets('every Unit 0 and 1.1 content surface renders; missing image placeholder and fallback still', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 400);
    t.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await mountJourney(t, reduced: true);
    final mock = d.services<MockBackend>();
    isolateContent(d);
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    final index = (await t.runAsync(() => mock.fixtures.object('unit0/SESSION_INDEX.json')))!;
    final paths = [
      ...(index['sessions'] as List).cast<Map>().map((r) => 'unit0/${r['path']}'),
      for (final lang in ['en', 'ar'])
        for (final track in ['explorer', 'new_muslim']) 'test_lessons/u1l1_${lang}_$track.json',
    ];
    for (final path in paths) {
      final fixture = (await t.runAsync(() => mock.fixtures.object(path)))!;
      if (path == 'test_lessons/u1l1_en_explorer.json') {
        final items = (fixture['items'] as List).cast<Map>();
        final teach = items.firstWhere((i) => i['type'] == 'teach');
        final point = (teach['points'] as List).cast<Map>().first;
        final scripture = (await t.runAsync(() => mock.fixtures.object('examples/Evidence__5_3_evidence__0.json')))!;
        final hadith = (await t.runAsync(() => mock.fixtures.object('examples/Evidence__5_3_evidence__1.json')))!;
        fixture['items'] = [
          {
            'type': 'paragraph',
            'block_id': 'paragraph-test',
            'sentences': [point['sentence']],
          },
          for (final entry in [scripture, hadith])
            {'type': 'evidence', 'block_id': '${entry['kind']}-test', 'evidence': entry, 'caption': null},
          {'type': 'visual', 'block_id': 'visual-test', 'visual': items.firstWhere((i) => i['type'] == 'hook')['visual'], 'caption': null},
          ...items,
        ];
      }
      contentOnly(fixture);
      final id = fixture['session_id'] as String;
      mock.db.sessions[id] = fixture;
      router.go('/session/$id');
      await journeyUntil(t, () => find.byType(SessionPlayerPage).evaluate().isNotEmpty && player(t).state.session?.sessionId == id);
      var safety = 0;
      while (player(t).state.status != PlayerStatus.previewEnded && safety++ < 60) {
        final item = player(t).state.item!;
        if (item is EvidenceItem) expect(find.byType(item.evidence is QuranEvidence ? QuranText : HadithText), findsOneWidget);
        if (item is PredictItem && player(t).state.status != PlayerStatus.feedback) {
          await select(t, 0);
        }
        if (player(t).state.status == PlayerStatus.feedback) {
          await t.tap(find.byKey(const ValueKey('predict-continue')));
          await pumpJourney(t);
        } else {
          await cta(t);
        }
        expect(t.takeException(), isNull, reason: path);
      }
      expect(player(t).state.status, PlayerStatus.previewEnded, reason: path);
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
  testWidgets('intro loading, error and retry remain reachable in a short window', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 400);
    t.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await mountJourney(t, reduced: true);
    final mock = d.services<MockBackend>();
    final pending = Completer<BackendResponse>();
    mock.router.routes.insert(0, MockRoute('POST', '/sessions', (r, p) => pending.future));
    unawaited(GoRouter.of(t.element(find.byType(JourneyPage))).push('/lesson/les_u0_l1/intro'));
    await pumpJourney(t);
    expect(t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status, LessonIntroStatus.loading);
    expect(find.byType(QInlineLoading), findsWidgets);
    expect(t.takeException(), isNull);
    pending.complete(BackendResponse.error(500, 'internal_error', 'Unavailable'));
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.removeAt(0);
    final retry = find.descendant(of: find.byType(QErrorView), matching: find.byType(QButton));
    await t.ensureVisible(retry);
    await t.tap(retry);
    await journeyUntil(t, () => find.byKey(const ValueKey('lesson-start')).evaluate().isNotEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
  testWidgets('generated scene still is loaded at its authored ratio in a browser', (t) async {
    final client = Dio();
    Map<String, dynamic>? fixture;
    if (kIsWeb) {
      fixture = await t.runAsync(
        () async => (await client.get<Map<String, dynamic>>(
          'http://localhost:8284/mock_fixture/unit0/sessions/session_u0_l01_en_explorer.json',
        )).data!,
      );
    } else {
      final d = await mountJourney(t, pump: false);
      fixture = await t.runAsync(() => d.services<MockBackend>().fixtures.object('unit0/sessions/session_u0_l01_en_explorer.json'));
      await t.runAsync(d.dispose);
    }
    final visual = (SessionDto.fromJson(fixture!).toEntity().items.whereType<HookItem>().first.visual as SceneVisual);
    final url = 'http://localhost:8284/mock_media/unit0/${Uri.parse(visual.fallbackImage.url).path.substring(1)}';
    await t.pumpWidget(
      MaterialApp(
        theme: QTheme.light(arabic: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VisualMediaScope(
            resolve: (raw) => kIsWeb
                ? RemoteMedia(Uri.parse(url))
                : AssetMedia('assets/mocks/unit0/${Uri.parse(visual.fallbackImage.url).path.substring(1)}'),
            child: VisualView(visual, use: VisualUse.hook),
          ),
        ),
      ),
    );
    if (kIsWeb) {
      for (var i = 0; i < 50 && find.byType(Image).evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 100));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(find.byType(Image), findsOneWidget);
    }
    expect(t.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio, 1.6);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
