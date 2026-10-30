import '../support/action_text.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/design/case_stage.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/features/bench/placement_bank.dart';
import 'package:trinktribunal/features/multiplayer/courtroom.dart';
import 'package:trinktribunal/design/judge_plate.dart';
import 'package:trinktribunal/domain/models/ids.dart';

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
  for (final phase in ['numbers', 'answers', 'ordering']) {
    testWidgets(
      'touch drag places an avatar during $phase without submitting an order',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = await numbers.pump(tester, allJudges: true);
        if (phase != 'numbers') {
          final base = fixture.room.state.snapshot!;
          fixture.transport.sockets.last.receive(
            SnapshotMessage.fromJson({
              ...base.toJson(),
              'revision': 2,
              'public': {...base.public.toJson(), 'phase': phase},
            }),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(Tab).at(1));
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('unplaced-p2'));
        final target = find.byKey(const ValueKey('order-seat-0'));
        final gesture = await tester.startGesture(
          tester.getTopLeft(source) + const Offset(8, 20),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        final bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
        expect(bank.slots.first, PlayerId('p2'));
        expect(bank.unplaced, isNot(contains(PlayerId('p2'))));
        expect(
          fixture.transport.sockets.last.sent.whereType<SubmitOrderMessage>(),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a twenty-player bank scrolls upward while an avatar is dragged to an earlier seat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await numbers.pump(tester, allJudges: true);
      final base = fixture.room.state.snapshot!;
      fixture.transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'revision': 2,
          'public': {
            ...base.public.toJson(),
            'roundId': 'round_many',
            'phase': 'ordering',
            'frozenRoster': [for (var i = 1; i <= 20; i++) 'p$i'],
            'players': [
              for (var i = 1; i <= 20; i++)
                {
                  ...base.public.players.first.toJson(),
                  'playerId': 'p$i',
                  'profile': {
                    ...base.public.players.first.profile.toJson(),
                    'name': 'Player $i',
                  },
                },
            ],
          },
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(RoomCourtroom),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.widget<PlacementBank>(find.byType(PlacementBank)).onPlace!(
        PlayerId('p20'),
        19,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('placement-pool-toggle')));
      await tester.pumpAndSettle();
      final source = find.descendant(
        of: find.byKey(const ValueKey('order-seat-19')),
        matching: find.byType(Draggable<PlayerId>),
      );
      await tester.scrollUntilVisible(source, 150, scrollable: scrollable);
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(scrollable);
      final before = scroll.position.pixels;
      final gesture = await tester.startGesture(
        tester.getTopLeft(source) + const Offset(8, 20),
      );
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      final bounds = tester.getRect(find.byType(RoomCourtroom));
      await gesture.moveTo(Offset(bounds.center.dx, bounds.top + 8));
      for (var i = 0; i < 100 && scroll.position.pixels > 0; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(scroll.position.pixels, lessThan(before));
      expect(scroll.position.pixels, 0);
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('order-seat-0'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlacementBank>(find.byType(PlacementBank)).slots.first,
        PlayerId('p20'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lobby option and server start connect every own figure in the actual courtroom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await numbers.pump(
            tester,
            lobby: true,
            host: true,
            own: false,
          ),
          socket = fixture.transport.sockets.last;
      await numbers.tapText(tester, AppStrings('de').get('localGameOptions'));
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
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
      final courtroomTab = widgetWithActionText(
        Tab,
        AppStrings('de').get('roomTitle'),
      );
      expect(courtroomTab.hitTestable(), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
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
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
      final reader = started.public.players
          .firstWhere((p) => p.playerId.value == 'p2')
          .profile
          .name;
      expect(
        find.byWidgetPredicate(
          (w) => w is JudgePlate && w.profile.player.name == reader,
        ),
        findsOneWidget,
      );
      socket.receive(phase('ordering', 4));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementBank), findsOneWidget);
      final bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.onPlace, isNotNull);
      expect(bank.unplaced.map((id) => id.value), ['p1', 'p2', 'p3']);
      expect(bank.slots, everyElement(isNull));
    },
  );
  testWidgets(
    'all judges submit the last placement automatically; own sealed echo confirms only this order',
    (tester) async {
      final socket = await normal.pump(tester, snapshot: allJudgesView()),
          frames = socket.sent.length;
      var bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.unplaced.map((id) => id.value), ['p1', 'p2', 'p3', 'p4']);
      for (var index = 0; index < 100; index++) {
        bank.onPlace!(PlayerId('p1'), index % 4);
      }
      final expected = [
        PlayerId('p2'),
        PlayerId('p3'),
        PlayerId('p4'),
        PlayerId('p1'),
      ];
      expect(socket.sent.length, frames);
      socket.receive(allJudgesView(revision: 2));
      await tester.pumpAndSettle();
      for (var i = 0; i < expected.length; i++) {
        bank.onPlace!(expected[i], i);
      }
      await tester.pumpAndSettle();
      bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.slots, expected);
      expect(
        actionText(AppStrings('de').get('phoneConfirmOrder')),
        findsNothing,
      );
      final sent = socket.sent.whereType<SubmitOrderMessage>().single;
      expect(sent.order.map((id) => id.value), ['p2', 'p3', 'p4', 'p1']);
      expect(sent.expectedRevision, 2);
      expect(
        tester.widget<PlacementBank>(find.byType(PlacementBank)).onPlace,
        isNull,
      );
      socket.receive(
        allJudgesView(
          revision: 3,
          ownOrder: sent.order.map((id) => id.value).toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        actionText(AppStrings('de').get('onlineOrderConfirmed')),
        findsNothing,
      );
      expect(
        tester
            .widget<BenchView>(find.byType(BenchView))
            .pending
            .map((p) => p.value),
        ['p1', 'p3', 'p4'],
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
        tester.widget<PlacementBank>(find.byType(PlacementBank)).onPlace,
        isNotNull,
      );
      socket.receive(allJudgesView(revision: 2, pending: true));
      await tester.pumpAndSettle();
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
      expect(
        actionText(AppStrings('de').get('phoneConfirmOrder')),
        findsNothing,
      );
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
    },
  );
}
