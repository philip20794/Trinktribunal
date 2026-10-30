import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/features/multiplayer/courtroom.dart';
import 'package:trinktribunal/features/multiplayer/lobby_bench.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;
import 'online_numbers_test.dart' show view;

SnapshotMessage lobby(int count) {
  final base = view(lobby: true, allJudges: true);
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'public': {
      ...base.public.toJson(),
      'players': [
        for (var i = 1; i <= count; i++)
          {
            ...base.public.players.first.toJson(),
            'playerId': 'p$i',
            'profile': {
              ...base.public.players.first.profile.toJson(),
              'name': 'Alexandra Beispiel $i',
            },
          },
      ],
    },
  });
}

void main() {
  for (final scenario in [
    (count: 6, size: const Size(360, 800), columns: 3),
    (count: 8, size: const Size(360, 560), columns: 3),
    (count: 12, size: const Size(390, 650), columns: 4),
    (count: 20, size: const Size(900, 800), columns: 4),
  ]) {
    testWidgets(
      '${scenario.count} players fit in ${scenario.columns} columns',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          accessibilityHost(
            RoomCourtroom(snapshot: lobby(scenario.count)),
            textScale: 1,
            size: scenario.size,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LobbyBench), findsOneWidget);
        final portraits = find.byType(AvatarView);
        expect(portraits, findsNWidgets(scenario.count));
        final first = tester.getRect(portraits.first);
        for (var col = 1; col < scenario.columns; col++) {
          expect(
            tester.getRect(portraits.at(col)).top,
            closeTo(first.top, .01),
          );
        }
        expect(
          tester.getRect(portraits.at(scenario.columns)).top,
          greaterThan(first.bottom),
        );
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.maxScrollExtent, closeTo(0, .01));
        for (final avatar in tester.widgetList<AvatarView>(portraits)) {
          expect(
            avatar.size,
            inInclusiveRange(
              LobbyBench.minAvatarSize,
              LobbyBench.maxAvatarSize,
            ),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'large text and a full small screen keep everyone reachable after resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        accessibilityHost(RoomCourtroom(snapshot: lobby(20)), textScale: 2),
      );
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(320, 360));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      final portraits = find.byType(AvatarView);
      for (final avatar in tester.widgetList<AvatarView>(portraits)) {
        expect(
          avatar.size,
          inInclusiveRange(LobbyBench.minAvatarSize, LobbyBench.maxAvatarSize),
        );
      }
      await Scrollable.ensureVisible(tester.element(portraits.last));
      await tester.pumpAndSettle();
      expect(portraits.last.hitTestable(), findsOneWidget);
      expect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data == 'Alexandra Beispiel 20' &&
                  widget.maxLines == 2,
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
