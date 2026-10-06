import 'dart:typed_data';
import 'package:qabas/app/config/app_config.dart';

sealed class ResolvedMedia {
  const ResolvedMedia();
}

final class AssetMedia extends ResolvedMedia {
  const AssetMedia(this.path);
  final String path;
}

final class MemoryMedia extends ResolvedMedia {
  MemoryMedia(List<int> bytes) : bytes = Uint8List.fromList(bytes);
  final Uint8List bytes;
}

/// Authored demo URLs reserved for unavailable media, never downloaded.
final class UnavailableMedia extends ResolvedMedia {
  const UnavailableMedia();
}

final class RemoteMedia extends ResolvedMedia {
  const RemoteMedia(this.uri);
  final Uri uri;
}

final class MediaResolver {
  const MediaResolver(this.config);
  final AppConfig config;
  ResolvedMedia resolve(String url) {
    if (config.allowsMocks) _validate(url);
    final uri = Uri.parse(url);
    if (config.allowsMocks) {
      // TODO(contract): A-31 — example CDN URLs are declared placeholders.
      if (config.recordingDemo) {
        // TODO(contract): A-55 — recording-only bundled illustrations and original upload previews.
        if (uri.scheme == 'data') {
          final data = UriData.fromUri(uri);
          if (!['image/png', 'image/jpeg', 'image/webp'].contains(data.mimeType) || url.length > 12 * 1024 * 1024) {
            throw const FormatException('Invalid recording image');
          }
          return MemoryMedia(data.contentAsBytes());
        }
        if (uri.host == 'recording.qabas.invalid' && ['/museum.png', '/dawn.png'].contains(uri.path)) {
          return AssetMedia('assets/mocks/recording${uri.path}');
        }
        if (uri.host == 'cdn.example.com' && uri.path.endsWith('/museum_gallery.webp')) {
          return const AssetMedia('assets/mocks/recording/museum.png');
        }
        if (uri.host == 'cdn.example.com' && uri.path.endsWith('/desert_dawn.webp')) {
          return const AssetMedia('assets/mocks/recording/dawn.png');
        }
      }
      if (uri.host == 'cdn.example.com') return const UnavailableMedia();
      if (uri.scheme == 'mock-asset') {
        final path = '${uri.host}${uri.path}';
        _validate(path);
        return AssetMedia('assets/mocks/contract/mock_assets/$path');
      }
      if (uri.scheme == 'http' && uri.host == 'localhost' && uri.port == 8765 && uri.path.startsWith('/media/')) {
        final path = uri.path.substring(1);
        _validate(path);
        return AssetMedia('assets/mocks/unit0/$path');
      }
    }
    if (!['http', 'https'].contains(uri.scheme)) throw const FormatException('Unsupported media scheme');
    return RemoteMedia(uri);
  }

  void _validate(String path) {
    if (path.isEmpty || Uri.decodeComponent(path).split('/').any((part) => part == '..' || part == '.')) {
      throw const FormatException('Invalid asset path');
    }
  }
}
