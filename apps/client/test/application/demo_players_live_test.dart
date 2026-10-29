import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/demo_players_controller.dart';
import 'package:trinktribunal/application/online_game_controller.dart';
import 'package:trinktribunal/application/online_order_controller.dart';
import 'package:trinktribunal/application/online_settings_controller.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/room_transport.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';

const _server = String.fromEnvironment('TT_DEMO_SERVER');

Future<SnapshotMessage> until(
  RoomController room,
  bool Function(PublicView) matches,
) async =>
    (await room.states
            .firstWhere(
              (state) =>
                  state.status == RoomConnectionStatus.online &&
                  state.snapshot != null &&
                  matches(state.snapshot!.public),
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                final state = room.state, view = room.state.snapshot?.public;
                throw StateError(
                  'Multiplayer wait timed out: status=${state.status.name}, phase=${view?.phase}, error=${state.errorCode}, players=${view?.players.length}, ready=${view?.players.where((p) => p.ready).length}',
                );
              },
            ))
        .snapshot!;

void main() {
  test(
    'real worker accepts two demo clients and their automatic actions through a full case',
    () async {
      final host = RoomController(
        transport: NetworkRoomTransport(Uri.parse(_server)),
        credentials: RoomCredentialStore(MemoryCredentialBackend()),
      );
      final demos = DemoPlayersController(
        host,
        createTransport: () => NetworkRoomTransport(Uri.parse(_server)),
      );
      final settings = OnlineSettingsController(host);
      final game = OnlineGameController(host);
      final order = OnlineOrderController(host);
      addTearDown(() async {
        demos.dispose();
        settings.dispose();
        game.dispose();
        order.dispose();
        final snapshot = host.state.snapshot;
        if (snapshot != null &&
            host.state.status == RoomConnectionStatus.online) {
          host.sendAction(
            CloseRoomMessage.create(
              actionId: ActionId(newRoomRequestId()),
              expectedRevision: snapshot.revision,
              confirmed: true,
            ),
          );
        }
        await host.dispose();
      });
      expect(
        await host.create(
          Profile.fromJson({
            'name': 'Demo Test Host',
            'avatar': AvatarConfig(seed: 'demo-host').toJson(),
          }),
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'lobby');
      settings.change('allJudges', true);
      settings.change('requestedRuleEvents', 0);
      settings.change('targetCases', 3);
      settings.flush();
      await until(
        host,
        (view) =>
            view.config.allJudges &&
            view.config.targetCases == 3 &&
            view.config.requestedRuleEvents == 0,
      );
      await demos.add();
      expect(demos.errorCode, isNull);
      await demos.add();
      expect(demos.errorCode, isNull);
      final lobby = await until(host, (view) => view.players.length == 3);
      expect(
        lobby.public.players.map((p) => p.profile.name),
        containsAll(['Demo 1', 'Demo 2']),
      );
      expect(
        host.sendAction(
          StartGameMessage.create(
            actionId: ActionId(newRoomRequestId()),
            expectedRevision: lobby.revision,
          ),
        ),
        isTrue,
      );
      final numbers = await until(host, (view) => view.phase == 'numbers');
      // Preparation is available before the ordering phase and stays local.
      final pool = List<PlayerId>.of(order.unplaced);
      for (var i = 0; i < pool.length; i++) {
        order.place(pool[i], i);
      }
      expect(order.complete, isTrue);
      game.revealOwnNumber();
      expect(game.acknowledgeNumber(), isTrue);
      final answers = await until(host, (view) => view.phase == 'answers');
      expect(order.slots, pool);
      expect(
        game.readyForOrdering(
          gameId: answers.public.gameId!,
          roundId: answers.public.roundId!,
        ),
        isTrue,
      );
      await until(host, (view) => view.players.every((p) => p.ready));
      expect(
        game.beginOrdering(
          gameId: answers.public.gameId!,
          roundId: answers.public.roundId!,
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'ordering');
      expect(
        order.confirm(
          gameId: numbers.public.gameId!,
          roundId: numbers.public.roundId!,
          confirmed: true,
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'revealing');
      for (var cursor = 0; cursor < 3; cursor++) {
        expect(
          game.revealNext(
            gameId: numbers.public.gameId!,
            roundId: numbers.public.roundId!,
            expectedCursor: cursor,
          ),
          isTrue,
        );
        await until(host, (view) => view.revealCursor == cursor + 1);
      }
      final judged = await until(host, (view) => view.phase == 'judged');
      expect(
        judged.public.players.where((p) => p.orderSubmitted),
        hasLength(3),
      );
      expect(judged.private.ownResult, isNotNull);
      expect(
        game.completeCase(
          gameId: judged.public.gameId!,
          roundId: judged.public.roundId!,
        ),
        isTrue,
      );
      final next = await until(
        host,
        (view) =>
            view.phase == 'numbers' && view.roundId != judged.public.roundId,
      );
      expect(next.public.readerId, isNot(next.you));
      expect(order.slots, everyElement(isNull));
      final nextPool = List<PlayerId>.of(order.unplaced);
      for (var i = 0; i < nextPool.length; i++) {
        order.place(nextPool[i], i);
      }
      game.revealOwnNumber();
      expect(game.acknowledgeNumber(), isTrue);
      await until(host, (view) => view.phase == 'answers');
      expect(
        game.readyForOrdering(
          gameId: next.public.gameId!,
          roundId: next.public.roundId!,
        ),
        isTrue,
      );
      // This time the demo reader begins ordering and reveals the verdict itself.
      await until(host, (view) => view.phase == 'ordering');
      expect(
        order.confirm(
          gameId: next.public.gameId!,
          roundId: next.public.roundId!,
          confirmed: true,
        ),
        isTrue,
      );
      final nextJudged = await until(host, (view) => view.phase == 'judged');
      expect(nextJudged.public.completedCases, 1);
      expect(nextJudged.private.ownResult, isNotNull);
    },
    skip: _server.isEmpty
        ? 'Run with --dart-define=TT_DEMO_SERVER=http://127.0.0.1:8795 and a local worker.'
        : false,
  );
  test(
    'normal public multiplayer preserves judge privacy, rotates roles and resumes identity',
    () async {
      final store = RoomCredentialStore(MemoryCredentialBackend());
      final host = RoomController(
        transport: NetworkRoomTransport(Uri.parse(_server)),
        credentials: store,
      );
      final demos = DemoPlayersController(
        host,
        createTransport: () => NetworkRoomTransport(Uri.parse(_server)),
      );
      final settings = OnlineSettingsController(host);
      final game = OnlineGameController(host);
      final order = OnlineOrderController(host);
      addTearDown(() async {
        demos.dispose();
        settings.dispose();
        game.dispose();
        order.dispose();
        final snapshot = host.state.snapshot;
        if (snapshot != null &&
            host.state.status == RoomConnectionStatus.online) {
          host.sendAction(
            CloseRoomMessage.create(
              actionId: ActionId(newRoomRequestId()),
              expectedRevision: snapshot.revision,
              confirmed: true,
            ),
          );
        }
        await host.dispose();
      });
      expect(
        await host.create(
          Profile.fromJson({
            'name': 'Normal Test Host',
            'avatar': AvatarConfig(seed: 'normal-test-host').toJson(),
          }),
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'lobby');
      settings.change('allJudges', false);
      settings.change('requestedRuleEvents', 0);
      settings.change('targetCases', 3);
      settings.flush();
      await until(
        host,
        (view) =>
            !view.config.allJudges &&
            view.config.targetCases == 3 &&
            view.config.requestedRuleEvents == 0,
      );
      await demos.add();
      expect(demos.errorCode, isNull);
      await demos.add();
      expect(demos.errorCode, isNull);
      final lobby = await until(host, (view) => view.players.length == 3);
      expect(
        host.sendAction(
          StartGameMessage.create(
            actionId: ActionId(newRoomRequestId()),
            expectedRevision: lobby.revision,
          ),
        ),
        isTrue,
      );
      final numbers = await until(host, (view) => view.phase == 'numbers');
      expect(numbers.public.judgeId, numbers.you);
      expect(numbers.private.ownNumber, isNull);
      final answers = await until(host, (view) => view.phase == 'answers');
      expect(
        game.readyForOrdering(
          gameId: answers.public.gameId!,
          roundId: answers.public.roundId!,
        ),
        isTrue,
      );
      await until(host, (view) => view.players.every((p) => p.ready));
      expect(
        game.beginOrdering(
          gameId: answers.public.gameId!,
          roundId: answers.public.roundId!,
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'ordering');
      expect(order.order, hasLength(2));
      expect(order.order, isNot(contains(numbers.you)));
      expect(
        order.confirm(
          gameId: numbers.public.gameId!,
          roundId: numbers.public.roundId!,
          confirmed: true,
        ),
        isTrue,
      );
      await until(host, (view) => view.phase == 'revealing');
      for (var cursor = 0; cursor < 2; cursor++) {
        expect(
          game.revealNext(
            gameId: numbers.public.gameId!,
            roundId: numbers.public.roundId!,
            expectedCursor: cursor,
          ),
          isTrue,
        );
        await until(host, (view) => view.revealCursor == cursor + 1);
      }
      final judged = await until(host, (view) => view.phase == 'judged');
      expect(judged.public.result, isNotNull);
      expect(judged.private.ownNumber, isNull);
      expect(
        game.completeCase(
          gameId: judged.public.gameId!,
          roundId: judged.public.roundId!,
        ),
        isTrue,
      );
      final next = await until(
        host,
        (view) =>
            view.phase == 'numbers' && view.roundId != judged.public.roundId,
      );
      expect(next.public.judgeId, isNot(next.you));
      expect(next.private.ownNumber, isNotNull);
      game.revealOwnNumber();
      expect(game.acknowledgeNumber(), isTrue);
      await until(host, (view) => view.phase == 'answers');
      expect(
        game.readyForOrdering(
          gameId: next.public.gameId!,
          roundId: next.public.roundId!,
        ),
        isTrue,
      );
      final nextJudged = await until(host, (view) => view.phase == 'judged');
      expect(nextJudged.public.completedCases, 1);
      final credential = (await store.load()).credentials.single;
      await host.resume(credential);
      final resumed = await until(host, (view) => view.phase == 'judged');
      expect(resumed.you, nextJudged.you);
      expect(resumed.public.roundId, nextJudged.public.roundId);
      expect(resumed.public.players, hasLength(3));
    },
    skip: _server.isEmpty
        ? 'Requires TT_DEMO_SERVER and a real worker.'
        : false,
  );
}
