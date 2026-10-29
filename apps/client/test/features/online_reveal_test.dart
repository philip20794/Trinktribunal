import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/multiplayer/order_view.dart';
import 'package:trinktribunal/features/multiplayer/game_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import '../application/online_order_controller_test.dart' show orderingView;

late Catalogs catalogs;

SnapshotMessage revealView({
  bool host = true,
  int cursor = 0,
  int revision = 1,
}) {
  final base = orderingView(
        judge: !host,
        phase: 'revealing',
        revision: revision,
      ),
      recipients = base.public.frozenRoster
          .where((id) => id != base.public.judgeId)
          .toList();
  final order = [recipients[1], recipients[0], recipients[2]],
      numbers = {
        for (var index = 0; index < recipients.length; index++)
          recipients[index]: [1, 4, 6][index],
      };
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'public': {
      ...base.public.toJson(),
      'phase': cursor == 3 ? 'judged' : 'revealing',
      'judgeOrder': order.map((id) => id.value).toList(),
      'revealCursor': cursor,
      'revealed': order
          .take(cursor)
          .map((id) => {'playerId': id.value, 'number': numbers[id]})
          .toList(),
      'players': base.public.players
          .map(
            (p) => {
              ...p.toJson(),
              'profile': {...p.profile.toJson(), 'name': p.playerId.value},
              'orderSubmitted': p.playerId == base.public.judgeId,
            },
          )
          .toList(),
      if (cursor == 3)
        'result': {
          'errors': 2,
          'penalties': base.public.frozenRoster
              .map(
                (id) => {
                  'playerId': id.value,
                  'sips': id == recipients[2] ? 0 : 2,
                },
              )
              .toList(),
        },
    },
    'private': {
      if (numbers.containsKey(base.you)) 'ownNumber': numbers[base.you],
      if (base.you == base.public.judgeId)
        'ownOrder': order.map((id) => id.value).toList(),
    },
  });
}

class _Surface extends ConsumerWidget {
  const _Surface();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view =
        ref.watch(roomSessionProvider).asData?.value.snapshot ??
        ref.read(roomControllerProvider).state.snapshot;
    return Scaffold(
      body: SingleChildScrollView(
        child: view == null
            ? const SizedBox()
            : Column(
                children: [
                  RoomGameScreen(snapshot: view),
                  OnlineOrderView(snapshot: view),
                ],
              ),
      ),
    );
  }
}

Future<({RoomController room, FakeRoomSocket socket})> pump(
  WidgetTester tester, {
  bool host = true,
  SnapshotMessage? snapshot,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  addTearDown(room.dispose);
  await room.resume(testCredential());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
        catalogsProvider.overrideWith((_) async => catalogs),
      ],
      child: const MaterialApp(home: _Surface()),
    ),
  );
  final socket = transport.sockets.single;
  socket.receive(roomFixture('authenticated'));
  socket.receive(snapshot ?? revealView(host: host));
  await tester.pumpAndSettle();
  return (room: room, socket: socket);
}

void main() {
  setUpAll(() async {
    catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  testWidgets(
    'host requests one cursor; bank and score change only from committed server views',
    (tester) async {
      final fixture = await pump(tester), socket = fixture.socket;
      expect(
        tester.widget<BenchView>(find.byType(BenchView)).revealedNumbers,
        isEmpty,
      );
      final reveal = find.text(AppStrings('de').get('phoneRevealNext'));
      await Scrollable.ensureVisible(tester.element(reveal), alignment: .5);
      await tester.pumpAndSettle();
      expect(reveal.hitTestable(), findsOneWidget);
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(
        socket.sent.whereType<RevealNextMessage>().single.expectedCursor,
        0,
      );
      expect(fixture.room.state.snapshot!.public.revealCursor, 0);
      expect(
        tester.widget<BenchView>(find.byType(BenchView)).revealedNumbers,
        isEmpty,
      );
      socket.receive(revealView(cursor: 1, revision: 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BenchView>(find.byType(BenchView)).revealedNumbers.length,
        1,
      );
      expect(
        find.text(AppStrings('de').get('wrongPositionsCount', {'count': 2})),
        findsNothing,
      );
      socket.receive(revealView(cursor: 3, revision: 3));
      await tester.pumpAndSettle();
      final bank = tester.widget<BenchView>(find.byType(BenchView));
      expect(bank.revealedNumbers.length, 3);
      expect(bank.incorrect.map((id) => id.value).toSet(), {'p2', 'p3'});
      expect(
        find.text(AppStrings('de').get('wrongPositionsCount', {'count': 2})),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings('de').get('sips', {'name': 'p4', 'count': 0})),
        findsOneWidget,
      );
      expect(find.text(AppStrings('de').get('phoneRevealNext')), findsNothing);
    },
  );
  testWidgets('judge without host role advances the committed public cursor', (
    tester,
  ) async {
    final fixture = await pump(tester, host: false);
    final button = find.text(AppStrings('de').get('phoneRevealNext'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      fixture.socket.sent.whereType<RevealNextMessage>().single.expectedCursor,
      0,
    );
    expect(fixture.room.state.snapshot!.public.revealCursor, 0);
  });
}
