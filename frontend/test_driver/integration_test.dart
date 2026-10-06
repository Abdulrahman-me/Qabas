import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots taken by integration tests to build/tour/.
Future<void> main() async {
  // Screenshot transport data can be hundreds of MB; preserve the captures
  // without duplicating their byte arrays in the protocol log.
  final driver = await FlutterDriver.connect(logCommunicationToFile: false);
  await integrationDriver(
    driver: driver,
    onScreenshot: (name, bytes, [args]) async {
      final file = File('build/tour/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
