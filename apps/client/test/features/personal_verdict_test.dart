import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../application/online_order_controller_test.dart' show orderingView;
import 'online_reveal_test.dart' as normal;

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
    normal.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  final vector = [2, 4, 0, 0];
  for (var index = 0; index < vector.length; index++) {
    final errors = vector[index];
    testWidgets(
      'personal result ${index + 1} displays only own $errors after full committed reveal',
      (tester) async {
        final fixture = await normal.pump(
              tester,
              snapshot: personalView(errors: errors),
            ),
            socket = fixture.socket;
        expect(
          find.text(
            AppStrings('de').get('onlinePersonalErrors', {'count': errors}),
          ),
          findsNothing,
        );
        var bank = tester.widget<BenchView>(find.byType(BenchView));
        expect(bank.order, fixture.room.state.snapshot!.public.frozenRoster);
        expect(bank.revealedNumbers, isEmpty);
        expect(bank.onMove, isNull);
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
        socket.receive(personalView(errors: errors, cursor: 1, revision: 2));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BenchView>(find.byType(BenchView))
              .revealedNumbers
              .length,
          1,
        );
        expect(
          find.text(
            AppStrings('de').get('onlinePersonalSips', {'count': errors}),
          ),
          findsNothing,
        );
        socket.receive(personalView(errors: errors, cursor: 4, revision: 3));
        await tester.pumpAndSettle();
        expect(
          find.text(
            AppStrings('de').get('onlinePersonalErrors', {'count': errors}),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStrings('de').get('onlinePersonalSips', {'count': errors}),
          ),
          findsOneWidget,
        );
        for (final other in {0, 2, 4}.difference({errors})) {
          expect(
            find.text(
              AppStrings('de').get('onlinePersonalSips', {'count': other}),
            ),
            findsNothing,
          );
        }
        bank = tester.widget<BenchView>(find.byType(BenchView));
        expect(bank.revealedNumbers.length, 4);
        expect(bank.incorrect, isEmpty);
        expect(fixture.room.state.snapshot!.public.result, isNull);
        expect(
          find.text(AppStrings('de').get('phoneRevealNext')),
          findsNothing,
        );
      },
    );
  }
  testWidgets('reader receives their own result and can guide reveal', (
    tester,
  ) async {
    final fixture = await normal.pump(
      tester,
      snapshot: personalView(errors: 2, host: false),
    );
    final button = find.text(AppStrings('de').get('phoneRevealNext'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      fixture.socket.sent.whereType<RevealNextMessage>().single.expectedCursor,
      0,
    );
    fixture.socket.receive(
      personalView(errors: 2, host: false, cursor: 4, revision: 2),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings('de').get('onlinePersonalSips', {'count': 2})),
      findsOneWidget,
    );
  });
}
