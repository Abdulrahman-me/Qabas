import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/shared/domain/entities/content.dart';

final class RecitationPlaybackImpl implements RecitationSegmentPlayback {
  RecitationPlaybackImpl(RecitationAudio audio, MediaResolver resolver) {
    _resolver = resolver;
    try {
      _media = resolver.resolve(audio.url);
    } catch (_) {
      _media = const UnavailableMedia();
    }
  }
  late final ResolvedMedia _media;
  late final MediaResolver _resolver;
  Timer? _clip;
  AudioPlayer? _player;
  StreamSubscription<Duration>? _position;
  StreamSubscription<void>? _done;
  @override
  bool get available => _media is! UnavailableMedia;
  @override
  Future<void> play(void Function(Duration) position, void Function(RecitationPlaybackStatus) status) async {
    _clip?.cancel();
    if (!available) throw StateError('Audio unavailable');
    final player = _player ??= AudioPlayer();
    await _position?.cancel();
    await _done?.cancel();
    _position = player.onPositionChanged.listen(position);
    _done = player.onPlayerComplete.listen((_) {
      status(RecitationPlaybackStatus.idle);
    });
    final source = switch (_media) {
      AssetMedia(:final path) => AssetSource(path.substring('assets/'.length)),
      RemoteMedia(:final uri) => UrlSource(uri.toString()),
      _ => throw StateError('Audio unavailable'),
    };
    await player.stop();
    await player.play(source);
  }

  @override
  Future<void> playSegment(RecitationSegment segment, void Function(RecitationPlaybackStatus) status) async {
    _clip?.cancel();
    final media = _resolver.resolve(segment.url), player = _player ??= AudioPlayer();
    final source = switch (media) {
      AssetMedia(:final path) => AssetSource(path.substring('assets/'.length)),
      RemoteMedia(:final uri) => UrlSource(uri.toString()),
      _ => throw StateError('Audio unavailable'),
    };
    await player.stop();
    status(RecitationPlaybackStatus.playing);
    await player.play(source, position: segment.start);
    _clip = Timer(segment.end - segment.start, () {
      unawaited(player.stop());
      status(RecitationPlaybackStatus.idle);
    });
  }

  @override
  Future<void> stop() async {
    _clip?.cancel();
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    _clip?.cancel();
    await _position?.cancel();
    await _done?.cancel();
    await _player?.dispose();
  }
}
