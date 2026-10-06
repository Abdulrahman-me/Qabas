import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_metrics_page.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

import '../journey/journey_responsive_test.dart' show journeySizes;

class _UnmeasuredRepository implements ReviewerRepository {
  @override
  Future<Result<ReviewMetrics>> metrics() async => Ok(
    ReviewMetrics(
      learning: ReviewLearningMetrics(
        prePost: const [],
        misconceptions: const ReviewMisconceptionMetrics(activated: 0, resolved: 0, resolutionRatePercent: null),
        completion: const ReviewCompletionMetrics(unitsStarted: 0, unitsCompleted: 0),
      ),
      raqeebBenchmark: null,
      factory: const ReviewFactoryMetrics(
        lessonsPublished: 0,
        avgGenerationMinutes: null,
        avgReviewMinutes: null,
        blindTest: ReviewBlindMetrics(responses: 0, handwrittenIdentifiedPercent: null, generatedPreferredOrSamePercent: null),
      ),
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('Unmeasured metrics wrap and remain distinct from measured zero $language', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = journeySizes.first;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final bloc = ReviewerMetricsBloc(ReviewerActions(_UnmeasuredRepository()))..add(const MetricsOpened());
      addTearDown(bloc.close);
      await t.pumpWidget(
        MaterialApp(
          theme: QTheme.light(arabic: language == 'ar'),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.35)),
            child: child!,
          ),
          home: BlocProvider.value(value: bloc, child: const ReviewerMetricsPage()),
        ),
      );
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(find.byType(ReviewerMetricsPage)));
      for (final size in journeySizes) {
        t.view.physicalSize = size;
        await t.pump();
        expect(t.takeException(), isNull, reason: '$size');
        expect(find.text(l.reviewerNotMeasured), findsNWidgets(7));
        expect(find.text(language == 'en' ? '0' : '٠'), findsNWidgets(6));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        for (final element in find.text(l.reviewerNotMeasured).evaluate()) {
          final rect = t.getRect(find.byElementPredicate((e) => identical(e, element)));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }
      }
    });
  }
}
