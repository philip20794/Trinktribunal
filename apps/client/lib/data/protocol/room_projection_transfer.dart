import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'room_message.dart';

/// One bounded transfer per connection; never publishes a partial projection.
final class RoomProjectionTransfer {
  ProjectionStartMessage? _start;
  BytesBuilder _bytes = BytesBuilder(copy: false);
  int _chunks = 0;
  bool get pending => _start != null;

  void clear() {
    _start = null;
    _bytes = BytesBuilder(copy: false);
    _chunks = 0;
  }

  Never _invalid() => throw const ProtocolDecodeException('INVALID_MESSAGE');
  RoomMessage? accept(RoomMessage message) {
    try {
      return _accept(message);
    } on Object {
      clear();
      rethrow;
    }
  }

  RoomMessage? _accept(RoomMessage message) {
    if (message is ProjectionStartMessage) {
      if (pending) _invalid();
      _start = message;
      return null;
    }
    final start = _start;
    if (message is ProjectionChunkMessage) {
      if (start == null ||
          message.requestId != start.requestId ||
          message.transferId != start.transferId ||
          message.index != _chunks ||
          _chunks >= start.chunks) {
        _invalid();
      }
      final bytes = base64Url.decode(base64Url.normalize(message.data));
      if (bytes.length > roomProtocolLimits['projectionChunkBytes']! ||
          _bytes.length + bytes.length > start.bytes) {
        _invalid();
      }
      _bytes.add(bytes);
      _chunks++;
      return null;
    }
    if (message is ProjectionEndMessage) {
      if (start == null ||
          message.requestId != start.requestId ||
          message.transferId != start.transferId ||
          _chunks != start.chunks ||
          _bytes.length != start.bytes) {
        _invalid();
      }
      final bytes = _bytes.takeBytes();
      if (sha256.convert(bytes).toString() != start.sha256) _invalid();
      final projection = decodeRoomMessage(
        utf8.decode(bytes),
        direction: 'server',
        logical: true,
      );
      if (projection is! SnapshotMessage && projection is! DeltaMessage) {
        _invalid();
      }
      final json = projection.toJson();
      if (json['revision'] != start.revision ||
          json['requestId'] != start.requestId.value) {
        _invalid();
      }
      clear();
      return projection;
    }
    if (pending) _invalid();
    return message;
  }
}
