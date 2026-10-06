import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/unit_guide/domain/unit_guide.dart';

enum GuideStatus { initial, loading, ready, failure }

final class UnitGuideState extends Equatable {
  const UnitGuideState({this.status = GuideStatus.initial, this.guide, this.failure});
  final GuideStatus status;
  final UnitGuide? guide;
  final Failure? failure;
  @override
  List<Object?> get props => [status, guide, failure];
}

final class UnitGuideOpened {
  const UnitGuideOpened(this.id);
  final String id;
}

final class UnitGuideBloc extends Bloc<UnitGuideOpened, UnitGuideState> {
  UnitGuideBloc(this.getGuide) : super(const UnitGuideState()) {
    on<UnitGuideOpened>((e, emit) async {
      emit(const UnitGuideState(status: GuideStatus.loading));
      final r = await getGuide(e.id);
      if (emit.isDone) return;
      switch (r) {
        case Ok(:final value):
          emit(UnitGuideState(status: GuideStatus.ready, guide: value));
        case Err(:final failure):
          emit(UnitGuideState(status: GuideStatus.failure, failure: failure));
      }
    }, transformer: restartable());
  }
  final GetUnitGuide getGuide;
}
