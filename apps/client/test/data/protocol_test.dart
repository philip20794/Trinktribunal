import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/domain/models/ids.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
  File('../../packages/protocol/fixtures/messages/$name.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  final fixtures = fixture('room-v1')['fixtures'] as List;
  for (final value in fixtures) {
    final row = value as Map<String, dynamic>;
    test(
      '${row['fixtureId']}: decode, immutable typed roundtrip, reject unknown authority',
      () {
        final message = decodeRoomMessage(jsonEncode(row['valid']));
        expect(message.toJson(), row['valid']);
        expect(jsonDecode(message.toWire()), row['valid']);
        expect(
          () => decodeRoomMessage(jsonEncode(row['invalid'])),
          throwsA(isA<ProtocolDecodeException>()),
        );
      },
    );
  }
  for (final value in fixture('codec-cases')['cases'] as List) {
    final row = value as Map<String, dynamic>;
    test('adversarial: ${row['name']}', () {
      if (row['code'] == null) {
        final message = decodeRoomMessage(row['wire'] as String);
        expect(jsonDecode(message.toWire()), jsonDecode(row['wire'] as String));
      } else {
        expect(
          () => decodeRoomMessage(row['wire'] as String),
          throwsA(
            isA<ProtocolDecodeException>().having(
              (e) => e.code,
              'code',
              row['code'],
            ),
          ),
        );
      }
    });
  }
  test('typed outbound construction preserves IDs and requires actual confirmation', () {
    final message = SubmitOrderMessage.create(
      actionId: ActionId('action'),
      expectedRevision: 0,
      gameId: GameId('game'),
      roundId: RoundId('round'),
      order: [PlayerId('p1'), PlayerId('p2')],
      confirmed: true,
    );
    expect(message.toJson()['actionId'], 'action');
    expect(message.toJson()['gameId'], 'game');
    expect(message.toJson()['roundId'], 'round');
    expect(
      () => CompleteWithoutVerdictMessage.create(
        actionId: ActionId('a'),
        expectedRevision: 0,
        gameId: GameId('g'),
        roundId: RoundId('r'),
        confirmed: false,
      ),
      throwsA(isA<ProtocolDecodeException>()),
    );
    final absent = PublicChanges.fromJson({}),
        clear = PublicChanges.fromJson({'question': null});
    expect(absent.contains('question'), false);
    expect(clear.contains('question'), true);
    expect(clear.question, isNull);
    expect(
      () => JoinMessage.fromJson({'invalid': Object()}),
      throwsA(isA<ProtocolDecodeException>()),
    );
  });
  test('action/game/round identities remain distinct in typed getters and equality', () {
    final row = fixtures.cast<Map>().firstWhere(
      (f) => (f['valid'] as Map)['type'] == 'submitOrder',
    );
    final message = SubmitOrderMessage.fromJson(
      Map<String, Object?>.from(row['valid'] as Map),
    );
    expect(message.actionId, isA<ActionId>());
    expect(message.gameId, isA<GameId>());
    expect(message.roundId, isA<RoundId>());
    expect(ActionId('same'), isNot(GameId('same')));
    expect(GameId('same'), isNot(RoundId('same')));
  });
  test(
    'returned JSON and typed lists cannot mutate or retain a private order',
    () {
      final row = fixtures.cast<Map>().firstWhere(
        (f) => (f['valid'] as Map)['type'] == 'submitOrder',
      );
      final message = SubmitOrderMessage.fromJson(
        Map<String, Object?>.from(row['valid'] as Map),
      );
      expect(
        () => message.order.add(PlayerId('foreign')),
        throwsUnsupportedError,
      );
      (message.toJson()['order'] as List).add('foreign');
      expect(message.order.length, 2);
      expect(
        () => decodeRoomMessage(message.toWire(), direction: 'server'),
        throwsA(isA<ProtocolDecodeException>()),
      );
      expect(
        () => SubmitOrderMessage.fromJson({
          'type': 'ping',
          'protocolVersion': 1,
          'requestId': 'req',
        }),
        throwsA(isA<ProtocolDecodeException>()),
      );
    },
  );
}
