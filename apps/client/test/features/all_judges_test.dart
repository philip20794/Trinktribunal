import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../application/online_order_controller_test.dart' show orderingView;
import 'online_order_test.dart' as normal;
import 'online_numbers_test.dart' as numbers;

SnapshotMessage allJudgesView({
  List<String>? ownOrder,
  int revision = 1,
  bool pending = false,
  bool reader = false,
}) {
  final base = orderingView();
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': revision,
    'public': {
      ...base.public.toJson(),
      'config': {...base.public.config.toJson(), 'allJudges': true},
      'judgeId': null,
      'readerId': reader ? 'p2' : 'p1',
      'frozenRoster': pending ? ['p1', 'p3', 'p4'] : ['p1', 'p2', 'p3', 'p4'],
      'players': base.public.players
          .map(
            (p) => {
              ...p.toJson(),
              'orderSubmitted': ownOrder != null && p.playerId == base.you,
            },
          )
          .toList(),
    },
    'private': {if (!pending) 'ownNumber': 2, 'ownOrder': ?ownOrder},
  });
}

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  testWidgets(
    'lobby option and server start connect every own figure in the actual courtroom',
    (tester) async {
      final fixture = await numbers.pump(
            tester,
            lobby: true,
            host: true,
            own: false,
          ),
          socket = fixture.transport.sockets.last;
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pumpAndSettle();
      await numbers.tapText(tester, AppStrings('de').get('onlineSaveSettings'));
      final config = socket.sent.whereType<SetConfigMessage>().single.config;
      expect(config.allJudges, isTrue);
      final base = fixture.room.state.snapshot!;
      socket.receive(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'revision': 2,
          'public': {...base.public.toJson(), 'config': config.toJson()},
        }),
      );
      await tester.pumpAndSettle();
      await numbers.tapText(tester, AppStrings('de').get('startHearing'));
      expect(socket.sent.whereType<StartGameMessage>(), hasLength(1));
      final started = numbers.view(host: true);
      SnapshotMessage phase(String phase, int revision) =>
          SnapshotMessage.fromJson({
            ...started.toJson(),
            'revision': revision,
            'public': {
              ...started.public.toJson(),
              'phase': phase,
              'config': config.toJson(),
              'judgeId': null,
              'readerId': 'p2',
            },
            'private': {'ownNumber': 2},
          });
      socket.receive(phase('numbers', 3));
      await tester.pumpAndSettle();
      expect(fixture.room.state.snapshot!.public.phase, 'numbers');
      await tester.scrollUntilVisible(
        find.byType(PrivateNumber),
        -250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.widget<PrivateNumber>(find.byType(PrivateNumber)).number,
        isNull,
      );
      final reader = started.public.players
          .firstWhere((p) => p.playerId.value == 'p2')
          .profile
          .name;
      expect(
        find.text(AppStrings('de').get('onlineReader', {'name': reader})),
        findsOneWidget,
      );
      socket.receive(phase('ordering', 4));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(BenchView),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final bank = tester.widget<BenchView>(find.byType(BenchView));
      expect(bank.onMove, isNotNull);
      expect(bank.order.map((id) => id.value), ['p1', 'p2', 'p3']);
    },
  );
  testWidgets(
    'all judges keep their own figure and 100 moves local; own sealed echo locks only this order',
    (tester) async {
      final socket = await normal.pump(tester, snapshot: allJudgesView()),
          frames = socket.sent.length;
      var bank = tester.widget<BenchView>(find.byType(BenchView));
      expect(bank.order.map((id) => id.value), ['p1', 'p2', 'p3', 'p4']);
      expect(bank.onMove, isNotNull);
      for (var index = 0; index < 100; index++) {
        bank.onMove!(0, 3);
      }
      await tester.pumpAndSettle();
      expect(socket.sent.length, frames);
      bank = tester.widget<BenchView>(find.byType(BenchView));
      bank.onMove!(0, 3);
      await tester.pumpAndSettle();
      socket.receive(allJudgesView(revision: 2));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BenchView>(find.byType(BenchView))
            .order
            .map((id) => id.value),
        ['p2', 'p3', 'p4', 'p1'],
      );
      final confirm = AppStrings('de').get('phoneConfirmOrder');
      await normal.tapText(tester, confirm);
      await tester.tap(find.text(AppStrings('de').get('cancel')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
      await normal.tapText(tester, confirm);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, confirm),
        ),
      );
      await tester.pumpAndSettle();
      final sent = socket.sent.whereType<SubmitOrderMessage>().single;
      expect(sent.order.map((id) => id.value), ['p2', 'p3', 'p4', 'p1']);
      expect(sent.expectedRevision, 2);
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
      socket.receive(
        allJudgesView(
          revision: 3,
          ownOrder: sent.order.map((id) => id.value).toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings('de').get('onlineOrderConfirmed')),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings('de').get('onlineOrderSubmitted')),
        findsOneWidget,
      );
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
    },
  );
  testWidgets(
    'reader owns an ordinary order; an observer outside the frozen roster has no editable bank',
    (tester) async {
      final socket = await normal.pump(
        tester,
        snapshot: allJudgesView(reader: true),
      );
      expect(
        tester.widget<BenchView>(find.byType(BenchView)).onMove,
        isNotNull,
      );
      socket.receive(allJudgesView(revision: 2, pending: true));
      await tester.pumpAndSettle();
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
      expect(
        find.text(AppStrings('de').get('phoneConfirmOrder')),
        findsNothing,
      );
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
    },
  );
}
