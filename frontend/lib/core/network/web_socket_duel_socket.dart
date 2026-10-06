import 'dart:convert';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class WebSocketDuelSocketFactory implements DuelSocketFactory {
  const WebSocketDuelSocketFactory();
  @override
  Future<DuelSocket> connect(Uri wsUrl) async {
    final channel = WebSocketChannel.connect(wsUrl);
    await channel.ready;
    return _WebSocket(channel);
  }
}

final class _WebSocket implements DuelSocket {
  _WebSocket(this.channel);
  final WebSocketChannel channel;
  @override
  Stream<WsEvent> get events => channel.stream.map((raw) {
    final j = jsonDecode(raw as String) as Map<String, dynamic>;
    return WsEvent(type: j['type'] as String, data: j['data'] as Map<String, dynamic>);
  });
  @override
  void send(WsClientMessage m) => channel.sink.add(
    jsonEncode(switch (m) {
      WsReady() => {'type': 'ready', 'data': <String, Object?>{}},
      WsPing() => {'type': 'ping', 'data': <String, Object?>{}},
      WsAnswer(:final questionIndex, :final answer) => {
        'type': 'answer',
        'data': {'question_index': questionIndex, 'answer': answer},
      },
    }),
  );
  @override
  Future<void> close() async {
    await channel.sink.close();
  }
}
