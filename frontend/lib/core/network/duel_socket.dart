/// Ticket URLs remain opaque; implementations arrive with challenges.
abstract interface class DuelSocket {
  Stream<WsEvent> get events;
  void send(WsClientMessage message);
  Future<void> close();
}

abstract interface class DuelSocketFactory {
  Future<DuelSocket> connect(Uri wsUrl);
}

final class WsEvent {
  const WsEvent({required this.type, required this.data});
  final String type;
  final Map<String, Object?> data;
}

sealed class WsClientMessage {
  const WsClientMessage();
}

final class WsReady extends WsClientMessage {
  const WsReady();
}

final class WsPing extends WsClientMessage {
  const WsPing();
}

final class WsAnswer extends WsClientMessage {
  const WsAnswer({required this.questionIndex, required this.answer});
  final int questionIndex;
  final Map<String, Object?> answer;
}
