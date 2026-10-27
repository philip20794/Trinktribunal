import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/room_transport.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import 'room_test_support.dart';

void main() {
  test('HTTP create/join serialize strict intent, normalize code, never put secrets in URLs or redirects', () async {
    final paths = <String>[];
    final transport = NetworkRoomTransport(
      testCredential().serverOrigin,
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.query, isEmpty);
        expect(request.followRedirects, isFalse);
        final message = decodeRoomMessage(request.body, direction: 'client');
        expect(['create', 'join'], contains(message.type));
        return http.Response(
          testCredential().message.toWire(),
          paths.length == 1 ? 201 : 200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );
    await transport.create(testProfile());
    await transport.join(' abcd-23 45 ', testProfile());
    expect(paths, ['/api/rooms', '/api/rooms/ABCD2345/join']);
    transport.dispose();
  });
  test('HTTP leave sends only its own body credential and validates the exact left action receipt', () async {
    final credential = testCredential(), id = ActionId('left');
    final transport = NetworkRoomTransport(
      credential.serverOrigin,
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          isNot(contains(credential.message.resumeToken)),
        );
        final message = decodeRoomMessage(request.body);
        expect(message, isA<LeaveHttpMessage>());
        expect(
          (message as LeaveHttpMessage).resumeToken,
          credential.message.resumeToken,
        );
        return http.Response(
          AckMessage.create(
            requestId: RequestId('req'),
            actionId: id,
            revision: 1,
            outcome: 'left',
          ).toWire(),
          200,
        );
      }),
    );
    expect((await transport.leave(credential, id)).outcome, 'left');
    final foreign = RoomCredential(
      serverOrigin: Uri.parse('https://foreign.example'),
      message: credential.message,
    );
    await expectLater(
      transport.connect(foreign),
      throwsA(isA<RoomTransportException>()),
    );
    transport.dispose();
  });
  test('HTTP parser bounds streaming bytes and masks arbitrary server/network details', () async {
    for (final body in [
      ' '.padRight(16385),
      '{"resumeToken":"synthetic-secret"',
    ]) {
      final transport = NetworkRoomTransport(
        testCredential().serverOrigin,
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        transport.create(testProfile()),
        throwsA(
          isA<RoomTransportException>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('synthetic-secret')),
          ),
        ),
      );
      transport.dispose();
    }
    var requests = 0;
    final transport = NetworkRoomTransport(
      testCredential().serverOrigin,
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('secret-platform-detail');
      }),
    );
    await expectLater(
      transport.create(testProfile()),
      throwsA(
        isA<RoomTransportException>().having(
          (e) => e.code,
          'code',
          'NETWORK_UNAVAILABLE',
        ),
      ),
    );
    expect(requests, 1);
    transport.dispose();
  });
  test('only typed server errors are exposed; invalid/foreign credentials are rejected', () async {
    final error = ErrorMessage.create(
      requestId: RequestId('req'),
      code: 'ROOM_FULL',
    );
    final transport = NetworkRoomTransport(
      testCredential().serverOrigin,
      client: MockClient(
        (_) async => http.Response(jsonEncode(error.toJson()), 409),
      ),
    );
    await expectLater(
      transport.join('ABCD2345', testProfile()),
      throwsA(
        isA<RoomTransportException>().having(
          (e) => e.code,
          'code',
          'ROOM_FULL',
        ),
      ),
    );
    transport.dispose();
    for (final code in [
      'x' * 65,
      'https://example.com/?room=ABCD2345',
      'ABCD\t2345',
    ]) {
      expect(
        () => normalizedRoomCode(code),
        throwsA(isA<ProtocolDecodeException>()),
      );
    }
  });
}
