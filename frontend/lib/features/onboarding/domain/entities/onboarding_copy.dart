import 'package:equatable/equatable.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';

final class CuriosityOption extends Equatable {
  const CuriosityOption({required this.anchor, required this.label, this.explorerBridge, this.newMuslimBridge});
  final String anchor, label;
  final String? explorerBridge, newMuslimBridge;
  String? bridge(TrackChoice? track) => track == TrackChoice.newMuslim ? newMuslimBridge : explorerBridge;
  @override
  List<Object?> get props => [anchor, label, explorerBridge, newMuslimBridge];
}

final class CuriosityCopy extends Equatable {
  CuriosityCopy({required this.question, required List<CuriosityOption> options}) : options = List.unmodifiable(options);
  final String question;
  final List<CuriosityOption> options;
  @override
  List<Object?> get props => [question, options];
}

final class PathPreview extends Equatable {
  const PathPreview({required this.number, required this.title, required this.artKey});
  final int number;
  final String title, artKey;
  @override
  List<Object?> get props => [number, title, artKey];
}
