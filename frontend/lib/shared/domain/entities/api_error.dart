import 'package:equatable/equatable.dart';

final class ApiError extends Equatable {
  ApiError({required this.code, required this.message, required Map<String, Object?> details}) : details = Map.unmodifiable(details);
  final String code, message;
  final Map<String, Object?> details;
  @override
  List<Object?> get props => [code, message, details];
}
