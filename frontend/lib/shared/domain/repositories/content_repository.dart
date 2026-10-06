import 'package:qabas/core/error/result.dart';

abstract interface class ContentRepository {
  Future<Result<void>> markTermOpened(String id);
  Future<Result<void>> playAudio(String url);
  Future<Result<void>> openSource(String url);
  Future<void> dispose();
}
