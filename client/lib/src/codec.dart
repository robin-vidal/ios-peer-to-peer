import 'dart:typed_data';

import 'exceptions.dart';

const _hexDigits = '0123456789abcdef';

String hexEncode(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(_hexDigits[(b >> 4) & 0x0f]);
    out.write(_hexDigits[b & 0x0f]);
  }
  return out.toString();
}

Uint8List hexDecode(String text) {
  if (text.length.isOdd) {
    throw const ProtocolException('hex string has an odd length');
  }
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final parsed = int.tryParse(text.substring(i * 2, i * 2 + 2), radix: 16);
    if (parsed == null) {
      throw const ProtocolException('hex string has a non hex character');
    }
    out[i] = parsed;
  }
  return out;
}

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class FieldWriter {
  final BytesBuilder _builder = BytesBuilder();

  void raw(List<int> bytes) => _builder.add(bytes);

  void field(List<int> bytes) {
    final header = Uint8List(4);
    ByteData.view(header.buffer).setUint32(0, bytes.length);
    _builder.add(header);
    _builder.add(bytes);
  }

  Uint8List take() => _builder.toBytes();
}

class FieldReader {
  FieldReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  int get remaining => _bytes.length - _offset;

  Uint8List raw(int length) {
    if (remaining < length) {
      throw const ProtocolException('truncated payload');
    }
    final out = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return out;
  }

  Uint8List field() {
    if (remaining < 4) {
      throw const ProtocolException('truncated field header');
    }
    final length = ByteData.sublistView(_bytes, _offset, _offset + 4).getUint32(0);
    _offset += 4;
    return raw(length);
  }

  void expectEnd() {
    if (remaining != 0) {
      throw const ProtocolException('trailing bytes in payload');
    }
  }
}

Uint8List uint16(int value) {
  final out = Uint8List(2);
  ByteData.view(out.buffer).setUint16(0, value);
  return out;
}

int readUint16(Uint8List bytes) {
  if (bytes.length != 2) {
    throw const ProtocolException('expected 2 bytes for a port');
  }
  return ByteData.sublistView(bytes).getUint16(0);
}

Uint8List int64(int value) {
  final out = Uint8List(8);
  ByteData.view(out.buffer).setInt64(0, value);
  return out;
}

int readInt64(Uint8List bytes) {
  if (bytes.length != 8) {
    throw const ProtocolException('expected 8 bytes for a timestamp');
  }
  return ByteData.sublistView(bytes).getInt64(0);
}
