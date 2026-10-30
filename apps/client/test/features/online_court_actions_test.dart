import '../support/action_text.dart';
import '../support/hold_action.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/features/bench/placement_bank.dart';

import 'online_numbers_test.dart' as numbers;

SnapshotMessage phase(
  SnapshotMessage base,
  String value,
  int revision, {
  required bool allJudges,
  bool ready = false,
  List<String>? ownOrder,
}) {
  final roster = base.public.frozenRoster;
  final recipients = roster
      .where((id) => allJudges || id != base.public.judgeId)
      .toList();
  final revealed = value == 'judged';
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'phase': value,
      'config': {...base.public.config.toJson(), 'allJudges': allJudges},
      'judgeId': allJudges ? null : base.public.judgeId!.value,
      'readerId': allJudges ? base.public.hostId.value : null,
      if (!allJudges && ['revealing', 'judged'].contains(value))
        'judgeOrder': recipients.map((id) => id.value).toList(),
      'players': base.public.players
          .map(
            (p) => {
              ...p.toJson(),
              'ready': ready,
              'orderSubmitted': ownOrder != null,
            },
          )
          .toList(),
      'revealCursor': revealed ? recipients.length : 0,
      'revealed': revealed
          ? [
              for (var i = 0; i < recipients.length; i++)
                {'playerId': recipients[i].value, 'number': i + 1},
            ]
          : [],
      if (revealed && !allJudges)
        'result': {
          'errors': 0,
          'penalties': [
            for (final id in roster) {'playerId': id.value, 'sips': 0},
          ],
        },
    },
    'private': {
      if (allJudges) 'ownNumber': 2,
      'ownOrder': ?ownOrder,
      if (revealed && allJudges) 'ownResult': {'errors': 0, 'sips': 0},
    },
  });
}

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final language in ['de', 'en']) {
    for (final host in [false, true]) {
      for (final allJudges in [false, true]) {
        testWidgets(
          'fixed court actions and tab scope: $language, host=$host, allJudges=$allJudges, 200 percent',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(360, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final fixture = await numbers.pump(
              tester,
              host: host,
              allJudges: allJudges,
              own: false,
              uiLanguage: language,
              textScale: 2,
            );
            final socket = fixture.transport.sockets.last,
                base = fixture.room.state.snapshot!,
                strings = AppStrings(language);
            Future<void> receive(
              String value,
              int revision, {
              bool ready = false,
              List<String>? ownOrder,
            }) async {
              socket.receive(
                phase(
                  base,
                  value,
                  revision,
                  allJudges: allJudges,
                  ready: ready,
                  ownOrder: ownOrder,
                ),
              );
              await tester.pumpAndSettle();
            }

            Future<void> press(String key) async {
              final target = actionText(strings.get(key));
              expect(target, findsOneWidget);
              expect(target.hitTestable(), findsOneWidget);
              if (key == 'nextJudge') {
                await holdAction(tester, target);
              } else {
                await tester.tap(target);
              }
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            if (!allJudges) {
              await receive('answers', 2);
              if (host) {
                await press('nextJudge');
                expect(
                  socket.sent.whereType<CompleteWithoutVerdictMessage>(),
                  hasLength(1),
                );
              } else {
                expect(actionText(strings.get('nextJudge')), findsNothing);
              }
              expect(find.byType(Tab), findsNWidgets(host ? 3 : 2));
              return;
            }
            await receive('answers', 2);
            expect(actionText(strings.get('onlineAnswerReady')), findsNothing);
            await tester.ensureVisible(
              widgetWithActionText(Tab, strings.get('roomMeTab')),
            );
            await tester.tap(
              widgetWithActionText(Tab, strings.get('roomMeTab')),
            );
            await tester.pumpAndSettle();
            expect(actionText(strings.get('onlineAnswerReady')), findsNothing);
            await tester.tap(
              widgetWithActionText(Tab, strings.get('roomTitle')),
            );
            await tester.pumpAndSettle();
            await receive('answers', 3, ready: true);
            expect(actionText(strings.get('phoneBeginOrder')), findsNothing);
            await receive('ordering', 4);
            final ownsOrder = host || allJudges;
            List<String>? ownOrder;
            if (ownsOrder) {
              final bank = tester.widget<PlacementBank>(
                find.byType(PlacementBank),
              );
              final pool = List.of(bank.unplaced);
              for (var i = 0; i < pool.length; i++) {
                bank.onPlace!(pool[i], i);
              }
              await tester.pumpAndSettle();
              expect(
                actionText(strings.get('phoneConfirmOrder')),
                findsNothing,
              );
              final sent = socket.sent.whereType<SubmitOrderMessage>().single;
              expect(sent.expectedRevision, 4);
              ownOrder = sent.order.map((id) => id.value).toList();
              expect(ownOrder.length, allJudges ? 3 : 2);
            } else {
              expect(
                actionText(strings.get('phoneConfirmOrder')),
                findsNothing,
              );
            }
            await receive('revealing', 5, ownOrder: ownOrder);
            expect(actionText(strings.get('phoneRevealNext')), findsNothing);
            await receive('judged', 6, ownOrder: ownOrder);
            await tester.tap(
              widgetWithActionText(Tab, strings.get('caseTabTitle')),
            );
            await tester.pumpAndSettle();
            expect(actionText(strings.get('holdToReveal')), findsNothing);
            if (host) {
              await press('nextJudge');
              expect(
                socket.sent
                    .whereType<CompleteCaseMessage>()
                    .single
                    .expectedRevision,
                6,
              );
            } else {
              expect(actionText(strings.get('nextJudge')), findsNothing);
            }
            expect(fixture.room.state.snapshot!.public.phase, 'judged');
            expect(
              socket.sent.whereType<CompleteWithoutVerdictMessage>(),
              isEmpty,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
