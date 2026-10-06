import 'package:audioplayers/audioplayers.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/shared/domain/repositories/content_repository.dart';
import 'package:url_launcher/url_launcher.dart';

final class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl(this.api, this.media);
  final ApiClient api;
  final MediaResolver media;
  AudioPlayer? _audio;
  @override
  Future<Result<void>> markTermOpened(String id) => guard(() => api.postNoContent('/glossary/${Uri.encodeComponent(id)}/opened'));
  @override
  Future<Result<void>> playAudio(String url) => guard(() async {
    final resolved = media.resolve(url);
    if (resolved is UnavailableMedia) throw const FormatException('Audio is unavailable');
    final audio = _audio ??= AudioPlayer();
    await audio.stop();
    await audio.play(switch (resolved) {
      UnavailableMedia() || MemoryMedia() => throw const FormatException('Audio is unavailable'),
      AssetMedia(:final path) => AssetSource(path.replaceFirst('assets/', '')),
      RemoteMedia(:final uri) => UrlSource(uri.toString()),
    });
  });
  @override
  Future<Result<void>> openSource(String url) => guard(() async {
    final uri = Uri.parse(url);
    if (!['https', 'http'].contains(uri.scheme) || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('Source is unavailable');
    }
  });
  @override
  Future<void> dispose() async {
    await _audio?.dispose();
  }
}
