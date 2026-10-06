import 'package:web/web.dart' as web;

Future<void> removeCaptureFile(String path) async {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}
