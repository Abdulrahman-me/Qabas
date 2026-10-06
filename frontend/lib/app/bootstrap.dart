import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Log only error types: exceptions can carry learner text, tokens or tickets.
  FlutterError.onError = (details) => Logger('app').severe('Flutter error: ${details.exception.runtimeType}');
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('app').severe('Unhandled error: ${error.runtimeType}');
    return true;
  };
  final view = PlatformDispatcher.instance.views.first;
  if (!kIsWeb &&
      [TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform) &&
      view.physicalSize.shortestSide / view.devicePixelRatio < QBreakpoints.phoneMax) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final package = await PackageInfo.fromPlatform();
  final dependencies = await AppDependencies.create(config: AppConfig.fromEnvironment(appVersion: package.version));
  runApp(QabasApp(dependencies: dependencies));
}
