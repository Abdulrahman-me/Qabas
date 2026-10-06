import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/tour/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
  responseDataCallback: (data) async {
    final report = data?['scene_benchmarks'];
    if (report != null) {
      final platform = (report as Map)['platform'];
      final file = File('build/phase7/${platform}_frame_timings.json');
      await file.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    }
  },
);
