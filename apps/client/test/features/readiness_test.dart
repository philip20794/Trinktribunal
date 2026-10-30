import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/features/multiplayer/readiness_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';

class _Surface extends ConsumerWidget {
  const _Surface();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(roomSessionProvider).asData?.value ??
        ref.read(roomControllerProvider).state;
    return Scaffold(
      body: SingleChildScrollView(
        child: state.snapshot == null
            ? const SizedBox()
            : ReadinessView(snapshot: state.snapshot!),
      ),
    );
  }
}

SnapshotMessage answerView({
  bool host = true,
  bool ready = false,
  bool offline = false,
  int revision = 1,
  String roundId = 'round_1',
}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': host ? 'p1' : 'p2',
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'phase': 'answers',
      'gameId': 'game_1',
      'roundId': roundId,
      'frozenRoster': ['p1', 'p2', 'p3'],
      'players': base.public.players
          .map(
            (player) => {
              ...player.toJson(),
              'ready': ready,
              'connected': !(offline && player.playerId.value == 'p3'),
            },
          )
          .toList(),
    },
    'private': <String, Object?>{},
  });
}

Future<({RoomController room, FakeRoomTransport transport})> pump(
  WidgetTester tester, {
  bool host = true,
  bool ready = false,
  bool offline = false,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  addTearDown(room.dispose);
  await room.resume(
    RoomCredential(
      serverOrigin: testCredential().serverOrigin,
      message: CredentialMessage.fromJson({
        ...testCredential().message.toJson(),
        'playerId': host ? 'p1' : 'p2',
      }),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: _Surface()),
    ),
  );
  transport.sockets.last.receive(
    AuthenticatedMessage.fromJson({
      ...roomFixture('authenticated').toJson(),
      'playerId': host ? 'p1' : 'p2',
    }),
  );
  transport.sockets.last.receive(
    answerView(host: host, ready: ready, offline: offline),
  );
  await tester.pumpAndSettle();
  return (room: room, transport: transport);
}

void main() {
  testWidgets(
    'own readiness sends one intent; host must wait for all server-confirmed participants',
    (tester) async {
      final fixture = await pump(tester),
          socket = fixture.transport.sockets.last;
      final begin = AppStrings('de').get('phoneBeginOrder');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, begin))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Meine Antwort ist bereit'));
      await tester.pumpAndSettle();
      final action = socket.sent.whereType<ReadyForOrderingMessage>().single;
      expect(action.toJson().keys.toSet(), {
        'type',
        'protocolVersion',
        'actionId',
        'expectedRevision',
        'gameId',
        'roundId',
      });
      expect(action.expectedRevision, 1);
      expect(
        fixture.room.state.snapshot!.public.players.every(
          (player) => !player.ready,
        ),
        isTrue,
      );
      expect(find.text('Deine Bereitschaft wird bestätigt …'), findsOneWidget);
      socket.receive(answerView(ready: true, revision: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text(begin));
      await tester.pumpAndSettle();
      expect(
        socket.sent.whereType<BeginOrderingMessage>().single.expectedRevision,
        2,
      );
      expect(fixture.room.state.snapshot!.public.phase, 'answers');
    },
  );
  testWidgets(
    'non-host has only its own readiness action and no host completion',
    (tester) async {
      final fixture = await pump(tester, host: false),
          socket = fixture.transport.sockets.last;
      expect(find.text(AppStrings('de').get('phoneBeginOrder')), findsNothing);
      expect(find.text('Fall ohne Urteil abschließen'), findsNothing);
      await tester.tap(find.text('Meine Antwort ist bereit'));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<ReadyForOrderingMessage>(), hasLength(1));
    },
  );
  testWidgets(
    'disconnected ready participant blocks host; cancellation sends nothing, explicit completion sends once',
    (tester) async {
      final fixture = await pump(tester, ready: true, offline: true),
          socket = fixture.transport.sockets.last;
      expect(
        find.text('Verbindung unterbrochen – die Phase wartet.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                AppStrings('de').get('phoneBeginOrder'),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Partieoptionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fall ohne Urteil abschließen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CompleteWithoutVerdictMessage>(), isEmpty);
      await tester.tap(find.byTooltip('Partieoptionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fall ohne Urteil abschließen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Fall abschließen'));
      await tester.pumpAndSettle();
      final action = socket.sent
          .whereType<CompleteWithoutVerdictMessage>()
          .single;
      expect(action.confirmed, isTrue);
      expect(action.roundId, fixture.room.state.snapshot!.public.roundId);
      expect(fixture.room.state.snapshot!.public.completedCases, 0);
    },
  );
  testWidgets(
    'an open confirmation cannot complete a later round after the server view changes',
    (tester) async {
      final fixture = await pump(tester),
          socket = fixture.transport.sockets.last;
      await tester.tap(find.byTooltip('Partieoptionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fall ohne Urteil abschließen'));
      await tester.pumpAndSettle();
      socket.receive(answerView(revision: 2, roundId: 'round_2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Fall abschließen'));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CompleteWithoutVerdictMessage>(), isEmpty);
      expect(fixture.room.state.snapshot!.public.roundId?.value, 'round_2');
    },
  );
}
