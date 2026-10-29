import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/design/case_stage.dart';

import '../support/hold_action.dart';

import 'package:trinktribunal/features/multiplayer/game_privacy.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'online_numbers_test.dart' as numbers;
import 'online_court_actions_test.dart' show phase;

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final allJudges in [false, true]) {
    for (final player in ['p1', 'p2', 'p3']) {
      testWidgets(
        'broadcast case changes select case tab and conceal number: $player / allJudges=$allJudges',
        (tester) async {
          final fixture = await numbers.pump(
            tester,
            playerId: player,
            allJudges: allJudges,
          );
          final socket = fixture.transport.sockets.last,
              base = fixture.room.state.snapshot!;
          final tabs = DefaultTabController.of(
            tester.element(find.byType(RoomGamePrivacy)),
          );
          SnapshotMessage next(
            String state,
            int revision, {
            int completed = 1,
          }) {
            final snapshot = phase(
              base,
              state,
              revision,
              allJudges: allJudges,
              ready: true,
              ownOrder: ['p1', 'p2', 'p3'],
            );
            return SnapshotMessage.fromJson({
              ...snapshot.toJson(),
              'public': {
                ...snapshot.public.toJson(),
                'roundId': 'round_$completed',
                'completedCases': completed,
                'judgeId': allJudges ? null : 'p2',
                'readerId': allJudges ? 'p2' : null,
              },
              'private': {
                ...snapshot.private.toJson(),
                if (allJudges || player != 'p2') 'ownNumber': 7,
              },
            });
          }

          expect(tabs.length, (allJudges ? 3 : 2) + (player == 'p1' ? 1 : 0));
          expect(tabs.index, allJudges ? 2 : 1);
          final holding = await startChargedHold(
            tester,
            find.text(AppStrings('de').get('holdToReveal')),
          );
          expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
          tabs.animateTo(0);
          await tester.pumpAndSettle();
          await holding.up();
          // Server commits next case and rotates to a non-host guide.
          socket.receive(next('numbers', 2));
          await tester.pumpAndSettle();
          expect(tabs.index, allJudges ? 2 : 1);
          if (find.byType(FlipCase).evaluate().isNotEmpty) {
            expect(
              tester.widget<FlipCase>(find.byType(FlipCase)).number,
              isNull,
            );
          }
          // Reroll is the same case: no forced navigation away from profile.
          tabs.animateTo(0);
          await tester.pumpAndSettle();
          socket.receive(next('answers', 3));
          await tester.pumpAndSettle();
          expect(tabs.index, 0);
          socket.receive(next('ordering', 4));
          await tester.pumpAndSettle();
          expect(tabs.index, allJudges ? 1 : 0);
          socket.receive(next('judged', 5));
          await tester.pumpAndSettle();
          expect(tabs.index, 1);
          if (allJudges) {
            tabs.animateTo(2);
            await tester.pumpAndSettle();
          }
          final advance = find.text(AppStrings('de').get('nextJudge'));
          if (player == 'p2') {
            expect(advance.hitTestable(), findsOneWidget);
            await holdAction(tester, advance);
            await tester.pumpAndSettle();
            expect(
              socket.sent
                  .whereType<CompleteCaseMessage>()
                  .single
                  .expectedRevision,
              5,
            );
            expect(fixture.room.state.snapshot!.public.completedCases, 1);
          } else {
            expect(advance, findsNothing);
          }
          tabs.animateTo(0);
          await tester.pumpAndSettle();
          socket.receive(next('numbers', 6, completed: 2));
          await tester.pumpAndSettle();
          expect(tabs.index, allJudges ? 2 : 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
