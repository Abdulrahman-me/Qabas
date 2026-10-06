import 'dart:async';
import 'package:qabas/core/events/app_events.dart';

final class AppEventBus {
  final _controller = StreamController<AppEvent>.broadcast();
  void publish(AppEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  Stream<T> on<T extends AppEvent>() => _controller.stream.where((event) => event is T).cast<T>();
  Future<void> dispose() => _controller.close();
}
