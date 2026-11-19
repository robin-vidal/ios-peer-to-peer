import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

import 'exceptions.dart';

class WireConnection {
  WireConnection(this._socket)
      : _lines = StreamQueue<String>(
          utf8.decoder.bind(_socket).transform(const LineSplitter()),
        );

  final Socket _socket;
  final StreamQueue<String> _lines;

  Future<String> request(String line, {required Duration timeout}) async {
    await send(line);
    return nextLine(timeout: timeout);
  }

  Future<void> send(String line) async {
    _socket.write('$line\n');
    await _socket.flush();
  }

  Future<String> nextLine({required Duration timeout}) async {
    final available = await _lines.hasNext.timeout(
      timeout,
      onTimeout: () => false,
    );
    if (!available) {
      throw const ProtocolException(
        'the server timed out or closed the connection',
      );
    }
    return _lines.next;
  }

  Future<void> close() async {
    await _lines.cancel(immediate: true);
    _socket.destroy();
  }
}
