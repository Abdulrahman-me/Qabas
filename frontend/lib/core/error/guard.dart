import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';

Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on FailureSource catch (error) {
    return Err(error.toFailure());
  } catch (_) {
    return const Err(UnexpectedFailure('Response decoding or local operation failed'));
  }
}
