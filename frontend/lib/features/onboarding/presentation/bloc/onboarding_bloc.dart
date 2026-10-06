import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_copy.dart';
import 'package:qabas/features/onboarding/domain/usecases/onboarding_actions.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum OnboardingPage { language, welcome, who, curiosity, familiarity, goal, privacy, ready }

enum OnboardingStatus { loading, ready, submitting, failure, complete }

final class OnboardingState extends Equatable {
  OnboardingState({
    this.status = OnboardingStatus.loading,
    this.page = OnboardingPage.language,
    this.language = 'en',
    this.track,
    this.familiarity,
    this.dailyGoal = 10,
    this.privateProfile = true,
    this.discreetReminders = true,
    this.reminderHour = 19,
    this.goalAnchor,
    this.curiosity,
    this.bridgeVisible = false,
    List<PathPreview> preview = const [],
    this.failure,
    this.user,
    this.selectionSerial = 0,
  }) : preview = List.unmodifiable(preview);
  final OnboardingStatus status;
  final OnboardingPage page;
  final String language;
  final TrackChoice? track;
  final Familiarity? familiarity;
  final int dailyGoal, reminderHour, selectionSerial;
  final bool privateProfile, discreetReminders, bridgeVisible;
  final String? goalAnchor;
  final CuriosityCopy? curiosity;
  final List<PathPreview> preview;
  final Failure? failure;
  final UserProfile? user;
  List<OnboardingPage> get pages => OnboardingPage.values.where((p) => p != OnboardingPage.curiosity || curiosity != null).toList();
  int get pageIndex => pages.indexOf(page);
  bool get hero => [OnboardingPage.language, OnboardingPage.welcome, OnboardingPage.ready].contains(page) || bridgeVisible;
  bool get canContinue => switch (page) {
    OnboardingPage.who => track != null,
    OnboardingPage.familiarity => familiarity != null,
    _ => true,
  };
  String? get bridge => curiosity?.options.where((option) => option.anchor == goalAnchor).firstOrNull?.bridge(track);
  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingPage? page,
    String? language,
    TrackChoice? track,
    Familiarity? familiarity,
    int? dailyGoal,
    int? reminderHour,
    bool? privateProfile,
    bool? discreetReminders,
    String? goalAnchor,
    bool clearAnchor = false,
    CuriosityCopy? curiosity,
    bool clearCuriosity = false,
    bool? bridgeVisible,
    List<PathPreview>? preview,
    Failure? failure,
    UserProfile? user,
    int? selectionSerial,
  }) => OnboardingState(
    status: status ?? this.status,
    page: page ?? this.page,
    language: language ?? this.language,
    track: track ?? this.track,
    familiarity: familiarity ?? this.familiarity,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    reminderHour: reminderHour ?? this.reminderHour,
    privateProfile: privateProfile ?? this.privateProfile,
    discreetReminders: discreetReminders ?? this.discreetReminders,
    goalAnchor: clearAnchor ? null : goalAnchor ?? this.goalAnchor,
    curiosity: clearCuriosity ? null : curiosity ?? this.curiosity,
    bridgeVisible: bridgeVisible ?? this.bridgeVisible,
    preview: preview ?? this.preview,
    failure: failure,
    user: user ?? this.user,
    selectionSerial: selectionSerial ?? this.selectionSerial,
  );
  @override
  List<Object?> get props => [
    status,
    page,
    language,
    track,
    familiarity,
    dailyGoal,
    privateProfile,
    discreetReminders,
    reminderHour,
    goalAnchor,
    curiosity,
    bridgeVisible,
    preview,
    failure,
    user,
    selectionSerial,
  ];
}

sealed class OnboardingEvent {
  const OnboardingEvent();
}

sealed class OnboardingEditEvent extends OnboardingEvent {
  const OnboardingEditEvent();
}

final class OnboardingOpened extends OnboardingEditEvent {
  const OnboardingOpened();
}

final class PageAdvanced extends OnboardingEditEvent {
  const PageAdvanced();
}

final class PageBacked extends OnboardingEditEvent {
  const PageBacked();
}

final class LanguagePicked extends OnboardingEditEvent {
  const LanguagePicked(this.language);
  final String language;
}

final class TrackPicked extends OnboardingEditEvent {
  const TrackPicked(this.track);
  final TrackChoice track;
}

final class FamiliarityPicked extends OnboardingEditEvent {
  const FamiliarityPicked(this.familiarity);
  final Familiarity familiarity;
}

final class GoalPicked extends OnboardingEditEvent {
  const GoalPicked(this.minutes);
  final int minutes;
}

final class PrivacyToggled extends OnboardingEditEvent {
  const PrivacyToggled(this.value);
  final bool value;
}

final class RemindersToggled extends OnboardingEditEvent {
  const RemindersToggled(this.value);
  final bool value;
}

final class ReminderTimePicked extends OnboardingEditEvent {
  const ReminderTimePicked(this.hour);
  final int hour;
}

final class CuriosityPicked extends OnboardingEditEvent {
  const CuriosityPicked(this.anchor);
  final String anchor;
}

final class CuriositySkipped extends OnboardingEditEvent {
  const CuriositySkipped();
}

final class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted();
}

final class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this.complete,
    required this.copy,
    required this.savePreferences,
    required this.curiosityEnabled,
    required this.changeLanguage,
    required String language,
    bool discreetReminders = true,
    int reminderHour = 19,
  }) : super(OnboardingState(language: language, discreetReminders: discreetReminders, reminderHour: reminderHour)) {
    on<OnboardingEvent>((event, emit) {
      final next = _operations.then((_) async {
        if (emit.isDone) return;
        try {
          await _handle(event, emit);
        } finally {
          if (event is OnboardingSubmitted) _submissionPending = false;
        }
      });
      _operations = next.catchError((Object _) {});
      return next;
    });
  }
  // Serialize copy loads, edits and submits without pausing the event stream;
  // disposal can cancel emitters even while an asset/request is still pending.
  Future<void> _operations = Future.value();
  bool _submissionPending = false;
  @override
  void add(OnboardingEvent event) {
    if (event is OnboardingSubmitted) {
      if (_submissionPending) return;
      _submissionPending = true;
    }
    super.add(event);
  }

  final CompleteOnboarding complete;
  final LoadOnboardingCopy copy;
  final SaveOnboardingPreferences savePreferences;
  final bool Function() curiosityEnabled;
  final Future<void> Function(String) changeLanguage;
  Future<void> _handle(OnboardingEvent event, Emitter<OnboardingState> emit) async {
    if (state.status == OnboardingStatus.complete || (state.status == OnboardingStatus.submitting && event is! OnboardingSubmitted)) return;
    switch (event) {
      case OnboardingOpened():
        await _loadCopy(emit);
      case LanguagePicked(:final language):
        if (!['en', 'ar'].contains(language)) return;
        emit(state.copyWith(language: language, selectionSerial: state.selectionSerial + 1));
        await changeLanguage(language);
        if (emit.isDone) return;
        await _loadCopy(emit);
      case PageAdvanced():
        if (!state.canContinue || state.pageIndex == state.pages.length - 1) return;
        if (state.page == OnboardingPage.curiosity && !state.bridgeVisible && state.bridge != null) {
          emit(state.copyWith(bridgeVisible: true));
        } else {
          emit(state.copyWith(page: state.pages[state.pageIndex + 1], bridgeVisible: false));
        }
      case PageBacked():
        if (state.bridgeVisible) {
          emit(state.copyWith(bridgeVisible: false));
        } else if (state.pageIndex > 0) {
          emit(state.copyWith(page: state.pages[state.pageIndex - 1]));
        }
      case TrackPicked(:final track):
        emit(state.copyWith(track: track, bridgeVisible: false, selectionSerial: state.selectionSerial + 1));
        await _loadPreview(emit);
      case FamiliarityPicked(:final familiarity):
        if (familiarity == Familiarity.unknown) return;
        emit(state.copyWith(familiarity: familiarity, selectionSerial: state.selectionSerial + 1));
      case GoalPicked(:final minutes):
        if (![5, 10, 15, 20].contains(minutes)) return;
        emit(state.copyWith(dailyGoal: minutes, selectionSerial: state.selectionSerial + 1));
      case PrivacyToggled(:final value):
        emit(state.copyWith(privateProfile: value, selectionSerial: state.selectionSerial + 1));
      case RemindersToggled(:final value):
        emit(state.copyWith(discreetReminders: value, selectionSerial: state.selectionSerial + 1));
      case ReminderTimePicked(:final hour):
        if (![8, 13, 19, 21].contains(hour)) return;
        emit(state.copyWith(reminderHour: hour, selectionSerial: state.selectionSerial + 1));
      case CuriosityPicked(:final anchor):
        if (state.curiosity?.options.any((option) => option.anchor == anchor) != true) return;
        emit(state.copyWith(goalAnchor: anchor, bridgeVisible: false, selectionSerial: state.selectionSerial + 1));
      case CuriositySkipped():
        emit(state.copyWith(clearAnchor: true, bridgeVisible: false, page: OnboardingPage.familiarity));
      case OnboardingSubmitted():
        if (state.page != OnboardingPage.ready || state.track == null || state.familiarity == null) return;
        emit(state.copyWith(status: OnboardingStatus.submitting));
        final local = await savePreferences(discreetReminders: state.discreetReminders, reminderHour: state.reminderHour);
        if (emit.isDone) return;
        if (local case Err<void>(:final failure)) {
          emit(state.copyWith(status: OnboardingStatus.failure, failure: failure));
          return;
        }
        final result = await complete(
          OnboardingAnswers(
            track: state.track!,
            language: state.language,
            familiarity: state.familiarity,
            dailyGoal: state.dailyGoal,
            privateProfile: state.privateProfile,
            goalAnchor: curiosityEnabled() && state.curiosity != null ? state.goalAnchor : null,
          ),
        );
        if (emit.isDone) return;
        switch (result) {
          case Ok<UserProfile>(:final value):
            emit(state.copyWith(status: OnboardingStatus.complete, user: value));
          case Err<UserProfile>(:final failure):
            emit(state.copyWith(status: OnboardingStatus.failure, failure: failure));
        }
    }
  }

  Future<void> _loadCopy(Emitter<OnboardingState> emit) async {
    final curiosity = curiosityEnabled() ? await copy.curiosity(state.language) : null;
    if (emit.isDone) return;
    emit(
      state.copyWith(
        status: OnboardingStatus.ready,
        curiosity: curiosity,
        clearCuriosity: curiosity == null,
        clearAnchor: curiosity == null,
        page: state.page == OnboardingPage.curiosity && curiosity == null ? OnboardingPage.familiarity : state.page,
      ),
    );
    await _loadPreview(emit);
  }

  Future<void> _loadPreview(Emitter<OnboardingState> emit) async {
    try {
      final preview = await copy.preview(state.language, state.track ?? TrackChoice.explorer);
      if (!emit.isDone) emit(state.copyWith(preview: preview));
    } catch (_) {
      // This optional summary never blocks onboarding; the server owns entry.
      if (!emit.isDone) emit(state.copyWith(preview: []));
    }
  }
}
