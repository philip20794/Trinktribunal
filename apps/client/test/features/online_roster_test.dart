import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/features/multiplayer/roster_management.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'online_numbers_test.dart' as numbers;

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  testWidgets(
    'retired profiles do not unlock a paused game; a pending third active identity enables explicit resume',
    (tester) async {
      final f = await numbers.pump(tester, host: true, own: false),
          socket = f.transport.sockets.last,
          base = f.room.state.snapshot!;
      SnapshotMessage paused({bool added = false}) => SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': added ? 3 : 2,
        'public': {
          ...base.public.toJson(),
          'phase': 'paused',
          'pausedFrom': 'case_boundary',
          'pauseReason': 'insufficient_players',
          'roundId': null,
          'question': null,
          'frozenRoster': [],
          'pendingRoster': added ? ['p1', 'p3', 'p4'] : [],
          'completedCases': 1,
          'players': [
            for (final p in base.public.players)
              {...p.toJson(), 'active': p.playerId.value != 'p2'},
            if (added)
              {
                ...base.public.players.last.toJson(),
                'playerId': 'p4',
                'active': true,
                'profile': {
                  ...base.public.players.last.profile.toJson(),
                  'name': 'New seat',
                },
              },
          ],
        },
        'private': <String, Object?>{},
      });
      socket.receive(paused());
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings('de').get('onlinePausePlayers')),
        findsOneWidget,
      );
      final resume = find.widgetWithText(
        FilledButton,
        AppStrings('de').get('roomContinue'),
      );
      expect(tester.widget<FilledButton>(resume).onPressed, isNull);
      expect(find.text(AppStrings('de').get('restartGame')), findsNothing);
      socket.receive(paused(added: true));
      await tester.pumpAndSettle();
      await numbers.tapText(tester, AppStrings('de').get('roomContinue'));
      expect(
        socket.sent.whereType<ResumePausedMessage>().single.gameId,
        base.public.gameId,
      );
      expect(f.room.state.snapshot!.public.phase, 'paused');
    },
  );
  testWidgets(
    'host manages only the next roster; frozen bank and retired profiles remain intact',
    (tester) async {
      final f = await numbers.pump(tester, host: true, own: false),
          socket = f.transport.sockets.last,
          base = f.room.state.snapshot!;
      SnapshotMessage view({
        int revision = 2,
        String? gameId,
        List<String> pending = const ['p3', 'p1', 'p4'],
      }) => SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': revision,
        'public': {
          ...base.public.toJson(),
          'gameId': gameId ?? base.public.gameId!.value,
          'phase': 'ordering',
          'pendingRoster': pending,
          'players': [
            base.public.players[2].toJson(),
            base.public.players[0].toJson(),
            {
              ...base.public.players[2].toJson(),
              'playerId': 'p4',
              'profile': {
                ...base.public.players[2].profile.toJson(),
                'name': 'New seat',
              },
            },
            {...base.public.players[1].toJson(), 'connected': false},
          ],
        },
        'private': <String, Object?>{},
      });
      socket.receive(view());
      await tester.pumpAndSettle();
      expect(f.room.state.snapshot!.public.frozenRoster.map((id) => id.value), [
        'p1',
        'p2',
        'p3',
      ]);
      await tester.ensureVisible(find.byType(Tab).last);
      await tester.tap(find.byType(Tab).last);
      await tester.pumpAndSettle();
      final presence = find.byKey(const PageStorageKey('room-presence'));
      await tester.scrollUntilVisible(
        presence,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(of: presence, matching: find.byType(ListTile)).first,
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(OnlineRosterManagement),
        250,
        scrollable: scrollable,
      );
      expect(
        find.text(AppStrings('de').get('onlineRosterJoining')),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings('de').get('onlineRosterLeaving')),
        findsOneWidget,
      );
      final retired = base.public.players[1].profile.name,
          host = base.public.players[0].profile.name,
          other = base.public.players[2].profile.name;
      expect(
        find.byTooltip(
          AppStrings('de').get('roomManagePlayer', {'name': retired}),
        ),
        findsNothing,
      );
      final hostMenu = find.byTooltip(
        AppStrings('de').get('roomManagePlayer', {'name': host}),
      );
      await Scrollable.ensureVisible(tester.element(hostMenu), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(hostMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings('de').get('roomMoveUp')));
      await tester.pumpAndSettle();
      expect(
        socket.sent.whereType<ReorderRosterMessage>().single.playerIds.map(
          (id) => id.value,
        ),
        ['p1', 'p3', 'p4'],
      );
      expect(
        f.room.state.snapshot!.public.pendingRoster.map((id) => id.value),
        ['p3', 'p1', 'p4'],
      );
      socket.receive(view(revision: 3, pending: ['p1', 'p3', 'p4']));
      await tester.pumpAndSettle();
      Future<void> openKick() async {
        final menu = find.byTooltip(
          AppStrings('de').get('roomManagePlayer', {'name': other}),
        );
        await Scrollable.ensureVisible(tester.element(menu), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings('de').get('roomKick')));
        await tester.pumpAndSettle();
      }

      await openKick();
      await tester.tap(find.text(AppStrings('de').get('cancel')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
      await openKick();
      socket.receive(view(revision: 4, gameId: 'another_game'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            FilledButton,
            AppStrings('de').get('roomKick'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
    },
  );
}
