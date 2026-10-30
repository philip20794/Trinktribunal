import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../application/online_order_controller_test.dart' show orderingView;
import 'online_numbers_test.dart' as numbers;

import 'package:trinktribunal/design/court_celebration.dart';
import 'package:trinktribunal/design/pending_order_avatar.dart';

SnapshotMessage personalView({
  required int errors,
  int cursor = 0,
  int revision = 1,
  bool host = true,
}) {
  final base = orderingView(judge: !host),
      roster = base.public.frozenRoster,
      order = errors == 4
          ? [roster[1], roster[0], roster[3], roster[2]]
          : errors == 2
          ? [roster[1], roster[0], roster[2], roster[3]]
          : roster;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'config': {
        ...base.public.config.toJson(),
        'allJudges': true,
        'factorTenths': 30,
      },
      'phase': cursor == 4 ? 'judged' : 'revealing',
      'judgeId': null,
      'readerId': host ? 'p1' : 'p2',
      'players': base.public.players
          .map((p) => {...p.toJson(), 'orderSubmitted': true})
          .toList(),
      'revealCursor': cursor,
      'revealed': [
        for (var index = 0; index < cursor; index++)
          {
            'playerId': roster[index].value,
            'number': [1, 4, 9, 12][index],
          },
      ],
    },
    'private': {
      'ownNumber': 4,
      'ownOrder': order.map((id) => id.value).toList(),
      if (cursor == 4) 'ownResult': {'errors': errors, 'sips': errors},
    },
  });
}

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final errors in [2, 4, 0]) {
    testWidgets(
      'court displays the private $errors-error order and its matching verdict',
      (tester) async {
        final fixture = await numbers.pump(
          tester,
          allJudges: true,
          textScale: 2,
        );
        final socket = fixture.transport.sockets.last;
        socket.receive(personalView(errors: errors, revision: 2));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(Tab, AppStrings('de').get('roomTitle')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<BenchView>(find.byType(BenchView)).order,
          fixture.room.state.snapshot!.private.ownOrder,
        );
        expect(
          find.text(AppStrings('de').get('phoneRevealNext')),
          findsNothing,
        );
        expect(find.text(AppStrings('de').get('verdictHeading')), findsNothing);
        socket.receive(personalView(errors: errors, cursor: 1, revision: 3));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BenchView>(find.byType(BenchView))
              .revealedNumbers
              .length,
          1,
        );
        expect(
          tester.widget<BenchView>(find.byType(BenchView)).showPositionResult,
          isFalse,
        );
        socket.receive(personalView(errors: errors, cursor: 4, revision: 4));
        await tester.pumpAndSettle();
        final bank = tester.widget<BenchView>(find.byType(BenchView));
        expect(bank.incorrect, hasLength(errors));
        expect(bank.order, fixture.room.state.snapshot!.private.ownOrder);
        expect(bank.showPositionResult, isTrue);
        expect(bank.pending, isEmpty);
        expect(
          find
              .byType(PendingOrderAvatar)
              .evaluate()
              .every((e) => !(e.widget as PendingOrderAvatar).pending),
          isTrue,
        );
        if (errors == 0) {
          expect(find.byType(CourtCelebration), findsOneWidget);
        } else {
          expect(
            find.text(
              AppStrings('de').get('drinkPersonalSips', {'count': errors}),
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.widgetWithText(FilledButton, AppStrings('de').get('confirm')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              AppStrings('de').get('drinkPersonalSips', {'count': errors}),
            ),
            findsNothing,
          );
        }
        expect(socket.sent.whereType<RevealNextMessage>(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
