import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/protocol/room_projection.dart';

import 'room_test_support.dart';

void main() {
  test('delta applies only to the exact room recipient and revision, without changing the previous view', () {
    final base = roomFixture('snapshot') as SnapshotMessage,
        delta = roomFixture('delta') as DeltaMessage;
    final next = applyRoomDelta(base, delta);
    expect(next.revision, 2);
    expect(base.revision, 1);
    for (final patch in [
      {'roomId': 'foreign'},
      {'you': 'foreign'},
      {'baseRevision': 0},
    ]) {
      expect(
        () => applyRoomDelta(
          base,
          DeltaMessage.fromJson({...delta.toJson(), ...patch}),
        ),
        throwsA(isA<ProtocolDecodeException>()),
      );
    }
    expect(base.private.ownNumber, 2);
  });
  test('explicit nulls clear public references and the private object replaces all old secrets', () {
    final base = roomFixture('snapshot') as SnapshotMessage;
    final delta = DeltaMessage.fromJson({
      ...roomFixture('delta').toJson(),
      'publicChanges': {
        'phase': 'lobby',
        'gameId': null,
        'roundId': null,
        'judgeId': null,
        'readerId': null,
        'question': null,
        'frozenRoster': [],
        'pendingRoster': [],
        'revealCursor': 0,
        'revealed': [],
      },
      'private': {},
    });
    final next = applyRoomDelta(base, delta);
    expect(next.public.gameId, isNull);
    expect(next.public.question, isNull);
    expect(next.private.toJson(), isEmpty);
    expect(base.public.gameId, isNotNull);
    expect(base.private.ownNumber, 2);
  });
}
