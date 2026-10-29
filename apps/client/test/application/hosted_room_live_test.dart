import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/hosted_room_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/room_transport.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import '../data/room_test_support.dart';
import 'demo_players_live_test.dart' show until;

const _server = String.fromEnvironment('TT_DEMO_SERVER');
void main() {
  test('one hosted room: cancel preserves it; a stored host identity closes it before replacement', () async {
    final credentials = RoomCredentialStore(MemoryCredentialBackend()),
        transport = NetworkRoomTransport(Uri.parse(_server));
    final original = RoomController(
      transport: transport,
      credentials: credentials,
    );
    final profile = Profile.fromJson({
      'name': 'Room replacement test',
      'avatar': AvatarConfig().toJson(),
    });
    expect(await original.create(profile), isTrue);
    await until(original, (view) => view.phase == 'lobby');
    final firstRoom = original.state.snapshot!.roomId,
        firstCode = original.roomCode!;
    expect(
      await HostedRoomController(original, credentials).prepareNewRoom((
        codes,
      ) async {
        expect(codes, [firstCode]);
        return false;
      }),
      isFalse,
    );
    expect(original.state.snapshot!.roomId, firstRoom);
    await original.dispose();
    final current = RoomController(
      transport: NetworkRoomTransport(Uri.parse(_server)),
      credentials: credentials,
    );
    addTearDown(current.dispose);
    expect(
      await HostedRoomController(current, credentials).prepareNewRoom((
        codes,
      ) async {
        expect(codes, [firstCode]);
        return true;
      }),
      isTrue,
    );
    expect((await credentials.load()).credentials, isEmpty);
    expect(
      await current.create(profile),
      isTrue,
      reason: current.state.errorCode,
    );
    await until(current, (view) => view.phase == 'lobby');
    expect(current.state.snapshot!.roomId, isNot(firstRoom));
    expect((await credentials.load()).credentials, hasLength(1));
    await HostedRoomController(
      current,
      credentials,
    ).prepareNewRoom((_) async => true);
  }, skip: _server.isEmpty ? 'Opt-in real HTTP/WebSocket test.' : false);
}
