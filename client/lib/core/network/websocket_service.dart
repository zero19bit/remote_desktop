import 'dart:convert';

import 'package:web_socket_channel/io.dart';


class WebSocketService {

  IOWebSocketChannel? _channel;


  Future<void> connect(String url) async {

    _channel = IOWebSocketChannel.connect(
      Uri.parse(url),
    );

    print("WebSocket Connected");

  }


  Stream<dynamic>? get messages {

    return _channel?.stream;

  }


  void send(Map<String, dynamic> message) {

    if (_channel == null) {
      print("WebSocket is not connected");
      return;
    }


    _channel!.sink.add(
      jsonEncode(message),
    );

  }


  void disconnect(){

    _channel?.sink.close();

  }

}